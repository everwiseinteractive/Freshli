import Foundation
import SwiftData

// MARK: - PreviewSampleData
/// Sample data for previews and initial app setup

@MainActor
final class PreviewSampleData {
    
    static let shared = PreviewSampleData()
    
    private init() {}
    
    var sampleFreshliItems: [FreshliItem] {
        [
            FreshliItem(
                name: "Milk",
                category: .dairy,
                storageLocation: .fridge,
                quantity: 1,
                unit: .liters,
                expiryDate: Date.daysFromNow(3),
                notes: "Organic whole milk"
            ),
            FreshliItem(
                name: "Apples",
                category: .fruits,
                storageLocation: .counter,
                quantity: 6,
                unit: .pieces,
                expiryDate: Date.daysFromNow(5)
            ),
            FreshliItem(
                name: "Chicken Breast",
                category: .meat,
                storageLocation: .fridge,
                quantity: 500,
                unit: .grams,
                expiryDate: Date.daysFromNow(2)
            ),
            FreshliItem(
                name: "Bread",
                category: .bakery,
                storageLocation: .pantry,
                quantity: 1,
                unit: .packs,
                expiryDate: Date.daysFromNow(4)
            ),
            FreshliItem(
                name: "Carrots",
                category: .vegetables,
                storageLocation: .fridge,
                quantity: 8,
                unit: .pieces,
                expiryDate: Date.daysFromNow(7)
            ),
            FreshliItem(
                name: "Yogurt",
                category: .dairy,
                storageLocation: .fridge,
                quantity: 4,
                unit: .cups,
                expiryDate: Date.daysFromNow(6)
            ),
            FreshliItem(
                name: "Rice",
                category: .grains,
                storageLocation: .pantry,
                quantity: 2,
                unit: .kilograms,
                expiryDate: Date.daysFromNow(180)
            ),
            FreshliItem(
                name: "Tomatoes",
                category: .vegetables,
                storageLocation: .counter,
                quantity: 5,
                unit: .pieces,
                expiryDate: Date.daysFromNow(4)
            )
        ]
    }
    
    var sampleUserProfile: UserProfile {
        let profile = UserProfile()
        profile.displayName = "Sarah Johnson"
        profile.hasCompletedOnboarding = true
        profile.notificationsEnabled = true
        profile.itemsSaved = 23
        profile.itemsShared = 5
        profile.itemsDonated = 3
        profile.mealsCreated = 12
        return profile
    }
}
