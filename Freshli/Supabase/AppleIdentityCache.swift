import Foundation
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - AppleIdentityCache
//
// Persists the user's Apple-verified identity to UserDefaults so the
// app can treat the user as authenticated *immediately* when Apple's
// system Sign-in sheet returns success — without waiting for the
// Supabase token-exchange round-trip.
//
// Architecture rationale:
//   The previous design required a successful Supabase token exchange
//   before flipping `authState = .authenticated`. Real users who tapped
//   Sign in with Apple, completed Face ID, but happened to be on a
//   slow / blocked / mid-rotation network experienced the spinner
//   hanging or — worse — silently dropping into guest mode after the
//   build-24 fallback was added. Apple had ALREADY authenticated them
//   — the app just couldn't prove it to its own backend in time.
//
//   With this cache, Apple sign-in flips the user to .authenticated
//   immediately. The server exchange runs in the background (with
//   retry); if it eventually succeeds the cloud session activates
//   silently, otherwise the user keeps using the app with local-only
//   data and a "Cloud sync paused" pill in Settings.
//
// Stored fields:
//   - `userIdentifier` — Apple's stable per-Apple-ID-per-team id
//                        (`ASAuthorizationAppleIDCredential.user`).
//                        Used as the local user ID until the Supabase
//                        UUID arrives.
//   - `email`          — only present on the first sign-in for a
//                        given Apple ID; cached so subsequent launches
//                        can show it.
//   - `displayName`    — same as email — first-sign-in only.
//   - `identityToken`  — the most recent JWT from Apple. Re-sent to
//                        Supabase on every retry.
//   - `nonce`          — the raw nonce that pairs with `identityToken`.
//
// Privacy:
//   All fields are stored in standard UserDefaults (the app's
//   sandboxed container). The identity token is a short-lived JWT
//   (~10 min) and is cleared on sign-out. No PII is shared with
//   anyone — this is purely local state.
// ══════════════════════════════════════════════════════════════════

@MainActor
enum AppleIdentityCache {

    private static let logger = Logger(subsystem: "com.freshli.app", category: "AppleIdentityCache")

    private struct Keys {
        static let userIdentifier = "freshli.apple.userIdentifier"
        static let email          = "freshli.apple.email"
        static let displayName    = "freshli.apple.displayName"
        static let identityToken  = "freshli.apple.identityToken"
        static let nonce          = "freshli.apple.nonce"
        static let cachedAt       = "freshli.apple.cachedAt"
    }

    // MARK: - Public API

    struct Identity: Sendable, Equatable {
        let userIdentifier: String
        let email: String?
        let displayName: String?
        let identityToken: String
        let nonce: String
    }

    static func save(
        userIdentifier: String,
        email: String?,
        displayName: String?,
        identityToken: String,
        nonce: String
    ) {
        let defaults = UserDefaults.standard
        defaults.set(userIdentifier, forKey: Keys.userIdentifier)
        defaults.set(identityToken, forKey: Keys.identityToken)
        defaults.set(nonce, forKey: Keys.nonce)
        defaults.set(Date().timeIntervalSince1970, forKey: Keys.cachedAt)

        // Email and display name are only present on first sign-in for
        // a given Apple ID. If we already have them cached (from a prior
        // first-sign-in), don't overwrite with nil on a re-sign-in.
        if let email, !email.isEmpty {
            defaults.set(email, forKey: Keys.email)
        }
        if let displayName, !displayName.isEmpty {
            defaults.set(displayName, forKey: Keys.displayName)
        }
        logger.info("Cached Apple identity for user \(userIdentifier, privacy: .public)")
    }

    /// Update only the identity token + nonce after a token refresh,
    /// without touching the cached user identifier / email / name.
    static func updateToken(identityToken: String, nonce: String) {
        let defaults = UserDefaults.standard
        defaults.set(identityToken, forKey: Keys.identityToken)
        defaults.set(nonce, forKey: Keys.nonce)
        defaults.set(Date().timeIntervalSince1970, forKey: Keys.cachedAt)
    }

    static func current() -> Identity? {
        let defaults = UserDefaults.standard
        guard
            let userIdentifier = defaults.string(forKey: Keys.userIdentifier),
            let identityToken = defaults.string(forKey: Keys.identityToken),
            let nonce = defaults.string(forKey: Keys.nonce)
        else { return nil }
        return Identity(
            userIdentifier: userIdentifier,
            email: defaults.string(forKey: Keys.email),
            displayName: defaults.string(forKey: Keys.displayName),
            identityToken: identityToken,
            nonce: nonce
        )
    }

    static func clear() {
        let defaults = UserDefaults.standard
        for key in [Keys.userIdentifier, Keys.email, Keys.displayName,
                    Keys.identityToken, Keys.nonce, Keys.cachedAt] {
            defaults.removeObject(forKey: key)
        }
        logger.info("Cleared Apple identity cache")
    }

    /// Whether the cached identity token is younger than `maxAge`.
    /// Apple identity tokens are short-lived (~10 min) so anything
    /// older should be considered stale and re-validated by re-running
    /// the SIWA flow before being sent to Supabase.
    static func isTokenFresh(maxAge: TimeInterval = 600) -> Bool {
        let cachedAt = UserDefaults.standard.double(forKey: Keys.cachedAt)
        guard cachedAt > 0 else { return false }
        return Date().timeIntervalSince1970 - cachedAt < maxAge
    }
}
