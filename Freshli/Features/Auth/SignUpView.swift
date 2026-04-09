import SwiftUI

// Figma-aligned: Sign-up screen with emerald theme, PSButton CTA,
// rounded-2xl inputs matching AddItemView style.

struct SignUpView: View {
    @Environment(AuthManager.self) private var authManager
    var switchToSignIn: () -> Void

    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showError = false
    @State private var localError: String?
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: PSSpacing.lg) {
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
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: PSLayout.scaledFont(48), weight: .regular))
                                    .foregroundStyle(PSColors.primaryGreen)
                            }

                        Image(systemName: "sparkles")
                            .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(PSColors.secondaryAmber)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                            .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
                            .offset(x: -20, y: -12)
                    }

                    VStack(spacing: PSSpacing.sm) {
                        Text(String(localized: "Create Account"))
                            .font(.system(size: PSLayout.scaledFont(30), weight: .black))
                            .tracking(-0.5)
                            .foregroundStyle(PSColors.textPrimary)

                        Text(String(localized: "Join Freshli and reduce food waste together"))
                            .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
                            .foregroundStyle(PSColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, PSLayout.headerTopPadding)
                .padding(.bottom, PSLayout.formHorizontalPadding)

                // Form
                VStack(spacing: PSSpacing.lg) {
                    authField(
                        label: String(localized: "Display Name"),
                        icon: "person.fill",
                        placeholder: String(localized: "Your name"),
                        text: $displayName,
                        contentType: .name,
                        capitalization: .words
                    )

                    authField(
                        label: String(localized: "Email"),
                        icon: "envelope.fill",
                        placeholder: String(localized: "your@email.com"),
                        text: $email,
                        contentType: .emailAddress,
                        keyboard: .emailAddress
                    )

                    // Password
                    VStack(alignment: .leading, spacing: PSSpacing.sm) {
                        Text(String(localized: "Password"))
                            .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                            .foregroundStyle(PSColors.textSecondary)

                        HStack(spacing: PSSpacing.sm) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: PSLayout.scaledFont(18)))
                                .foregroundStyle(PSColors.textTertiary)

                            SecureField(String(localized: "At least 6 characters"), text: $password)
                                .font(.system(size: PSLayout.scaledFont(16)))
                                .foregroundStyle(PSColors.textPrimary)
                                .textContentType(.newPassword)
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

                    // Confirm password
                    VStack(alignment: .leading, spacing: PSSpacing.sm) {
                        Text(String(localized: "Confirm Password"))
                            .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                            .foregroundStyle(PSColors.textSecondary)

                        HStack(spacing: PSSpacing.sm) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: PSLayout.scaledFont(18)))
                                .foregroundStyle(PSColors.textTertiary)

                            SecureField(String(localized: "Re-enter your password"), text: $confirmPassword)
                                .font(.system(size: PSLayout.scaledFont(16)))
                                .foregroundStyle(PSColors.textPrimary)
                                .textContentType(.newPassword)
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
                    if showError {
                        let errorText = localError ?? authManager.errorMessage ?? ""
                        if !errorText.isEmpty {
                            HStack(spacing: PSSpacing.sm) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 14))
                                Text(errorText)
                                    .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                            }
                            .foregroundStyle(PSColors.expiredRed)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(PSColors.expiredRed.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                }
                .padding(.horizontal, PSLayout.formHorizontalPadding)
                .padding(.bottom, 32)

                // CTA
                VStack(spacing: PSSpacing.xl) {
                    PSButton(
                        title: String(localized: "Create Account"),
                        icon: "person.badge.plus",
                        isLoading: authManager.isProcessing
                    ) {
                        signUp()
                    }

                    HStack(spacing: 4) {
                        Text(String(localized: "Already have an account?"))
                            .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                            .foregroundStyle(PSColors.textSecondary)

                        Button(action: switchToSignIn) {
                            Text(String(localized: "Sign In"))
                                .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                                .foregroundStyle(PSColors.primaryGreen)
                        }
                    }

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
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(PSMotion.springDefault.delay(0.1)) {
                appeared = true
            }
        }
    }

    // MARK: - Reusable Field

    private func authField(
        label: String,
        icon: String,
        placeholder: String,
        text: Binding<String>,
        contentType: UITextContentType? = nil,
        keyboard: UIKeyboardType = .default,
        capitalization: TextInputAutocapitalization = .never
    ) -> some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            Text(label)
                .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                .foregroundStyle(PSColors.textSecondary)

            HStack(spacing: PSSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: PSLayout.scaledFont(18)))
                    .foregroundStyle(PSColors.textTertiary)

                TextField(placeholder, text: text)
                    .font(.system(size: PSLayout.scaledFont(16)))
                    .foregroundStyle(PSColors.textPrimary)
                    .textContentType(contentType)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(capitalization)
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
    }

    // MARK: - Sign Up Action

    private func signUp() {
        PSHaptics.shared.mediumTap()
        showError = false
        localError = nil

        guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty else {
            PSHaptics.shared.error()
            localError = String(localized: "Please enter your name.")
            withAnimation(PSMotion.springQuick) { showError = true }
            return
        }

        guard password == confirmPassword else {
            PSHaptics.shared.error()
            localError = String(localized: "Passwords don't match.")
            withAnimation(PSMotion.springQuick) { showError = true }
            return
        }

        Task {
            do {
                try await authManager.signUp(
                    email: email,
                    password: password,
                    displayName: displayName.trimmingCharacters(in: .whitespaces)
                )
                PSHaptics.shared.success()
            } catch {
                PSHaptics.shared.error()
                withAnimation(PSMotion.springQuick) {
                    showError = true
                }
            }
        }
    }
}
