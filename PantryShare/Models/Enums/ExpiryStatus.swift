import Foundation

enum ExpiryStatus: String, Codable, CaseIterable, Identifiable {
    case fresh
    case expiringSoon
    case expiringToday
    case expired

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fresh: return String(localized: "Fresh")
        case .expiringSoon: return String(localized: "Expiring Soon")
        case .expiringToday: return String(localized: "Expires Today")
        case .expired: return String(localized: "Expired")
        }
    }

    var icon: String {
        switch self {
        case .fresh: return "checkmark.circle.fill"
        case .expiringSoon: return "exclamationmark.triangle.fill"
        case .expiringToday: return "clock.fill"
        case .expired: return "xmark.circle.fill"
        }
    }

    var sortOrder: Int {
        switch self {
        case .expired: return 0
        case .expiringToday: return 1
        case .expiringSoon: return 2
        case .fresh: return 3
        }
    }

    static func from(expiryDate: Date) -> ExpiryStatus {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        let expiry = calendar.startOfDay(for: expiryDate)
        let days = calendar.dateComponents([.day], from: now, to: expiry).day ?? 0

        if days < 0 { return .expired }
        if days == 0 { return .expiringToday }
        if days <= 3 { return .expiringSoon }
        return .fresh
    }
}
