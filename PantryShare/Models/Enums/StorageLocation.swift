import Foundation

enum StorageLocation: String, Codable, CaseIterable, Identifiable {
    case fridge
    case freezer
    case pantry
    case counter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fridge: return String(localized: "Fridge")
        case .freezer: return String(localized: "Freezer")
        case .pantry: return String(localized: "Pantry")
        case .counter: return String(localized: "Counter")
        }
    }

    var icon: String {
        switch self {
        case .fridge: return "refrigerator.fill"
        case .freezer: return "snowflake"
        case .pantry: return "cabinet.fill"
        case .counter: return "table.furniture.fill"
        }
    }
}
