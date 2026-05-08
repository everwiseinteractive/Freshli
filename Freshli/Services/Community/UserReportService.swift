import Foundation
import Supabase
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - UserReportService
//
// Files community-rules violation reports against another user
// (harassment, hate speech / racial language, bullying, spam, fraud,
// inappropriate content). Backed by the `report_user(...)` Postgres
// RPC and the append-only `user_reports` table.
//
// Two roles:
//
//   • **Reporter** — any authenticated user can call `report(...)`.
//     RLS enforces `auth.uid() = reporter_id` on insert; the RPC
//     blocks self-reports and validates the reason whitelist.
//
//   • **Moderator** — only profiles with `is_verified = true` can
//     read every row. The founder account
//     (hello@alderframe.co.uk) is verified and uses the inbox
//     surface to triage; future trusted partners can be
//     promoted by setting their `is_verified` flag in the database.
//
// The companion `ModeratorReportService` subscribes to Supabase
// Realtime so new reports surface as time-sensitive local
// notifications the moment they're filed.
// ══════════════════════════════════════════════════════════════════

@Observable @MainActor
final class UserReportService {
    static let shared = UserReportService()

    private(set) var isSubmitting: Bool = false
    private(set) var lastError: String?

    private let client = AppSupabase.client
    private let logger = Logger(subsystem: "com.freshli.app", category: "UserReports")

    private init() {}

    // MARK: - Public API

    /// File a report. Returns `true` on success. Sets `lastError`
    /// with a localised message on failure.
    @discardableResult
    func report(
        reportedUserId: UUID,
        reason: ReportReason,
        details: String?,
        listingId: UUID? = nil
    ) async -> Bool {
        isSubmitting = true
        lastError = nil
        defer { isSubmitting = false }

        struct Params: Encodable {
            let p_reported_user_id: UUID
            let p_reason: String
            let p_details: String?
            let p_listing_id: UUID?
        }

        let params = Params(
            p_reported_user_id: reportedUserId,
            p_reason: reason.rawValue,
            p_details: details?.trimmingCharacters(in: .whitespacesAndNewlines),
            p_listing_id: listingId
        )

        do {
            try await client.rpc("report_user", params: params).execute()
            logger.info("Report filed against user \(reportedUserId.uuidString, privacy: .public) reason=\(reason.rawValue, privacy: .public)")
            return true
        } catch {
            let message = error.localizedDescription.lowercased()
            logger.error("Report failed: \(error.localizedDescription, privacy: .public)")
            if message.contains("cannot report yourself") {
                lastError = String(localized: "You can't report yourself.")
            } else if message.contains("must be authenticated") || message.contains("jwt") {
                lastError = String(localized: "Please sign in to report.")
            } else {
                lastError = String(localized: "Couldn't submit your report. Please try again.")
            }
            return false
        }
    }
}

// MARK: - ReportReason

/// Whitelisted reasons the server's `user_reports.reason` CHECK
/// constraint accepts. Adding a new case here means adding it to the
/// CHECK constraint and the moderator inbox display map.
enum ReportReason: String, CaseIterable, Identifiable, Sendable {
    case harassment      = "harassment"
    case hateSpeech      = "hate_speech"
    case bullying        = "bullying"
    case spam            = "spam"
    case fraud           = "fraud"
    case inappropriate   = "inappropriate"
    case other           = "other"

    var id: String { rawValue }

    /// User-facing label shown in the report sheet. Localised.
    var displayName: String {
        switch self {
        case .harassment:    return String(localized: "Harassment")
        case .hateSpeech:    return String(localized: "Hate speech or racism")
        case .bullying:      return String(localized: "Bullying or threats")
        case .spam:          return String(localized: "Spam or scam")
        case .fraud:         return String(localized: "Fraud or impersonation")
        case .inappropriate: return String(localized: "Inappropriate content")
        case .other:         return String(localized: "Something else")
        }
    }

    /// SF Symbol used in the report-sheet picker row.
    var icon: String {
        switch self {
        case .harassment:    return "exclamationmark.bubble"
        case .hateSpeech:    return "hand.raised.slash"
        case .bullying:      return "person.crop.circle.badge.exclamationmark"
        case .spam:          return "envelope.badge"
        case .fraud:         return "creditcard.trianglebadge.exclamationmark"
        case .inappropriate: return "eye.slash"
        case .other:         return "questionmark.circle"
        }
    }
}
