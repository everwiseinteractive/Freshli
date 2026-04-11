import SwiftUI

// MARK: - FoodCardImage
// Maps recipe-category SF Symbol names to beautiful food photography bundled
// in Assets.xcassets. All existing call sites remain identical — only the
// visual rendering changes from coloured SF Symbols to real food photos.
//
// Photography credits: Unsplash (unsplash.com) — free to use under the
// Unsplash License. No attribution required per their licence terms.

struct FoodCardImage: View {

    let imageSystemName: String
    var height: CGFloat
    var cornerRadius: CGFloat = 0

    // MARK: - Symbol → Asset Mapping

    /// Maps the legacy SF Symbol name to a bundled photo asset.
    private var assetName: String {
        switch imageSystemName {

        // Breakfast / smoothies / drinks
        case "cup.and.saucer.fill", "mug.fill", "takeoutbag.and.cup.and.straw.fill":
            return "recipe_smoothie"

        // Asian / wok / stir-fry
        case "frying.pan.fill", "frying.pan":
            return "recipe_asian"

        // Italian / pasta / fork-and-knife dishes
        case "fork.knife", "fork.knife.circle.fill":
            return "recipe_pasta"

        // Seafood / fish
        case "fish.fill", "fish":
            return "recipe_seafood"

        // BBQ / grilled / comfort food
        case "flame.fill", "flame":
            return "recipe_grilled"

        // Salad / vegan / plant-based
        case "leaf.fill", "leaf":
            return "recipe_salad"

        // Desserts / cakes / baking
        case "birthday.cake.fill", "birthday.cake", "oven.fill":
            return "recipe_dessert"

        // Breakfast / egg dishes / morning
        case "sunrise.fill", "sun.max.fill", "sun.horizon.fill":
            return "recipe_breakfast"

        // Soups / sauces / broths
        case "drop.fill", "drop":
            return "recipe_soup"

        // Bread / baking / grain
        case "basket.fill", "loaf.fill":
            return "recipe_bread"

        // Stew / slow-cook / pot dishes
        case "cooktop.fill", "pot.fill", "pot.fill.and.steam.fill":
            return "recipe_stew"

        // Default — vibrant healthy food
        default:
            return "recipe_healthy"
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 1. Real food photography — fills frame, crops to fit
            Image(assetName)
                .resizable()
                .scaledToFill()

            // 2. Subtle top micro-vignette — adds photographic lens depth
            LinearGradient(
                colors: [.black.opacity(0.12), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.30)
            )

            // 3. Gentle bottom lift — aids text legibility for caller overlays
            // (callers typically add their own heavier gradient over this)
            LinearGradient(
                colors: [.clear, .black.opacity(0.18)],
                startPoint: UnitPoint(x: 0.5, y: 0.55),
                endPoint: .bottom
            )

            // 4. Subtle left-edge highlight — editorial/studio lighting feel
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
                ("fork.knife",           "Pasta"),
                ("frying.pan.fill",      "Asian"),
                ("fish.fill",            "Seafood"),
                ("leaf.fill",            "Salad"),
                ("flame.fill",           "Grilled"),
                ("cup.and.saucer.fill",  "Smoothie"),
                ("birthday.cake.fill",   "Dessert"),
                ("drop.fill",            "Soup"),
                ("loaf.fill",            "Bread"),
                ("sunrise.fill",         "Breakfast"),
                ("pot.fill",             "Stew"),
                ("sparkles",             "Default"),
            ], id: \.0) { symbol, label in
                VStack(spacing: 6) {
                    FoodCardImage(imageSystemName: symbol, height: 120, cornerRadius: 16)
                    Text(label)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
