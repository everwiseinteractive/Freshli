import Foundation
import SwiftData

// MARK: - Meal Plan Models

struct MealSlot: Identifiable {
    let id = UUID()
    let dayLabel: String        // "Today", "Tomorrow", "Wednesday"
    let recipe: Recipe
    let portionLabel: String    // "first half", "remaining half", "⅓ of the bag"
}

struct IngredientMealPlan: Identifiable {
    let id = UUID()
    let ingredient: FreshliItem
    let totalPortionLabel: String
    let slots: [MealSlot]

    var coveragePercent: Int {
        min(100, slots.count * 50)   // 2 meals = 100%
    }
}

// MARK: - Meal Plan Service
// Generates "waste-free bulk plans" that split a single bulk ingredient across
// multiple meals so nothing gets thrown away. Logic is intentionally lightweight
// and offline — no network call required.

@MainActor
final class MealPlanService {

    static let shared = MealPlanService()
    private init() {}

    // MARK: - Generation

    /// Generate plans for any ingredient that appears in 2+ recipes.
    /// Returns one plan per qualifying ingredient, sorted by expiry urgency.
    func generateBulkPlan(for items: [FreshliItem]) -> [IngredientMealPlan] {
        guard !items.isEmpty else { return [] }

        let allRecipes = RecipeService.shared.recipesForFreshli(items: items)
        var plans: [IngredientMealPlan] = []

        // Prefer items that have a larger-than-usual quantity or are expiring soon
        let candidates = items
            .filter { !$0.isConsumed && !$0.isShared && !$0.isDonated }
            .sorted { $0.expiryDate < $1.expiryDate }  // most urgent first

        for item in candidates {
            let name = item.name.lowercased()

            // Find every recipe that uses this ingredient
            let matching = allRecipes.filter { recipe in
                recipe.ingredients.contains(where: {
                    $0.localizedCaseInsensitiveContains(name) ||
                    name.localizedCaseInsensitiveContains($0)
                })
            }

            guard matching.count >= 2 else { continue }

            let dayLabels = daySequence()
            let portionLabels = portionSequence(for: item)

            let slots = zip(matching.prefix(portionLabels.count), zip(dayLabels, portionLabels)).map { (recipe, dayAndPortion) in
                MealSlot(
                    dayLabel: dayAndPortion.0,
                    recipe: recipe,
                    portionLabel: dayAndPortion.1
                )
            }

            plans.append(IngredientMealPlan(
                ingredient: item,
                totalPortionLabel: totalLabel(for: item),
                slots: Array(slots)
            ))

            // Cap at 3 plans to avoid overwhelming the UI
            if plans.count >= 3 { break }
        }

        return plans
    }

    // MARK: - Helpers

    private func daySequence() -> [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let today = Date()
        return [
            "Today",
            "Tomorrow",
            formatter.string(from: today.addingTimeInterval(172_800)),
            formatter.string(from: today.addingTimeInterval(259_200)),
        ]
    }

    private func portionSequence(for item: FreshliItem) -> [String] {
        let qty = item.quantity
        switch item.unit {
        case .grams where qty >= 400:
            return ["first 200g", "remaining 200g", "last portion"]
        case .grams where qty >= 200:
            return ["first half (\(Int(qty/2))g)", "second half (\(Int(qty/2))g)"]
        case .pieces where qty >= 4:
            let half = Int(qty / 2)
            return ["\(half) pieces", "remaining \(half) pieces"]
        case .liters where qty >= 1:
            return ["first half", "second half"]
        default:
            return ["first serving", "second serving"]
        }
    }

    private func totalLabel(for item: FreshliItem) -> String {
        let qty = item.quantityDisplay
        return "\(qty) of \(item.name)"
    }
}
