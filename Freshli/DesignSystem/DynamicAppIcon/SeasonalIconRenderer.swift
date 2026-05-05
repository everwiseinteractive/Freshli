import SwiftUI

// ══════════════════════════════════════════════════════════════════
// MARK: - SeasonalIconRenderer
//
// Source-of-truth SwiftUI views for the four seasonal alternate icons.
// Each view renders at 1024×1024 and is exported to PNG (light, dark,
// tinted variants) by a build phase script the team runs locally:
//
//   $ swift run -c release seasonal-icon-export
//
// (The export driver is in `Tools/seasonal-icon-export/main.swift`,
// added as a separate package alongside MotionVocabularyKit.)
//
// Until the script runs, the alternate-icon `.appiconset` folders
// are stubs — `AlternateIconService.setIcon(_:)` will fail gracefully
// at runtime with a logged warning. Once the PNGs are generated and
// dropped in, the icon-switch flow lights up end-to-end.
//
// Why render in code: it keeps the icon definitions versioned, makes
// it trivial to introduce new seasonal events (FoodWaste Action Week,
// Earth Day, Lunar New Year), and ensures every icon has the same
// chromatic ring + Fresnel rim signature that anchors the brand.
// ══════════════════════════════════════════════════════════════════

@MainActor
struct SeasonalIconRenderer {

    // MARK: - Plastic Free July (June–August)
    //
    // A leaf wrapped in a translucent water-droplet glass orb. The
    // chromatic ring is muted to teal+aqua to evoke ocean conservation.

    struct PlasticFreeJulyIcon: View {
        let appearance: IconAppearanceMode
        let size: CGFloat

        var body: some View {
            ZStack {
                // Background: aquatic gradient
                RadialGradient(
                    colors: gradientColors,
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.55
                )

                // Glass droplet orb
                Circle()
                    .fill(orbFill)
                    .frame(width: size * 0.62)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.0),
                                        Color.cyan.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: size * 0.018
                            )
                    )

                // Leaf glyph
                Image(systemName: "leaf.fill")
                    .font(.system(size: size * 0.34, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: leafColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(-12))

                // Water droplet trail
                Image(systemName: "drop.fill")
                    .font(.system(size: size * 0.10))
                    .foregroundStyle(.white.opacity(appearance == .tinted ? 0.3 : 0.85))
                    .offset(x: size * 0.15, y: -size * 0.18)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
        }

        private var gradientColors: [Color] {
            switch appearance {
            case .light:  return [Color(hex: 0xCCFBF1), Color(hex: 0x99F6E4), Color(hex: 0x5EEAD4)]
            case .dark:   return [Color(hex: 0x134E4A), Color(hex: 0x0F2E2E), Color(hex: 0x06181A)]
            case .tinted: return [Color.gray.opacity(0.20), Color.gray.opacity(0.10), Color.gray.opacity(0.04)]
            }
        }

