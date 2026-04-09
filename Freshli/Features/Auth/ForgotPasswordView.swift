import SwiftUI

// MARK: - Forgot Password View
// Supabase password reset flow with emerald theme.

struct ForgotPasswordView: View {
    @Environment(AuthManager.self) private var authManager
    var switchToSignIn: () -> Void

    @State private var email = ""
    @State private var isSending = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
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
                                Image(systemName: "envelope.badge.shield.half.filled")
                                    .font(.system(size: PSLayout.scaledFont(44), weight: .regular))
                                    .foregroundStyle(PSColors.primaryGreen)
                            }
                    }

                    VStack(spacing: PSSpacing.sm) {
                        Text(String(localized: "Reset Password"))
                            .font(.system(size: PSLayout.scaledFont(30), weight: .black))
                            .tracking(-0.5)
                            .foregroundStyle(PSColors.textPrimary)

                        Text(String(localized: "Enter your email and we'll send you a link to reset your password"))
                            .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
                            .foregroundStyle(PSColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.top, PSLayout.scaled(80))
                .padding(.bottom, PSLayout.scaled(40))

                if showSuccess {
                    // Success state
                    VStack(spacing: PSSpacing.xl) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: PSLayout.scaledFont(56)))
                            .foregroundStyle(PSColors.primaryGreen)
                            .symbolEffect(.bounce)

                        VStack(spacing: PSSpacing.sm) {
                            Text(String(localized: "Check your email"))
                                .font(.system(size: PSLayout.scaledFont(20), weight: .bold))
                                .foregroundStyle(PSColors.textPrimary)

                            Text(String(localized: "We've sent a password reset link to \(email)"))
                                .font(.system(size: PSLayout.scaledFont(15), weight: .medium))
                                .foregroundStyle(PSColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }

                        PSButton(
                            title: String(localized: "Back to Sign In"),
                            icon: "arrow.left",
                            style: .secondary
                        ) {
                            switchToSignIn()
                        }
                    }
                    .padding(.horizontal, PSLayout.formHorizontalPadding)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    // Email form
                    VStack(spacing: PSSpacing.xl) {
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

                        // Error
                        if showError && !errorMessage.isEmpty {
                            HStack(spacing: PSSpacing.sm) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 14))
                                Text(errorMessage)
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

                        // Send button
                        PSButton(
                            title: String(localized: "Send Reset Link"),
                            icon: "paperplane.fill",
                            isLoading: isSending
                        ) {
                            sendReset()
                        }
                        .disabled(email.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(email.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)

                        // Back to sign in
                        Button(action: switchToSignIn) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 14))
                                Text(String(localized: "Back to Sign In"))
                                    .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                            }
                            .foregroundStyle(PSColors.primaryGreen)
                        }
                    }
                    .padding(.horizontal, PSLayout.formHorizontalPadding)
                }
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

    private func sendReset() {
        PSHaptics.shared.mediumTap()
        showError = false
        isSending = true

        Task {
            do {
                try await authManager.resetPassword(email: email.trimmingCharacters(in: .whitespaces))
                PSHaptics.shared.success()
                withAnimation(PSMotion.springDefault) {
                    showSuccess = true
                }
            } catch {
                PSHaptics.shared.error()
                errorMessage = error.localizedDescription
                withAnimation(PSMotion.springQuick) { showError = true }
            }
            isSending = false
        }
    }
}
