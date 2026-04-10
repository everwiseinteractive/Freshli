import Foundation
import AuthenticationServices

// MARK: - Apple Sign In Error

enum AppleSignInError: LocalizedError {
    case failed
    case cancelled
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .failed: return "Sign in with Apple failed"
        case .cancelled: return nil // User cancelled - don't show error
        case .unknown(let message): return message
        }
    }
}

// MARK: - Apple Sign In Result

struct AppleSignInResult {
    let identityToken: String
    let nonce: String
    let fullName: String?
}

// MARK: - Apple Sign In Coordinator

@MainActor
final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    private var continuation: CheckedContinuation<AppleSignInResult, Error>?
    private var currentNonce: String?
    
    func signIn() async throws -> AppleSignInResult {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            
            // Generate nonce
            let nonce = UUID().uuidString
            self.currentNonce = nonce
            
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = nonce
            
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }
    
    // MARK: - ASAuthorizationControllerDelegate
    
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                continuation?.resume(throwing: AppleSignInError.failed)
                return
            }
            
            let fullName: String?
            if let name = credential.fullName {
                var components: [String] = []
                if let given = name.givenName { components.append(given) }
                if let family = name.familyName { components.append(family) }
                fullName = components.isEmpty ? nil : components.joined(separator: " ")
            } else {
                fullName = nil
            }
            
            let result = AppleSignInResult(
                identityToken: token,
                nonce: nonce,
                fullName: fullName
            )
            
            continuation?.resume(returning: result)
            continuation = nil
        }
    }
    
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            if let error = error as? ASAuthorizationError, error.code == .canceled {
                continuation?.resume(throwing: AppleSignInError.cancelled)
            } else {
                continuation?.resume(throwing: AppleSignInError.unknown(error.localizedDescription))
            }
            continuation = nil
        }
    }
    
    // MARK: - ASAuthorizationControllerPresentationContextProviding
    
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
}
