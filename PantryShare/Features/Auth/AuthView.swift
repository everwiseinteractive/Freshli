import SwiftUI
import AuthenticationServices

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

    var body: some View {
        ZStack {
            // Background
            PSColors.green50.ignoresSafeArea()

            Circle()
                .fill(PSColors.emeraldLight)
                .frame(width: UIScreen.main.bounds.width * 1.2,
                       height: UIScreen.main.bounds.width * 1.2)
                .blur(radius: 100)
                .opacity(0.3)
                .offset(x: 120, y: -200)

            Circle()
                .fill(PSColors.primaryGreen.opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: -100, y: 300)

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
    }
}

// MARK: - Auth Landing View
// Beautiful hero landing page with social auth + email options.

struct AuthLandingView: View {
    @Environment(AuthManager.self) private var authManager
    var navigateTo: (AuthScreen) -> Void

    @State private var appeared = false
    @State private var showAppleError = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero section
            VStack(spacing: PSSpacing.xl) {
                // App icon
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: PSSpacing.radiusHero, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [PSColors.primaryGreen, PSColors.primaryGreenDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: PSColors.primaryGreen.opacity(0.3), radius: 24, y: 12)
                        .overlay {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 44, weight: .medium))
                                .foregroundStyle(.white)
                        }

                    Circle()
                        .fill(PSColors.secondaryAmber)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Image(systemName: "sparkle")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        .offset(x: 6, y: -6)
                }

                VStack(spacing: PSSpacing.sm) {
                    Text(String(localized: "PantryShare"))
                        .font(.system(size: 34, weight: .black))
                        .tracking(-0.5)
                        .foregroundStyle(PSColors.textPrimary)

                    Text(String(localized: "Share food, reduce waste, build community"))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .scaleEffect(appeared ? 1 : 0.9)
            .opacity(appeared ? 1 : 0)

            Spacer()

            // Auth buttons section
            VStack(spacing: PSSpacing.lg) {
                // Sign in with Apple
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { _ in }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
                .overlay {
                    // Intercept with our own handler that goes through AuthManager
                    Button {
                        signInWithApple()
                    } label: {
                        Color.clear
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

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

            // Skip auth
            Button {
                authManager.skipAuth()
            } label: {
                Text(String(localized: "Continue without account"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PSColors.textTertiary)
            }
            .padding(.top, PSSpacing.xl)
            .padding(.bottom, 48)
            .opacity(appeared ? 1 : 0)
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

    private func signInWithApple() {
        Task {
            do {
                try await authManager.signInWithApple()
            } catch {
                if authManager.errorMessage != nil {
                    showAppleError = true
                }
            }
        }
    }
}

// Make AuthScreen conform for animation value
extension AuthScreen: Equatable {}
