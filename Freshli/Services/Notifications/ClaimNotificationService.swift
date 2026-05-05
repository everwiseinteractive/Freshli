import Foundation
import UIKit
import UserNotifications
import Supabase
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - ClaimNotificationService
//
// When a community member claims one of the user's listings, fire two
// kinds of feedback:
//
//   1. **Local notification** — delivered immediately via
//      `UNUserNotificationCenter`. Works whether the app is in the
//      background, locked, or sitting on Home Screen. The schedule
//      runs on every claim event the Supabase Realtime channel
//      surfaces, so the listing creator always finds out within
//      seconds — without depending on a server-side APNs pipeline
//      that hasn't been deployed yet.
//
//   2. **In-app celebration popup** — when the creator is foreground,
//      route a delightful celebration through `PopupCenter` (above
//      sheets, with the staggered animation cascade and one clear
//      acknowledge button).
//
// Subscription model:
//   On `currentUserId.didSet` (and after auth state goes
//   `.authenticated`), the service subscribes to the `claims` table
//   via Supabase Realtime v2. We then fetch the parent listing for
//   each insert and only act if the listing's `user_id` matches the
//   current user.
//
// Privacy:
//   Only the listing-creator user receives the event. The claimer's
//   display name is anonymised to "first name + last initial".
// ══════════════════════════════════════════════════════════════════

@MainActor
@Observable
final class ClaimNotificationService {
    static let shared = ClaimNotificationService()

    private let logger = Logger(subsystem: "com.freshli.app", category: "ClaimNotification")
    private var channel: RealtimeChannelV2?
    private var listenTask: Task<Void, Never>?
    private var subscribedUserId: UUID?

    private init() {}

    // MARK: - Lifecycle

    /// Subscribe (or re-subscribe) to claim events for the given listing-
    /// creator user. Idempotent — calling with the same userId is a no-op.
    /// Pass `nil` (e.g. on sign-out) to tear down the subscription.
    func bind(currentUserId: UUID?) {
        guard subscribedUserId != currentUserId else { return }
        Task { await unbind() }

        guard let userId = currentUserId else { return }
        subscribedUserId = userId
        logger.info("Subscribing to claim events for user \(userId.uuidString, privacy: .public)")

        listenTask = Task { [weak self] in
            await self?.streamClaimEvents(forCreator: userId)
        }
    }

    func unbind() async {
        listenTask?.cancel()
        listenTask = nil
        if let channel {
            await channel.unsubscribe()
        }
        channel = nil
        subscribedUserId = nil
    }

    // MARK: - Realtime stream

    private func streamClaimEvents(forCreator userId: UUID) async {
        // Match the pattern proven in `FreshliAuthSync` — `client.realtimeV2`,
        // `channel.postgresChange(AnyAction.self, ...)`, then
        // `subscribeWithError`, then for-await the change stream.
        let channel = AppSupabase.client.realtimeV2.channel("claims-creator-\(userId.uuidString.prefix(8))")
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "claims"
        )

        do {
            try await channel.subscribeWithError()
        } catch {
            logger.warning("Realtime subscribe failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        self.channel = channel
        logger.debug("Subscribed to claims channel")

        for await change in changes {
            // Only INSERT actions matter — claim status updates are out
            // of scope for this notification.
            guard case .insert(let action) = change else { continue }

            // Field extraction matches the FreshliAuthSync pattern.
            // PostgreSQL row values come through as `AnyJSON`; we read
            // them with the `.stringValue` accessor.
            guard
                let listingIdString = action.record["listing_id"]?.stringValue,
                let listingId = UUID(uuidString: listingIdString),
                let claimerIdString = action.record["claimer_id"]?.stringValue,
                let claimerId = UUID(uuidString: claimerIdString)
            else {
                continue
            }

            await handleIncomingClaim(
                listingId: listingId,
                claimerId: claimerId,
                creatorUserId: userId
            )
        }
    }

    /// Fetches the parent listing, verifies the current user is the
    /// creator, then fires the local notification + in-app popup.
    private func handleIncomingClaim(listingId: UUID, claimerId: UUID, creatorUserId: UUID) async {
        do {
            let listingService = ListingSupabaseService()
            let listing = try await listingService.fetchListing(id: listingId)
            guard listing.userId == creatorUserId else { return }

            let claimerName = await fetchClaimerDisplayName(claimerId) ?? String(localized: "A neighbour")
            let anonymisedName = Self.anonymise(claimerName)

            scheduleLocalNotification(
                itemName: listing.itemName,
                claimerName: anonymisedName
            )

            if UIApplication.shared.applicationState == .active {
                presentInAppCelebration(
                    itemName: listing.itemName,
                    claimerName: anonymisedName
                )
            }

            logger.info("Claim notified: \(listing.itemName, privacy: .public) by \(anonymisedName, privacy: .public)")
        } catch {
            logger.warning("handleIncomingClaim failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func fetchClaimerDisplayName(_ claimerId: UUID) async -> String? {
        do {
            // ProfileService.fetchProfile uses `userId:` label — match it.
            let profile = try await ProfileService().fetchProfile(userId: claimerId)
            return profile.displayName
        } catch {
            return nil
        }
    }

    // MARK: - Local notification

    private func scheduleLocalNotification(itemName: String, claimerName: String) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "🎉 Someone wants your \(itemName)!")
        content.body = String(localized: "\(claimerName) just claimed it. One less item in a landfill — thanks for sharing.")
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = "claim.received"
        content.userInfo = [
            "kind": "claim.received",
            "itemName": itemName,
            "claimerName": claimerName
        ]

        let request = UNNotificationRequest(
            identifier: "claim.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { [logger] error in
            if let error {
                logger.warning("Local notification failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - In-app popup

    private func presentInAppCelebration(itemName: String, claimerName: String) {
        let popup = Popup(
            icon: "hand.wave.fill",
            title: String(localized: "🎉 Someone wants your \(itemName)!"),
            message: String(localized: "\(claimerName) just claimed it. They'll reach out to coordinate pickup. Thank you for keeping food out of landfill."),
            primaryCTA: String(localized: "View Claim"),
            backgroundTint: .blue,
            confettiCount: 28,
            intensity: .high
        ) {
            // CTA tap: deep-link could go to listing detail; no-op for now.
        }
        PopupCenter.shared.present(popup)
    }

    // MARK: - Anonymisation

    /// "Sarah Johnson" → "Sarah J". Single-word names returned as-is.
    static func anonymise(_ fullName: String) -> String {
        let parts = fullName.split(separator: " ").map(String.init)
        guard parts.count >= 2, let first = parts.first, let last = parts.last,
              !last.isEmpty else {
            return fullName
        }
        let initial = last.prefix(1)
        return "\(first) \(initial)"
    }
}
