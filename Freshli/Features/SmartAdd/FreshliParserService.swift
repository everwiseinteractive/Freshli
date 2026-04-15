import Foundation

/// Parsed item returned by the Freshli AI parser from recognized text.
struct ParsedFoodItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let category: FoodCategory
    let storageLocation: StorageLocation
    let estimatedExpiryDays: Int
    let quantity: Double
    let unit: MeasurementUnit
    let confidence: Double

    var estimatedExpiryDate: Date {
        Calendar.current.date(byAdding: .day, value: estimatedExpiryDays, to: Date()) ?? Date()
    }

    static func == (lhs: ParsedFoodItem, rhs: ParsedFoodItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// Simulated AI service that parses recognized text from receipts/food labels
/// into structured food items with categories and estimated expiry dates.
/// In production, this would call a Supabase Edge Function.
@Observable @MainActor
final class FreshliParserService {

    // MARK: - Public API

    /// Parse recognized text lines into structured food items.
    func parse(recognizedTexts: [String]) async -> [ParsedFoodItem] {
        // Simulate network latency for the AI parsing step
        try? await Task.sleep(for: .milliseconds(600))

        let combined = recognizedTexts.joined(separator: "\n").lowercased()
        var items: [ParsedFoodItem] = []
        var seen = Set<String>()

        for entry in Self.knownItems {
            for keyword in entry.keywords {
                if combined.contains(keyword), !seen.contains(entry.name) {
                    seen.insert(entry.name)
                    items.append(ParsedFoodItem(
                        id: UUID(),
                        name: entry.name,
                        category: entry.category,
                        storageLocation: entry.storage,
                        estimatedExpiryDays: entry.expiryDays,
                        quantity: 1,
                        unit: entry.unit,
                        confidence: entry.confidence
                    ))
                }
            }
        }

        return items
    }

    // MARK: - Suggestion Database (for manual search)

    struct FoodSuggestion: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let category: FoodCategory
        let storage: StorageLocation
        let expiryDays: Int
        let unit: MeasurementUnit
    }

    /// Returns suggestions matching a search query for manual entry.
    func suggestions(for query: String) -> [FoodSuggestion] {
        guard query.count >= 2 else { return [] }
        let q = query.lowercased()
        return Self.suggestionDatabase.filter { suggestion in
            suggestion.name.lowercased().contains(q)
        }
    }

    // MARK: - Static Data

    private struct KnownEntry {
        let name: String
        let keywords: [String]
        let category: FoodCategory
        let storage: StorageLocation
        let expiryDays: Int
        let unit: MeasurementUnit
        let confidence: Double
    }

    private static let knownItems: [KnownEntry] = [
        KnownEntry(name: "Organic Bananas", keywords: ["banana", "bananas"], category: .fruits, storage: .counter, expiryDays: 5, unit: .pieces, confidence: 0.95),
        KnownEntry(name: "Whole Milk", keywords: ["milk", "whole milk", "2% milk"], category: .dairy, storage: .fridge, expiryDays: 7, unit: .liters, confidence: 0.92),
        KnownEntry(name: "Greek Yogurt", keywords: ["yogurt", "yoghurt", "greek yogurt"], category: .dairy, storage: .fridge, expiryDays: 14, unit: .pieces, confidence: 0.90),
        KnownEntry(name: "Chicken Breast", keywords: ["chicken", "chicken breast", "chkn"], category: .meat, storage: .fridge, expiryDays: 3, unit: .kilograms, confidence: 0.88),
        KnownEntry(name: "Salmon Fillet", keywords: ["salmon", "salmon fillet"], category: .seafood, storage: .fridge, expiryDays: 2, unit: .kilograms, confidence: 0.91),
        KnownEntry(name: "Sourdough Bread", keywords: ["bread", "sourdough", "loaf"], category: .bakery, storage: .counter, expiryDays: 4, unit: .pieces, confidence: 0.93),
        KnownEntry(name: "Baby Spinach", keywords: ["spinach", "baby spinach"], category: .vegetables, storage: .fridge, expiryDays: 5, unit: .grams, confidence: 0.89),
        KnownEntry(name: "Avocados", keywords: ["avocado", "avocados"], category: .fruits, storage: .counter, expiryDays: 4, unit: .pieces, confidence: 0.94),
        KnownEntry(name: "Cheddar Cheese", keywords: ["cheddar", "cheese"], category: .dairy, storage: .fridge, expiryDays: 21, unit: .grams, confidence: 0.87),
        KnownEntry(name: "Fresh Eggs", keywords: ["eggs", "egg", "large eggs"], category: .dairy, storage: .fridge, expiryDays: 21, unit: .pieces, confidence: 0.96),
        KnownEntry(name: "Orange Juice", keywords: ["orange juice", "oj", "juice"], category: .beverages, storage: .fridge, expiryDays: 10, unit: .liters, confidence: 0.90),
        KnownEntry(name: "Broccoli", keywords: ["broccoli"], category: .vegetables, storage: .fridge, expiryDays: 5, unit: .pieces, confidence: 0.93),
        KnownEntry(name: "Strawberries", keywords: ["strawberry", "strawberries"], category: .fruits, storage: .fridge, expiryDays: 4, unit: .grams, confidence: 0.91),
        KnownEntry(name: "Ground Beef", keywords: ["ground beef", "beef", "mince"], category: .meat, storage: .fridge, expiryDays: 2, unit: .kilograms, confidence: 0.85),
        KnownEntry(name: "Pasta", keywords: ["pasta", "spaghetti", "penne"], category: .grains, storage: .pantry, expiryDays: 365, unit: .grams, confidence: 0.97),
        KnownEntry(name: "Rice", keywords: ["rice", "basmati", "jasmine rice"], category: .grains, storage: .pantry, expiryDays: 365, unit: .kilograms, confidence: 0.96),
        KnownEntry(name: "Tomatoes", keywords: ["tomato", "tomatoes"], category: .vegetables, storage: .counter, expiryDays: 6, unit: .pieces, confidence: 0.92),
        KnownEntry(name: "Apples", keywords: ["apple", "apples", "gala", "fuji"], category: .fruits, storage: .fridge, expiryDays: 14, unit: .pieces, confidence: 0.94),
        KnownEntry(name: "Butter", keywords: ["butter", "unsalted butter"], category: .dairy, storage: .fridge, expiryDays: 30, unit: .grams, confidence: 0.93),
        KnownEntry(name: "Frozen Pizza", keywords: ["frozen pizza", "pizza"], category: .frozen, storage: .freezer, expiryDays: 90, unit: .pieces, confidence: 0.88),
        KnownEntry(name: "Olive Oil", keywords: ["olive oil"], category: .condiments, storage: .pantry, expiryDays: 180, unit: .milliliters, confidence: 0.95),
        KnownEntry(name: "Tortilla Chips", keywords: ["tortilla chips", "chips", "nachos"], category: .snacks, storage: .pantry, expiryDays: 60, unit: .grams, confidence: 0.86),
        KnownEntry(name: "Canned Tomatoes", keywords: ["canned tomato", "diced tomatoes", "crushed tomatoes"], category: .canned, storage: .pantry, expiryDays: 365, unit: .pieces, confidence: 0.97),
    ]

    static let suggestionDatabase: [FoodSuggestion] = [
        FoodSuggestion(name: "Apple", icon: "apple.logo", category: .fruits, storage: .fridge, expiryDays: 14, unit: .pieces),
        FoodSuggestion(name: "Banana", icon: "leaf.fill", category: .fruits, storage: .counter, expiryDays: 5, unit: .pieces),
        FoodSuggestion(name: "Avocado", icon: "leaf.fill", category: .fruits, storage: .counter, expiryDays: 4, unit: .pieces),
        FoodSuggestion(name: "Strawberries", icon: "leaf.fill", category: .fruits, storage: .fridge, expiryDays: 4, unit: .grams),
        FoodSuggestion(name: "Blueberries", icon: "leaf.fill", category: .fruits, storage: .fridge, expiryDays: 7, unit: .grams),
        FoodSuggestion(name: "Bread", icon: "birthday.cake.fill", category: .bakery, storage: .counter, expiryDays: 4, unit: .pieces),
        FoodSuggestion(name: "Bagel", icon: "birthday.cake.fill", category: .bakery, storage: .counter, expiryDays: 3, unit: .pieces),
        FoodSuggestion(name: "Milk", icon: "cup.and.saucer.fill", category: .dairy, storage: .fridge, expiryDays: 7, unit: .liters),
        FoodSuggestion(name: "Yogurt", icon: "cup.and.saucer.fill", category: .dairy, storage: .fridge, expiryDays: 14, unit: .pieces),
        FoodSuggestion(name: "Cheese", icon: "cup.and.saucer.fill", category: .dairy, storage: .fridge, expiryDays: 21, unit: .grams),
        FoodSuggestion(name: "Butter", icon: "cup.and.saucer.fill", category: .dairy, storage: .fridge, expiryDays: 30, unit: .grams),
        FoodSuggestion(name: "Eggs", icon: "cup.and.saucer.fill", category: .dairy, storage: .fridge, expiryDays: 21, unit: .pieces),
        FoodSuggestion(name: "Chicken Breast", icon: "flame.fill", category: .meat, storage: .fridge, expiryDays: 3, unit: .kilograms),
        FoodSuggestion(name: "Ground Beef", icon: "flame.fill", category: .meat, storage: .fridge, expiryDays: 2, unit: .kilograms),
        FoodSuggestion(name: "Salmon", icon: "fish.fill", category: .seafood, storage: .fridge, expiryDays: 2, unit: .kilograms),
        FoodSuggestion(name: "Shrimp", icon: "fish.fill", category: .seafood, storage: .freezer, expiryDays: 90, unit: .kilograms),
        FoodSuggestion(name: "Broccoli", icon: "leaf.fill", category: .vegetables, storage: .fridge, expiryDays: 5, unit: .pieces),
        FoodSuggestion(name: "Spinach", icon: "leaf.fill", category: .vegetables, storage: .fridge, expiryDays: 5, unit: .grams),
        FoodSuggestion(name: "Tomato", icon: "leaf.fill", category: .vegetables, storage: .counter, expiryDays: 6, unit: .pieces),
        FoodSuggestion(name: "Carrot", icon: "leaf.fill", category: .vegetables, storage: .fridge, expiryDays: 14, unit: .pieces),
        FoodSuggestion(name: "Onion", icon: "leaf.fill", category: .vegetables, storage: .pantry, expiryDays: 30, unit: .pieces),
        FoodSuggestion(name: "Potato", icon: "leaf.fill", category: .vegetables, storage: .pantry, expiryDays: 21, unit: .kilograms),
        FoodSuggestion(name: "Rice", icon: "storefront.fill", category: .grains, storage: .pantry, expiryDays: 365, unit: .kilograms),
        FoodSuggestion(name: "Pasta", icon: "storefront.fill", category: .grains, storage: .pantry, expiryDays: 365, unit: .grams),
        FoodSuggestion(name: "Oats", icon: "storefront.fill", category: .grains, storage: .pantry, expiryDays: 180, unit: .grams),
        FoodSuggestion(name: "Orange Juice", icon: "waterbottle.fill", category: .beverages, storage: .fridge, expiryDays: 10, unit: .liters),
        FoodSuggestion(name: "Olive Oil", icon: "drop.fill", category: .condiments, storage: .pantry, expiryDays: 180, unit: .milliliters),
        FoodSuggestion(name: "Frozen Pizza", icon: "snowflake", category: .frozen, storage: .freezer, expiryDays: 90, unit: .pieces),
        FoodSuggestion(name: "Ice Cream", icon: "snowflake", category: .frozen, storage: .freezer, expiryDays: 60, unit: .milliliters),
        FoodSuggestion(name: "Chips", icon: "popcorn.fill", category: .snacks, storage: .pantry, expiryDays: 60, unit: .grams),
    ]
}
