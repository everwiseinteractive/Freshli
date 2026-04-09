import Foundation

enum MeasurementUnit: String, Codable, CaseIterable, Identifiable {
    case pieces
    case grams
    case kilograms
    case milliliters
    case liters
    case cups
    case tablespoons
    case teaspoons
    case ounces
    case pounds
    case packs
    case bottles
    case cans
    case bags

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pieces: return String(localized: "pcs")
        case .grams: return String(localized: "g")
        case .kilograms: return String(localized: "kg")
        case .milliliters: return String(localized: "ml")
        case .liters: return String(localized: "L")
        case .cups: return String(localized: "cups")
        case .tablespoons: return String(localized: "tbsp")
        case .teaspoons: return String(localized: "tsp")
        case .ounces: return String(localized: "oz")
        case .pounds: return String(localized: "lbs")
        case .packs: return String(localized: "packs")
        case .bottles: return String(localized: "bottles")
        case .cans: return String(localized: "cans")
        case .bags: return String(localized: "bags")
        }
    }

    var fullName: String {
        switch self {
        case .pieces: return String(localized: "Pieces")
        case .grams: return String(localized: "Grams")
        case .kilograms: return String(localized: "Kilograms")
        case .milliliters: return String(localized: "Milliliters")
        case .liters: return String(localized: "Liters")
        case .cups: return String(localized: "Cups")
        case .tablespoons: return String(localized: "Tablespoons")
        case .teaspoons: return String(localized: "Teaspoons")
        case .ounces: return String(localized: "Ounces")
        case .pounds: return String(localized: "Pounds")
        case .packs: return String(localized: "Packs")
        case .bottles: return String(localized: "Bottles")
        case .cans: return String(localized: "Cans")
        case .bags: return String(localized: "Bags")
        }
    }
}
