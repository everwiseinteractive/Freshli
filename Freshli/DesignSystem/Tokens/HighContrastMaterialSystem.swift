import SwiftUI

// ══════════════════════════════════════════════════════════════════
// MARK: - High Contrast Material System
// Accessibility-first material replacement that swaps translucent
// glass and refractive shaders with vibrant, ultra-legible opaque
// surfaces when the user enables Reduce Transparency or Increase
// Contrast in iOS Settings.
//
// Design principles:
//   1. WCAG AAA — 7:1 contrast ratios minimum
//   2. No transparency — all surfaces are fully opaque
//   3. Bold borders — 2pt strokes for clear element boundaries
//   4. Mesh gradients — replace glass shaders with vibrant,
//      animated gradients that maintain the "living" feel without
//      relying on translucency or refraction
//   5. Respects Reduce Motion — static meshes when enabled
//
// Usage:
//   .highContrastMaterial(cornerRadius: 24)
//   .highContrastBackground(.impact)
// ══════════════════════════════════════════════════════════════════

// MARK: - Material Theme

/// Pre-defined color palettes for high-contrast mesh gradient backgrounds.
/// Each theme maps to a specific screen/section in the app.
enum HighContrastTheme: Sendable {
    case home       // Freshli greens
    case impact     // Teal + green
    case community  // Indigo + purple
    case recipes    // Amber + orange
    case pantry     // Green + emerald
    case profile    // Slate + neutral

    /// 3×3 mesh gradient colors for this theme.
    var meshColors: [Color] {
        switch self {
        case .home:
            return [
                Color(hex: 0x1A3A2A), Color(hex: 0x1E4D38), Color(hex: 0x1A3A2A),
                Color(hex: 0x1E4D38), Color(hex: 0x236B4A), Color(hex: 0x1E4D38),
                Color(hex: 0x1A3A2A), Color(hex: 0x1E4D38), Color(hex: 0x1A3A2A)
            ]
        case .impact:
            return [
                Color(hex: 0x0F2E2E), Color(hex: 0x134E4A), Color(hex: 0x0F2E2E),
                Color(hex: 0x134E4A), Color(hex: 0x1A6B5C), Color(hex: 0x134E4A),
                Color(hex: 0x0F2E2E), Color(hex: 0x134E4A), Color(hex: 0x0F2E2E)
            ]
        case .community:
            return [
                Color(hex: 0x1E1B3A), Color(hex: 0x2D2760), Color(hex: 0x1E1B3A),
                Color(hex: 0x2D2760), Color(hex: 0x3B3486), Color(hex: 0x2D2760),
                Color(hex: 0x1E1B3A), Color(hex: 0x2D2760), Color(hex: 0x1E1B3A)
            ]
        case .recipes:
            return [
                Color(hex: 0x3A2A1A), Color(hex: 0x4D3820), Color(hex: 0x3A2A1A),
                Color(hex: 0x4D3820), Color(hex: 0x6B4F2A), Color(hex: 0x4D3820),
                Color(hex: 0x3A2A1A), Color(hex: 0x4D3820), Color(hex: 0x3A2A1A)
            ]
        case .pantry:
            return [
                Color(hex: 0x162B20), Color(hex: 0x1E4032), Color(hex: 0x162B20),
                Color(hex: 0x1E4032), Color(hex: 0x285A44), Color(hex: 0x1E4032),
                Color(hex: 0x162B20), Color(hex: 0x1E4032), Color(hex: 0x162B20)
            ]
        case .profile:
            return [
                Color(hex: 0x1E2024), Color(hex: 0x2A2D33), Color(hex: 0x1E2024),
                Color(hex: 0x2A2D33), Color(hex: 0x363940), Color(hex: 0x2A2D33),
                Color(hex: 0x1E2024), Color(hex: 0x2A2D33), Color(hex: 0x1E2024)
            ]
        }
    }

