import Foundation
import SwiftUI

// MARK: - Freshli Brand
// Single source of truth for every user-facing mission string, impact
// constant, and tagline used anywhere in the app. One place to tune the
// voice, one place to A/B test copy, one place to localise. Everything
// here ladders up to the mission:
//
//     Freshli is for the people and for the planet.
//     The food you save saves someone, somewhere.

enum FreshliBrand {

    // MARK: - Taglines

    /// The primary line used on the paywall, launch screen, About page.
    static let tagline = String(localized: "The food you save saves someone, somewhere.")

    /// Short hero line for the Freshli+ paywall and Apple Intelligence.
    static let heroLine = String(localized: "Eat the food. Save the planet. Repeat.")

    /// Mission statement used in About and marketing materials.
    static let mission = String(localized: "Freshli is for the people and for the planet. Every item you rescue keeps food on a plate and carbon out of the sky.")

    /// Call-to-action used on the Home rescue card and push notifications.
    static let callToAction = String(localized: "Rescue one thing today. That's all it takes.")

    // MARK: - Impact Constants (per-item averages)
    //
    // Sources:
    //   • FAO Food Wastage Footprint report (2013, updated 2019)
    //   • UK WRAP "Household Food Waste" study (2023)
    //   • WWF-UK "Driven to Waste" (2021)
    //
    // These are deliberately conservative so we never over-claim.

    /// Average CO₂e avoided per rescued food item (kg).
    static let co2PerItemKg: Double = 2.5

    /// Average water saved per rescued item (litres).
    static let waterPerItemL: Double = 85

    /// Average retail cost of one rescued item (£).
    static let moneyPerItemGBP: Double = 3.50

    /// Rescued items required to feed one additional person a meal.
    static let itemsPerMealFed: Int = 4

    /// Trees equivalent planted per kg of CO₂ avoided (roughly).
    static let treesPerKgCO2: Double = 0.045

    // MARK: - Impact Phrases
    //
    // Each rescue moment gets a rotating message so the app never feels
    // repetitive. The phrases mix PEOPLE wins and PLANET wins — always
    // both, never just one.

    /// Returns a random mission-aligned impact phrase for a consumed item.
    static func impactPhrase(itemName: String, totalRescued: Int) -> String {
        let co2 = String(format: "%.1f", co2PerItemKg)
        let phrases = [
            // Planet-centric
            String(localized: "\(itemName) rescued. That's \(co2)kg of CO₂ kept out of the atmosphere. 🌍"),
            String(localized: "\(itemName) rescued. \(Int(waterPerItemL))L of water saved in the supply chain. 💧"),
            String(localized: "\(itemName) rescued. One less meal in landfill. One more in your belly. 🌱"),

            // People-centric
            String(localized: "\(itemName) rescued. £\(String(format: "%.2f", moneyPerItemGBP)) back in your pocket. 💚"),
            String(localized: "\(itemName) rescued. Every \(itemsPerMealFed) rescues feeds one extra person. 🤝"),

            // Collective / milestone
            totalRescued > 0
                ? String(localized: "\(itemName) rescued. Rescue #\(totalRescued). The whole neighbourhood just got a little greener. 🌿")
                : String(localized: "\(itemName) rescued. Your first of many. 🌿"),
        ]
        return phrases.randomElement() ?? phrases[0]
    }

    /// Returns a mission-aligned empty-state message for the pantry.
    static func emptyPantryTagline() -> String {
        String(localized: "Every item you add is one step toward a zero-waste neighbourhood.")
    }

    /// Returns a streak-milestone celebration phrase.
    static func streakMilestone(days: Int) -> String {
        switch days {
        case ..<3:   return String(localized: "You're building a rescue habit. Keep going.")
        case 3..<7:  return String(localized: "\(days) days in a row. Your planet thanks you. 🌱")
        case 7..<14: return String(localized: "A full week of rescues. That's about \(Int(Double(days) * co2PerItemKg))kg of CO₂ avoided.")
        case 14..<30: return String(localized: "\(days)-day streak. You're in the top 5% of rescuers.")
        case 30..<100: return String(localized: "A whole month! You've fed approximately \(days / itemsPerMealFed) extra meals worth of people.")
        default:     return String(localized: "\(days)-day legend status. You're the reason the planet is still standing. 👑")
        }
    }

    // MARK: - Social Proof Copy

    /// Rotating social-proof lines used on the paywall and Home wave card.
    static let collectivePhrases: [String] = [
        String(localized: "rescued food in the last hour"),
        String(localized: "chose people and planet today"),
        String(localized: "picked up the baton from a neighbour"),
        String(localized: "said yes to one more rescue"),
    ]

    // MARK: - Colours

    /// Mission accent used on the collective wave card, brand CTAs.
    static let missionAccent = Color(hex: 0x16A34A)    // rich green-600
    static let missionAccentLight = Color(hex: 0x22C55E)
    static let planetBlue = Color(hex: 0x0EA5E9)       // sky-500
    static let peoplePink = Color(hex: 0xEC4899)       // pink-500
}
