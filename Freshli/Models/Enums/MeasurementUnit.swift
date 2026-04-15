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

    nonisolated var displayName: String {
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

    /// Returns the correctly pluralized display name for a given quantity.
    /// Abbreviated units (g, kg, ml, etc.) are invariant; countable units
    /// (bags, packs, bottles, cans, cups) use singular form when quantity == 1.
    nonisolated func displayName(for quantity: Double) -> String {
        let isSingular = quantity == 1
        switch self {
        // Abbreviated units — no plural change
        case .pieces:      return String(localized: "pcs")
        case .grams:       return String(localized: "g")
        case .kilograms:   return String(localized: "kg")
        case .milliliters: return String(localized: "ml")
        case .liters:      return String(localized: "L")
        case .tablespoons: return String(localized: "tbsp")
        case .teaspoons:   return String(localized: "tsp")
        case .ounces:      return String(localized: "oz")
        case .pounds:      return String(localized: "lbs")
        // Countable units — singular/plural
        case .cups:    return isSingular ? String(localized: "cup")    : String(localized: "cups")
        case .packs:   return isSingular ? String(localized: "pack")   : String(localized: "packs")
        case .bottles: return isSingular ? String(localized: "bottle") : String(localized: "bottles")
        case .cans:    return isSingular ? String(localized: "can")    : String(localized: "cans")
        case .bags:    return isSingular ? String(localized: "bag")    : String(localized: "bags")
        }
    }

    nonisolated var fullName: String {
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
