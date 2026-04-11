import SwiftUI

// MARK: - FoodItemImage
// Renders real food photography for individual pantry items (salmon,
// chicken, spinach, milk, etc.) instead of emoji or SF Symbols.
//
// Matching is done on a lowercased item name via keyword lookup, with
// a category-based fallback. Photography sourced from Unsplash.

struct FoodItemImage: View {

    /// User-entered item name — e.g. "Fresh Salmon", "Organic Spinach".
    let name: String

    /// Category fallback when the name doesn't match any specific keyword.
    let category: FoodCategory

    var size: CGFloat
    var cornerRadius: CGFloat

    init(name: String, category: FoodCategory, size: CGFloat, cornerRadius: CGFloat? = nil) {
        self.name = name
        self.category = category
        self.size = size
        self.cornerRadius = cornerRadius ?? (size / 2)  // circle by default
    }

    // MARK: - Asset Resolution

    private var assetName: String {
        let lower = name.lowercased()

        // Tier 1: specific item name match (most accurate)
        if let match = Self.nameMatch(lower) {
            return match
        }

        // Tier 2: category fallback
        return Self.categoryMatch(category)
    }

    private static func nameMatch(_ lower: String) -> String? {
        // Seafood
        if ["salmon", "tuna", "cod", "haddock", "prawn", "shrimp",
            "fish", "sea bass", "mackerel", "sardine"].contains(where: lower.contains) {
            return "food_salmon"
        }

        // Meat
        if ["chicken", "turkey", "poultry", "drumstick", "breast"].contains(where: lower.contains) {
            return "food_chicken"
        }
        if ["beef", "steak", "pork", "lamb", "mince", "ribs", "bacon", "ham"].contains(where: lower.contains) {
            return "food_chicken"  // shares the raw meat aesthetic
        }

        // Leafy greens
        if ["spinach", "kale", "lettuce", "chard", "arugula", "rocket",
            "cabbage", "romaine", "greens"].contains(where: lower.contains) {
            return "food_leafy"
        }

        // Dairy — milk
        if lower.contains("milk") || lower.contains("cream") || lower.contains("yogurt") || lower.contains("yoghurt") {
            return "food_milk"
        }

        // Dairy — cheese
        if ["cheese", "parmesan", "cheddar", "mozzarella", "feta", "brie",
            "gouda", "halloumi"].contains(where: lower.contains) {
            return "food_cheese"
        }

        // Eggs
        if lower.contains("egg") {
            return "food_egg"
        }

        // Bread / bakery
        if ["bread", "loaf", "sourdough", "baguette", "roll", "bun",
            "muffin", "croissant", "bagel", "toast"].contains(where: lower.contains) {
            return "food_bread"
        }

        // Fruits
        if ["apple", "banana", "orange", "mango", "papaya", "kiwi",
            "grape", "pineapple", "peach", "pear", "plum", "berry",
            "strawberr", "blueberr", "raspberry", "watermelon", "lemon",
            "lime", "avocado", "fruit"].contains(where: lower.contains) {
            return "food_fruit"
        }

        // Vegetables (non-leafy)
        if ["carrot", "broccoli", "cauliflower", "pepper", "tomato",
            "cucumber", "zucchini", "courgette", "onion", "garlic",
            "potato", "squash", "pumpkin", "corn", "bean", "pea",
            "mushroom", "radish", "celery", "vegetable"].contains(where: lower.contains) {
            return "food_veg"
        }

        // Grains
        if ["rice", "pasta", "oat", "quinoa", "cereal", "flour",
            "noodle", "couscous", "barley", "grain"].contains(where: lower.contains) {
            return "food_grains"
        }

        return nil
    }

    private static func categoryMatch(_ category: FoodCategory) -> String {
        switch category {
        case .fruits:     return "food_fruit"
        case .vegetables: return "food_veg"
        case .dairy:      return "food_milk"
        case .meat:       return "food_chicken"
        case .seafood:    return "food_salmon"
        case .grains:     return "food_grains"
        case .bakery:     return "food_bread"
        case .frozen:     return "food_generic"
        case .canned:     return "food_generic"
        case .condiments: return "food_generic"
        case .snacks:     return "food_generic"
        case .beverages:  return "food_milk"
        case .other:      return "food_generic"
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Image(assetName)
                .resizable()
                .scaledToFill()

            // Subtle top-left highlight — "lit from above" editorial feel
            LinearGradient(
                colors: [.white.opacity(0.08), .clear],
                startPoint: .topLeading,
                endPoint: UnitPoint(x: 0.5, y: 0.5)
            )
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Preview

#Preview("Food Items") {
    let items: [(String, FoodCategory)] = [
        ("Fresh Salmon",    .seafood),
        ("Chicken Breast",  .meat),
        ("Organic Spinach", .vegetables),
        ("Whole Milk",      .dairy),
        ("Sourdough Bread", .bakery),
        ("Strawberries",    .fruits),
        ("Carrots",         .vegetables),
        ("Large Eggs",      .dairy),
        ("Cheddar Cheese",  .dairy),
        ("Brown Rice",      .grains),
        ("Mystery Item",    .other),
    ]
    return ScrollView {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(items, id: \.0) { name, cat in
                VStack(spacing: 6) {
                    FoodItemImage(name: name, category: cat, size: 80)
                    Text(name)
                        .font(.caption2.bold())
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
