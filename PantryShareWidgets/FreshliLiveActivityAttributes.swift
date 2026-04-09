import ActivityKit
import Foundation

// MARK: - Freshli Live Activity Attributes (Widget Target)
// Mirror of PantryShare/Models/FreshliLiveActivityAttributes.swift
// Both targets must have identical definitions.

// MARK: - Scenario 1: Expiring Soon

struct FreshliExpiryAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var progress: Double
        var minutesRemaining: Int
        var expiryDate: Date
        var status: String
    }

    var itemName: String
    var category: String
    var quantity: String
}

// MARK: - Scenario 2: Community Claim

struct FreshliClaimAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var distanceMeters: Double
        var etaMinutes: Int
        var status: String
    }

    var itemName: String
    var category: String
    var claimCode: String
    var pickupLocation: String
    var sharerName: String
}

// MARK: - Scenario 3: Recipe Timer

struct FreshliRecipeTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentStep: Int
        var totalSteps: Int
        var stepDescription: String
        var timerEnd: Date
        var stepDurationSeconds: Int
        var status: String
    }

    var recipeName: String
    var recipeEmoji: String
}
