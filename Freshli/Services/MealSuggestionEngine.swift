import Foundation

// MARK: - Meal Suggestion Engine
// Suggests quick recipes based on expiring ingredients and food category.
// Used by the "Use It Up" feature to help users rescue food before it expires.

enum MealSuggestionEngine {

    /// A lightweight recipe suggestion with name, description, and estimated prep time.
    struct Suggestion: Sendable {
        let name: String
        let description: String
        let minutes: Int
    }

    // MARK: - Public API

    /// Suggest a recipe for the given ingredients, category, and time constraint.
    /// Always returns a suggestion — falls back to a quick preparation if nothing fits the time.
    static func suggest(
        ingredients: [String],
        category: FoodCategory,
        maxMinutes: Int
    ) -> Suggestion {
        let recipes = recipeBank[category] ?? []
        // Find the best recipe that fits the time constraint
        if let match = recipes.first(where: { $0.minutes <= maxMinutes }) {
            return match
        }
        // Fallback: a quick toss/prep that always fits
        return Suggestion(
            name: fallbackName(for: category),
            description: "Quick \(category.displayName.lowercased()) preparation using \(ingredients.first ?? "your ingredients").",
            minutes: min(maxMinutes, 1)
        )
    }

    // MARK: - Recipe Bank

    /// Pre-defined recipes per food category, sorted by shortest time first.
    private static let recipeBank: [FoodCategory: [Suggestion]] = [
        .fruits: [
            Suggestion(name: "Fresh Fruit Bowl", description: "A colorful medley of seasonal fruits with a honey drizzle.", minutes: 3),
            Suggestion(name: "Smoothie", description: "Blend fruits with yogurt and ice for a refreshing drink.", minutes: 5),
            Suggestion(name: "Fruit Salad", description: "Chopped fruits tossed with lime juice and mint.", minutes: 8),
        ],
        .vegetables: [
            Suggestion(name: "Garden Salad", description: "Fresh vegetables with olive oil and lemon dressing.", minutes: 5),
            Suggestion(name: "Quick Stir-Fry", description: "Vegetables sauteed in sesame oil with soy sauce.", minutes: 8),
            Suggestion(name: "Roasted Vegetables", description: "Oven-roasted with herbs and olive oil.", minutes: 25),
        ],
        .dairy: [
            Suggestion(name: "Cheese Plate", description: "Artfully arranged cheeses with crackers and fruit.", minutes: 3),
            Suggestion(name: "Yogurt Parfait", description: "Layered yogurt with granola and fresh berries.", minutes: 5),
            Suggestion(name: "Mac & Cheese", description: "Creamy stovetop macaroni and cheese.", minutes: 15),
        ],
        .meat: [
            Suggestion(name: "Quick Wrap", description: "Sliced meat in a tortilla with greens and sauce.", minutes: 5),
            Suggestion(name: "Stir-Fry", description: "Thinly sliced meat with vegetables in a hot wok.", minutes: 10),
            Suggestion(name: "Pan-Seared", description: "Seasoned and seared to perfection.", minutes: 15),
        ],
        .seafood: [
            Suggestion(name: "Seared Fish", description: "Quick pan-seared fillet with lemon butter.", minutes: 8),
            Suggestion(name: "Shrimp Stir-Fry", description: "Shrimp with garlic, ginger, and vegetables.", minutes: 10),
            Suggestion(name: "Fish Tacos", description: "Flaky fish in warm tortillas with slaw.", minutes: 15),
        ],
        .grains: [
            Suggestion(name: "Quick Toast", description: "Toasted bread topped with olive oil and seasoning.", minutes: 3),
            Suggestion(name: "Fried Rice", description: "Day-old rice stir-fried with eggs and vegetables.", minutes: 10),
            Suggestion(name: "Grain Bowl", description: "Warm grains topped with vegetables and dressing.", minutes: 12),
        ],
        .bakery: [
            Suggestion(name: "Bruschetta", description: "Toasted bread rubbed with garlic and topped with tomatoes.", minutes: 5),
            Suggestion(name: "French Toast", description: "Bread dipped in egg mixture and pan-fried.", minutes: 10),
            Suggestion(name: "Bread Pudding", description: "Cubed bread baked with custard and spices.", minutes: 30),
        ],
        .frozen: [
            Suggestion(name: "Quick Reheat", description: "Thawed and heated with fresh seasoning.", minutes: 5),
            Suggestion(name: "Frozen Stir-Fry", description: "Frozen vegetables and protein in a hot pan.", minutes: 10),
            Suggestion(name: "Baked from Frozen", description: "Oven-baked with added herbs.", minutes: 20),
        ],
        .canned: [
            Suggestion(name: "Quick Beans", description: "Warmed canned beans with spices and a squeeze of lime.", minutes: 5),
            Suggestion(name: "Soup", description: "Heated canned soup enhanced with fresh herbs.", minutes: 8),
            Suggestion(name: "Bean Salad", description: "Mixed beans with olive oil, onion, and vinegar.", minutes: 5),
        ],
        .condiments: [
            Suggestion(name: "Dipping Sauce", description: "Mixed condiments for a custom dipping sauce.", minutes: 2),
            Suggestion(name: "Marinade", description: "Combine condiments for a flavorful marinade.", minutes: 3),
            Suggestion(name: "Glaze", description: "Reduced condiments into a savory glaze.", minutes: 8),
        ],
        .snacks: [
            Suggestion(name: "Trail Mix", description: "Combined snacks into a custom trail mix.", minutes: 2),
            Suggestion(name: "Snack Plate", description: "Arranged snacks with dips on a sharing plate.", minutes: 5),
            Suggestion(name: "Snack Bars", description: "Pressed and chilled into no-bake bars.", minutes: 15),
        ],
        .beverages: [
            Suggestion(name: "Infused Water", description: "Water infused with fruit slices and herbs.", minutes: 2),
            Suggestion(name: "Smoothie", description: "Blended beverage with fresh fruit additions.", minutes: 5),
            Suggestion(name: "Iced Tea", description: "Chilled tea with lemon and sweetener.", minutes: 5),
        ],
        .other: [
            Suggestion(name: "Quick Prep", description: "Simple preparation with available ingredients.", minutes: 3),
            Suggestion(name: "Mixed Plate", description: "A balanced plate of available items.", minutes: 5),
            Suggestion(name: "Creative Bowl", description: "A freestyle bowl combining what you have.", minutes: 10),
        ],
    ]

    // MARK: - Fallback

    private static func fallbackName(for category: FoodCategory) -> String {
        switch category {
        case .fruits:     return "Quick Fruit Bite"
        case .vegetables: return "Veggie Snack"
        case .dairy:      return "Dairy Bite"
        case .meat:       return "Quick Meat Wrap"
        case .seafood:    return "Seafood Bite"
        case .grains:     return "Grain Snack"
        case .bakery:     return "Quick Toast"
        case .frozen:     return "Thaw & Serve"
        case .canned:     return "Open & Serve"
        case .condiments: return "Quick Mix"
        case .snacks:     return "Grab & Go"
        case .beverages:  return "Quick Pour"
        case .other:      return "Quick Prep"
        }
    }
}
