import Foundation

enum FoodCategory: String, Codable, CaseIterable, Identifiable {
    case fruits
    case vegetables
    case dairy
    case meat
    case seafood
    case grains
    case bakery
    case frozen
    case canned
    case condiments
    case snacks
    case beverages
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fruits: return String(localized: "Fruits")
        case .vegetables: return String(localized: "Vegetables")
        case .dairy: return String(localized: "Dairy")
        case .meat: return String(localized: "Meat")
        case .seafood: return String(localized: "Seafood")
        case .grains: return String(localized: "Grains")
        case .bakery: return String(localized: "Bakery")
        case .frozen: return String(localized: "Frozen")
        case .canned: return String(localized: "Canned")
        case .condiments: return String(localized: "Condiments")
        case .snacks: return String(localized: "Snacks")
        case .beverages: return String(localized: "Beverages")
        case .other: return String(localized: "Other")
        }
    }

    var icon: String {
        switch self {
        case .fruits: return "apple.logo"
        case .vegetables: return "leaf.fill"
        case .dairy: return "cup.and.saucer.fill"
        case .meat: return "flame.fill"
        case .seafood: return "fish.fill"
        case .grains: return "wheat.bundle.fill"
        case .bakery: return "birthday.cake.fill"
        case .frozen: return "snowflake"
        case .canned: return "cylinder.fill"
        case .condiments: return "drop.fill"
        case .snacks: return "popcorn.fill"
        case .beverages: return "waterbottle.fill"
        case .other: return "basket.fill"
        }
    }

    var emoji: String {
        switch self {
        case .fruits: return "🍎"
        case .vegetables: return "🥬"
        case .dairy: return "🥛"
        case .meat: return "🥩"
        case .seafood: return "🐟"
        case .grains: return "🌾"
        case .bakery: return "🍞"
        case .frozen: return "🧊"
        case .canned: return "🥫"
        case .condiments: return "🧂"
        case .snacks: return "🍿"
        case .beverages: return "🧃"
        case .other: return "📦"
        }
    }
}
