import Foundation
import SwiftUI
import SwiftData
import os

// MARK: - Sendable Transfer Types
// Thread-safe value types for passing ingredient data between Supabase background threads and UI.

struct FreshliIngredientSnapshot: Sendable, Hashable, Codable {
    let name: String
    let category: String
    let expiryDate: Date
    let itemId: UUID

    init(from item: FreshliItem) {
        self.name = item.name
        self.category = item.categoryRaw
        self.expiryDate = item.expiryDate
        self.itemId = item.id
    }
}

struct FreshliRecipeSnapshot: Sendable, Hashable, Identifiable, Codable {
    let id: UUID
    let title: String
    let summary: String
    let ingredients: [String]
    let steps: [String]
    let prepTimeMinutes: Int
    let difficulty: String
    let matchingCount: Int
    let totalCount: Int
    let imageSystemName: String

    var matchPercentage: Double {
        guard totalCount > 0 else { return 0 }
        return Double(matchingCount) / Double(totalCount)
    }

    var matchPercentageDisplay: String {
        "\(Int(matchPercentage * 100))% match"
    }

    var prepTimeDisplay: String {
        "\(prepTimeMinutes) min"
    }

    init(from recipe: Recipe) {
        self.id = recipe.id
        self.title = recipe.title
        self.summary = recipe.summary
        self.ingredients = recipe.ingredients
        self.steps = recipe.steps
        self.prepTimeMinutes = recipe.prepTimeMinutes
        self.difficulty = recipe.difficulty.rawValue
        self.matchingCount = recipe.matchingIngredientCount
        self.totalCount = recipe.totalIngredientCount
        self.imageSystemName = recipe.imageSystemName
    }

    var difficultyEnum: RecipeDifficulty {
        RecipeDifficulty(rawValue: difficulty) ?? .easy
    }
}

struct FreshliImpactPayload: Sendable {
    let userId: UUID
    let itemSnapshots: [FreshliIngredientSnapshot]
    let recipeName: String
    let co2Avoided: Double
    let moneySaved: Double
}

// MARK: - Typed Encodable struct for Supabase .update()

struct FreshliItemConsumedUpdate: Encodable {
    let isConsumed: Bool
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case isConsumed = "is_consumed"
        case updatedAt = "updated_at"
    }

    init(consumed: Bool = true) {
        self.isConsumed = consumed
        self.updatedAt = ISO8601DateFormatter().string(from: Date())
    }
}

// MARK: - Impact Update Actor
// Isolated actor for background Supabase impact writes, preventing data races.

actor FreshliImpactActor {
    private let impactService = ImpactSupabaseService()
    private let logger = Logger(subsystem: "com.freshli.app", category: "FreshliImpactActor")

    func recordRecipeUsage(_ payload: FreshliImpactPayload) async {
        do {
            // Record one impact event per ingredient used
            for snapshot in payload.itemSnapshots {
                _ = try await impactService.recordEvent(
                    userId: payload.userId,
                    eventType: "recipe_ingredient_used",
                    itemName: snapshot.name,
                    moneySaved: payload.moneySaved / Double(payload.itemSnapshots.count),
                    co2Avoided: payload.co2Avoided / Double(payload.itemSnapshots.count),
                    metadata: [
                        "recipe_name": AnyCodable.string(payload.recipeName),
                        "category": AnyCodable.string(snapshot.category),
                        "item_id": AnyCodable.string(snapshot.itemId.uuidString)
                    ]
                )
            }

            // Record aggregate recipe completion event
            _ = try await impactService.recordEvent(
                userId: payload.userId,
                eventType: "recipe_completed",
                itemName: payload.recipeName,
                moneySaved: payload.moneySaved,
                co2Avoided: payload.co2Avoided,
                metadata: [
                    "ingredients_used": AnyCodable.double(Double(payload.itemSnapshots.count)),
                    "recipe_name": AnyCodable.string(payload.recipeName)
                ]
            )

            logger.info("Recorded impact for recipe '\(payload.recipeName)' with \(payload.itemSnapshots.count) ingredients")
        } catch {
            logger.error("Failed to record recipe impact: \(error.localizedDescription)")
        }
    }
}

// MARK: - Recipe Rescue Engine
// @Observable state machine for the Recipe Rescue flow with zero-overhead UI filtering.

enum RecipeFilterMode: String, CaseIterable, Identifiable {
    case forYou = "For You"
    case quickEasy = "Quick & Easy"
    case expiringSoon = "Expiring Soon"
    case bestMatch = "Best Match"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .forYou: return "sparkles"
        case .quickEasy: return "bolt.fill"
        case .expiringSoon: return "exclamationmark.triangle.fill"
        case .bestMatch: return "chart.pie.fill"
        }
    }
}

enum RecipeFlowDestination: Hashable {
    case detail(FreshliRecipeSnapshot)
    case cooking(FreshliRecipeSnapshot)
}

@Observable
@MainActor
final class RecipeRescueEngine {
    // MARK: - Published State

    private(set) var allRecipeSnapshots: [FreshliRecipeSnapshot] = []
    private(set) var filteredSnapshots: [FreshliRecipeSnapshot] = []
    private(set) var ingredientSnapshots: [FreshliIngredientSnapshot] = []
    private(set) var isLoading = false
    private(set) var usedItemIds: Set<UUID> = []

    var activeFilter: RecipeFilterMode = .forYou {
        didSet { applyFilter() }
    }

    var navigationPath = NavigationPath()

    // MARK: - Cooking State

    private(set) var currentRecipe: FreshliRecipeSnapshot?
    private(set) var completedSteps: Set<Int> = []
    private(set) var cookingStartTime: Date?

    var isCooking: Bool { currentRecipe != nil }

