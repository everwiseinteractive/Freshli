import Foundation
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - ReviewerAccountService
//
// Single source of truth for "is the App Review reviewer signed in?"
//
// Why this exists:
//   The production Freshli app must NEVER show fabricated rescue
//   counts, fake user names, or pre-coded community fridges to real
//   users — that is dishonest UI.
//
//   At the same time, the App Store reviewer needs to be able to
//   verify Freshli's social features (Live Rescue Wave, Community
//   Marketplace, Community Fridges, etc.) without waiting for real
//   users in the wild to populate the data.
//
//   This service threads that needle: real users see real data
//   (which may legitimately be empty for the first hours after
//   launch), and the reviewer account sees a curated demonstration
//   set so the review can complete.
//
// The reviewer account email is `reviewer@freshli.app` (documented
// publicly in `REVIEWER_NOTES.md`). The detection is by signed-in
// email, not by build configuration, so the same TestFlight / App
// Store binary works for both real users and the reviewer.
// ══════════════════════════════════════════════════════════════════

@Observable @MainActor
final class ReviewerAccountService {
    static let shared = ReviewerAccountService()

    private let logger = Logger(subsystem: "com.freshli.app", category: "ReviewerAccount")

    /// Whitelist of reviewer email addresses. The submission credentials
    /// in `REVIEWER_NOTES.md` use `reviewer@freshli.app`; we add the
    /// `+test` variant as future-proofing in case Apple's review pool
    /// rotates accounts mid-cycle.
    private let reviewerEmails: Set<String> = [
        "reviewer@freshli.app",
        "reviewer+test@freshli.app",
        "appreview@freshli.app"
    ]

    /// True when the currently-signed-in user is the App Review reviewer.
    /// Read this everywhere production data is empty and the UX would
    /// suffer for a non-real user (App Review). Real users (everyone
    /// else, including signed-out guests) get the strict empty state.
    var isReviewerActive: Bool {
        guard let email = currentSignedInEmail()?.lowercased() else { return false }
        let result = reviewerEmails.contains(email)
        if result {
            logger.info("Reviewer account active — demonstration data enabled")
        }
        return result
    }

    /// Read the current signed-in email from the AuthManager UserDefaults
    /// cache. We don't take an `AuthManager` dependency directly so this
    /// service can be queried from anywhere (services, widgets, App
    /// Intents) without dragging in the auth stack.
    private func currentSignedInEmail() -> String? {
        // AuthManager mirrors the signed-in user's email to UserDefaults
        // for App Group sharing with the widgets extension. The key is a
        // documented contract — do not rename without updating the App
        // Group consumers.
        let defaults = UserDefaults(suiteName: "group.everwise.interactive.Freshli") ?? .standard
        return defaults.string(forKey: "freshli.auth.currentUserEmail")
    }
}
