import SwiftUI

// ══════════════════════════════════════════════════════════════════
// MARK: - Material Density Token
// Maps to Figma's "Material Density" design variable. Controls the
// optical weight of Liquid Glass surfaces — refraction strength,
// blur radius, chromatic aberration, and border/shadow emphasis.
//
// Usage:
//   .liquidGlass(.high)                 // hero cards
//   .liquidGlass(.low, cornerRadius: 8) // subtle inline chips
// ══════════════════════════════════════════════════════════════════

enum MaterialDensity: String, Sendable, CaseIterable {
    case low
    case medium
    case high

    // MARK: - Refraction

    /// Refraction index fed to the LiquidGlass Metal shader.
    nonisolated var refractionIndex: Float {
        switch self {
        case .low:    return 0.02
        case .medium: return 0.05
        case .high:   return 0.10
        }
    }

    // MARK: - Blur

    /// Background blur radius applied behind the glass surface.
    nonisolated var blurIntensity: CGFloat {
        switch self {
        case .low:    return 8
        case .medium: return 16
        case .high:   return 24
        }
    }

    // MARK: - Chromatic Aberration

    /// RGB channel offset magnitude for the premium prismatic fringe.
    nonisolated var chromaShift: Float {
        switch self {
        case .low:    return 0.003
        case .medium: return 0.006
        case .high:   return 0.012
        }
    }

    // MARK: - Border

    /// Opacity of the 0.5 pt primary-color border stroke.
    nonisolated var borderOpacity: Double {
        switch self {
        case .low:    return 0.08
        case .medium: return 0.12
        case .high:   return 0.18
        }
    }

    // MARK: - Shadow

    /// Blur radius for the drop shadow beneath the glass surface.
    nonisolated var shadowRadius: CGFloat {
        switch self {
        case .low:    return 6
        case .medium: return 12
        case .high:   return 20
        }
    }

    /// Opacity of the drop shadow.
    nonisolated var shadowOpacity: Double {
        switch self {
        case .low:    return 0.04
        case .medium: return 0.08
        case .high:   return 0.14
        }
    }
}

// ══════════════════════════════════════════════════════════════════
// MARK: - Liquid Glass View Modifier
// Composites `.glassEffect`, the LiquidGlass Metal shader
// (time-driven refraction), a thin border stroke, and an
// elevation shadow — all parameterised by MaterialDensity.
//
// Accessibility:
//   - Reduce Motion → shader is skipped; static glass + border only
// ══════════════════════════════════════════════════════════════════

struct LiquidGlassModifier: ViewModifier {
    let density: MaterialDensity
    let cornerRadius: CGFloat

    // MARK: - Initialiser

    init(
        density: MaterialDensity = .medium,
        cornerRadius: CGFloat = PSSpacing.radiusLg
    ) {
        self.density = density
        self.cornerRadius = cornerRadius
    }

    // MARK: - Body

    func body(content: Content) -> some View {
        // Pure SwiftUI path — glassEffect + border + shadow (no Metal shader)
        content
            .glassEffect(
                .regular,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(density.borderOpacity), lineWidth: 0.5)
            )
            .shadow(
                color: Color.primary.opacity(density.shadowOpacity),
                radius: density.shadowRadius,
                y: 4
            )
    }
}

// MARK: - View Extension

extension View {
    /// Apply the Freshli Liquid Glass treatment at the given density.
    ///
    /// - Parameters:
    ///   - density: Optical weight of the glass surface (default `.medium`).
    ///   - cornerRadius: Corner radius of the glass shape (default `PSSpacing.radiusLg`).
    func liquidGlass(
        _ density: MaterialDensity = .medium,
        cornerRadius: CGFloat = PSSpacing.radiusLg
    ) -> some View {
        modifier(LiquidGlassModifier(density: density, cornerRadius: cornerRadius))
    }
}

// ══════════════════════════════════════════════════════════════════
// MARK: - Editorial Font
// Serif typeface for editorial headlines (Weekly Wrap, Impact
// stories, recipe intros). Uses "Newsreader" when bundled,
// falling back to the system serif design.
// ══════════════════════════════════════════════════════════════════

extension Font {
    /// Serif editorial headline — "Newsreader" with system serif fallback.
    /// Use for weekly-wrap titles, impact story headers, and recipe intros.
    nonisolated static var freshliEditorial: Font {
        if let _ = UIFont(name: "Newsreader", size: 1) {
            return Font.custom("Newsreader", size: UIFont.preferredFont(forTextStyle: .title2).pointSize, relativeTo: .title2)
        } else {
            return .system(.title2, design: .serif)
        }
    }
}
