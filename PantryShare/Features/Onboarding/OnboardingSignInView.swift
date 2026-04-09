import SwiftUI
import AuthenticationServices

// MARK: - Onboarding Sign In View
// High-gloss Sign in with Apple as the primary CTA, with email fallback.

struct OnboardingSignInView: View {
    @Environment(AuthManager.self) private var authManager
    let onSignedIn: () -> Void
    let onSkip: () -> Void

    @State private var appeared = false
    @State private var isSigningIn = false
    @State private var showAppleError = false
    @State private var buttonGlow = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero icon
            ZStack {
                // Outer glow rings
                ForEach(0..<3, id: \.self) { ring in
                    Circle()
                        .fill(PSColors.primaryGreen.opacity(0.04 + Double(ring) * 0.02))
                        .frame(
                            width: PSLayout.scaled(CGFloat(180 + ring * 40)),
                            height: PSLayout.scaled(CGFloat(180 + ring * 40))
                        )
                        .scaleEffect(appeared ? 1 : 0.7)
                        .opacity(appeared ? 1 : 0)
                        .animation(
                            reduceMotion ? .none : PSMotion.springGentle.delay(Double(ring) * 0.1),
                            value: appeared
                        )
                }

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
                        .frame(width: PSLayout.scaled(120), height: PSLayout.scaled(120))
                        .shadow(color: PSColors.primaryGreen.opacity(0.35), radius: 30, y: 12)
                        .overlay {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: PSLayout.scaledFont(52), weight: .medium))
                                .foregroundStyle(.white)
                        }

                    // Sparkle badge
                    Circle()
                        .fill(PSColors.secondaryAmber)
                        .frame(width: PSLayout.scaled(32), height: PSLayout.scaled(32))
                        .overlay {
                            Image(systemName: "sparkle")
                                .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
                        .offset(x: 8, y: -8)
                }
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)
            }

            Spacer()
                .frame(height: PSLayout.scaled(48))

            // Welcome text
            VStack(spacing: PSSpacing.sm) {
                Text(String(localized: "Welcome to Freshli"))
                    .font(.system(size: PSLayout.scaledFont(30), weight: .black, design: .rounded))
                    .tracking(-0.5)
                    .foregroundStyle(PSColors.textPrimary)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)

                Text(String(localized: "Sign in to sync your pantry across devices and join the community"))
                    .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, PSSpacing.xxl)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
            }

            Spacer()

            // Auth buttons
            VStack(spacing: PSSpacing.lg) {
                // High-gloss Sign in with Apple button
                Button {
                    signInWithApple()
                } label: {
                    HStack(spacing: PSSpacing.md) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: PSLayout.scaledFont(20), weight: .semibold))

                        Text(String(localized: "Sign in with Apple"))
                            .font(.system(size: PSLayout.scaledFont(18), weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: PSLayout.scaled(60))
                    .background(
                        ZStack {
                            // Base black
                            RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                                .fill(.black)

                            // High-gloss top highlight
                            RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        stops: [
                                            .init(color: .white.opacity(0.18), location: 0),
                                            .init(color: .white.opacity(0.05), location: 0.45),
                                            .init(color: .clear, location: 0.5),
                                            .init(color: .black.opacity(0.1), location: 1.0),
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                            // Glow border
                            RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.25), .white.opacity(0.05)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                    )
                    .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
                    .shadow(color: PSColors.primaryGreen.opacity(buttonGlow ? 0.2 : 0), radius: 20, y: 0)
                    .overlay {
                        if isSigningIn {
                            RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                                .fill(.black.opacity(0.5))
                            ProgressView()
                                .tint(.white)
                        }
                    }
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(isSigningIn)
                .accessibilityLabel(String(localized: "Sign in with Apple"))
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

                // Skip / Continue without account
                Button {
                    PSHaptics.shared.lightTap()
                    onSkip()
                } label: {
                    Text(String(localized: "Continue without account"))
                        .font(.system(size: PSLayout.scaledFont(15), weight: .medium))
                        .foregroundStyle(PSColors.textTertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .opacity(appeared ? 1 : 0)
            }
            .padding(.horizontal, PSLayout.formHorizontalPadding)
            .padding(.bottom, PSLayout.scaled(48))
        }
        .onAppear {
            guard !reduceMotion else { appeared = true; return }
            withAnimation(PSMotion.springDefault.delay(0.15)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(0.5)) {
                buttonGlow = true
            }
        }
        .alert(String(localized: "Sign In Failed"), isPresented: $showAppleError) {
            Button(String(localized: "OK")) {}
        } message: {
            Text(authManager.errorMessage ?? String(localized: "Could not complete Apple Sign In. Please try again."))
        }
    }

    private func signInWithApple() {
        PSHaptics.shared.mediumTap()
        isSigningIn = true
        Task {
            do {
                try await authManager.signInWithApple()
                PSHaptics.shared.success()
                onSignedIn()
            } catch {
                if authManager.errorMessage != nil {
                    PSHaptics.shared.error()
                    showAppleError = true
                }
            }
            isSigningIn = false
        }
    }
}

#Preview {
    OnboardingSignInView(onSignedIn: {}, onSkip: {})
        .environment(AuthManager())
}
