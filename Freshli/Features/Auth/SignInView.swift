import SwiftUI

// Figma-aligned: Sign-in screen with emerald theme, PSButton CTA,
// rounded-2xl inputs matching AddItemView style.

struct SignInView: View {
    @Environment(AuthManager.self) private var authManager
    var switchToSignUp: () -> Void
    var switchToForgotPassword: (() -> Void)?

    @State private var email = ""
    @State private var password = ""
    @State private var showError = false
    @State private var errorShakeTrigger = false
    @State private var successFlashTrigger = false
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                // Logo + Welcome
                VStack(spacing: PSSpacing.lg) {
                    // Icon matching onboarding style
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: PSSpacing.radiusHero, style: .continuous)
                            .fill(PSColors.emeraldLight)
                            .adaptiveFrame(width: 120, height: 120)
                            .overlay(
                                RoundedRectangle(cornerRadius: PSSpacing.radiusHero, style: .continuous)
                                    .strokeBorder(.white, lineWidth: 3)
                            )
                            .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
                            .overlay {
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: PSLayout.scaledFont(52), weight: .regular))
                                    .foregroundStyle(PSColors.primaryGreen)
                            }

                        Image(systemName: "sparkles")
                            .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(PSColors.primaryGreen)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                            .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
                            .offset(x: -20, y: -12)
                    }

                    VStack(spacing: PSSpacing.sm) {
                        Text(String(localized: "Welcome Back"))
                            .font(.system(size: PSLayout.scaledFont(30), weight: .black))
                            .tracking(-0.5)
                            .foregroundStyle(PSColors.textPrimary)

                        Text(String(localized: "Sign in to sync your pantry across devices"))
                            .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
                            .foregroundStyle(PSColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, PSSpacing.xxl)
                .padding(.bottom, PSLayout.formHorizontalPadding)
                .cardEntrance(index: 0)

                // Form
                VStack(spacing: PSSpacing.lg) {
                    // Email field
                    VStack(alignment: .leading, spacing: PSSpacing.sm) {
                        Text(String(localized: "Email"))
                            .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                            .foregroundStyle(PSColors.textSecondary)

                        HStack(spacing: PSSpacing.sm) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: PSLayout.scaledFont(18)))
                                .foregroundStyle(PSColors.textTertiary)

                            TextField(String(localized: "your@email.com"), text: $email)
                                .font(.system(size: PSLayout.scaledFont(16)))
                                .foregroundStyle(PSColors.textPrimary)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(.horizontal, 16)
                        .frame(height: PSLayout.inputFieldHeight)
                        .background(PSColors.backgroundSecondary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                                .strokeBorder(PSColors.border, lineWidth: 1)
                        )
                    }

                    // Password field
                    VStack(alignment: .leading, spacing: PSSpacing.sm) {
                        HStack {
                            Text(String(localized: "Password"))
                                .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                                .foregroundStyle(PSColors.textSecondary)

                            Spacer()

                            if let action = switchToForgotPassword {
                                Button(action: action) {
                                    Text(String(localized: "Forgot?"))
                                        .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                                        .foregroundStyle(PSColors.primaryGreen)
                                }
                            }
                        }

                        HStack(spacing: PSSpacing.sm) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: PSLayout.scaledFont(18)))
                                .foregroundStyle(PSColors.textTertiary)

                            SecureField(String(localized: "Enter your password"), text: $password)
                                .font(.system(size: PSLayout.scaledFont(16)))
                                .foregroundStyle(PSColors.textPrimary)
                                .textContentType(.password)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: PSLayout.inputFieldHeight)
                        .background(PSColors.backgroundSecondary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                                .strokeBorder(PSColors.border, lineWidth: 1)
                        )
                    }

                    // Error message
                    if showError, let error = authManager.errorMessage {
                        HStack(spacing: PSSpacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                            Text(error)
                                .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                        }
                        .foregroundStyle(PSColors.expiredRed)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PSColors.expiredRed.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .errorShake(trigger: $errorShakeTrigger)
                    }
                }
                .padding(.horizontal, PSLayout.formHorizontalPadding)
                .padding(.bottom, 32)
                .cardEntrance(index: 1)
                .successFlash(trigger: $successFlashTrigger)

                // CTA
                VStack(spacing: PSSpacing.xl) {
                    PSButton(
                        title: String(localized: "Sign In"),
                        icon: "arrow.right",
                        isLoading: authManager.isProcessing
                    ) {
                        signIn()
                    }

                    // Switch to Sign Up
                    HStack(spacing: 4) {
                        Text(String(localized: "Don't have an account?"))
                            .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                            .foregroundStyle(PSColors.textSecondary)

                        Button(action: switchToSignUp) {
                            Text(String(localized: "Sign Up"))
                                .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                                .foregroundStyle(PSColors.primaryGreen)
                        }
                    }

                    // Skip for now
                    Button {
                        authManager.skipAuth()
                    } label: {
                        Text(String(localized: "Continue without account"))
                            .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                            .foregroundStyle(PSColors.textTertiary)
                    }
                }
                .padding(.horizontal, PSLayout.formHorizontalPadding)
                .padding(.bottom, PSLayout.scaled(48))
                .cardEntrance(index: 2)

                Spacer(minLength: 0)
            }
            .frame(minHeight: proxy.size.height)
        }
        }  // GeometryReader
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            let base: Animation = reduceMotion ? .easeOut(duration: 0.2) : PSMotion.springDefault.delay(0.1)
            withAnimation(base) {
                appeared = true
            }
        }
    }

    private func signIn() {
        PSHaptics.shared.mediumTap()
        showError = false
        Task { @MainActor in
            do {
                try await authManager.signIn(email: email, password: password)
                // SuccessFlashModifier owns the haptic via .sensoryFeedback(.success, ...)
                successFlashTrigger = true
            } catch {
                withAnimation(FLMotion.adaptive(PSMotion.springQuick, reduceMotion: reduceMotion)) {
                    showError = true
                }
                // Error shake handles haptic internally; only trigger when
                // motion is allowed so we don't double-haptic with sensoryFeedback.
                errorShakeTrigger = true
            }
        }
    }
}
