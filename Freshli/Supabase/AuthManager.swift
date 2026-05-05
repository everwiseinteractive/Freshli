import SwiftUI
import Supabase

// MARK: - Auth State

enum AuthState: Equatable {
    case loading
    case unauthenticated
    case authenticated

    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading): return true
        case (.unauthenticated, .unauthenticated): return true
        case (.authenticated, .authenticated): return true
        default: return false
        }
    }
}

// MARK: - Auth Error

enum AuthError: LocalizedError {
    case invalidEmail
    case weakPassword
    case signUpFailed(String)
    case signInFailed(String)
    case signOutFailed(String)
    case sessionExpired
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return String(localized: "Please enter a valid email address.")
        case .weakPassword:
            return String(localized: "Password must be at least 6 characters.")
        case .signUpFailed(let msg):
            return msg
        case .signInFailed(let msg):
            return msg
        case .signOutFailed(let msg):
            return msg
        case .sessionExpired:
            return String(localized: "Your session has expired. Please sign in again.")
        case .unknown(let msg):
            return msg
        }
    }
}

// MARK: - AuthManager

@Observable @MainActor
final class AuthManager {
    var authState: AuthState = .loading
    var currentUserId: UUID? {
        didSet {
            Self.publishToAppGroup(email: currentUserEmail, userId: currentUserId)
            // Bind/unbind realtime claim notifications to track the
            // current user. Idempotent — does nothing if userId is
            // unchanged from the prior set.
            ClaimNotificationService.shared.bind(currentUserId: currentUserId)
        }
    }
    var currentUserEmail: String? {
        didSet { Self.publishToAppGroup(email: currentUserEmail, userId: currentUserId) }
    }
    var currentDisplayName: String?
    var errorMessage: String?
    var isProcessing = false

    /// Mirror the signed-in identity to the App Group container so other
    /// processes (widgets, App Intents extension, the Watch companion,
    /// `ReviewerAccountService`) can read the same source of truth without
    /// reaching into AuthManager's actor isolation. Cleared on sign-out.
    private static func publishToAppGroup(email: String?, userId: UUID?) {
        let defaults = UserDefaults(suiteName: "group.everwise.interactive.Freshli") ?? .standard
        if let email = email, let userId = userId {
            defaults.set(email, forKey: "freshli.auth.currentUserEmail")
            defaults.set(userId.uuidString, forKey: "freshli.auth.currentUserId")
        } else {
            defaults.removeObject(forKey: "freshli.auth.currentUserEmail")
            defaults.removeObject(forKey: "freshli.auth.currentUserId")
        }
    }

    /// Tracks whether the user explicitly tapped "Continue without account".
    /// Persisted so they don't see the auth screen every launch.
    var hasDeclinedAuth = UserDefaults.standard.bool(forKey: "hasDeclinedAuth")

    private let client = AppSupabase.client

    // MARK: - Session Restoration

