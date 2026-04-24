import SwiftUI
import AuthenticationServices
import os

// MARK: - Auth Container
// Beautiful Apple-premium auth landing with social sign in, email options, and smooth transitions.

enum AuthScreen {
    case landing
    case signIn
    case signUp
    case forgotPassword
}

struct AuthView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var currentScreen: AuthScreen = .landing

    private let logger = Logger(subsystem: "com.freshli.app", category: "AuthView")

    var body: some View {
        ZStack {
            // Background
            PSColors.green50.ignoresSafeArea()

            // Adaptive decorative circles - smaller on SE
            Circle()
                .fill(PSColors.emeraldLight)
                .frame(width: PSLayout.scaled(300),
                       height: PSLayout.scaled(300))
                .blur(radius: PSLayout.scaled(100))
                .opacity(0.3)
                .offset(x: PSLayout.scaled(120), y: PSLayout.scaled(-200))

            Circle()
                .fill(PSColors.primaryGreen.opacity(0.08))
                .frame(width: PSLayout.scaled(300), height: PSLayout.scaled(300))
                .blur(radius: PSLayout.scaled(80))
                .offset(x: PSLayout.scaled(-100), y: PSLayout.scaled(300))

            switch currentScreen {
            case .landing:
                AuthLandingView(
                    navigateTo: { screen in
                        withAnimation(PSMotion.springDefault) { currentScreen = screen }
                    }
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.98)),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            case .signIn:
                SignInView(
                    switchToSignUp: {
                        withAnimation(PSMotion.springDefault) { currentScreen = .signUp }
                    },
                    switchToForgotPassword: {
                        withAnimation(PSMotion.springDefault) { currentScreen = .forgotPassword }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            case .signUp:
                SignUpView(
                    switchToSignIn: {
                        withAnimation(PSMotion.springDefault) { currentScreen = .signIn }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            case .forgotPassword:
                ForgotPasswordView(
                    switchToSignIn: {
                        withAnimation(PSMotion.springDefault) { currentScreen = .signIn }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .animation(PSMotion.springDefault, value: currentScreen)
        .onAppear {
            logger.info("AuthView appeared — screen: \(String(describing: currentScreen))")
        }
    }
}

// MARK: - Auth Landing View
// Beautiful hero landing page with social auth + email options.

struct AuthLandingView: View {
    @Environment(AuthManager.self) private var authManager
    var navigateTo: (AuthScreen) -> Void

    @State private var appeared = false
    @State private var showAppleError = false
    @State private var isSigningIn = false
    // Nonce is generated in `onRequest` and consumed in `onCompletion`. We
    // stash it here so the two closures can share state without forcing us
    // to spin up our own ASAuthorizationController (which is what previously
    // broke on iPadOS Stage Manager).
    @State private var pendingNonce: String?

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    // Hero section - adaptive sizing for SE
                    VStack(spacing: PSSpacing.xl) {
                        // App icon - scale down on SE
                        ZStack(alignment: .topTrailing) {
                            RoundedRectangle(cornerRadius: PSSpacing.radiusHero, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [PSColors.primaryGreen, PSColors.primaryGreenDark],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: PSLayout.scaled(100), height: PSLayout.scaled(100))
                                .shadow(color: PSColors.primaryGreen.opacity(0.3), radius: 24, y: 12)
                                .overlay {
                                    Image(systemName: "leaf.fill")
                                        .font(.system(size: PSLayout.scaledFont(44), weight: .medium))
                                        .foregroundStyle(.white)
                                }

                            Circle()
                                .fill(PSColors.secondaryAmber)
                                .frame(width: PSLayout.scaled(28), height: PSLayout.scaled(28))
                                .overlay {
                                    Image(systemName: "sparkle")
                                        .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                                .offset(x: 6, y: -6)
                        }

                        VStack(spacing: PSSpacing.sm) {
                            Text(String(localized: "Freshli"))
                                .font(.system(size: PSLayout.scaledFont(34), weight: .black))
                                .tracking(-0.5)
                                .foregroundStyle(PSColors.textPrimary)

                            Text(String(localized: "Share food, reduce waste, build community"))
                                .font(.system(size: PSLayout.scaledFont(17), weight: .medium))
                                .foregroundStyle(PSColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .scaleEffect(appeared ? 1 : 0.9)
                    .opacity(appeared ? 1 : 0)

                    Spacer(minLength: PSSpacing.xxxl)

                    // Auth buttons section
                    VStack(spacing: PSSpacing.lg) {
                // Sign in with Apple — OFFICIAL SwiftUI button.
                //
                // We use Apple's SignInWithAppleButton (not a custom Button) for two reasons:
                //   1. HIG compliance — §4.8 Sign in with Apple requires the
                //      Apple-provided button.
                //   2. iPadOS 26 / Stage Manager — SignInWithAppleButton owns its
                //      own ASAuthorizationController and presentation anchor, so
                //      SwiftUI picks the correct window automatically. Custom
                //      ASAuthorizationController presentation has been unreliable
                //      on iPad Air 11" M3 / iPadOS 26.4.1 in App Review, producing
                //      the "an error message was displayed" rejection.
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                    let nonce = AppleSignInCoordinator.randomNonceString()
                    pendingNonce = nonce
                    request.nonce = AppleSignInCoordinator.sha256(nonce)
                } onCompletion: { result in
                    handleAppleSignInCompletion(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
                .disabled(isSigningIn)
                .accessibilityLabel(String(localized: "Sign in with Apple"))
                .accessibilityHint(String(localized: "Uses your Apple ID to sign in securely"))

                // Divider
                HStack(spacing: PSSpacing.md) {
                    Rectangle()
                        .fill(PSColors.border)
                        .frame(height: 1)
                    Text(String(localized: "or"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PSColors.textTertiary)
                    Rectangle()
                        .fill(PSColors.border)
                        .frame(height: 1)
                }

                // Email sign in
                Button { navigateTo(.signIn) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 18))
                        Text(String(localized: "Continue with Email"))
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(PSColors.primaryGreen)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
                    .shadow(color: PSColors.primaryGreen.opacity(0.3), radius: 12, y: 6)
                }
                .buttonStyle(PressableButtonStyle())

                // Create account
                Button { navigateTo(.signUp) } label: {
                    Text(String(localized: "Create Account"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(PSColors.primaryGreen)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(PSColors.primaryGreen.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(.horizontal, PSLayout.formHorizontalPadding)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 30)

            // Loading overlay for sign-in
            if isSigningIn {
                HStack(spacing: PSSpacing.sm) {
                    ProgressView()
                        .tint(PSColors.primaryGreen)
                    Text(String(localized: "Signing in..."))
                        .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                }
                .padding(.top, PSSpacing.md)
            }

                    // Skip auth
                    Button {
                        authManager.skipAuth()
                    } label: {
                        Text(String(localized: "Continue without account"))
                            .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                            .foregroundStyle(PSColors.textTertiary)
                    }
                    .padding(.top, PSSpacing.xl)
                    .padding(.bottom, PSLayout.scaled(48))
                    .opacity(appeared ? 1 : 0)

                    Spacer(minLength: 0)
                }
                .frame(minHeight: proxy.size.height)
            }
            .ignoresSafeArea(.keyboard)
        }
        .onAppear {
            withAnimation(PSMotion.springDefault.delay(0.1)) {
                appeared = true
            }
        }
        .alert(String(localized: "Sign In Failed"), isPresented: $showAppleError) {
            Button(String(localized: "OK")) {}
        } message: {
            Text(authManager.errorMessage ?? String(localized: "Could not complete Apple Sign In. Please try again."))
        }
    }

    private func handleAppleSignInCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = credential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8),
                  let nonce = pendingNonce else {
                authManager.errorMessage = String(localized: "Could not retrieve Apple ID credentials. Please try again.")
                showAppleError = true
                return
            }

            let fullName: String? = {
                guard let nc = credential.fullName else { return nil }
                let parts = [nc.givenName, nc.familyName].compactMap { $0 }
                return parts.isEmpty ? nil : parts.joined(separator: " ")
            }()

            isSigningIn = true
            Task {
                do {
                    try await authManager.signInWithApple(
                        idToken: identityToken,
                        nonce: nonce,
                        fullName: fullName
                    )
                } catch {
                    if authManager.errorMessage != nil {
                        showAppleError = true
                    }
                }
                isSigningIn = false
                pendingNonce = nil
            }

        case .failure(let error):
            // User-initiated cancel: ASAuthorizationError.canceled — silent.
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                pendingNonce = nil
                return
            }
            authManager.errorMessage = String(localized: "Sign in with Apple failed. Please try again or use email sign in.")
            logger.error("SignInWithAppleButton failed: \(error.localizedDescription, privacy: .public)")
            showAppleError = true
            pendingNonce = nil
        }
    }

    private var logger: Logger { Logger(subsystem: "com.freshli.app", category: "AuthView") }
}

// Make AuthScreen conform for animation value
extension AuthScreen: Equatable {}
