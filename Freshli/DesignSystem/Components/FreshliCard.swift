import SwiftUI

// MARK: - FreshliSurface
//
// Unified surface card modifier — one-line API that gives every card in
// the app the same quiet, consistent visual language. Coexists with the
// existing `FreshliCardStyle` glass-morphism modifier; this is the more
// opinionated, solid-background variant used for the primary content
// cards on Home, Pantry, Profile etc.
//
//   • 24pt rounded rectangle (Apple's default large container radius)
//   • PSColors.surfaceCard background (plain), or prominent / mission /
//     warning gradient variants
//   • 1pt hairline stroke
//   • Soft drop shadow tuned per variant
//   • Inner content padding: PSSpacing.lg (20pt) by default
//
// Usage:
//   VStack { … }
//       .freshliSurface()               // default
//       .freshliSurface(.prominent)     // subtle emphasis
//       .freshliSurface(.mission)       // the Live Wave card uses this
//
// This replaces the 40+ ad-hoc `.background().clipShape().overlay().shadow()`
// stacks scattered across individual views, and gives every screen the
// same quiet rhythm a user can feel even if they can't name it.

enum FreshliSurfaceVariant {
    case plain
    case prominent
    case mission
    case warning

    var background: AnyShapeStyle {
        switch self {
        case .plain:
            return AnyShapeStyle(PSColors.surfaceCard)
        case .prominent:
            return AnyShapeStyle(PSColors.primaryGreen.opacity(0.05))
        case .mission:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        FreshliBrand.missionAccentLight,
                        FreshliBrand.missionAccent,
                        FreshliBrand.planetBlue.opacity(0.9),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .warning:
            return AnyShapeStyle(PSColors.secondaryAmber.opacity(0.06))
        }
    }

    var strokeColor: Color {
        switch self {
        case .plain:     return PSColors.borderLight
        case .prominent: return PSColors.primaryGreen.opacity(0.18)
        case .mission:   return .white.opacity(0.15)
        case .warning:   return PSColors.secondaryAmber.opacity(0.25)
        }
    }

    var shadowColor: Color {
        switch self {
        case .plain:     return .black.opacity(0.05)
        case .prominent: return PSColors.primaryGreen.opacity(0.12)
        case .mission:   return FreshliBrand.missionAccent.opacity(0.30)
        case .warning:   return PSColors.secondaryAmber.opacity(0.12)
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .plain:     return 14
        case .prominent: return 16
        case .mission:   return 22
        case .warning:   return 12
        }
    }

    var shadowY: CGFloat {
        switch self {
        case .plain:     return 6
        case .prominent: return 8
        case .mission:   return 10
        case .warning:   return 5
        }
    }
}

struct FreshliSurfaceModifier: ViewModifier {
    let variant: FreshliSurfaceVariant
    let padding: CGFloat?
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .padding(padding ?? PSSpacing.lg)
            .background(variant.background)
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(variant.strokeColor, lineWidth: 1)
            }
            .shadow(color: variant.shadowColor, radius: variant.shadowRadius, x: 0, y: variant.shadowY)
    }
}

extension View {
    /// Applies the unified Freshli surface style. One line. Always consistent.
    ///
    /// - Parameters:
    ///   - variant: Plain (default), prominent, mission, or warning.
    ///   - padding: Inner content padding. Defaults to `PSSpacing.lg` (20pt).
    ///              Pass `nil` for default, or a custom value (or `0` for flush content).
    ///   - cornerRadius: Defaults to 24pt (Apple's standard large-container radius).
    func freshliSurface(
        _ variant: FreshliSurfaceVariant = .plain,
        padding: CGFloat? = nil,
        cornerRadius: CGFloat = 24
    ) -> some View {
        modifier(FreshliSurfaceModifier(variant: variant, padding: padding, cornerRadius: cornerRadius))
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            Text("Plain surface").freshliSurface()
            Text("Prominent surface").freshliSurface(.prominent)

            VStack(alignment: .leading, spacing: 8) {
                Text("LIVE WAVE").font(.caption.bold()).foregroundStyle(.white.opacity(0.7))
                Text("347").font(.system(size: 48, weight: .black)).foregroundStyle(.white)
                Text("people rescued food in the last hour")
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .freshliSurface(.mission)

            Text("⚠️ Warning surface").freshliSurface(.warning)
        }
        .padding()
    }
    .background(PSColors.backgroundSecondary)
}
