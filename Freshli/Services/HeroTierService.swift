import SwiftUI

// MARK: - Hero Tier
// A tiered community hero system inspired by Olio's Food Waste Heroes.
// Tiers are calculated from total items rescued (consumed + shared + donated).

enum HeroTier: Int, CaseIterable {
    case seedling  = 0
    case saviour   = 1
    case guardian  = 2
    case champion  = 3
    case legend    = 4

    // MARK: - Display

    var title: String {
        switch self {
        case .seedling:  return "Seedling"
        case .saviour:   return "Saviour"
        case .guardian:  return "Guardian"
        case .champion:  return "Champion"
        case .legend:    return "Legend"
        }
    }

    var emoji: String {
        switch self {
        case .seedling:  return "🌱"
        case .saviour:   return "🌿"
        case .guardian:  return "🛡️"
        case .champion:  return "⭐"
        case .legend:    return "👑"
        }
    }

    var icon: String {
        switch self {
        case .seedling:  return "leaf"
        case .saviour:   return "leaf.fill"
        case .guardian:  return "shield.lefthalf.filled"
        case .champion:  return "star.fill"
        case .legend:    return "crown.fill"
        }
    }

    var color: Color {
        switch self {
        case .seedling:  return Color(hex: 0x86EFAC)   // light green
        case .saviour:   return Color(hex: 0x22C55E)   // green
        case .guardian:  return Color(hex: 0x3B82F6)   // blue
        case .champion:  return Color(hex: 0xF59E0B)   // amber
        case .legend:    return Color(hex: 0xA855F7)   // purple
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .seedling:  return [Color(hex: 0x86EFAC), Color(hex: 0x4ADE80)]
        case .saviour:   return [Color(hex: 0x4ADE80), Color(hex: 0x16A34A)]
        case .guardian:  return [Color(hex: 0x60A5FA), Color(hex: 0x2563EB)]
        case .champion:  return [Color(hex: 0xFBBF24), Color(hex: 0xD97706)]
        case .legend:    return [Color(hex: 0xC084FC), Color(hex: 0x7C3AED)]
        }
    }

    var description: String {
        switch self {
        case .seedling:  return "Every journey starts with one rescued item."
        case .saviour:   return "You're making a real dent in food waste."
        case .guardian:  return "Your pantry and the planet are safer with you."
        case .champion:  return "You inspire others to rescue more food."
        case .legend:    return "A true zero-waste icon. You've changed habits for life."
        }
    }

    // MARK: - Thresholds

    /// Minimum total items rescued to reach this tier.
    var minItems: Int {
        switch self {
        case .seedling:  return 0
        case .saviour:   return 5
        case .guardian:  return 20
        case .champion:  return 50
        case .legend:    return 100
        }
    }

    var nextTier: HeroTier? {
        let next = rawValue + 1
        return HeroTier(rawValue: next)
    }

    var itemsToNextTier: Int {
        nextTier.map { $0.minItems } ?? Int.max
    }

    // MARK: - Factory

    static func tier(for itemsSaved: Int) -> HeroTier {
        // Highest tier that the user qualifies for
        HeroTier.allCases.reversed().first { itemsSaved >= $0.minItems } ?? .seedling
    }

    /// Progress 0…1 within the current tier (how close to the next one).
    static func progressToNextTier(for itemsSaved: Int) -> Double {
        let current = tier(for: itemsSaved)
        guard let next = current.nextTier else { return 1.0 }
        let rangeStart = Double(current.minItems)
        let rangeEnd   = Double(next.minItems)
        let progress   = (Double(itemsSaved) - rangeStart) / (rangeEnd - rangeStart)
        return min(max(progress, 0), 1)
    }
}

// MARK: - Hero Tier Service

@MainActor
final class HeroTierService {
    static let shared = HeroTierService()
    private init() {}

    func tier(for itemsSaved: Int) -> HeroTier { HeroTier.tier(for: itemsSaved) }
    func progress(for itemsSaved: Int) -> Double { HeroTier.progressToNextTier(for: itemsSaved) }
}
