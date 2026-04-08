import SwiftUI

// MARK: - Celebration Type Definitions
// Figma: CelebrationSystem — 10 celebration variants, 3 intensity tiers
// Each type defines its own color palette, icon, copy, and intensity

enum CelebrationIntensity {
    case small    // Quick 1.5s toast, 4 confetti, no CTA
    case medium   // Full-screen, 6 confetti, CTA button
    case hero     // Full-screen, 12 confetti, badge reveal, extra stats
}

enum CelebrationType: Identifiable, Equatable {
    case firstItemAdded
    case firstFoodSaved
    case recipeMatchSuccess(recipeName: String)
    case shareCompleted(itemName: String)
    case donationCompleted(itemName: String)
    case expiryRescueStreak(count: Int)
    case impactMilestone(milestone: String, stat: String)
    case weeklyRecap(saved: Int, shared: Int, co2: Double, money: Double)
    case communityImpact(totalItems: Int, neighbors: Int)
    case achievementUnlock(title: String, icon: String)

    var id: String {
        switch self {
        case .firstItemAdded: return "firstItemAdded"
        case .firstFoodSaved: return "firstFoodSaved"
        case .recipeMatchSuccess: return "recipeMatch"
        case .shareCompleted: return "shareCompleted"
        case .donationCompleted: return "donationCompleted"
        case .expiryRescueStreak: return "expiryStreak"
        case .impactMilestone: return "impactMilestone"
        case .weeklyRecap: return "weeklyRecap"
        case .communityImpact: return "communityImpact"
        case .achievementUnlock: return "achievementUnlock"
        }
    }

    static func == (lhs: CelebrationType, rhs: CelebrationType) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Visual Properties

    var intensity: CelebrationIntensity {
        switch self {
        case .firstItemAdded: return .medium
        case .firstFoodSaved: return .medium
        case .recipeMatchSuccess: return .small
        case .shareCompleted: return .medium
        case .donationCompleted: return .medium
        case .expiryRescueStreak(let count): return count >= 7 ? .hero : .medium
        case .impactMilestone: return .hero
        case .weeklyRecap: return .hero
        case .communityImpact: return .hero
        case .achievementUnlock: return .hero
        }
    }

    // Figma: Each celebration uses a distinct background from the Tailwind palette
    var backgroundColor: Color {
        switch self {
        case .firstItemAdded:      return Color(hex: 0x22C55E)  // green-500
        case .firstFoodSaved:      return Color(hex: 0x16A34A)  // green-600
        case .recipeMatchSuccess:  return Color(hex: 0x8B5CF6)  // violet-500
        case .shareCompleted:      return Color(hex: 0x3B82F6)  // blue-500
        case .donationCompleted:   return Color(hex: 0x14B8A6)  // teal-500
        case .expiryRescueStreak:  return Color(hex: 0xF59E0B)  // amber-500
        case .impactMilestone:     return Color(hex: 0x059669)  // emerald-600
        case .weeklyRecap:         return Color(hex: 0x1E293B)  // slate-800
        case .communityImpact:     return Color(hex: 0x0D9488)  // teal-600
        case .achievementUnlock:   return Color(hex: 0xD97706)  // amber-600
        }
    }

    // Figma: Icon container background — one step lighter than main bg
    var iconBackgroundColor: Color {
        switch self {
        case .firstItemAdded:      return Color(hex: 0x4ADE80)  // green-400
        case .firstFoodSaved:      return Color(hex: 0x22C55E)  // green-500
        case .recipeMatchSuccess:  return Color(hex: 0xA78BFA)  // violet-400
        case .shareCompleted:      return Color(hex: 0x60A5FA)  // blue-400
        case .donationCompleted:   return Color(hex: 0x2DD4BF)  // teal-400
        case .expiryRescueStreak:  return Color(hex: 0xFBBF24)  // amber-400
        case .impactMilestone:     return Color(hex: 0x10B981)  // emerald-500
        case .weeklyRecap:         return Color(hex: 0x334155)  // slate-700
        case .communityImpact:     return Color(hex: 0x14B8A6)  // teal-500
        case .achievementUnlock:   return Color(hex: 0xF59E0B)  // amber-500
        }
    }

