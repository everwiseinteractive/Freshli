import SwiftUI

// ══════════════════════════════════════════════════════════════════
// MARK: - Icon Composer Configuration
// Defines the three appearance layers for Freshli's adaptive app icon
// (iOS 18+ automatic Dark Mode & Tinted icon support).
//
// Setup in Xcode → AppIcon asset catalog:
//   1. Select AppIcon → set "Appearances" to "Any, Dark, Tinted"
//   2. Import the layers defined below for each appearance
//
// Icon Composer (Xcode 16+) creates the final composited icon from
// foreground + background layers per appearance.
// ══════════════════════════════════════════════════════════════════

enum FreshliIconConfig {
    // MARK: - Brand Colors

    /// Primary Freshli Green — the luminous source for Tinted mode
    static let freshliGreen = Color(red: 0, green: 1, blue: 0) // #00FF00

    /// Deep forest — background base for Light & Dark
    static let backgroundDark  = Color(hex: 0x0A1F0E)
    static let backgroundLight = Color(hex: 0xF0FFF4)

    // MARK: - Layer Definitions

    /// **Light Appearance (Default)**
    /// - Background: Soft mint gradient (backgroundLight → white)
    /// - Foreground: Freshli leaf icon in deep forest green
    /// - Specular: Subtle top-left highlight for depth
    enum Light {
        static let backgroundGradient = LinearGradient(
            colors: [Color(hex: 0xF0FFF4), .white],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let foregroundColor = Color(hex: 0x0A1F0E)
        static let specularOpacity: Double = 0.15
    }

    /// **Dark Appearance**
    /// - Background: True black with subtle green vignette
    /// - Foreground: Freshli leaf icon in luminous green
    /// - Specular: Strong specular rim for OLED "glow" effect
    enum Dark {
        static let backgroundGradient = LinearGradient(
            colors: [Color(hex: 0x0A1F0E), .black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let foregroundColor = Color(hex: 0x00FF00)
        static let specularOpacity: Double = 0.35
        static let glowRadius: CGFloat = 24
        static let glowColor = Color(hex: 0x00FF00).opacity(0.4)
    }

    /// **Tinted Appearance**
    /// The system applies the user's chosen tint colour over a
    /// monochrome base. We provide maximum contrast layers:
    /// - Background: Pure white (#FFFFFF) — becomes the tint colour
    /// - Foreground: Pure black (#000000) — stays dark as the icon shape
    /// - The Freshli Green (#00FF00) is the "primary luminous source"
    ///   when the user's tint matches our brand colour.
    enum Tinted {
        static let backgroundBase = Color.white
        static let foregroundBase = Color.black
        static let brandTint = Color(hex: 0x00FF00)
    }

    // MARK: - Specular Layer

    /// Specular highlight overlay — applied as the topmost composited layer.
    /// Creates the "glass catching light" effect on the icon surface.
    /// In Icon Composer, set this as an overlay with Screen blend mode.
    static func specularHighlight(size: CGFloat) -> some View {
        ZStack {
            // Top-left specular hotspot
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.5), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: size * 0.6
                    )
                )
                .frame(width: size, height: size)

            // Bottom-right subtle reflection
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.1), .clear],
                        center: .bottomTrailing,
                        startRadius: 0,
                        endRadius: size * 0.4
                    )
                )
                .frame(width: size, height: size)
        }
    }
}
