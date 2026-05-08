import Foundation
import UIKit
import UserNotifications
import Supabase
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - ModeratorReportService
//
// The founder's "always-on" inbox. Subscribes to Supabase Realtime
// for INSERTs into `public.user_reports`, fires a time-sensitive
// local notification per event, and keeps a published count of
// pending reports so the Profile tab can show a badge.
//
// Activates only when the signed-in account has
// `profiles.is_verified = true`. Real users never reach this code
// path — `bind(currentUserId:)` checks the flag and tears down
// without subscribing if the user isn't a moderator.
//
// Subscription model mirrors `ClaimNotificationService`:
//   • `realtimeV2.channel` + `postgresChange(AnyAction.self, ...)`
//     filtered to schema=public, table=user_reports
//   • `for await change in changes { guard case .insert(let action) }`
//     pulls fields via `action.record["..."]?.stringValue`.
//
// Privacy:
//   The reporter's identity is shown to moderators (so they can
//   triage repeat reporters), but never to the reported user. The
//   reported user only ever sees that an action was taken.
// ══════════════════════════════════════════════════════════════════

@MainActor
@Observable
final class ModeratorReportService {
    static let shared = ModeratorReportService()

    /// Number of `status='pending'` rows in `user_reports`. Bind to
    /// a badge on the Profile tab when the user is a moderator.
    private(set) var pendingCount: Int = 0

    /// Latest error string, mostly for diagnostics. Cleared on each
    /// successful refresh.
    private(set) var lastError: String?

    /// True while the realtime subscription is live. Used by the
    /// inbox UI to render a small "live" pulse.
    private(set) var isSubscribed: Bool = false

    private let logger = Logger(subsystem: "com.freshli.app", category: "ModeratorReports")
    private let client = AppSupabase.client

    private var channel: RealtimeChannelV2?
    private var listenTask: Task<Void, Never>?
    /// The userId we last successfully bound for. `nil` when not
    /// bound. Used to short-circuit redundant `bind` calls.
    private var subscribedUserId: UUID?
    /// Cached `is_verified` for the bound user — set after the
    /// gating check so we don't re-query Supabase on every
    /// `pendingCount` refresh.
    private var moderatorVerified = false

    private init() {}

    // MARK: - Lifecycle

    /// Bind / re-bind to the current user. Must be called whenever
    /// `AuthManager.currentUserId` changes. Pass `nil` on sign-out
    /// to tear down. Idempotent for the same user id.
    func bind(currentUserId: UUID?) {
        guard subscribedUserId != currentUserId else { return }
        // Tear down any previous subscription before we re-evaluate.
        Task { await unbind() }

        guard let userId = currentUserId else { return }
        subscribedUserId = userId

        // Async gate — only verified moderators get the realtime
        // subscription. We do the check off-the-bat so unverified
        // users never reach the channel-creation cost.
        listenTask = Task { [weak self] in
            await self?.activateIfModerator(userId: userId)
        }
    }

    /// Tear down the subscription and clear all state.
    func unbind() async {
        listenTask?.cancel()
        listenTask = nil
        if let channel {
            await channel.unsubscribe()
        }
        channel = nil
        isSubscribed = false
        moderatorVerified = false
        pendingCount = 0
        subscribedUserId = nil
    }

    /// Force a refresh of the pending-count badge — used by the
    /// inbox view's "pull to refresh" and after the moderator
    /// resolves a report.
    func refreshPendingCount() async {
        guard moderatorVerified else { return }
        do {
            let count: Int = try await client.rpc("pending_user_report_count")
                .execute()
                .value
            pendingCount = count
        } catch {
            logger.warning("pending_user_report_count failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Activation

    private func activateIfModerator(userId: UUID) async {
        // Look up `profiles.is_verified` directly — RLS allows users
        // to read their own profile row. Anything other than `true`
        // means we silently exit; this code path is harmless to
        // every non-moderator user.
        struct VerifiedSlice: Decodable {
            let isVerified: Bool?
            enum CodingKeys: String, CodingKey { case isVerified = "is_verified" }
        }
        let slice: VerifiedSlice
        do {
            slice = try await client
                .from("profiles")
                .select("is_verified")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
        } catch {
            logger.warning("Verification check failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        guard slice.isVerified == true else {
            logger.debug("User is not a moderator — skipping report subscription")
            return
        }

        moderatorVerified = true
        await refreshPendingCount()
        await streamReports(userId: userId)
    }

    private func streamReports(userId: UUID) async {
        let channel = client.realtimeV2.channel("user-reports-mod-\(userId.uuidString.prefix(8))")
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "user_reports"
        )

        do {
            try await channel.subscribeWithError()
        } catch {
            logger.warning("Realtime subscribe failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        self.channel = channel
        isSubscribed = true
        logger.info("Subscribed to user_reports realtime channel")

        for await change in changes {
            guard case .insert(let action) = change else { continue }
            guard
                let reportedIdString = action.record["reported_user_id"]?.stringValue,
                let reportedId       = UUID(uuidString: reportedIdString),
                let reporterIdString = action.record["reporter_id"]?.stringValue,
                let reporterId       = UUID(uuidString: reporterIdString),
                let reasonRaw        = action.record["reason"]?.stringValue
            else { continue }

            let listingIdString = action.record["listing_id"]?.stringValue
            let details         = action.record["details"]?.stringValue
            let reason          = ReportReason(rawValue: reasonRaw) ?? .other

            await handleNewReport(
                reportedUserId: reportedId,
                reporterId: reporterId,
                reason: reason,
                details: details,
                listingId: listingIdString.flatMap(UUID.init(uuidString:))
            )
        }
    }

    private func handleNewReport(
        reportedUserId: UUID,
        reporterId: UUID,
        reason: ReportReason,
        details: String?,
        listingId: UUID?
    ) async {
        pendingCount += 1

        let reportedName  = (try? await fetchDisplayName(reporterId)) ?? String(localized: "A neighbour")
        let reportedTarget = (try? await fetchDisplayName(reportedUserId))
            ?? String(localized: "another user")

        scheduleLocalNotification(
            reason: reason,
            reporterName: reportedName,
            reportedName: reportedTarget,
            details: details
        )
        logger.info("New user report: \(reason.rawValue, privacy: .public) by \(reportedName, privacy: .public) about \(reportedTarget, privacy: .public)")
    }

    private func fetchDisplayName(_ userId: UUID) async throws -> String? {
        let profile = try await ProfileService().fetchProfile(userId: userId)
        return profile.displayName
    }

    // MARK: - Local notification

    private func scheduleLocalNotification(
        reason: ReportReason,
        reporterName: String,
        reportedName: String,
        details: String?
    ) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "🚩 New community report")
        // Body summarises who reported whom and the category.
        let bodyLine = String(
            localized: "\(reporterName) reported \(reportedName) for \(reason.displayName)."
        )
        if let details, !details.isEmpty {
            content.body = bodyLine + "\n" + String(details.prefix(160))
        } else {
            content.body = bodyLine
        }
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = "moderator.report.received"
        content.userInfo = [
            "kind": "moderator.report.received",
            "reason": reason.rawValue,
            "reporter": reporterName,
            "reported": reportedName
        ]

        let request = UNNotificationRequest(
            identifier: "moderator.report.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { [logger] error in
            if let error {
                logger.warning("Moderator notification failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
