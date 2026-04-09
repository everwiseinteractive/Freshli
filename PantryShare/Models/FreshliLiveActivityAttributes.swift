import ActivityKit
import Foundation

// MARK: - Freshli Live Activity Attributes
// Shared definitions for all three Live Activity scenarios.
// These structs must match the definitions in the PantryShareWidgets extension.

// MARK: - Scenario 1: Expiring Soon

/// Live Activity for items expiring within 6 hours.
/// Shows a progress bar transitioning from green to amber on the Lock Screen.
struct FreshliExpiryAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Fraction of time remaining (1.0 = full, 0.0 = expired).
        var progress: Double
        /// Minutes remaining until expiry.
        var minutesRemaining: Int
        /// The exact expiry date for timer rendering.
        var expiryDate: Date
        /// Current status: "expiring", "rescued", "expired"
        var status: String
    }

    var itemName: String
    var category: String
    var quantity: String
}

// MARK: - Scenario 2: Community Claim (Pickup)

/// Live Activity for when a user is on their way to pick up a shared item.
/// Dynamic Island shows distance to pickup and the claim code.
struct FreshliClaimAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Distance to pickup point in meters.
        var distanceMeters: Double
        /// Estimated minutes to arrival.
        var etaMinutes: Int
        /// Current status: "en_route", "arriving", "arrived", "collected"
        var status: String
    }

    var itemName: String
    var category: String
    var claimCode: String
    var pickupLocation: String
    var sharerName: String
}

// MARK: - Scenario 3: Recipe Timer

/// Live Activity for an active Freshli recipe cook session.
/// Dynamic Island shows current step and countdown timer.
struct FreshliRecipeTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Current step number (1-based).
        var currentStep: Int
        /// Total number of steps.
        var totalSteps: Int
        /// Short description of the current step.
        var stepDescription: String
        /// Target date when the current timer ends.
        var timerEnd: Date
        /// Duration of current step in seconds (for progress).
        var stepDurationSeconds: Int
        /// Current status: "cooking", "paused", "step_complete", "done"
        var status: String
    }

    var recipeName: String
    var recipeEmoji: String
}
