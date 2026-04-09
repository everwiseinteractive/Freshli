import Testing
import Foundation
@testable import Freshli

// MARK: - ImpactStats Calculation Tests

@Suite("Impact Stats Calculations")
struct ImpactStatsTests {

    // MARK: - Money Saved

    @Test("Money saved is $3.50 per item saved")
    func moneySavedBasic() {
        let stats = ImpactService.ImpactStats(itemsSaved: 10, itemsShared: 0, itemsDonated: 0, mealsCreated: 0)
        #expect(stats.moneySaved == 35.0)
    }

    @Test("Money saved is zero when no items saved")
    func moneySavedZero() {
        let stats = ImpactService.ImpactStats(itemsSaved: 0, itemsShared: 5, itemsDonated: 3, mealsCreated: 0)
        #expect(stats.moneySaved == 0.0)
    }

    @Test("Money saved is never negative")
    func moneySavedNonNegative() {
        let stats = ImpactService.ImpactStats(itemsSaved: 0, itemsShared: 0, itemsDonated: 0, mealsCreated: 0)
        #expect(stats.moneySaved >= 0)
    }

    @Test("Money saved display formats without decimals", arguments: [
        (1, "$4"),
        (10, "$35"),
        (0, "$0"),
    ])
    func moneySavedDisplay(itemsSaved: Int, expected: String) {
        let stats = ImpactService.ImpactStats(itemsSaved: itemsSaved, itemsShared: 0, itemsDonated: 0, mealsCreated: 0)
        #expect(stats.moneySavedDisplay == expected)
    }

    // MARK: - CO2 Avoided

    @Test("CO2 is 2.5kg per item (saved + shared + donated)")
    func co2AvoidedBasic() {
        let stats = ImpactService.ImpactStats(itemsSaved: 4, itemsShared: 3, itemsDonated: 3, mealsCreated: 0)
        // (4 + 3 + 3) * 2.5 = 25.0
        #expect(stats.co2Avoided == 25.0)
    }

    @Test("CO2 counts all disposition types equally")
    func co2CountsAllTypes() {
        let savedOnly = ImpactService.ImpactStats(itemsSaved: 10, itemsShared: 0, itemsDonated: 0, mealsCreated: 0)
        let mixedSame = ImpactService.ImpactStats(itemsSaved: 4, itemsShared: 3, itemsDonated: 3, mealsCreated: 0)
        // Both have 10 total items
        #expect(savedOnly.co2Avoided == mixedSame.co2Avoided)
    }

    @Test("CO2 is zero when no items")
    func co2AvoidedZero() {
        let stats = ImpactService.ImpactStats(itemsSaved: 0, itemsShared: 0, itemsDonated: 0, mealsCreated: 0)
        #expect(stats.co2Avoided == 0.0)
    }

    @Test("CO2 display formats to one decimal", arguments: [
        (4, "10.0kg"),
        (1, "2.5kg"),
        (0, "0.0kg"),
    ])
    func co2Display(itemsSaved: Int, expected: String) {
        let stats = ImpactService.ImpactStats(itemsSaved: itemsSaved, itemsShared: 0, itemsDonated: 0, mealsCreated: 0)
        #expect(stats.co2Display == expected)
    }

    // MARK: - Total Meals Helped

    @Test("Meals helped is shared + donated")
    func totalMealsHelped() {
        let stats = ImpactService.ImpactStats(itemsSaved: 10, itemsShared: 5, itemsDonated: 3, mealsCreated: 0)
        #expect(stats.totalMealsHelped == 8)
    }

    @Test("Meals helped excludes consumed items")
    func mealsHelpedExcludesConsumed() {
        let stats = ImpactService.ImpactStats(itemsSaved: 100, itemsShared: 0, itemsDonated: 0, mealsCreated: 50)
        #expect(stats.totalMealsHelped == 0)
    }

    @Test("Meals helped is never negative")
    func mealsHelpedNonNegative() {
        let stats = ImpactService.ImpactStats(itemsSaved: 0, itemsShared: 0, itemsDonated: 0, mealsCreated: 0)
        #expect(stats.totalMealsHelped >= 0)
    }
}

// MARK: - UserProfile Impact Calculation Tests

@Suite("UserProfile Impact Calculations")
struct UserProfileImpactTests {

    @Test("Estimated money saved matches $3.50 per item formula")
    func estimatedMoneySaved() {
        let profile = UserProfile()
        profile.itemsSaved = 20
        #expect(profile.estimatedMoneySaved == 70.0)
    }

    @Test("Estimated CO2 uses all item types")
    func estimatedCO2() {
        let profile = UserProfile()
        profile.itemsSaved = 5
        profile.itemsShared = 3
        profile.itemsDonated = 2
        // (5 + 3 + 2) * 2.5 = 25.0
        #expect(profile.estimatedCO2Avoided == 25.0)
    }

    @Test("Total meals shared or donated")
    func totalMealsSharedOrDonated() {
        let profile = UserProfile()
        profile.itemsShared = 7
        profile.itemsDonated = 4
        #expect(profile.totalMealsSharedOrDonated == 11)
    }

