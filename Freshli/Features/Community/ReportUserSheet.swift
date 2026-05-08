import SwiftUI

// ══════════════════════════════════════════════════════════════════
// MARK: - ReportUserSheet
//
// Modal sheet for filing a community-rules violation report against
// another user. Renders:
//
//   1. Context: "Reporting {displayName}" so the user is sure who
//      they're reporting.
//   2. Reason picker (radio-style list, one tap to select).
//   3. Optional free-text details (up to 2000 chars; the RPC
//      truncates server-side as a defence).
//   4. Submit + Cancel.
//
// On submit, calls `UserReportService.report(...)` and presents a
// confirmation popup via the existing `PopupCenter` celebration
// surface so the reporter knows the report landed safely. Reports
// are visible only to verified moderators (the founder).
// ══════════════════════════════════════════════════════════════════

struct ReportUserSheet: View {
    let reportedUserId: UUID
    let reportedDisplayName: String
    /// Optional listing context — when the user taps "Report" from a
    /// specific listing card or detail view, we attach the listing id
    /// so the moderator can review the offending content alongside.
    let listingId: UUID?

    @Environment(\.dismiss) private var dismiss

    @State private var selectedReason: UserReportReason?
    @State private var details: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    /// Optional caller-side completion callback so e.g. a feed view
    /// can hide the reported listing locally after a successful
    /// report. Fires only on success.
    var onSubmitted: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerCard
                    reasonPicker
                    detailsField
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.red)
                            .padding(.horizontal, 4)
                    }
                    submitFooter
                    safetyDisclaimer
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle(String(localized: "Report user"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
            }
        }
    }

    // MARK: - Sections

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Reporting"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(reportedDisplayName)
                .font(.system(size: 22, weight: .bold))
                .lineLimit(1)
                .truncationMode(.tail)
            Text(String(localized: "Your report goes directly to the Freshli team. The user you're reporting will not see your name."))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var reasonPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Why are you reporting?"))
                .font(.system(size: 15, weight: .semibold))
            VStack(spacing: 8) {
                ForEach(UserReportReason.allCases) { reason in
                    Button {
                        withAnimation(.snappy(duration: 0.15)) {
                            selectedReason = reason
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: reason.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 22)
                                .foregroundStyle(selectedReason == reason ? .white : .secondary)
                            Text(reason.displayName)
                                .font(.system(size: 16, weight: selectedReason == reason ? .semibold : .regular))
                                .foregroundStyle(selectedReason == reason ? .white : .primary)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            Image(systemName: selectedReason == reason ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 18))
                                .foregroundStyle(selectedReason == reason ? .white : Color.secondary.opacity(0.5))
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(
                            selectedReason == reason
                                ? Color.red
                                : Color(uiColor: .secondarySystemBackground)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedReason == reason ? [.isSelected] : [])
                }
            }
        }
    }

    private var detailsField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Add details (optional)"))
                .font(.system(size: 15, weight: .semibold))
            TextField(
                String(localized: "What happened? Include screenshots if relevant…"),
                text: $details,
                axis: .vertical
            )
            .lineLimit(4...10)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onChange(of: details) { _, newValue in
                // Defensive cap matching the RPC's 2000-char trim.
                if newValue.count > 2000 {
                    details = String(newValue.prefix(2000))
                }
            }
            HStack {
                Spacer()
                Text("\(details.count) / 2000")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var submitFooter: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack {
                if isSubmitting {
                    ProgressView().controlSize(.small).tint(.white)
                }
                Text(isSubmitting ? String(localized: "Submitting…") : String(localized: "Submit report"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canSubmit ? Color.red : Color.red.opacity(0.4), in: RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!canSubmit)
    }

    private var safetyDisclaimer: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(.top, 1)
            Text(String(localized: "False or malicious reports may result in restrictions on your own account. Please only report genuine violations."))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private var canSubmit: Bool {
        selectedReason != nil && !isSubmitting
    }

    // MARK: - Submit

    private func submit() async {
        guard let reason = selectedReason else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let success = await UserReportService.shared.report(
            reportedUserId: reportedUserId,
            reason: reason,
            details: details.isEmpty ? nil : details,
            listingId: listingId
        )

        if success {
            // Surface a confirmation through the centralised popup
            // system so the user gets clear acknowledgement that their
            // report landed.
            PopupCenter.shared.present(Popup(
                icon: "checkmark.shield.fill",
                title: String(localized: "Report sent"),
                message: String(localized: "Thanks for keeping the community safe. The Freshli team will review your report shortly."),
                primaryCTA: String(localized: "Done"),
                backgroundTint: .green,
                confettiCount: 0,
                intensity: .standard
            ))
            onSubmitted?()
            dismiss()
        } else {
            errorMessage = UserReportService.shared.lastError
                ?? String(localized: "Couldn't submit your report. Please try again.")
        }
    }
}

#Preview {
    ReportUserSheet(
        reportedUserId: UUID(),
        reportedDisplayName: "Sample User",
        listingId: nil
    )
}