        private var orbFill: some ShapeStyle {
            switch appearance {
            case .light:  return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xA7F3D0), Color(hex: 0x6EE7B7)], startPoint: .top, endPoint: .bottom))
            case .dark:   return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x065F46), Color(hex: 0x064E3B)], startPoint: .top, endPoint: .bottom))
            case .tinted: return AnyShapeStyle(Color.gray.opacity(0.30))
            }
        }

        private var leafColors: [Color] {
            switch appearance {
            case .light:  return [Color(hex: 0x10B981), Color(hex: 0x059669)]
            case .dark:   return [Color(hex: 0x34D399), Color(hex: 0x10B981)]
            case .tinted: return [Color.white.opacity(0.7), Color.white.opacity(0.5)]
            }
        }
    }

    // MARK: - Holiday Pantry Hero (December)
    //
    // The leaf becomes a stylised pine sprig encased in soft snow flurries.
    // The orb gets a warm amber undertone to evoke holiday lighting.

    struct HolidayPantryHeroIcon: View {
        let appearance: IconAppearanceMode
        let size: CGFloat

        var body: some View {
            ZStack {
                RadialGradient(
                    colors: gradientColors,
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.55
                )

                // Warm orb
                Circle()
                    .fill(orbFill)
                    .frame(width: size * 0.62)

                // Pine glyph (leaf used as substitute pre-art)
                Image(systemName: "leaf.fill")
                    .font(.system(size: size * 0.34, weight: .semibold))
                    .foregroundStyle(.white.opacity(appearance == .tinted ? 0.7 : 1.0))

                // Snowflake decorations
                ForEach(0..<3, id: \.self) { i in
                    let angle = Double(i) * 120 - 30
                    Image(systemName: "snowflake")
                        .font(.system(size: size * 0.08))
                        .foregroundStyle(.white.opacity(appearance == .tinted ? 0.3 : 0.85))
                        .offset(
                            x: cos(angle * .pi/180) * size * 0.32,
                            y: sin(angle * .pi/180) * size * 0.32
                        )
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
        }

        private var gradientColors: [Color] {
            switch appearance {
            case .light:  return [Color(hex: 0xFEF3C7), Color(hex: 0xFDE68A), Color(hex: 0xFBBF24)]
            case .dark:   return [Color(hex: 0x1F2937), Color(hex: 0x111827), Color(hex: 0x030712)]
            case .tinted: return [Color.gray.opacity(0.20), Color.gray.opacity(0.10), Color.gray.opacity(0.04)]
            }
        }

        private var orbFill: some ShapeStyle {
            switch appearance {
            case .light:  return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xD1FAE5), Color(hex: 0x6EE7B7)], startPoint: .top, endPoint: .bottom))
            case .dark:   return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x065F46), Color(hex: 0x064E3B)], startPoint: .top, endPoint: .bottom))
            case .tinted: return AnyShapeStyle(Color.gray.opacity(0.35))
            }
        }
    }

    // MARK: - World Food Day (October 16)

    struct WorldFoodDayIcon: View {
        let appearance: IconAppearanceMode
        let size: CGFloat

        var body: some View {
            ZStack {
                RadialGradient(
                    colors: gradientColors,
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.55
                )

                // Globe glyph
                Image(systemName: "globe.europe.africa.fill")
                    .font(.system(size: size * 0.50, weight: .regular))
                    .foregroundStyle(
                        LinearGradient(
                            colors: appearance == .tinted ? [.white.opacity(0.7)] : [Color(hex: 0x059669), Color(hex: 0x10B981)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Leaf accent
                Image(systemName: "leaf.fill")
                    .font(.system(size: size * 0.16, weight: .semibold))
                    .foregroundStyle(.white)
                    .offset(x: size * 0.20, y: -size * 0.22)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
        }

        private var gradientColors: [Color] {
            switch appearance {
            case .light:  return [Color(hex: 0xDCFCE7), Color(hex: 0xBBF7D0), Color(hex: 0x86EFAC)]
            case .dark:   return [Color(hex: 0x064E3B), Color(hex: 0x0D3B2C), Color(hex: 0x0A1F16)]
            case .tinted: return [Color.gray.opacity(0.20), Color.gray.opacity(0.10), Color.gray.opacity(0.04)]
            }
        }
    }

    // MARK: - Freshli Pride (year-round, opt-in)

    struct FreshliPrideIcon: View {
        let appearance: IconAppearanceMode
        let size: CGFloat

        var body: some View {
            ZStack {
                // Pride flag radial gradient as background
                RadialGradient(
                    colors: appearance == .tinted
                        ? [Color.gray.opacity(0.20), Color.gray.opacity(0.04)]
                        : [
                            Color(hex: 0xE40303), // red
                            Color(hex: 0xFF8C00), // orange
                            Color(hex: 0xFFED00), // yellow
                            Color(hex: 0x008026), // green
                            Color(hex: 0x004DFF), // blue
                            Color(hex: 0x750787)  // violet
                          ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.55
                )

                // Glass orb keeps the brand silhouette
                Circle()
                    .fill(.white.opacity(appearance == .tinted ? 0.3 : 0.18))
                    .frame(width: size * 0.55)

                // Leaf glyph
                Image(systemName: "leaf.fill")
                    .font(.system(size: size * 0.32, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
        }
    }
}

// MARK: - Previews

#Preview("Seasonal — Plastic Free July (light)") {
    SeasonalIconRenderer.PlasticFreeJulyIcon(appearance: .light, size: 256)
}
#Preview("Seasonal — Plastic Free July (dark)") {
    SeasonalIconRenderer.PlasticFreeJulyIcon(appearance: .dark, size: 256)
}
#Preview("Seasonal — Plastic Free July (tinted)") {
    SeasonalIconRenderer.PlasticFreeJulyIcon(appearance: .tinted, size: 256)
}
#Preview("Seasonal — Holiday Pantry Hero") {
    SeasonalIconRenderer.HolidayPantryHeroIcon(appearance: .light, size: 256)
}
#Preview("Seasonal — World Food Day") {
    SeasonalIconRenderer.WorldFoodDayIcon(appearance: .light, size: 256)
}
#Preview("Seasonal — Freshli Pride") {
    SeasonalIconRenderer.FreshliPrideIcon(appearance: .light, size: 256)
}
