import Foundation
import UIKit
import UserNotifications
import Supabase
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - PingService
//
// Real area-scoped "Ping Your Pod" — replaces the old in-memory
// `CommunityPodsService` mock that never broadcast anything.
//
// Two responsibilities:
//
//   1. **Send** — when the current user submits a Ping form,
//      INSERT a row into `ingredient_requests` with their
//      `current_area_id` as the geofence. RLS guarantees only
//      neighbours in that area see it.
//
//   2. **Listen** — every signed-in user with a confirmed area
//      subscribes to a Supabase Realtime channel filtered to
//      INSERTs in `public.ingredient_requests` where
//      `area_id = my_current_area_id` AND `requester_id != me`.
//      On a hit, fire a time-sensitive local notification so the
//      user can step in immediately. Same channel pattern as
//      `ClaimNotificationService` and `ModeratorReportService`.
//
// Privacy: the requester's display name is anonymised to
// "first name + last initial" before notification (matches the
// existing claims-notification pattern). Their UUID is logged but
// never shown to other users.
// ══════════════════════════════════════════════════════════════════

@MainActor
@Observable
final class PingService {
    static let shared = PingService()

    private(set) var isSending: Bool = false
    private(set) var lastError: String?
    private(set) var isSubscribed: Bool = false

    private let client = AppSupabase.client
    private let logger = Logger(subsystem: "com.freshli.app", category: "Pings")

    private var channel: RealtimeChannelV2?
    private var listenTask: Task<Void, Never>?
    private var subscribedUserId: UUID?
    private var subscribedAreaId: UUID?

    private init() {}

    // MARK: - Lifecycle

    /// Bind / re-bind the Realtime listener to the current user.
    /// Idempotent — calling with the same userId+areaId is a no-op.
    /// Pass `nil` userId on sign-out to tear down.
    func bind(currentUserId: UUID?) {
        guard subscribedUserId != currentUserId else { return }
        Task { await unbind() }

        guard let userId = currentUserId else { return }
        subscribedUserId = userId

        listenTask = Task { [weak self] in
            await self?.activate(userId: userId)
        }
    }

    func unbind() async {
        listenTask?.cancel()
        listenTask = nil
        if let channel { await channel.unsubscribe() }
        channel = nil
        isSubscribed = false
        subscribedUserId = nil
        subscribedAreaId = nil
    }

    // MARK: - Send

    /// Insert a new ingredient request scoped to the user's
    /// confirmed area. Returns `true` on success; on failure
    /// `lastError` carries a localised message.
    @discardableResult
    func sendPing(
        itemName: String,
        quantity: String,
        urgency: String,
        note: String?,
        karmaCost: Int
    ) async -> Bool {
        isSending = true
        lastError = nil
        defer { isSending = false }

        guard let userId = subscribedUserId else {
            lastError = String(localized: "Please sign in to send a ping.")
            return false
        }
        guard let areaId = AreaService.shared.currentArea?.id else {
            lastError = String(localized: "Set your neighbourhood in the Community tab before pinging.")
            return false
        }

        // Expires 24 hours from now — keeps the table tidy and the
        // requester's expectations realistic.
        let expiry = Date().addingTimeInterval(60 * 60 * 24)
        let formatter = ISO8601DateFormatter()

        let payload: [String: AnyJSON] = [
            "requester_id": .string(userId.uuidString),
            "area_id":      .string(areaId.uuidString),
            "item_name":    .string(itemName.trimmingCharacters(in: .whitespacesAndNewlines)),
            "quantity":     .string(quantity.isEmpty ? "1" : quantity),
            "urgency":      .string(urgency),
            "note":         note.map { .string($0) } ?? .null,
            "karma_cost":   .integer(karmaCost),
            "status":       .string("open"),
            "expires_at":   .string(formatter.string(from: expiry))
        ]

        do {
            try await client.from("ingredient_requests").insert(payload).execute()
            logger.info("Ping sent for \(itemName, privacy: .public) in area \(areaId.uuidString.prefix(8), privacy: .public)")
            return true
        } catch {
            let msg = error.localizedDescription.lowercased()
            logger.error("Ping send failed: \(error.localizedDescription, privacy: .public)")
            if msg.contains("row-level security") || msg.contains("401") || msg.contains("jwt") {
                lastError = String(localized: "Your session expired. Please sign in again.")
            } else {
                lastError = String(localized: "Couldn't send your ping. Please try again.")
            }
            return false
        }
    }