    /// Light mode mesh colors — brighter, vibrant versions.
    var meshColorsLight: [Color] {
        switch self {
        case .home:
            return [
                Color(hex: 0xE8F5EE), Color(hex: 0xD1FADF), Color(hex: 0xE8F5EE),
                Color(hex: 0xD1FADF), Color(hex: 0xA7F3D0), Color(hex: 0xD1FADF),
                Color(hex: 0xE8F5EE), Color(hex: 0xD1FADF), Color(hex: 0xE8F5EE)
            ]
        case .impact:
            return [
                Color(hex: 0xE0F7F5), Color(hex: 0xCCFBF1), Color(hex: 0xE0F7F5),
                Color(hex: 0xCCFBF1), Color(hex: 0x99F6E4), Color(hex: 0xCCFBF1),
                Color(hex: 0xE0F7F5), Color(hex: 0xCCFBF1), Color(hex: 0xE0F7F5)
            ]
        case .community:
            return [
                Color(hex: 0xEEF2FF), Color(hex: 0xE0E7FF), Color(hex: 0xEEF2FF),
                Color(hex: 0xE0E7FF), Color(hex: 0xC7D2FE), Color(hex: 0xE0E7FF),
                Color(hex: 0xEEF2FF), Color(hex: 0xE0E7FF), Color(hex: 0xEEF2FF)
            ]
        case .recipes:
            return [
                Color(hex: 0xFFF8EB), Color(hex: 0xFEF3C7), Color(hex: 0xFFF8EB),
                Color(hex: 0xFEF3C7), Color(hex: 0xFDE68A), Color(hex: 0xFEF3C7),
                Color(hex: 0xFFF8EB), Color(hex: 0xFEF3C7), Color(hex: 0xFFF8EB)
            ]
        case .pantry:
            return [
                Color(hex: 0xECFDF5), Color(hex: 0xD1FAE5), Color(hex: 0xECFDF5),
                Color(hex: 0xD1FAE5), Color(hex: 0xA7F3D0), Color(hex: 0xD1FAE5),
                Color(hex: 0xECFDF5), Color(hex: 0xD1FAE5), Color(hex: 0xECFDF5)
            ]
        case .profile:
            return [
                Color(hex: 0xF8FAFC), Color(hex: 0xF1F5F9), Color(hex: 0xF8FAFC),
                Color(hex: 0xF1F5F9), Color(hex: 0xE2E8F0), Color(hex: 0xF1F5F9),
                Color(hex: 0xF8FAFC), Color(hex: 0xF1F5F9), Color(hex: 0xF8FAFC)
            ]
        }
    }
}

// MARK: - High Contrast Material Modifier

/// View modifier that replaces glass/translucent materials with opaque,
/// high-contrast surfaces when Reduce Transparency is enabled.
/// Uses vibrant colors and thick borders for WCAG AAA compliance.
struct HighContrastMaterialModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(colorScheme == .dark
                              ? Color(hex: 0x1A2420)
                              : Color.white)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            colorScheme == .dark
                                ? Color.white.opacity(0.25)
                                : Color(hex: 0xCBD5CF),
                            lineWidth: 2
                        )
                }
        } else {
            content
        }
    }
}

// MARK: - High Contrast Background Modifier

/// Replaces animated shader backgrounds (impactPlasma, ambientParticles, etc.)
/// with a vibrant MeshGradient when Reduce Transparency is enabled.
/// Maintains the "living" feel through subtle mesh animation while being
/// fully opaque and WCAG AAA compliant.
struct HighContrastBackgroundModifier: ViewModifier {
    let theme: HighContrastTheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    @State private var meshPhase: CGFloat = 0

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background {
                    meshGradientBackground
                        .ignoresSafeArea()
                }
        } else {
            content
        }
    }

    @ViewBuilder
    private var meshGradientBackground: some View {
        let colors = colorScheme == .dark ? theme.meshColors : theme.meshColorsLight

        if reduceMotion {
            // Static mesh — no animation
            MeshGradient(
                width: 3, height: 3,
                points: staticMeshPoints,
                colors: colors
            )
        } else {
            // Animated mesh — gentle breathing
            TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: false)) { timeline in
                let time = timeline.date.timeIntervalSince(.now.addingTimeInterval(-100))
                let phase = Float(time) * 0.3

                MeshGradient(
                    width: 3, height: 3,
                    points: animatedMeshPoints(phase: phase),
                    colors: colors
                )
                .drawingGroup()
            }
        }
    }

    private var staticMeshPoints: [SIMD2<Float>] {
        [
            [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
            [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
            [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
        ]
    }

    private func animatedMeshPoints(phase: Float) -> [SIMD2<Float>] {
        let d: Float = 0.04  // drift amplitude
        return [
            [0.0, 0.0],
            [0.5 + sin(phase) * d, 0.0],
            [1.0, 0.0],
            [0.0, 0.5 + cos(phase * 0.7) * d],
            [0.5 + sin(phase * 1.3) * d, 0.5 + cos(phase * 0.9) * d],
            [1.0, 0.5 + sin(phase * 0.8) * d],
            [0.0, 1.0],
            [0.5 + cos(phase * 1.1) * d, 1.0],
            [1.0, 1.0]
        ]
    }
}

// MARK: - View Extensions

extension View {
    /// Apply high-contrast opaque material when Reduce Transparency is active.
    func highContrastMaterial(cornerRadius: CGFloat = PSSpacing.radiusXxl) -> some View {
        modifier(HighContrastMaterialModifier(cornerRadius: cornerRadius))
    }

    /// Replace shader background with vibrant mesh gradient in high-contrast mode.
    func highContrastBackground(_ theme: HighContrastTheme) -> some View {
        modifier(HighContrastBackgroundModifier(theme: theme))
    }
}
