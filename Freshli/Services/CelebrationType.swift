import SwiftUI

// MARK: - CelebrationType
/// Types of celebrations that can be triggered in the app

enum CelebrationType: Equatable {
    
    // MARK: - First-Time Events
    
    case firstItemAdded
    case firstFoodSaved
    
    // MARK: - Achievements
    
    case achievementUnlock(title: String, icon: String)
    case expiryRescueStreak(count: Int)
    
    // MARK: - Community Actions
    
    case shareCompleted(itemName: String)
    case donationCompleted(itemName: String)
    case communityImpact(totalItems: Int, neighbors: Int)
    
    // MARK: - Recipe Matching
    
    case recipeMatchSuccess(recipeName: String)
    
    // MARK: - Weekly Recap
    
    case weeklyRecap(saved: Int, shared: Int, co2: Double, money: Double)
    
    // MARK: - Display Properties
    
    var title: String {
        switch self {
        case .firstItemAdded:
            return String(localized: "🎉 Welcome to Freshli!")
        case .firstFoodSaved:
            return String(localized: "🌱 First Item Saved!")
        case .achievementUnlock(let title, _):
            return "🏆 \(title)"
        case .expiryRescueStreak(let count):
            return String(localized: "🔥 \(count) Day Streak!")
        case .shareCompleted(let itemName):
            return String(localized: "💚 Shared: \(itemName)")
        case .donationCompleted(let itemName):
            return String(localized: "🎁 Donated: \(itemName)")
        case .communityImpact(let total, let neighbors):
            return String(localized: "🌟 \(total) Items Shared!")
        case .recipeMatchSuccess(let recipeName):
            return String(localized: "✨ Recipe Found!")
        case .weeklyRecap:
            return String(localized: "📊 Your Weekly Impact")
        }
    }
    
    var message: String {
        switch self {
        case .firstItemAdded:
            return String(localized: "You've taken the first step toward reducing food waste!")
        case .firstFoodSaved:
            return String(localized: "You've prevented food waste and saved money!")
        case .achievementUnlock(_, let icon):
            return String(localized: "Achievement unlocked! Keep up the great work.")
        case .expiryRescueStreak(let count):
            return String(localized: "You've been actively managing your pantry for \(count) days straight!")
        case .shareCompleted(let itemName):
            return String(localized: "\(itemName) is now available for your community!")
        case .donationCompleted(let itemName):
            return String(localized: "\(itemName) will help someone in need. Thank you!")
        case .communityImpact(_, let neighbors):
            return String(localized: "You've helped \(neighbors) neighbors in your community!")
        case .recipeMatchSuccess(let recipeName):
            return String(localized: "We found a perfect recipe: \(recipeName)")
        case .weeklyRecap(let saved, let shared, let co2, let money):
            return String(localized: "Saved: \(saved) | Shared: \(shared)\nCO₂ Avoided: \(String(format: "%.1f", co2))kg | Money Saved: $\(String(format: "%.2f", money))")
        }
    }
    
    var icon: String {
        switch self {
        case .firstItemAdded:
            return "leaf.fill"
        case .firstFoodSaved:
            return "checkmark.circle.fill"
        case .achievementUnlock(_, let icon):
            return icon
        case .expiryRescueStreak:
            return "flame.fill"
        case .shareCompleted:
            return "heart.fill"
        case .donationCompleted:
            return "gift.fill"
        case .communityImpact:
            return "person.2.fill"
        case .recipeMatchSuccess:
            return "sparkles"
        case .weeklyRecap:
            return "chart.bar.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .firstItemAdded, .firstFoodSaved:
            return PSColors.primaryGreen
        case .achievementUnlock:
            return Color(hex: 0xFFD700) // Gold
        case .expiryRescueStreak:
            return Color(hex: 0xFF6B35) // Orange
        case .shareCompleted, .communityImpact:
            return PSColors.primaryGreen
        case .donationCompleted:
            return Color(hex: 0x9B5DE5) // Purple
        case .recipeMatchSuccess:
            return Color(hex: 0xF15BB5) // Pink
        case .weeklyRecap:
            return Color(hex: 0x00BBF9) // Blue
        }
    }
    
    var intensity: FreshliHapticManager.CelebrationIntensity {
        switch self {
        case .firstItemAdded, .shareCompleted, .donationCompleted, .recipeMatchSuccess:
            return .small
        case .firstFoodSaved, .expiryRescueStreak:
            return .medium
        case .achievementUnlock, .communityImpact, .weeklyRecap:
            return .large
        }
    }
    
    var shouldAutoDismiss: Bool {
        switch self {
        case .firstItemAdded, .firstFoodSaved, .shareCompleted, .donationCompleted, .recipeMatchSuccess:
            return true
        case .achievementUnlock, .expiryRescueStreak, .communityImpact, .weeklyRecap:
            return false // User must dismiss manually
        }
    }
}
