import SwiftUI
import LocalAuthentication

/// Displays a user's identity verification badge and allows biometric verification.
/// Uses FaceID/TouchID to "sign" a claim, proving the claimer is the account owner.
struct IdentityBadgeView: View {
    let userId: UUID
    @State private var verificationService = IdentityVerificationService()
    @State private var showVerifySheet = false
    @State private var animateBadge = false

    var body: some View {
        Button {
            if verificationService.verificationStatus == .verified {
                PSHaptics.shared.lightTap()
            } else {
                showVerifySheet = true
                PSHaptics.shared.mediumTap()
            }
        } label: {
            badgeContent
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showVerifySheet) {
            verifySheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            verificationService.checkVerification()
        }
    }

    // MARK: - Badge Content

    @ViewBuilder
    private var badgeContent: some View {
        HStack(spacing: PSSpacing.xs) {
            Image(systemName: verificationService.biometricIcon)
                .font(.system(size: 14, weight: .semibold))
                .symbolEffect(.bounce, value: animateBadge)

            Text(statusLabel)
                .font(PSTypography.caption1Medium)
        }
        .padding(.horizontal, PSSpacing.sm)
        .padding(.vertical, PSSpacing.xxs + 2)
        .background(statusBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(statusBorderColor, lineWidth: 0.5)
        )
    }

    private var statusLabel: String {
        switch verificationService.verificationStatus {
        case .verified: String(localized: "Verified")
        case .expired: String(localized: "Re-verify")
        case .unverified: String(localized: "Verify Identity")
        }
    }

    private var statusBackground: some ShapeStyle {
        switch verificationService.verificationStatus {
        case .verified: AnyShapeStyle(PSColors.primaryGreen.opacity(0.12))
        case .expired: AnyShapeStyle(PSColors.warningAmber.opacity(0.12))
        case .unverified: AnyShapeStyle(PSColors.backgroundSecondary)
        }
    }

    private var statusBorderColor: Color {
        switch verificationService.verificationStatus {
        case .verified: PSColors.primaryGreen.opacity(0.3)
        case .expired: PSColors.warningAmber.opacity(0.3)
        case .unverified: PSColors.border
        }
    }

    private var statusTextColor: Color {
        switch verificationService.verificationStatus {
        case .verified: PSColors.primaryGreen
        case .expired: PSColors.warningAmber
        case .unverified: PSColors.textSecondary
        }
    }

    // MARK: - Verify Sheet

    @ViewBuilder
    private var verifySheet: some View {
        VStack(spacing: PSSpacing.xxl) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(PSColors.primaryGreen.opacity(0.1))
                    .frame(width: 96, height: 96)

                Image(systemName: verificationService.biometricIcon)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(PSColors.primaryGreen)
                    .symbolEffect(.pulse, isActive: verificationService.isAuthenticating)
            }

            // Text
            VStack(spacing: PSSpacing.sm) {
                Text("Verify Your Identity")
                    .font(PSTypography.title2)
                    .foregroundStyle(PSColors.textPrimary)

                Text("Use \(verificationService.biometricName) to prove you're the account owner. This adds a trust badge to your claims.")
                    .font(PSTypography.body)
                    .foregroundStyle(PSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, PSSpacing.lg)
            }

            // Error
            if let errorMessage = verificationService.errorMessage {
                Text(errorMessage)
                    .font(PSTypography.footnote)
                    .foregroundStyle(PSColors.expiredRed)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, PSSpacing.lg)
            }

            Spacer()

            // Action
            VStack(spacing: PSSpacing.md) {
                PSButton(
                    title: String(localized: "Verify with \(verificationService.biometricName)"),
                    icon: verificationService.biometricIcon,
                    isLoading: verificationService.isAuthenticating
                ) {
                    Task {
                        let success = await verificationService.verify(userId: userId)
                        if success {
                            PSHaptics.shared.success()
                            withAnimation(PSMotion.springBouncy) {
                                animateBadge.toggle()
                            }
                            try? await Task.sleep(for: .milliseconds(600))
                            showVerifySheet = false
                        } else {
                            PSHaptics.shared.error()
                        }
                    }
                }

                Button(String(localized: "Not Now")) {
                    showVerifySheet = false
                }
                .font(PSTypography.calloutMedium)
                .foregroundStyle(PSColors.textSecondary)
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.bottom, PSSpacing.xxxl)
        }
    }
}

// MARK: - Compact Badge (for inline use in cards/lists)

struct IdentityBadgeCompact: View {
    let isVerified: Bool

    var body: some View {
        if isVerified {
            HStack(spacing: 3) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 12))
                Text("Verified")
                    .font(PSTypography.caption2Medium)
            }
            .foregroundStyle(PSColors.primaryGreen)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        IdentityBadgeView(userId: UUID())
        IdentityBadgeCompact(isVerified: true)
        IdentityBadgeCompact(isVerified: false)
    }
    .padding()
}
