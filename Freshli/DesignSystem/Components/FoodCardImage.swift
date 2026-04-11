import SwiftUI

// MARK: - FoodCardImage
// Renders real food photography for every recipe card. Matching is
// two-tiered:
//   1. Title-based keyword scan (most specific — 40+ keywords)
//   2. SF Symbol-based category fallback (for legacy callers without a title)
//
// All existing call sites remain source-compatible — the new optional
// `title` parameter unlocks accurate matching. Photography: Unsplash.

struct FoodCardImage: View {

    /// The recipe/item title — used for precise photo matching.
    /// If nil or unrecognised, falls back to SF Symbol based matching.
    var title: String? = nil

    /// Legacy SF Symbol name — fallback when no title matches.
    let imageSystemName: String

    var height: CGFloat
    var cornerRadius: CGFloat = 0

    // MARK: - Asset Resolution

    private var assetName: String {
        // Tier 1: exact title keyword match (most specific)
        if let title = title?.lowercased(), !title.isEmpty {
            if let match = Self.titleMatch(title) {
                return match
            }
        }
        // Tier 2: SF Symbol category fallback
        return Self.symbolMatch(imageSystemName)
    }

    // MARK: - Title Keyword Matcher
    // Priority-ordered: the first match wins, so we list the most specific
    // keywords first ("carbonara" before "pasta"). Keys are checked against
    // the lowercased recipe title via `contains`.

    private static func titleMatch(_ lower: String) -> String? {
        // Soups / stews / broths — very specific first
        if lower.contains("tortilla soup") || lower.contains("noodle soup") ||
           lower.contains("miso soup") || lower.contains("chowder") ||
           lower.contains("bisque") || lower.contains("ramen") {
            // Ramen is actually asian — override below for broader match
            if lower.contains("ramen") || lower.contains("pho") { return "recipe_asian" }
            return "recipe_soup"
        }
        if lower.contains("soup") || lower.contains("broth") { return "recipe_soup" }
        if lower.contains("stew") || lower.contains("chili") ||
           lower.contains("chilli") || lower.contains("casserole") ||
           lower.contains("goulash") || lower.contains("curry") {
            return "recipe_stew"
        }

        // Asian — stir-fry, fried rice, noodles
        if lower.contains("fried rice") || lower.contains("stir fry") ||
           lower.contains("stir-fry") || lower.contains("pad thai") ||
           lower.contains("lo mein") || lower.contains("chow mein") ||
           lower.contains("dumpling") || lower.contains("sushi") ||
           lower.contains("teriyaki") || lower.contains("katsu") ||
           lower.contains("pho") || lower.contains("ramen") ||
           lower.contains("bibimbap") {
            return "recipe_asian"
        }

        // Pasta — very common; check after asian to avoid "noodle" overlap
        if lower.contains("pasta") || lower.contains("spaghetti") ||
           lower.contains("linguine") || lower.contains("fettuccine") ||
           lower.contains("penne") || lower.contains("macaroni") ||
           lower.contains("lasagna") || lower.contains("carbonara") ||
           lower.contains("bolognese") || lower.contains("fettucini") ||
           lower.contains("ravioli") || lower.contains("gnocchi") ||
           lower.contains("tortellini") {
            return "recipe_pasta"
        }
        if lower.contains("frittata") || lower.contains("quiche") {
            return "recipe_breakfast"
        }

        // Breakfast — eggs, oats, pancakes, toast (excluding avocado toast below)
        if lower.contains("pancake") || lower.contains("waffle") ||
           lower.contains("french toast") || lower.contains("granola") ||
           lower.contains("oatmeal") || lower.contains("porridge") ||
           lower.contains("muesli") || lower.contains("scramble") ||
           lower.contains("omelette") || lower.contains("omelet") ||
           lower.contains("benedict") || lower.contains("breakfast") {
            return "recipe_breakfast"
        }

        // Bread / toast / sandwiches
        if lower.contains("banana bread") || lower.contains("sourdough") ||
           lower.contains("focaccia") || lower.contains("flatbread") ||
           lower.contains("brioche") || lower.contains("bagel") ||
           lower.contains("muffin") || lower.contains("loaf") ||
           lower.contains("bruschetta") || lower.contains("crostini") {
            return "recipe_bread"
        }
        if lower.contains("toast") || lower.contains("sandwich") ||
           lower.contains("panini") || lower.contains("wrap") ||
           lower.contains("burrito") || lower.contains("quesadilla") {
            return "recipe_bread"
        }
        if lower.contains("bread") { return "recipe_bread" }

        // Desserts — cakes, pies, cookies
        if lower.contains("cake") || lower.contains("pie") ||
           lower.contains("tart") || lower.contains("cookie") ||
           lower.contains("brownie") || lower.contains("pudding") ||
           lower.contains("mousse") || lower.contains("cheesecake") ||
           lower.contains("crumble") || lower.contains("cobbler") ||
           lower.contains("custard") || lower.contains("soufflé") ||
           lower.contains("souffle") || lower.contains("sorbet") ||
           lower.contains("ice cream") || lower.contains("tiramisu") {
            return "recipe_dessert"
        }

        // Smoothies / drinks
        if lower.contains("smoothie") || lower.contains("juice") ||
           lower.contains("shake") || lower.contains("latte") ||
           lower.contains("milkshake") || lower.contains("frappe") {
            return "recipe_smoothie"
        }

        // Seafood
        if lower.contains("salmon") || lower.contains("tuna") ||
           lower.contains("cod") || lower.contains("prawn") ||
           lower.contains("shrimp") || lower.contains("calamari") ||
           lower.contains("mussel") || lower.contains("oyster") ||
           lower.contains("scallop") || lower.contains("lobster") ||
           lower.contains("crab") || lower.contains("fish") ||
           lower.contains("ceviche") || lower.contains("gravlax") {
            return "recipe_seafood"
        }

        // Grilled / BBQ / comfort meats
        if lower.contains("grilled") || lower.contains("barbecue") ||
           lower.contains("bbq") || lower.contains("steak") ||
           lower.contains("burger") || lower.contains("ribs") ||
           lower.contains("brisket") || lower.contains("kebab") ||
           lower.contains("skewer") || lower.contains("roast") {
            return "recipe_grilled"
        }

        // Salad / bowls / plant-based
        if lower.contains("salad") || lower.contains("slaw") ||
           lower.contains("buddha bowl") || lower.contains("poke bowl") ||
           lower.contains("grain bowl") || lower.contains("quinoa bowl") {
            return "recipe_salad"
        }

        // Vegetable dishes / healthy
        if lower.contains("vegetable") || lower.contains("veggie") ||
           lower.contains("ratatouille") || lower.contains("gazpacho") ||
           lower.contains("hummus") || lower.contains("falafel") ||
           lower.contains("stuffed pepper") || lower.contains("risotto") ||
           lower.contains("bowl") {
            return "recipe_healthy"
        }

        return nil
    }

