import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var displayName: String
    var hasCompletedOnboarding: Bool
    var notificationsEnabled: Bool
    var expiryReminderDays: Int
    var preferredLanguage: String

    // MARK: - Impact Stats

    var itemsSaved: Int
    var itemsShared: Int
    var itemsDonated: Int
    var mealsCreated: Int

    var estimatedMoneySaved: Double {
        Double(itemsSaved) * 3.50
    }

    var estimatedCO2Avoided: Double {
        Double(itemsSaved + itemsShared + itemsDonated) * 2.5
    }

    var totalMealsSharedOrDonated: Int {
        itemsShared + itemsDonated
    }

    init() {
        self.id = UUID()
        self.displayName = ""
        self.hasCompletedOnboarding = false
        self.notificationsEnabled = true
        self.expiryReminderDays = 3
        self.preferredLanguage = "en"
        self.itemsSaved = 0
        self.itemsShared = 0
        self.itemsDonated = 0
        self.mealsCreated = 0
    }
}