    // MARK: - Listen (realtime → local notification)

    private func activate(userId: UUID) async {
        // Hydrate the user's current_area_id so we can filter inbound.
        if AreaService.shared.currentArea == nil {
            _ = try? await AreaService.shared.loadCurrentArea(for: userId)
        }
        guard let areaId = AreaService.shared.currentArea?.id else {
            logger.debug("No current_area_id — skipping ping subscription")
            return
        }
        subscribedAreaId = areaId
        await streamPings(userId: userId, areaId: areaId)
    }

    private func streamPings(userId: UUID, areaId: UUID) async {
        let channel = client.realtimeV2.channel("pings-area-\(areaId.uuidString.prefix(8))")
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "ingredient_requests"
        )

        do {
            try await channel.subscribeWithError()
        } catch {
            logger.warning("Realtime subscribe failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        self.channel = channel
        isSubscribed = true
        logger.info("Subscribed to ingredient_requests for area \(areaId.uuidString.prefix(8), privacy: .public)")

        for await change in changes {
            guard case .insert(let action) = change else { continue }

            // Filter client-side by area + not-self. The server-side
            // RLS already restricts what we can SELECT, but the
            // realtime stream surfaces every INSERT we're allowed
            // to read — including our own. Skip the latter so the
            // requester doesn't get a notification for their own
            // ping.
            guard
                let requesterIdString = action.record["requester_id"]?.stringValue,
                let requesterId = UUID(uuidString: requesterIdString),
                requesterId != userId,
                let pingAreaIdString = action.record["area_id"]?.stringValue,
                let pingAreaId = UUID(uuidString: pingAreaIdString),
                pingAreaId == areaId,
                let itemName = action.record["item_name"]?.stringValue
            else { continue }

            let urgency = action.record["urgency"]?.stringValue ?? "today"
            let note    = action.record["note"]?.stringValue

            let displayName = (try? await fetchDisplayName(requesterId)) ?? String(localized: "A neighbour")
            let anonymised = Self.anonymise(displayName)

            scheduleLocalNotification(
                requesterName: anonymised,
                itemName: itemName,
                urgency: urgency,
                note: note
            )
            logger.info("Ping notified for \(itemName, privacy: .public) by \(anonymised, privacy: .public)")
        }
    }

    private func fetchDisplayName(_ userId: UUID) async throws -> String? {
        let profile = try await ProfileService().fetchProfile(userId: userId)
        return profile.displayName
    }

    // MARK: - Local notification

    private func scheduleLocalNotification(
        requesterName: String,
        itemName: String,
        urgency: String,
        note: String?
    ) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "🥕 \(requesterName) needs \(itemName)")
        let urgencyText = Self.urgencyDisplay(urgency)
        if let note, !note.isEmpty {
            content.body = "\(urgencyText) — \(note)"
        } else {
            content.body = String(localized: "\(urgencyText). Help out and earn Karma Credits.")
        }
        content.sound = .default
        // `.timeSensitive` so the notification can break through
        // Focus modes — pings are inherently time-bounded.
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = "ping.received"
        content.userInfo = [
            "kind": "ping.received",
            "itemName": itemName,
            "requester": requesterName,
            "urgency": urgency
        ]

        let request = UNNotificationRequest(
            identifier: "ping.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { [logger] error in
            if let error {
                logger.warning("Ping notification failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private static func urgencyDisplay(_ raw: String) -> String {
        switch raw {
        case "now":       return String(localized: "Needed right now")
        case "today":     return String(localized: "Needed today")
        case "this_week": return String(localized: "Needed this week")
        default:          return String(localized: "Needs your help")
        }
    }

    // MARK: - Anonymisation

    /// "Sarah Johnson" → "Sarah J". Single-word names returned as-is.
    private static func anonymise(_ fullName: String) -> String {
        let parts = fullName.split(separator: " ").map(String.init)
        guard parts.count >= 2, let first = parts.first, let last = parts.last,
              !last.isEmpty else {
            return fullName
        }
        return "\(first) \(last.prefix(1))"
    }
}