    // MARK: - SF Symbol Fallback
    // Only used when title matching returns nil (legacy callers).

    private static func symbolMatch(_ symbol: String) -> String {
        switch symbol {
        case "cup.and.saucer.fill", "mug.fill", "takeoutbag.and.cup.and.straw.fill":
            return "recipe_smoothie"
        case "frying.pan.fill", "frying.pan":
            return "recipe_asian"
        case "fork.knife", "fork.knife.circle.fill":
            return "recipe_pasta"
        case "fish.fill", "fish":
            return "recipe_seafood"
        case "flame.fill", "flame":
            return "recipe_grilled"
        case "leaf.fill", "leaf":
            return "recipe_salad"
        case "birthday.cake.fill", "birthday.cake", "oven.fill":
            return "recipe_dessert"
        case "sunrise.fill", "sun.max.fill", "sun.horizon.fill":
            return "recipe_breakfast"
        case "drop.fill", "drop":
            return "recipe_soup"
        case "basket.fill", "loaf.fill":
            return "recipe_bread"
        case "cooktop.fill", "pot.fill", "pot.fill.and.steam.fill":
            return "recipe_stew"
        default:
            return "recipe_healthy"
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 1. Real food photography
            Image(assetName)
                .resizable()
                .scaledToFill()

            // 2. Subtle top micro-vignette
            LinearGradient(
                colors: [.black.opacity(0.12), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.30)
            )

            // 3. Gentle bottom lift — legibility aid for caller overlays
            LinearGradient(
                colors: [.clear, .black.opacity(0.18)],
                startPoint: UnitPoint(x: 0.5, y: 0.55),
                endPoint: .bottom
            )

            // 4. Subtle left-edge highlight — editorial lighting
            LinearGradient(
                colors: [.white.opacity(0.06), .clear],
                startPoint: .leading,
                endPoint: UnitPoint(x: 0.5, y: 0.5)
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Preview

#Preview("Recipe Cards") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach([
                ("Chicken Tortilla Soup", "fork.knife"),
                ("Leftover Fried Rice",    "frying.pan.fill"),
                ("Spaghetti Carbonara",    "fork.knife"),
                ("Banana Bread",           "cup.and.saucer.fill"),
                ("Berry Smoothie",         "cup.and.saucer.fill"),
                ("Avocado Toast",          "fork.knife"),
                ("Pasta Frittata",         "fork.knife"),
                ("Grilled Salmon",         "fish.fill"),
            ], id: \.0) { name, symbol in
                VStack(spacing: 6) {
                    FoodCardImage(title: name, imageSystemName: symbol, height: 120, cornerRadius: 16)
                    Text(name)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