    // Figma: Radial pulse — two steps lighter for glow rings
    var pulseColor: Color {
        switch self {
        case .firstItemAdded:      return Color(hex: 0x86EFAC)  // green-300
        case .firstFoodSaved:      return Color(hex: 0x4ADE80)  // green-400
        case .recipeMatchSuccess:  return Color(hex: 0xC4B5FD)  // violet-300
        case .shareCompleted:      return Color(hex: 0x93C5FD)  // blue-300
        case .donationCompleted:   return Color(hex: 0x5EEAD4)  // teal-300
        case .expiryRescueStreak:  return Color(hex: 0xFDE68A)  // amber-200
        case .impactMilestone:     return Color(hex: 0x6EE7B7)  // emerald-300
        case .weeklyRecap:         return Color(hex: 0x475569)  // slate-600
        case .communityImpact:     return Color(hex: 0x5EEAD4)  // teal-300
        case .achievementUnlock:   return Color(hex: 0xFDE68A)  // amber-200
        }
    }

    // Figma: Description text color — light variant of theme
    var descriptionColor: Color {
        switch self {
        case .weeklyRecap: return Color(hex: 0x94A3B8) // slate-400
        default: return backgroundColor.opacity(0.7).blended(with: .white, amount: 0.6)
        }
    }

    // Figma: CTA text color — matches main bg for contrast on white button
    var ctaTextColor: Color {
        switch self {
        case .weeklyRecap: return Color(hex: 0x1E293B)
        default: return backgroundColor
        }
    }

    // Figma: shadow-green-900/20 (or theme equivalent)
    var ctaShadowColor: Color {
        backgroundColor.opacity(0.2)
    }

    var icon: String {
        switch self {
        case .firstItemAdded:      return "plus.circle"
        case .firstFoodSaved:      return "leaf.fill"
        case .recipeMatchSuccess:  return "fork.knife"
        case .shareCompleted:      return "hand.raised.fill"
        case .donationCompleted:   return "heart.fill"
        case .expiryRescueStreak:  return "flame.fill"
        case .impactMilestone:     return "star.fill"
        case .weeklyRecap:         return "chart.bar.fill"
        case .communityImpact:     return "person.3.fill"
        case .achievementUnlock(_, let icon): return icon
        }
    }

    var title: String {
        switch self {
        case .firstItemAdded:
            return String(localized: "First Item Added!")
        case .firstFoodSaved:
            return String(localized: "Food Saved!")
        case .recipeMatchSuccess(let name):
            return String(localized: "Recipe Match!")
        case .shareCompleted:
            return String(localized: "Shared Successfully!")
        case .donationCompleted:
            return String(localized: "Donation Complete!")
        case .expiryRescueStreak(let count):
            return String(localized: "\(count)-Day Streak!")
        case .impactMilestone(let milestone, _):
            return milestone
        case .weeklyRecap:
            return String(localized: "Your Week in Review")
        case .communityImpact:
            return String(localized: "Community Impact!")
        case .achievementUnlock(let title, _):
            return title
        }
    }

    var subtitle: String {
        switch self {
        case .firstItemAdded:
            return String(localized: "Welcome to Freshli! Your journey to reduce food waste starts now.")
        case .firstFoodSaved:
            return String(localized: "You saved food from going to waste. Every item matters.")
        case .recipeMatchSuccess(let name):
            return String(localized: "\(name) uses ingredients you already have!")
        case .shareCompleted(let name):
            return String(localized: "\(name) will help someone in your community.")
        case .donationCompleted(let name):
            return String(localized: "\(name) is on its way to those in need. Thank you!")
        case .expiryRescueStreak(let count):
            return String(localized: "You've rescued food \(count) days in a row. Keep it up!")
        case .impactMilestone(_, let stat):
            return String(localized: "You've reached \(stat). You're making a real difference.")
        case .weeklyRecap:
            return String(localized: "Here's the impact you made this week.")
        case .communityImpact(let items, let neighbors):
            return String(localized: "\(items) items shared with \(neighbors) neighbors this month!")
        case .achievementUnlock:
            return String(localized: "You've unlocked a new achievement!")
        }
    }

    var ctaLabel: String {
        switch self {
        case .weeklyRecap: return String(localized: "Keep Going")
        case .achievementUnlock: return String(localized: "View Achievements")
        case .communityImpact: return String(localized: "View Community")
        default: return String(localized: "Continue")
        }
    }

    var confettiCount: Int {
        switch intensity {
        case .small: return 4
        case .medium: return 6
        case .hero: return 12
        }
    }
}

// MARK: - Color Blending Helper

private extension Color {
    func blended(with other: Color, amount: CGFloat) -> Color {
        // Simple approximation — in production use UIColor interpolation
        self.opacity(1 - amount)
    }
}