    var currentStepIndex: Int {
        guard let recipe = currentRecipe else { return 0 }
        for i in 0..<recipe.steps.count {
            if !completedSteps.contains(i) { return i }
        }
        return recipe.steps.count - 1
    }

    var nextStepText: String? {
        guard let recipe = currentRecipe else { return nil }
        let idx = currentStepIndex
        guard idx < recipe.steps.count else { return nil }
        return recipe.steps[idx]
    }

    var cookingProgress: Double {
        guard let recipe = currentRecipe, !recipe.steps.isEmpty else { return 0 }
        return Double(completedSteps.count) / Double(recipe.steps.count)
    }

    var allStepsCompleted: Bool {
        guard let recipe = currentRecipe else { return false }
        return completedSteps.count == recipe.steps.count
    }

    // MARK: - Private

    private let impactActor = FreshliImpactActor()
    private let logger = PSLogger(category: .recipe)

    // MARK: - Data Loading

    func loadRecipes(pantryItems: [FreshliItem]) {
        isLoading = true

        // Create Sendable snapshots from FreshliItem (SwiftData model, not Sendable)
        ingredientSnapshots = pantryItems.map { FreshliIngredientSnapshot(from: $0) }

        // Get matched recipes and convert to Sendable snapshots
        let matched = RecipeService.shared.recipesForFreshli(items: pantryItems)
        allRecipeSnapshots = matched.map { FreshliRecipeSnapshot(from: $0) }

        applyFilter()
        isLoading = false
        logger.info("Loaded \(allRecipeSnapshots.count) recipe snapshots from \(pantryItems.count) pantry items")
    }

    // MARK: - Filtering (zero-overhead: direct array ops on @Observable state)

    private func applyFilter() {
        switch activeFilter {
        case .forYou:
            filteredSnapshots = allRecipeSnapshots

        case .quickEasy:
            filteredSnapshots = allRecipeSnapshots.filter { $0.prepTimeMinutes <= 20 }

        case .expiringSoon:
            // Prioritize recipes using ingredients expiring within 24 hours
            let urgentNames = Set(
                ingredientSnapshots
                    .filter { $0.expiryDate.timeIntervalSinceNow < 86400 }
                    .map { $0.name.lowercased() }
            )
            filteredSnapshots = allRecipeSnapshots
                .filter { recipe in
                    recipe.ingredients.contains { ingredient in
                        urgentNames.contains { pantryName in
                            pantryName.localizedCaseInsensitiveContains(ingredient) ||
                            ingredient.localizedCaseInsensitiveContains(pantryName)
                        }
                    }
                }
                .sorted { $0.matchPercentage > $1.matchPercentage }

        case .bestMatch:
            filteredSnapshots = allRecipeSnapshots
                .sorted { $0.matchPercentage > $1.matchPercentage }
        }
    }

    // MARK: - Cooking Flow

    func startCooking(recipe: FreshliRecipeSnapshot) {
        currentRecipe = recipe
        completedSteps = []
        cookingStartTime = Date()
        logger.info("Started cooking: \(recipe.title)")
    }

    func toggleStep(_ index: Int) {
        if completedSteps.contains(index) {
            completedSteps.remove(index)
        } else {
            completedSteps.insert(index)
        }
    }

    func stopCooking() {
        currentRecipe = nil
        completedSteps = []
        cookingStartTime = nil
    }

    // MARK: - Mark Items Used + Impact Engine

    /// Marks matching pantry items as consumed and fires a background impact update.
    /// Returns the IDs of items that were marked consumed.
    @discardableResult
    func markIngredientsUsed(
        recipe: FreshliRecipeSnapshot,
        pantryItems: [FreshliItem],
        modelContext: ModelContext,
        userId: UUID?
    ) -> [UUID] {
        let recipeIngredients = Set(recipe.ingredients.map { $0.lowercased() })
        var markedIds: [UUID] = []
        var snapshots: [FreshliIngredientSnapshot] = []

        for item in pantryItems where !item.isConsumed {
            let matches = recipeIngredients.contains { ingredient in
                item.name.localizedCaseInsensitiveContains(ingredient) ||
                ingredient.localizedCaseInsensitiveContains(item.name)
            }
            if matches {
                item.isConsumed = true
                markedIds.append(item.id)
                snapshots.append(FreshliIngredientSnapshot(from: item))
            }
        }

        if !markedIds.isEmpty {
            try? modelContext.save()
            usedItemIds.formUnion(markedIds)
            logger.info("Marked \(markedIds.count) items consumed for recipe '\(recipe.title)'")
        }

        // Fire background impact update
        if let userId, !snapshots.isEmpty {
            let co2PerItem = 0.8 // ~0.8 kg CO2 per food item rescued
            let moneyPerItem = 3.50 // ~$3.50 average value per item

            let payload = FreshliImpactPayload(
                userId: userId,
                itemSnapshots: snapshots,
                recipeName: recipe.title,
                co2Avoided: co2PerItem * Double(snapshots.count),
                moneySaved: moneyPerItem * Double(snapshots.count)
            )

            Task.detached { [impactActor] in
                await impactActor.recordRecipeUsage(payload)
            }
        }

        return markedIds
    }

    // MARK: - Navigation

    func navigateToDetail(_ recipe: FreshliRecipeSnapshot) {
        navigationPath.append(RecipeFlowDestination.detail(recipe))
    }

    func navigateToCooking(_ recipe: FreshliRecipeSnapshot) {
        startCooking(recipe: recipe)
        navigationPath.append(RecipeFlowDestination.cooking(recipe))
    }

    func popToRoot() {
        navigationPath = NavigationPath()
        stopCooking()
    }
}
