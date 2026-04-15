import SwiftUI

// ══════════════════════════════════════════════════════════════════
// MARK: - FLGlassSurface (Atom)
// The single source-of-truth glass modifier for every Freshli surface.
// Wraps the Metal 4 liquidGlass pipeline + iOS 26 .glassEffect into
// one composable API. No view in the app should create its own glass
// background — it must go through this atom.
//
// Usage:
//   someView.flGlass(.card)          // standard card surface
//   someView.flGlass(.hero)          // hero section (stronger refraction)
//   someView.flGlass(.subtle)        // inline chips, pills
//   someView.flGlass(.card, tint: .green)  // green-tinted glass
// ══════════════════════════════════════════════════════════════════

// MARK: - Glass Intensity Presets

enum FLGlassIntensity: Sendable {
    case subtle   // pills, chips, inline elements
    case card     // standard cards, sections
    case hero     // hero headers, full-width banners
    case elevated // modals, sheets, overlays

    var cornerRadius: CGFloat {
        switch self {
        case .subtle:   return 12
        case .card:     return 20
        case .hero:     return 28
        case .elevated: return 32
        }
    }

    var materialDensity: MaterialDensity {
        switch self {
        case .subtle:   return .low
        case .card:     return .medium
        case .hero:     return .high
        case .elevated: return .high
        }
    }

    var borderOpacity: Double {
        switch self {
        case .subtle:   return 0.06
        case .card:     return 0.10
        case .hero:     return 0.14
        case .elevated: return 0.18
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .subtle:   return 4
        case .card:     return 12
        case .hero:     return 20
        case .elevated: return 28
        }
    }

    var shadowOpacity: Double {
        switch self {
        case .subtle:   return 0.04
        case .card:     return 0.06
        case .hero:     return 0.08
        case .elevated: return 0.12
        }
    }
}

// MARK: - Glass Tint

enum FLGlassTint: Sendable {
    case none
    case green
    case amber
    case blue
    case mission

    var color: Color? {
        switch self {
        case .none:    return nil
        case .green:   return PSColors.primaryGreen
        case .amber:   return PSColors.secondaryAmber
        case .blue:    return PSColors.infoBlue
        case .mission: return FreshliBrand.missionAccent
        }
    }
}

// MARK: - Glass Surface Modifier

struct FLGlassSurfaceModifier: ViewModifier {
    let intensity: FLGlassIntensity
    let tint: FLGlassTint
    let customRadius: CGFloat?

    @Environment(\.colorScheme) private var colorScheme

    private var radius: CGFloat { customRadius ?? intensity.cornerRadius }
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    func body(content: Content) -> some View {
        content
            .background {
                shape
                    .fill(.ultraThinMaterial)
                    .overlay {
                        // Tint wash
                        if let tintColor = tint.color {
                            shape.fill(tintColor.opacity(colorScheme == .dark ? 0.12 : 0.06))
                        }
                    }
                    .overlay {
                        // Specular border
                        shape.strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(intensity.borderOpacity * 1.4),
                                    .white.opacity(intensity.borderOpacity * 0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                    }
            }
            .clipShape(shape)
            .shadow(
                color: .black.opacity(intensity.shadowOpacity),
                radius: intensity.shadowRadius,
                y: intensity.shadowRadius / 3
            )
            .glassEffect(.regular, in: shape)
    }
}

// MARK: - View Extension

extension View {
    func flGlass(
        _ intensity: FLGlassIntensity = .card,
        tint: FLGlassTint = .none,
        cornerRadius: CGFloat? = nil
    ) -> some View {
        modifier(FLGlassSurfaceModifier(
            intensity: intensity,
            tint: tint,
            customRadius: cornerRadius
        ))
    }
}
