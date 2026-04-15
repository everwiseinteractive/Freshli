import SwiftUI

// MARK: - FoodItemImage
// Renders real food photography for individual pantry items (salmon,
// chicken, spinach, milk, etc.) with a small category icon badge.
//
// Matching: lowercased item name → keyword lookup → category fallback.
// Categories without photos (frozen, canned, condiments, snacks, other)
// render a gradient + SF Symbol instead of a generic placeholder.

struct FoodItemImage: View {

    /// User-entered item name — e.g. "Fresh Salmon", "Organic Spinach".
    let name: String

    /// Category fallback when the name doesn't match any specific keyword.
    let category: FoodCategory

    var size: CGFloat
    var cornerRadius: CGFloat
    var showBadge: Bool

    init(name: String, category: FoodCategory, size: CGFloat, cornerRadius: CGFloat? = nil, showBadge: Bool = true) {
        self.name = name
        self.category = category
        self.size = size
        self.cornerRadius = cornerRadius ?? (size / 2)  // circle by default
        self.showBadge = showBadge
    }

    // MARK: - Asset Resolution

    private var assetName: String? {
        let lower = name.lowercased()

        // Tier 1: specific item name match (most accurate)
        if let match = Self.nameMatch(lower) {
            return match
        }

        // Tier 2: category fallback (nil = use gradient icon)
        return Self.categoryMatch(category)
    }

    private static func nameMatch(_ lower: String) -> String? {
        // Seafood
        if ["salmon", "tuna", "cod", "haddock", "prawn", "shrimp",
            "fish", "sea bass", "mackerel", "sardine", "trout",
            "crab", "lobster", "mussel", "oyster", "squid", "calamari",
            "anchovy", "swordfish", "tilapia"].contains(where: lower.contains) {
            return "food_salmon"
        }

        // Poultry
        if ["chicken", "turkey", "poultry", "drumstick", "breast",
            "wing", "thigh"].contains(where: lower.contains) {
            return "food_chicken"
        }

        // Red meat
        if ["beef", "steak", "pork", "lamb", "mince", "ribs", "bacon",
            "ham", "sausage", "chorizo", "salami", "prosciutto",
            "venison", "veal", "brisket"].contains(where: lower.contains) {
            return "food_chicken"  // shares the raw meat aesthetic
        }

        // Leafy greens
        if ["spinach", "kale", "lettuce", "chard", "arugula", "rocket",
            "cabbage", "romaine", "greens", "watercress", "endive",
            "radicchio", "collard", "bok choy", "pak choi"].contains(where: lower.contains) {
            return "food_leafy"
        }

        // Dairy — milk & cream
        if ["milk", "cream", "yogurt", "yoghurt", "buttermilk",
            "kefir", "sour cream", "crème"].contains(where: lower.contains) {
            return "food_milk"
        }

        // Dairy — cheese
        if ["cheese", "parmesan", "cheddar", "mozzarella", "feta", "brie",
            "gouda", "halloumi", "gruyere", "camembert", "ricotta",
            "mascarpone", "cottage cheese", "cream cheese"].contains(where: lower.contains) {
            return "food_cheese"
        }

        // Eggs
        if lower.contains("egg") {
            return "food_egg"
        }

        // Bread / bakery
        if ["bread", "loaf", "sourdough", "baguette", "roll", "bun",
            "muffin", "croissant", "bagel", "toast", "naan", "pita",
            "tortilla", "wrap", "flatbread", "brioche", "scone",
            "crumpet", "waffle", "pancake"].contains(where: lower.contains) {
            return "food_bread"
        }

        // Fruits
        if ["apple", "banana", "orange", "mango", "papaya", "kiwi",
            "grape", "pineapple", "peach", "pear", "plum", "berry",
            "strawberr", "blueberr", "raspberry", "blackberr",
            "watermelon", "lemon", "lime", "avocado", "fruit",
            "melon", "cherry", "fig", "pomegranate", "grapefruit",
            "tangerine", "clementine", "nectarine", "apricot",
            "coconut", "passion fruit", "lychee", "guava"].contains(where: lower.contains) {
            return "food_fruit"
        }

        // Vegetables (non-leafy)
        if ["carrot", "broccoli", "cauliflower", "pepper", "tomato",
            "cucumber", "zucchini", "courgette", "onion", "garlic",
            "potato", "squash", "pumpkin", "corn", "bean", "pea",
            "mushroom", "radish", "celery", "vegetable", "asparagus",
            "aubergine", "eggplant", "beetroot", "turnip", "parsnip",
            "sweet potato", "artichoke", "fennel", "leek",
            "spring onion", "shallot", "ginger", "chili"].contains(where: lower.contains) {
            return "food_veg"
        }

        // Grains
        if ["rice", "pasta", "oat", "quinoa", "cereal", "flour",
            "noodle", "couscous", "barley", "grain", "spaghetti",
            "penne", "fusilli", "macaroni", "linguine", "orzo",
            "bulgur", "muesli", "granola", "polenta"].contains(where: lower.contains) {
            return "food_grains"
        }

        // Beverages (match before generic fallback)
        if ["juice", "water", "soda", "cola", "tea", "coffee",
            "smoothie", "kombucha", "beer", "wine", "lemonade"].contains(where: lower.contains) {
            return "food_milk"  // beverage-adjacent photo
        }

        // Condiments / sauces
        if ["ketchup", "mustard", "mayo", "mayonnaise", "sauce",
            "vinegar", "oil", "dressing", "salsa", "chutney", "pesto",
            "soy sauce", "sriracha", "hot sauce", "honey", "jam",
            "marmalade", "syrup", "butter"].contains(where: lower.contains) {
            return nil  // use gradient fallback
        }

        // Frozen
        if ["ice cream", "frozen", "pizza", "nugget", "chip", "fries",
            "sorbet", "gelato"].contains(where: lower.contains) {
            return nil  // use gradient fallback
        }

        // Canned
        if ["canned", "tinned", "can of", "tin of"].contains(where: lower.contains) {
            return nil  // use gradient fallback
        }

        return nil
    }

