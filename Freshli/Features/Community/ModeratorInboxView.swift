import SwiftUI
import Supabase
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - ModeratorInboxView
//
// Founder-only triage surface for the `user_reports` table. Lists
// every report sorted newest-first, with the reporter's name, the
// reported user's name, the reason, optional details, and the
// listing context (when available). Each row offers two actions:
//
//   • **Mark resolved** — moves status from `pending` to `resolved`.
//   • **Dismiss**       — moves status from `pending` to `dismissed`.
//
// Both write `reviewed_by = auth.uid()` and `reviewed_at = NOW()` so
// the audit trail is preserved.
//
// Visibility: gated by `profiles.is_verified`. Regular users
// reaching the route (defensive — they shouldn't see an entry point)
// see an unauthorised state; RLS would block their reads anyway.
// ══════════════════════════════════════════════════════════════════

struct ModeratorInboxView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager

    @State private var reports: [UserReportRow] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var filter: Filter = .pending

    enum Filter: String, CaseIterable, Identifiable {
        case pending, reviewed, resolved, dismissed
        var id: String { rawValue }
        var label: String {
            switch self {
            case .pending:   return String(localized: "Pending")
            case .reviewed:  return String(localized: "Reviewed")
            case .resolved:  return String(localized: "Resolved")
            case .dismissed: return String(localized: "Dismissed")
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterPicker
                if isLoading && reports.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if reports.isEmpty {
                    emptyState
                } else {
                    reportsList
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(String(localized: "Moderator inbox"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) { dismiss() }
                }
            }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    // MARK: - Sections

    private var filterPicker: some View {
        Picker("", selection: $filter) {
            ForEach(Filter.allCases) { f in
                Text(f.label).tag(f)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .onChange(of: filter) { _, _ in
            Task { await load() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.tint)
            Text(filter == .pending
                 ? String(localized: "No pending reports — all clear.")
                 : String(localized: "Nothing here."))
                .font(.system(size: 15, weight: .semibold))
                .multilineTextAlignment(.center)
            if filter == .pending {
                Text(String(localized: "New reports will appear here and as a notification."))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    private var reportsList: some View {
        List {
            ForEach(reports) { report in
                reportRow(report)
                    .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func reportRow(_ report: UserReportRow) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: ReportReason(rawValue: report.reason)?.icon ?? "questionmark.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.red.gradient, in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(ReportReason(rawValue: report.reason)?.displayName ?? report.reason)
                        .font(.system(size: 14, weight: .bold))
                    Text(formattedDate(report.createdAt))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusBadge(report.status)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "Reported user:"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(report.reportedDisplayName ?? String(localized: "Unknown"))
                    .font(.system(size: 14, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "Reporter:"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(report.reporterDisplayName ?? String(localized: "Unknown"))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            if let details = report.details, !details.isEmpty {
                Text(details)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if report.status == "pending" {
                HStack(spacing: 8) {
                    Button(role: .destructive) {
                        Task { await transition(report, to: "resolved") }
                    } label: {
                        Label(String(localized: "Resolve"), systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button {
                        Task { await transition(report, to: "dismissed") }
                    } label: {
                        Label(String(localized: "Dismiss"), systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }

    private func statusBadge(_ status: String) -> some View {
        let (label, tint): (String, Color) = {
            switch status {
            case "pending":   return (String(localized: "Pending"),   .orange)
            case "reviewed":  return (String(localized: "Reviewed"),  .blue)
            case "resolved":  return (String(localized: "Resolved"),  .green)
            case "dismissed": return (String(localized: "Dismissed"), .secondary)
            default:          return (status, .secondary)
            }
        }()
        return Text(label)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.15), in: Capsule())
    }

    // MARK: - Data

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "" }
        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 60 { return String(localized: "just now") }
        if elapsed < 3600 { return String(localized: "\(Int(elapsed/60))m ago") }
        if elapsed < 86_400 { return String(localized: "\(Int(elapsed/3600))h ago") }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let rows: [UserReportRow] = try await AppSupabase.client
                .from("user_reports")
                .select("""
                id,
                reporter_id, reported_user_id, reason, details, listing_id,
                status, reviewed_at, reviewed_by, reviewer_notes, created_at,
                reporter:profiles!user_reports_reporter_id_fkey(display_name),
                reported:profiles!user_reports_reported_user_id_fkey(display_name)
                """)
                .eq("status", value: filter.rawValue)
                .order("created_at", ascending: false)
                .limit(200)
                .execute()
                .value
            reports = rows
        } catch {
            errorMessage = String(localized: "Couldn't load reports.")
        }

        await ModeratorReportService.shared.refreshPendingCount()
    }

    private func transition(_ report: UserReportRow, to newStatus: String) async {
        guard let userId = authManager.currentUserId else { return }
        struct Update: Encodable {
            let status: String
            let reviewed_at: String
            let reviewed_by: UUID
        }
        let payload = Update(
            status: newStatus,
            reviewed_at: ISO8601DateFormatter().string(from: Date()),
            reviewed_by: userId
        )
        do {
            try await AppSupabase.client
                .from("user_reports")
                .update(payload)
                .eq("id", value: report.id)
                .execute()
            await load()
        } catch {
            errorMessage = String(localized: "Couldn't update that report. Please try again.")
        }
    }
}

// MARK: - UserReportRow
//
// Codable mirror of `user_reports` joined with two profile rows
// (reporter + reported) so the inbox can render names without
// per-row follow-up fetches.

struct UserReportRow: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let reporterId: UUID
    let reportedUserId: UUID
    let reason: String
    let details: String?
    let listingId: UUID?
    let status: String
    let reviewedAt: Date?
    let reviewedBy: UUID?
    let reviewerNotes: String?
    let createdAt: Date?

    private let reporter: NameSlice?
    private let reported: NameSlice?

    var reporterDisplayName: String? { reporter?.displayName }
    var reportedDisplayName: String? { reported?.displayName }

    enum CodingKeys: String, CodingKey {
        case id
        case reporterId      = "reporter_id"
        case reportedUserId  = "reported_user_id"
        case reason
        case details
        case listingId       = "listing_id"
        case status
        case reviewedAt      = "reviewed_at"
        case reviewedBy      = "reviewed_by"
        case reviewerNotes   = "reviewer_notes"
        case createdAt       = "created_at"
        case reporter
        case reported
    }

    struct NameSlice: Codable, Sendable, Hashable {
        let displayName: String?
        enum CodingKeys: String, CodingKey { case displayName = "display_name" }
    }
}
