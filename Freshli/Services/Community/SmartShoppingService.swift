import Foundation
import SwiftUI

// MARK: - Smart Shopping Service
// Reverse integration: tells users what to buy based on waste patterns
// and "Fill the Gap" recipe logic.

// MARK: - Models

struct WastePrediction: Identifiable {
    let id = UUID()
    let itemName: String
    let suggestedQuantity: Double
    let suggestedUnit: String
    let wasteRate: Double          // 0.0 → 1.0
    let wastedCount: Int
    let totalCount: Int
    let estimatedSavings: Double   // dollars
    let reason: String
}

struct GapFillSuggestion: Identifiable {
    let id = UUID()
    let itemToBuy: String
    let category: FoodCategory
    let unlocksRecipes: [Recipe]
    let pantryMatchCount: Int      // ingredients user already has
}

// MARK: - Service

@MainActor
final class SmartShoppingService {
    static let shared = SmartShoppingService()
    private init() {}

    // MARK: - Waste Predictions

    /// Analyse historical items to identify patterns where the user wastes ≥20%.
    func predictWastefulItems(from allItems: [FreshliItem]) -> [WastePrediction] {
        let now = Date()
        let grouped = Dictionary(grouping: allItems) {
            $0.name.lowercased().trimmingCharacters(in: .whitespaces)
        }
        var predictions: [WastePrediction] = []

        for (_, items) in grouped {
            guard items.count >= 2,
                  let sample = items.first else { continue }
            let total = items.count
            guard total > 0 else { continue }
            let wasted = items.filter {
                !$0.isConsumed && !$0.isShared && !$0.isDonated && $0.expiryDate < now
            }.count
            let wasteRate = Double(wasted) / Double(total)
            guard wasteRate >= 0.20 else { continue }
            let suggestedQty = max(0.5, sample.quantity * (1.0 - wasteRate * 0.5))
            let estimatedSavings = Double(wasted) * 2.50

            predictions.append(WastePrediction(
                itemName: sample.name,
                suggestedQuantity: suggestedQty,
                suggestedUnit: sample.unitRaw,
                wasteRate: wasteRate,
                wastedCount: wasted,
                totalCount: total,
                estimatedSavings: estimatedSavings,
                reason: "You've wasted \(Int(wasteRate * 100))% of your \(sample.name.lowercased()) — try buying \(formatQty(suggestedQty, unit: sample.unitRaw)) instead."
            ))
        }
        return predictions.sorted { $0.estimatedSavings > $1.estimatedSavings }
    }

    // MARK: - Fill-the-Gap Suggestions

    /// Return items to buy that unlock the most recipes from the user's current pantry.
    func fillGapSuggestions(pantryItems: [FreshliItem], recipes: [Recipe]) -> [GapFillSuggestion] {
        let pantryNames = Set(pantryItems.map { $0.name.lowercased() })
        var missingToRecipes: [String: [Recipe]] = [:]

        for recipe in recipes {
            let lower = recipe.ingredients.map { $0.lowercased() }
            let missing = lower.filter { ingredient in
                !pantryNames.contains(where: {
                    $0.contains(ingredient) || ingredient.contains($0)
                })
            }
            if missing.count == 1 {
                missingToRecipes[missing[0], default: []].append(recipe)
            }
        }

        return missingToRecipes
            .filter { $0.value.count >= 2 }
            .map { (ingredient, matched) in
                GapFillSuggestion(
                    itemToBuy: ingredient.capitalized,
                    category: inferCategory(for: ingredient),
                    unlocksRecipes: matched,
                    pantryMatchCount: matched[0].totalIngredientCount - 1
                )
            }
            .sorted { $0.unlocksRecipes.count > $1.unlocksRecipes.count }
    }

    // MARK: - Helpers

    private func formatQty(_ qty: Double, unit: String) -> String {
        qty == qty.rounded() ? "\(Int(qty)) \(unit)" : String(format: "%.1f \(unit)", qty)
    }

    private func inferCategory(for ingredient: String) -> FoodCategory {
        let l = ingredient.lowercased()
        if ["milk", "cheese", "yogurt", "butter", "cream", "egg"].contains(where: l.contains) { return .dairy }
        if ["chicken", "beef", "pork", "lamb", "turkey", "bacon"].contains(where: l.contains) { return .meat }
        if ["salmon", "tuna", "cod", "prawn", "shrimp"].contains(where: l.contains) { return .seafood }
        if ["apple", "banana", "berry", "orange", "lemon", "mango", "avocado"].contains(where: l.contains) { return .fruits }
        if ["pasta", "rice", "bread", "flour", "oat", "cereal"].contains(where: l.contains) { return .grains }
        return .vegetables
    }
}
