import SwiftUI

// MARK: - FoodCardImage
// Rich visual recipe-image replacement that maps SF Symbol names to
// food-category colour palettes. Each palette has a dominant gradient and
// a photography-style diagonal highlight so the tile looks closer to a
// real food photo than a plain icon.

struct FoodCardImage: View {

    let imageSystemName: String
    var height: CGFloat
    var cornerRadius: CGFloat = 0

    // MARK: - Palette

    private struct Palette {
        let leading: Color
        let trailing: Color
        let accentSymbol: String
    }

    private var palette: Palette {
        switch imageSystemName {

        // Breakfast, smoothies, drinks — warm honey-amber
        case "cup.and.saucer.fill", "mug.fill", "takeoutbag.and.cup.and.straw.fill":
            return Palette(leading: Color(hex: 0xF59E0B), trailing: Color(hex: 0xB45309), accentSymbol: "sparkles")

        // Hot wok / stir-fry / Asian cuisine — deep terracotta-red
        case "frying.pan.fill", "frying.pan":
            return Palette(leading: Color(hex: 0xDC2626), trailing: Color(hex: 0x7F1D1D), accentSymbol: "smoke")

        // Pasta / Italian / fork-and-knife dishes — rich tomato
        case "fork.knife", "fork.knife.circle.fill":
            return Palette(leading: Color(hex: 0xEF4444), trailing: Color(hex: 0x991B1B), accentSymbol: "leaf")

        // Seafood / fish — ocean blue-teal
        case "fish.fill", "fish":
            return Palette(leading: Color(hex: 0x0EA5E9), trailing: Color(hex: 0x075985), accentSymbol: "drop.fill")

        // Comfort food / BBQ / grilled — fire orange
        case "flame.fill", "flame":
            return Palette(leading: Color(hex: 0xF97316), trailing: Color(hex: 0x9A3412), accentSymbol: "smoke.fill")

        // Salad / vegan / plant-based — fresh grass-green
        case "leaf.fill", "leaf":
            return Palette(leading: Color(hex: 0x22C55E), trailing: Color(hex: 0x14532D), accentSymbol: "drop.fill")

        // Desserts / baking — blush-pink
        case "birthday.cake.fill", "birthday.cake", "oven.fill":
            return Palette(leading: Color(hex: 0xEC4899), trailing: Color(hex: 0x831843), accentSymbol: "sparkles")

        // Breakfast / morning egg dishes — golden sunrise
        case "sunrise.fill", "sun.max.fill", "sun.horizon.fill":
            return Palette(leading: Color(hex: 0xFBBF24), trailing: Color(hex: 0xB45309), accentSymbol: "sparkle")

        // Soups / sauces / liquids — deep ocean-blue
        case "drop.fill", "drop":
            return Palette(leading: Color(hex: 0x3B82F6), trailing: Color(hex: 0x1D4ED8), accentSymbol: "bubbles.and.sparkles")

        // Bread / baking / grain — warm wheat
        case "basket.fill", "loaf.fill":
            return Palette(leading: Color(hex: 0xD97706), trailing: Color(hex: 0x78350F), accentSymbol: "sparkles")

        // Pot / stew / slow cook — deep purple-plum
        case "cooktop.fill", "pot.fill", "pot.fill.and.steam.fill":
            return Palette(leading: Color(hex: 0x7C3AED), trailing: Color(hex: 0x3B0764), accentSymbol: "smoke.fill")

        // Default — Freshli brand green-to-teal
        default:
            return Palette(leading: Color(hex: 0x22C55E), trailing: Color(hex: 0x0D9488), accentSymbol: "sparkles")
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 1 — Gradient background (food-category colour)
            LinearGradient(
                colors: [palette.leading, palette.trailing],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 2 — Drop-shadow duplicate to add depth (simulates object shadow in photography)
            Image(systemName: imageSystemName)
                .font(.system(size: height * 0.50))
                .foregroundStyle(.black.opacity(0.22))
                .blur(radius: height * 0.10)
                .offset(x: height * 0.06, y: height * 0.08)

            // 3 — Ambient accent symbol (top-right, very faint)
            Image(systemName: palette.accentSymbol)
                .font(.system(size: height * 0.26))
                .foregroundStyle(.white.opacity(0.14))
                .offset(x: height * 0.26, y: -height * 0.20)
                .blur(radius: 1.5)

            // 4 — Main icon (centred, slightly smaller than height so it breathes)
            Image(systemName: imageSystemName)
                .font(.system(size: height * 0.50))
                .foregroundStyle(.white.opacity(0.90))
                .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)

            // 5 — Photography-style diagonal highlight (top-left radial)
            LinearGradient(
                colors: [.white.opacity(0.22), .clear],
                startPoint: .topLeading,
                endPoint: UnitPoint(x: 0.65, y: 0.65)
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
