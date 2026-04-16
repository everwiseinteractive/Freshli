import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

// MARK: - Apple Sign In Coordinator
// Manages the ASAuthorizationController flow and nonce generation for Sign in with Apple.
//
// iPadOS 26 note:
//   ASAuthorizationController REQUIRES a presentationContextProvider on iPadOS
//   (and on iOS when running inside a multi-window scene) so it can decide which
//   UIWindow to present the system sheet in. Without it, performRequests()
//   resolves with an error on iPad and the sheet never appears — which is the
//   failure mode flagged by App Review on iPad Air 11-inch (M3), iPadOS 26.4.1.

@MainActor
final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<AppleSignInResult, Error>?
    private var currentNonce: String?

    /// Perform the Sign in with Apple flow. Returns identity token + nonce on success.
    func signIn() async throws -> AppleSignInResult {
        let nonce = Self.randomNonceString()
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Find the foreground-active key window across all connected scenes.
        // This handles iPadOS multi-window, Split View, Slide Over, and Stage Manager.
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        let keyWindow = scenes
            .first(where: { $0.activationState == .foregroundActive })?
            .windows
            .first(where: { $0.isKeyWindow })
            ?? scenes.first?.windows.first(where: { $0.isKeyWindow })
            ?? scenes.first?.windows.first

        return keyWindow ?? ASPresentationAnchor()
    }

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = appleCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8),
              let nonce = currentNonce else {
            continuation?.resume(throwing: AppleSignInError.missingToken)
            continuation = nil
            return
        }

        let fullName: String? = {
            guard let nameComponents = appleCredential.fullName else { return nil }
            let parts = [nameComponents.givenName, nameComponents.familyName].compactMap { $0 }
            return parts.isEmpty ? nil : parts.joined(separator: " ")
        }()

        let result = AppleSignInResult(
            identityToken: identityToken,
            nonce: nonce,
            email: appleCredential.email,
            fullName: fullName
        )

        continuation?.resume(returning: result)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            continuation?.resume(throwing: AppleSignInError.cancelled)
        } else {
            continuation?.resume(throwing: AppleSignInError.failed(error.localizedDescription))
        }
        continuation = nil
    }

    // MARK: - Nonce Utilities

    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        guard errorCode == errSecSuccess else {
            // Fallback: use UUID-based randomness instead of crashing
            let fallback = (0..<length).map { _ in
                String(format: "%02x", UInt8.random(in: 0...255))
            }.joined()
            return String(fallback.prefix(length))
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Result & Errors

struct AppleSignInResult {
    let identityToken: String
    let nonce: String
    let email: String?
    let fullName: String?
}

enum AppleSignInError: LocalizedError {
    case missingToken
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .missingToken: return String(localized: "Could not retrieve Apple ID credentials.")
        case .cancelled: return nil // User-initiated, no error to show
        case .failed(let msg): return msg
        }
    }
}