    /// Returns nil for categories that should use the gradient icon fallback.
    private static func categoryMatch(_ category: FoodCategory) -> String? {
        switch category {
        case .fruits:     return "food_fruit"
        case .vegetables: return "food_veg"
        case .dairy:      return "food_milk"
        case .meat:       return "food_chicken"
        case .seafood:    return "food_salmon"
        case .grains:     return "food_grains"
        case .bakery:     return "food_bread"
        case .frozen:     return nil
        case .canned:     return nil
        case .condiments: return nil
        case .snacks:     return nil
        case .beverages:  return nil
        case .other:      return nil
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let asset = assetName {
                // Real food photo
                photoView(asset: asset)
            } else {
                // Gradient + icon for categories without photos
                gradientIconView
            }

            // Category icon badge
            if showBadge && size >= 36 {
                categoryBadge
            }
        }
    }

    // MARK: - Photo View

    private func photoView(asset: String) -> some View {
        Color.clear
            .overlay(
                Image(asset)
                    .resizable()
                    .scaledToFill()
            )
            .overlay(
                LinearGradient(
                    colors: [.white.opacity(0.08), .clear],
                    startPoint: .topLeading,
                    endPoint: UnitPoint(x: 0.5, y: 0.5)
                )
            )
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    // MARK: - Gradient Icon Fallback

    private var gradientIconView: some View {
        let catColor = PSColors.categoryColor(for: category)
        return ZStack {
            // Soft radial gradient in category colour
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [catColor.opacity(0.35), catColor.opacity(0.12)],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.65
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(PSColors.backgroundSecondary.opacity(0.6))
                )

            // Large centred SF Symbol
            Image(systemName: category.icon)
                .font(.system(size: size * 0.38, weight: .medium))
                .foregroundStyle(catColor)
        }
        .frame(width: size, height: size)
    }

    // MARK: - Category Badge

    private var categoryBadge: some View {
        let badgeSize = max(size * 0.28, 14.0)
        let catColor = PSColors.categoryColor(for: category)
        return Image(systemName: category.icon)
            .font(.system(size: badgeSize * 0.52, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: badgeSize, height: badgeSize)
            .background(catColor)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
            .elevation(.z1)
            .offset(x: size * 0.06, y: size * 0.06)
    }
}

// MARK: - Preview

#Preview("Food Items — Photos") {
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

#Preview("Food Items — Gradient Fallbacks") {
    let items: [(String, FoodCategory)] = [
        ("Frozen Pizza",    .frozen),
        ("Baked Beans",     .canned),
        ("Hot Sauce",       .condiments),
        ("Crisps",          .snacks),
        ("Orange Juice",    .beverages),
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