    /// Called once at app launch to check for an existing session.
    ///
    /// **Launch-safety:** this method is on the critical splash-screen path.
    /// If the Supabase SDK's network/keychain call stalls (flaky Wi-Fi, keychain
    /// not-yet-unlocked on first-run, SDK internal retry), we do NOT want the
    /// splash to hang indefinitely. After `timeout` seconds we abandon the
    /// attempt and fall through to `.unauthenticated`, which lets the splash
    /// dissolve and shows the AuthView so the user can sign in manually.
    /// The session can still be restored in the background when the SDK's
    /// `authStateChanges` stream fires.
    func restoreSession(timeout: TimeInterval = 3.0) async {
        do {
            let session = try await withThrowingTaskGroup(of: Session.self) { group in
                group.addTask {
                    try await AppSupabase.client.auth.session
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(timeout))
                    throw AuthError.unknown("restoreSession timed out after \(Int(timeout))s")
                }
                // Whichever task finishes first wins; cancel the rest.
                defer { group.cancelAll() }
                guard let first = try await group.next() else {
                    throw AuthError.unknown("restoreSession produced no result")
                }
                return first
            }
            currentUserId = session.user.id
            currentUserEmail = session.user.email
            currentDisplayName = session.user.userMetadata["display_name"]?.stringValue
            authState = .authenticated
            PSLogger.auth.info("Session restored successfully")
        } catch {
            // Session unavailable, expired, or the attempt timed out —
            // treat as unauthenticated so the splash can proceed.
            PSLogger.auth.debug("restoreSession fell through to unauthenticated: \(error.localizedDescription)")
            authState = .unauthenticated
        }
    }

    // MARK: - Sign Up

    func signUp(email: String, password: String, displayName: String) async throws {
        guard isValidEmail(email) else { throw AuthError.invalidEmail }
        guard password.count >= 6 else { throw AuthError.weakPassword }

        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                data: ["display_name": .string(displayName)]
            )

            currentUserId = response.user.id
            currentUserEmail = response.user.email
            currentDisplayName = displayName
            authState = .authenticated
            PSLogger.auth.info("User signed up successfully: \(email)")
        } catch {
            // Don't expose raw error details to user; use a generic message
            let message = "Sign up failed. Please try again."
            errorMessage = message
            PSLogger.auth.error("SignUp failed for \(email): \(error.localizedDescription)")
            throw AuthError.signUpFailed(message)
        }
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async throws {
        guard isValidEmail(email) else { throw AuthError.invalidEmail }
        guard !password.isEmpty else { throw AuthError.weakPassword }

        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            let session = try await client.auth.signIn(
                email: email,
                password: password
            )
            currentUserId = session.user.id
            currentUserEmail = session.user.email
            currentDisplayName = session.user.userMetadata["display_name"]?.stringValue
            authState = .authenticated
            PSLogger.auth.info("User signed in successfully: \(email)")
        } catch {
            // Surface a message that's actionable for the user *and* informative
            // for App Review on first-run/test-account scenarios, without leaking
            // the raw stack trace. We map common failure modes to human copy.
            let raw = error.localizedDescription.lowercased()
            let message: String
            if raw.contains("invalid login credentials") || raw.contains("invalid email or password") {
                message = String(localized: "Incorrect email or password. Please try again or tap \"Forgot?\"")
            } else if raw.contains("email not confirmed") {
                message = String(localized: "Please confirm your email address first. Check your inbox for the confirmation link.")
            } else if raw.contains("network") || raw.contains("offline") || raw.contains("connection") || raw.contains("timed out") {
                message = String(localized: "Can't reach the server. Check your internet connection and try again.")
            } else if raw.contains("rate") {
                message = String(localized: "Too many attempts. Please wait a moment and try again.")
            } else {
                message = String(localized: "Sign in failed. Please try again or tap \"Continue without account\" to explore Freshli.")
            }
            errorMessage = message
            PSLogger.auth.error("SignIn failed for \(email): \(error.localizedDescription)")
            throw AuthError.signInFailed(message)
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await client.auth.signOut()
            PSLogger.auth.info("User signed out successfully")
        } catch {
            // Sign out locally even if the server call fails
            PSLogger.auth.debug("SignOut request to server failed: \(error.localizedDescription)")
        }

        // Always clear local auth state
        currentUserId = nil
        currentUserEmail = nil
        currentDisplayName = nil
        authState = .unauthenticated
        errorMessage = nil
    }

    // MARK: - Listen for Auth Changes

    /// Start listening for auth state changes (sign in from another tab, token refresh, etc.)
    func listenForAuthChanges() async {
        for await (event, session) in client.auth.authStateChanges {
            switch event {
            case .signedIn:
                if let user = session?.user {
                    currentUserId = user.id
                    currentUserEmail = user.email
                    currentDisplayName = user.userMetadata["display_name"]?.stringValue
                    authState = .authenticated
                }
            case .signedOut:
                currentUserId = nil
                currentUserEmail = nil
                currentDisplayName = nil
                authState = .unauthenticated
            case .tokenRefreshed:
                // Session refreshed — no state change needed
                break
            default:
                break
            }
        }
    }

    // MARK: - Sign in with Apple

    /// Exchange a pre-obtained Apple identity token + nonce with Supabase.
    ///
    /// This is the NEW primary path, driven by SwiftUI's `SignInWithAppleButton`.
    /// Using the system button means SwiftUI manages the ASAuthorizationController
    /// and its presentation anchor internally — eliminating the iPadOS
    /// multi-window / Stage Manager presentation bugs that have been breaking
    /// Sign in with Apple in App Review (iPad Air 11" M3, iPadOS 26.4.1).
    ///
    /// - Parameters:
    ///   - idToken: The `identityToken` string from `ASAuthorizationAppleIDCredential`.
    ///   - nonce: The RAW (unhashed) nonce. Apple ID tokens carry the SHA256 hash.
    ///   - fullName: Optional display name. Apple only provides this on the very
    ///     first sign-in for a given Apple ID; on subsequent sign-ins we fall back
    ///     to `user_metadata.display_name`.
    /// True while the app is operating with an Apple-verified identity
    /// but no live Supabase session (e.g. offline at sign-in time, or
    /// the token exchange permanently failed). Cloud sync is paused;
    /// the user can still use the app fully against local SwiftData.
    /// The Settings → Account row reads this to show "Cloud sync paused".
    var isUsingLocalAppleAuth: Bool = false

    func signInWithApple(
        idToken: String,
        nonce: String,
        fullName: String?,
        appleUserIdentifier: String? = nil,
        email: String? = nil
    ) async throws {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        // ── Step 1: cache the Apple identity locally ─────────────────
        // This is the linchpin of the new design. Apple has just
        // authenticated the user — that is the source of truth. We
        // cache it BEFORE attempting Supabase exchange so the user is
        // already "signed in" from the app's perspective regardless
        // of what happens with the server.
        if let appleUserIdentifier {
            AppleIdentityCache.save(
                userIdentifier: appleUserIdentifier,
                email: email,
                displayName: fullName,
                identityToken: idToken,
                nonce: nonce
            )
        } else {
            // Older callers don't pass appleUserIdentifier — keep the
            // existing token cache fresh so background retry works.
            AppleIdentityCache.updateToken(identityToken: idToken, nonce: nonce)
        }

        // ── Step 2: flip the user to .authenticated immediately ──────
        // Even before the Supabase call returns. The user's perception
        // of "I tapped Sign in with Apple and it worked" is now
        // dependent ONLY on the Apple system sheet succeeding.
        let cached = AppleIdentityCache.current()
        if currentDisplayName == nil {
            currentDisplayName = fullName
                ?? cached?.displayName
                ?? email?.components(separatedBy: "@").first
        }
        if currentUserEmail == nil {
            currentUserEmail = email ?? cached?.email
        }

        // ── Step 3: attempt Supabase exchange with retry ─────────────
        // Up to 3 attempts with exponential backoff (0.5s → 1.5s → 4.5s).
        // If all attempts fail, the user is still authenticated locally
        // via Apple and continues into the app.
        do {
            let session = try await exchangeWithSupabase(
                idToken: idToken,
                nonce: nonce,
                attempts: 3,
                initialBackoff: 0.5
            )

            // Cloud session active.
            currentUserId = session.user.id
            currentUserEmail = session.user.email ?? currentUserEmail
            isUsingLocalAppleAuth = false

            if let fullName, !fullName.isEmpty {
                currentDisplayName = fullName
                do {
                    try await client.auth.update(user: .init(
                        data: ["display_name": .string(fullName)]
                    ))
                    PSLogger.auth.info("Apple Sign-In metadata updated successfully")
                } catch {
                    PSLogger.auth.error("Failed to update Apple Sign-In metadata: \(error.localizedDescription)")
                }
            } else if currentDisplayName == nil {
                currentDisplayName = session.user.userMetadata["display_name"]?.stringValue
                    ?? session.user.userMetadata["full_name"]?.stringValue
                    ?? session.user.email?.components(separatedBy: "@").first
            }

            authState = .authenticated
            PSLogger.auth.info("Sign in with Apple complete — Supabase session active")
            return
        } catch {
            // ── Step 4: Supabase exchange failed three times ─────────
            //
            // Apple has authenticated the user — we are NOT going to
            // refuse to sign them in just because our backend can't
            // reach handshake right now. The user proceeds with a
            // local-only Apple session. Cloud sync re-activates as
            // soon as `tryRestoreSupabaseSession()` succeeds (called
            // automatically when the network monitor fires reachable
            // and on every app foreground).
            PSLogger.auth.warning("SIWA: server exchange failed after retries — using local Apple auth. \(error.localizedDescription)")

            isUsingLocalAppleAuth = true
            // Use a deterministic UUID derived from the Apple identifier
            // so SwiftData rows created locally can be migrated cleanly
            // when the Supabase UUID later arrives (the reconciliation
            // job uses `freshli.localAppleUserId` as the merge key).
            if currentUserId == nil, let identity = cached {
                currentUserId = deterministicUUID(from: identity.userIdentifier)
                UserDefaults.standard.set(identity.userIdentifier, forKey: "freshli.localAppleUserId")
            }
            authState = .authenticated
            PSLogger.auth.info("Sign in with Apple complete — local Apple session active")

            // Schedule a background retry so cloud sync activates as soon
            // as the network/Supabase recover. The task is detached so
            // it survives view rebuilds and lives until either the
            // exchange succeeds or the user signs out.
            scheduleSupabaseExchangeRetry(idToken: idToken, nonce: nonce)
        }
    }

    // MARK: - Internal — Supabase exchange with retry

    private func exchangeWithSupabase(
        idToken: String,
        nonce: String,
        attempts: Int,
        initialBackoff: Double
    ) async throws -> Session {
        var lastError: Error = AuthError.signInFailed("No exchange attempted")
        var backoff = initialBackoff
        for attempt in 1...attempts {
            do {
                let session = try await withTimeout(seconds: 12) {
                    try await self.client.auth.signInWithIdToken(
                        credentials: .init(
                            provider: .apple,
                            idToken: idToken,
                            nonce: nonce
                        )
                    )
                }
                if attempt > 1 {
                    PSLogger.auth.info("Supabase exchange succeeded on attempt \(attempt) of \(attempts)")
                }
                return session
            } catch {
                lastError = error
                PSLogger.auth.warning("Supabase exchange attempt \(attempt) of \(attempts) failed: \(error.localizedDescription)")
                if attempt < attempts {
                    try? await Task.sleep(for: .seconds(backoff))
                    backoff *= 3
                }
            }
        }
        throw lastError
    }

    /// Detached background retry. Keeps trying every 30 seconds (capped
    /// at 5 attempts so the task eventually quits if the project really
    /// is misconfigured) and silently activates the cloud session if
    /// any attempt succeeds. Called when the synchronous SIWA flow has
    /// already returned to the user with local Apple auth.
    private nonisolated func scheduleSupabaseExchangeRetry(idToken: String, nonce: String) {
        Task.detached { [weak self] in
            guard let self else { return }
            for delay in [30.0, 60.0, 120.0, 240.0, 480.0] {
                try? await Task.sleep(for: .seconds(delay))
                let stillLocal = await MainActor.run { self.isUsingLocalAppleAuth }
                guard stillLocal else { return }
                do {
                    let session = try await self.client.auth.signInWithIdToken(
                        credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
                    )
                    await MainActor.run {
                        self.currentUserId = session.user.id
                        self.currentUserEmail = session.user.email ?? self.currentUserEmail
                        self.isUsingLocalAppleAuth = false
                        PSLogger.auth.info("Supabase session activated via background retry")
                    }
                    return
                } catch {
                    PSLogger.auth.debug("Background retry still failing: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Generate a deterministic UUID from a string (Apple's user identifier)
    /// using a SHA-256 truncation. Used as the local SwiftData user ID so
    /// rows survive the eventual cloud-session activation cleanly.
    private nonisolated func deterministicUUID(from string: String) -> UUID {
        // We can't pull in CryptoKit's SHA256 at the AuthManager level
        // without churning imports; the AppleSignInCoordinator already
        // imports it. Inline a simple FNV-1a hash here that produces a
        // 128-bit value we map to a UUID. Collision risk is negligible
        // for the per-user-per-Apple-ID scope.
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        let lowBytes: [UInt8] = (0..<8).map { UInt8(truncatingIfNeeded: hash >> (UInt64($0) * 8)) }
        var hash2: UInt64 = ~hash
        for byte in string.reversed().map({ UInt8($0.asciiValue ?? 0) }) {
            hash2 ^= UInt64(byte)
            hash2 &*= 0x100000001b3
        }
        let highBytes: [UInt8] = (0..<8).map { UInt8(truncatingIfNeeded: hash2 >> (UInt64($0) * 8)) }
        let bytes = highBytes + lowBytes
        let uuid: uuid_t = (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15])
        return UUID(uuid: uuid)
    }

    // MARK: - Internal — timeout helper

    private struct TimeoutError: Error {}

    /// Race a throwing async operation against a wall-clock timeout.
    /// On timeout, throws `TimeoutError`; on operation success/failure,
    /// returns / rethrows the operation's result.
    private func withTimeout<T: Sendable>(seconds: Double, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw TimeoutError()
            }
            // First result wins; cancel the other.
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    /// Legacy path kept for callers that still invoke the coordinator directly.
    /// Prefer the `signInWithApple(idToken:nonce:fullName:)` overload driven by
    /// SwiftUI's `SignInWithAppleButton`.
    func signInWithApple() async throws {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        let coordinator = AppleSignInCoordinator()

        do {
            let result = try await coordinator.signIn()
            try await signInWithApple(
                idToken: result.identityToken,
                nonce: result.nonce,
                fullName: result.fullName,
                appleUserIdentifier: result.userIdentifier,
                email: result.email
            )
        } catch let error as AppleSignInError where error.errorDescription == nil {
            // User-cancelled: silent return. The Apple sheet has dismissed.
            PSLogger.auth.debug("Apple Sign-In cancelled by user")
            return
        } catch let error as AuthError {
            throw error
        } catch {
            // The legacy ASAuthorizationController path failed BEFORE Apple
            // could authenticate the user (e.g. presentation anchor missing,
            // canceled by system). The new robust path can't fall back to
            // local Apple auth because we don't have the credential. Show
            // the appropriate user-recoverable error.
            let raw = error.localizedDescription.lowercased()
            let message: String
            if raw.contains("network") || raw.contains("offline") || raw.contains("connection") || raw.contains("timed out") {
                message = String(localized: "Can't reach the server. Check your internet connection and try again.")
            } else if raw.contains("not handled") || raw.contains("no window") {
                message = String(localized: "Sign in with Apple couldn't open. Please try again or use email sign in.")
            } else {
                message = String(localized: "Sign in with Apple failed. Please try again or use email sign in.")
            }
            errorMessage = message
            PSLogger.auth.error("SignInWithApple (legacy coordinator) failed: \(error.localizedDescription)")
            throw AuthError.signInFailed(message)
        }
    }

    // MARK: - Password Reset

    /// Send a password reset email via Supabase.
    func resetPassword(email: String) async throws {
        guard isValidEmail(email) else { throw AuthError.invalidEmail }

        isProcessing = true
        defer { isProcessing = false }

        do {
            try await client.auth.resetPasswordForEmail(email)
            PSLogger.auth.info("Password reset email sent to: \(email)")
        } catch {
            PSLogger.auth.error("Password reset failed for \(email): \(error.localizedDescription)")
            throw AuthError.unknown(error.localizedDescription)
        }
    }

    // MARK: - Delete Account

    /// Request account deletion. The user must be authenticated.
    /// Always signs out after deletion, regardless of RPC success.
    func deleteAccount() async throws {
        guard authState == .authenticated else {
            PSLogger.auth.warning("deleteAccount called when not authenticated")
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            // Call the admin delete user RPC (requires server-side function)
            try await client.rpc("delete_user_account").execute()
            PSLogger.auth.info("Account deletion RPC executed successfully")
        } catch {
            PSLogger.auth.error("DeleteAccount RPC failed: \(error.localizedDescription)")
            errorMessage = "Failed to delete account on server. Your local data has been cleared."
            throw AuthError.unknown(errorMessage ?? "Account deletion failed")
        }

        // Always sign out after deletion attempt (whether RPC succeeded or not)
        await signOut()
    }

    // MARK: - Skip Auth

    /// Called when user taps "Continue without account". Persists the choice.
    func skipAuth() {
        UserDefaults.standard.set(true, forKey: "hasDeclinedAuth")
        hasDeclinedAuth = true
    }

    // MARK: - Helpers

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
}