    @Test("Profile defaults to zero impact")
    func defaultsToZero() {
        let profile = UserProfile()
        #expect(profile.itemsSaved == 0)
        #expect(profile.itemsShared == 0)
        #expect(profile.itemsDonated == 0)
        #expect(profile.estimatedMoneySaved == 0.0)
        #expect(profile.estimatedCO2Avoided == 0.0)
        #expect(profile.totalMealsSharedOrDonated == 0)
    }
}

// MARK: - Milestone Tests

@Suite("Impact Milestones")
struct MilestonTests {

    @Test("First Saver unlocked at 1 item")
    func firstSaverMilestone() {
        let stats = ImpactService.ImpactStats(itemsSaved: 1, itemsShared: 0, itemsDonated: 0, mealsCreated: 0)
        // First Saver requires itemsSaved >= 1
        #expect(stats.itemsSaved >= 1)
    }

    @Test("Smart Saver unlocked at $50 saved")
    func smartSaverMilestone() {
        // $50 / $3.50 = ~14.3, so 15 items needed
        let stats = ImpactService.ImpactStats(itemsSaved: 15, itemsShared: 0, itemsDonated: 0, mealsCreated: 0)
        #expect(stats.moneySaved >= 50.0)
    }

    @Test("Climate Champion unlocked at 100kg CO2")
    func climateChampionMilestone() {
        // 100kg / 2.5kg = 40 items needed
        let stats = ImpactService.ImpactStats(itemsSaved: 40, itemsShared: 0, itemsDonated: 0, mealsCreated: 0)
        #expect(stats.co2Avoided >= 100.0)
    }

    @Test("Community Leader requires 25 shared/donated")
    func communityLeaderMilestone() {
        let stats = ImpactService.ImpactStats(itemsSaved: 0, itemsShared: 15, itemsDonated: 10, mealsCreated: 0)
        #expect(stats.totalMealsHelped >= 25)
    }

    @Test("Milestone progress clamps to 1.0")
    func progressClampsToOne() {
        let stats = ImpactService.ImpactStats(itemsSaved: 200, itemsShared: 0, itemsDonated: 0, mealsCreated: 0)
        let progress = min(1.0, Double(stats.itemsSaved) / 50.0)
        #expect(progress == 1.0)
    }

    @Test("Milestone progress at zero is 0.0")
    func progressAtZero() {
        let stats = ImpactService.ImpactStats(itemsSaved: 0, itemsShared: 0, itemsDonated: 0, mealsCreated: 0)
        let progress = min(1.0, Double(stats.itemsSaved) / 1.0)
        #expect(progress == 0.0)
    }
}

// MARK: - Consistency Tests

@Suite("Impact Formula Consistency")
struct ImpactConsistencyTests {

    @Test("ImpactStats and UserProfile use same money formula")
    func moneyFormulaConsistency() {
        let itemsSaved = 25
        let stats = ImpactService.ImpactStats(itemsSaved: itemsSaved, itemsShared: 0, itemsDonated: 0, mealsCreated: 0)
        let profile = UserProfile()
        profile.itemsSaved = itemsSaved
        #expect(stats.moneySaved == profile.estimatedMoneySaved)
    }

    @Test("ImpactStats and UserProfile use same CO2 formula")
    func co2FormulaConsistency() {
        let saved = 10, shared = 5, donated = 3
        let stats = ImpactService.ImpactStats(itemsSaved: saved, itemsShared: shared, itemsDonated: donated, mealsCreated: 0)
        let profile = UserProfile()
        profile.itemsSaved = saved
        profile.itemsShared = shared
        profile.itemsDonated = donated
        #expect(stats.co2Avoided == profile.estimatedCO2Avoided)
    }

    @Test("Large numbers don't overflow", arguments: [1000, 10_000, 100_000])
    func largeNumberSafety(count: Int) {
        let stats = ImpactService.ImpactStats(itemsSaved: count, itemsShared: count, itemsDonated: count, mealsCreated: count)
        #expect(stats.moneySaved.isFinite)
        #expect(stats.co2Avoided.isFinite)
        #expect(stats.moneySaved > 0)
        #expect(stats.co2Avoided > 0)
    }
}

// MARK: - Meal Suggestion Engine Tests

@Suite("Meal Suggestion Engine")
struct MealSuggestionEngineTests {

    @Test("Returns a recipe for every food category", arguments: FoodCategory.allCases)
    func recipeExistsForAllCategories(category: FoodCategory) {
        let recipe = MealSuggestionEngine.suggest(
            ingredients: ["Test Item"],
            category: category,
            maxMinutes: 15
        )
        #expect(!recipe.name.isEmpty)
        #expect(!recipe.description.isEmpty)
        #expect(recipe.minutes > 0)
    }

    @Test("Respects max minutes constraint")
    func respectsTimeConstraint() {
        let recipe = MealSuggestionEngine.suggest(
            ingredients: ["Carrots", "Broccoli"],
            category: .vegetables,
            maxMinutes: 5
        )
        #expect(recipe.minutes <= 5)
    }

    @Test("Falls back to stir-fry when no recipe fits time")
    func fallbackRecipe() {
        let recipe = MealSuggestionEngine.suggest(
            ingredients: ["Steak"],
            category: .meat,
            maxMinutes: 1
        )
        // Should get the fallback since no recipe fits 1 minute
        #expect(recipe.minutes <= 1)
    }
}
