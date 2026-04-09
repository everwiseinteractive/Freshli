import Foundation
import LocalAuthentication

/// Handles biometric identity verification (FaceID/TouchID) for claim signing.
/// Users authenticate with biometrics to prove they are the account owner before claiming.
@Observable
final class IdentityVerificationService: @unchecked Sendable {

    // MARK: - State

    var verificationStatus: VerificationStatus = .unverified
    var currentVerification: IdentityVerification?
    var isAuthenticating = false
    var errorMessage: String?

    // MARK: - Constants

    /// Verification lasts 24 hours before requiring re-auth
    private static let verificationDuration: TimeInterval = 24 * 60 * 60

    // MARK: - Biometric Availability

    var biometricType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    var biometricName: String {
        switch biometricType {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        @unknown default: String(localized: "Biometrics")
        }
    }

    var biometricIcon: String {
        switch biometricType {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        @unknown default: "person.badge.key"
        }
    }

    var isBiometricAvailable: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    // MARK: - Verification

    /// Authenticate with biometrics and create a signed verification for the given user.
    /// Returns `true` if authentication succeeded.
    @MainActor
    func verify(userId: UUID) async -> Bool {
        guard !isAuthenticating else { return false }

        isAuthenticating = true
        errorMessage = nil

        defer { isAuthenticating = false }

        let context = LAContext()
        context.localizedCancelTitle = String(localized: "Cancel")

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            errorMessage = error?.localizedDescription ?? String(localized: "Biometric authentication is not available.")
            verificationStatus = .unverified
            return false
        }

        let reason = String(localized: "Verify your identity to sign this claim")

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )

            guard success else {
                errorMessage = String(localized: "Authentication failed.")
                return false
            }

            let method: String = switch biometricType {
            case .faceID: "faceID"
            case .touchID: "touchID"
            case .opticID: "opticID"
            @unknown default: "biometric"
            }

            let now = Date()
            let verification = IdentityVerification(
                userId: userId,
                verifiedAt: now,
                method: method,
                expiresAt: now.addingTimeInterval(Self.verificationDuration)
            )

            currentVerification = verification
            verificationStatus = .verified
            return true
        } catch {
            let laError = error as? LAError
            switch laError?.code {
            case .userCancel:
                errorMessage = nil // User cancelled intentionally
            case .userFallback:
                errorMessage = String(localized: "Passcode fallback is not supported for identity verification.")
            case .biometryLockout:
                errorMessage = String(localized: "Too many failed attempts. Please try again later.")
            default:
                errorMessage = error.localizedDescription
            }
            return false
        }
    }

    /// Check whether the current verification is still valid.
    func checkVerification() {
        guard let verification = currentVerification else {
            verificationStatus = .unverified
            return
        }
        verificationStatus = verification.isValid ? .verified : .expired
        if !verification.isValid {
            currentVerification = nil
        }
    }

    /// Clear the current verification (e.g., on sign out).
    func clearVerification() {
        currentVerification = nil
        verificationStatus = .unverified
        errorMessage = nil
    }
}
