import Foundation

enum ExpiryStatus: String, Codable, CaseIterable, Identifiable {
    case fresh
    case expiringSoon
    case expiringToday
    case expired

    var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .fresh: return String(localized: "Fresh")
        case .expiringSoon: return String(localized: "Expiring Soon")
        case .expiringToday: return String(localized: "Expires Today")
        case .expired: return String(localized: "Expired")
        }
    }

    nonisolated var icon: String {
        switch self {
        case .fresh: return "checkmark.circle.fill"
        case .expiringSoon: return "exclamationmark.triangle.fill"
        case .expiringToday: return "clock.fill"
        case .expired: return "xmark.circle.fill"
        }
    }

    /// A short, screen-reader-friendly description that VoiceOver reads
    /// alongside each item in the pantry. Crucially, it does not rely on
    /// colour or shape — it is a plain-language status that works
    /// identically for every user regardless of vision.
    nonisolated var accessibilityLabel: String {
        switch self {
        case .fresh:
            return String(localized: "Status: fresh")
        case .expiringSoon:
            return String(localized: "Status: expiring within a few days")
        case .expiringToday:
            return String(localized: "Status: expires today")
        case .expired:
            return String(localized: "Status: expired, needs attention")
        }
    }

    /// Extra context VoiceOver reads after the label. Explains what a
    /// user can do about each state so the announcement is actionable,
    /// not just descriptive.
    nonisolated var accessibilityHint: String {
        switch self {
        case .fresh:
            return String(localized: "Safe to use at your leisure")
        case .expiringSoon:
            return String(localized: "Plan to use this soon to avoid waste")
        case .expiringToday:
            return String(localized: "Use today or donate to avoid waste")
        case .expired:
            return String(localized: "No longer safe to eat, consider composting")
        }
    }

    nonisolated var sortOrder: Int {
        switch self {
        case .expired: return 0
        case .expiringToday: return 1
        case .expiringSoon: return 2
        case .fresh: return 3
        }
    }

    nonisolated static func from(expiryDate: Date) -> ExpiryStatus {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        let expiry = calendar.startOfDay(for: expiryDate)
        let days = calendar.dateComponents([.day], from: now, to: expiry).day ?? 0

        if days < 0 { return .expired }
        if days == 0 { return .expiringToday }
        if days <= 3 { return .expiringSoon }
        return .fresh
    }

    /// Bridge to Motion Vocabulary's `FreshnessLevel` for haptic encoding.
    nonisolated var freshnessLevel: FreshnessLevel {
        switch self {
        case .expired:      return .expired
        case .expiringToday: return .critical
        case .expiringSoon: return .wilting
        case .fresh:        return .fresh
        }
    }
}
