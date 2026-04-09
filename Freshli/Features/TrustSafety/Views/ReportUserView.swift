import SwiftUI

/// Full "Report User" sheet with structured reason selection and details input.
struct ReportUserView: View {
    let reportedUserId: UUID
    let reportedUserName: String
    let listingId: UUID?
    let listingTitle: String?
    let listingStatus: String?
    let onComplete: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason: ReportReason?
    @State private var details: String = ""
    @State private var isSubmitting = false
    @State private var showConfirmation = false
    @State private var safetyService = SafetyService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PSSpacing.xxl) {
                    headerSection
                    reasonSelection
                    detailsSection
                    disclaimerSection
                }
                .padding(.vertical, PSSpacing.lg)
            }
            .background(PSColors.backgroundPrimary)
            .navigationTitle(String(localized: "Report User"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                    .foregroundStyle(PSColors.textSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                submitButton
            }
            .alert(String(localized: "Report Submitted"), isPresented: $showConfirmation) {
                Button(String(localized: "Done")) {
                    onComplete(true)
                    dismiss()
                }
            } message: {
                Text("Thank you for helping keep Freshli safe. We'll review this report and take action if needed.")
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: PSSpacing.md) {
            ZStack {
                Circle()
                    .fill(PSColors.expiredRed.opacity(0.1))
                    .frame(width: 64, height: 64)

                Image(systemName: "shield.slash.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(PSColors.expiredRed)
            }

            VStack(spacing: PSSpacing.xs) {
                Text("Report \(reportedUserName)")
                    .font(PSTypography.title3)
                    .foregroundStyle(PSColors.textPrimary)

                Text("Help us understand what happened so we can take appropriate action.")
                    .font(PSTypography.body)
                    .foregroundStyle(PSColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, PSSpacing.screenHorizontal)
    }

    // MARK: - Reason Selection

    @ViewBuilder
    private var reasonSelection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            Text("What's the issue?")
                .font(PSTypography.headline)
                .foregroundStyle(PSColors.textPrimary)
                .padding(.horizontal, PSSpacing.screenHorizontal)

            VStack(spacing: PSSpacing.sm) {
                ForEach(ReportReason.allCases) { reason in
                    reasonRow(reason)
                }
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
        }
    }

    @ViewBuilder
    private func reasonRow(_ reason: ReportReason) -> some View {
        let isSelected = selectedReason == reason

        Button {
            PSHaptics.shared.lightTap()
            withAnimation(PSMotion.springQuick) {
                selectedReason = reason
            }
        } label: {
            HStack(spacing: PSSpacing.md) {
                // Icon
                Image(systemName: reason.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isSelected ? PSColors.expiredRed : PSColors.textSecondary)
                    .frame(width: 24)

                // Label
                Text(reason.displayName)
                    .font(PSTypography.body)
                    .foregroundStyle(PSColors.textPrimary)

                Spacer()

                // Check
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? PSColors.expiredRed : PSColors.textTertiary)
                    .symbolEffect(.bounce, value: isSelected)
            }
            .padding(PSSpacing.md)
            .background(isSelected ? PSColors.expiredRed.opacity(0.06) : PSColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous)
                    .stroke(
                        isSelected ? PSColors.expiredRed.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Details

    @ViewBuilder
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            Text("Additional details (optional)")
                .font(PSTypography.footnoteMedium)
                .foregroundStyle(PSColors.textSecondary)

            TextField(
                String(localized: "Describe what happened..."),
                text: $details,
                axis: .vertical
            )
            .lineLimit(3...8)
            .font(PSTypography.body)
            .padding(PSSpacing.md)
            .background(PSColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
        }
        .padding(.horizontal, PSSpacing.screenHorizontal)
    }

    // MARK: - Disclaimer

    @ViewBuilder
    private var disclaimerSection: some View {
        HStack(alignment: .top, spacing: PSSpacing.sm) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 14))
                .foregroundStyle(PSColors.textTertiary)

            Text("Your report is confidential. The reported user will not see who filed this report.")
                .font(PSTypography.caption1)
                .foregroundStyle(PSColors.textTertiary)
        }
        .padding(.horizontal, PSSpacing.screenHorizontal)
    }

    // MARK: - Submit

    @ViewBuilder
    private var submitButton: some View {
        VStack {
            Divider()
            PSButton(
                title: String(localized: "Submit Report"),
                icon: "exclamationmark.shield.fill",
                style: .destructive,
                isLoading: isSubmitting
            ) {
                submitReport()
            }
            .disabled(selectedReason == nil)
            .opacity(selectedReason == nil ? 0.5 : 1)
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.vertical, PSSpacing.md)
        }
        .background(PSColors.backgroundPrimary)
    }

    // MARK: - Submit Action

    private func submitReport() {
        guard let reason = selectedReason, !isSubmitting else { return }
        isSubmitting = true
        PSHaptics.shared.mediumTap()

        Task {
            let success = await safetyService.reportUser(
                reporterId: UUID(), // Placeholder — inject from auth
                reportedUserId: reportedUserId,
                listingId: listingId,
                reason: reason,
                details: details.isEmpty ? nil : details,
                listingTitle: listingTitle,
                listingStatus: listingStatus,
                interactionType: listingId != nil ? "claim" : nil,
                reporterVerified: false // Combine with IdentityVerificationService
            )

            isSubmitting = false

            if success {
                PSHaptics.shared.success()
                showConfirmation = true
            } else {
                PSHaptics.shared.error()
            }
        }
    }
}

#Preview {
    ReportUserView(
        reportedUserId: UUID(),
        reportedUserName: "Alex",
        listingId: UUID(),
        listingTitle: "Fresh Tomatoes",
        listingStatus: "active"
    ) { _ in }
}
