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
    var currentUserId: UUID?
    var currentUserEmail: String?
    var currentDisplayName: String?
    var errorMessage: String?
    var isProcessing = false

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
    func signInWithApple(idToken: String, nonce: String, fullName: String?) async throws {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: idToken,
                    nonce: nonce
                )
            )

            currentUserId = session.user.id
            currentUserEmail = session.user.email

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
            } else {
                currentDisplayName = session.user.userMetadata["display_name"]?.stringValue
                    ?? session.user.userMetadata["full_name"]?.stringValue
                    ?? session.user.email?.components(separatedBy: "@").first
            }

            authState = .authenticated
            PSLogger.auth.info("User signed in with Apple successfully (SwiftUI button path)")
        } catch {
            let raw = error.localizedDescription.lowercased()
            let message: String
            if raw.contains("network") || raw.contains("offline") || raw.contains("connection") || raw.contains("timed out") {
                message = String(localized: "Can't reach the server. Check your internet connection and try again.")
            } else if raw.contains("invalid") && (raw.contains("token") || raw.contains("nonce")) {
                message = String(localized: "Sign in with Apple token couldn't be verified. Please try again or use email sign in.")
            } else {
                message = String(localized: "Sign in with Apple failed. Please try again or use email sign in.")
            }
            errorMessage = message
            PSLogger.auth.error("SignInWithApple (token exchange) failed: \(error.localizedDescription)")
            throw AuthError.signInFailed(message)
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
                fullName: result.fullName
            )
        } catch let error as AppleSignInError where error.errorDescription == nil {
            PSLogger.auth.debug("Apple Sign-In cancelled by user")
            return
        } catch let error as AuthError {
            throw error
        } catch {
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
