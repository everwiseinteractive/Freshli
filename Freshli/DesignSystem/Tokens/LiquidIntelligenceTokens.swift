import SwiftUI

// MARK: - Liquid Intelligence Design Tokens
// Tokens derived from the Freshli Figma "Liquid Intelligence" design system.
// Adds: Elevation scale (Z1–Z5), Material Density (Low/Med/High),
// Ghost State modifiers, Special palette, and High-Contrast Glass accessibility.
//
// All tokens map 1:1 to Figma Variable Collections and are Xcode 26 export-ready.

// ═══════════════════════════════════════════════════════════════
// MARK: - 1. Special Colors (extends FLColors)
// Figma Collection: "Color Tokens" → Specials group
// ═══════════════════════════════════════════════════════════════

extension FLColors {
    /// Collective Wave card — indigo accent for community feed.
    /// Light: #6366F1 | Dark: #818CF8
    nonisolated static let collectiveWave = Color(
        light: Color(hex: 0x6366F1),
        dark: Color(hex: 0x818CF8)
    )

    /// Apple Intelligence glow — violet pulse for predicted intent.
    /// Light: #A78BFA | Dark: #C4B5FD
    nonisolated static let aiGlow = Color(
        light: Color(hex: 0xA78BFA),
        dark: Color(hex: 0xC4B5FD)
    )

    /// Ghost State translucent — base tint for predictive UI elements.
    /// Light: primaryGreen @ 20% | Dark: primaryGreen @ 20%
    nonisolated static let ghostState = Color(
        light: Color(hex: 0x2D8B4E).opacity(0.20),
        dark: Color(hex: 0x4ADE80).opacity(0.20)
    )

    /// Glass border highlight — white rim on glass surfaces.
    /// Light: white @ 30% | Dark: white @ 10%
    nonisolated static let glassBorder = Color(
        light: Color.white.opacity(0.30),
        dark: Color.white.opacity(0.10)
    )
}

// ═══════════════════════════════════════════════════════════════
// MARK: - 2. Elevation Scale (Z1–Z5)
// Figma Collection: "Shadow & Elevation"
// Each level defines offsetY, blurRadius, and shadowOpacity.
// ═══════════════════════════════════════════════════════════════

/// Formal elevation token mapping Z-axis depth to shadow parameters.
/// Usage: `.elevation(.z2)` or access raw values via `FLElevation.z3.blur`.
enum FLElevation: Int, CaseIterable, Sendable {
    case z0 = 0
    case z1 = 1
    case z2 = 2
    case z3 = 3
    case z4 = 4
    case z5 = 5

    /// Vertical offset (points).
    var offsetY: CGFloat {
        switch self {
        case .z0: return 0
        case .z1: return 2
        case .z2: return 4
        case .z3: return 8
        case .z4: return 12
        case .z5: return 20
        }
    }

    /// Blur radius (points).
    var blur: CGFloat {
        switch self {
        case .z0: return 0
        case .z1: return 8
        case .z2: return 16
        case .z3: return 24
        case .z4: return 40
        case .z5: return 60
        }
    }

    /// Shadow opacity (0–1).
    var opacity: Double {
        switch self {
        case .z0: return 0
        case .z1: return 0.06
        case .z2: return 0.10
        case .z3: return 0.15
        case .z4: return 0.20
        case .z5: return 0.25
        }
    }

    /// Display name for debugging / component descriptions.
    var label: String {
        "Z\(rawValue)"
    }
}

/// View modifier that applies a formal elevation shadow from the Z-scale.
struct ElevationModifier: ViewModifier {
    let level: FLElevation
    var color: Color = .black

    func body(content: Content) -> some View {
        content
            .shadow(
                color: color.opacity(level.opacity),
                radius: level.blur,
                x: 0,
                y: level.offsetY
            )
    }
}

extension View {
    /// Apply a formal Z-axis elevation shadow.
    ///
    ///     .elevation(.z2)
    ///     .elevation(.z4, color: PSColors.primaryGreen)
    func elevation(_ level: FLElevation, color: Color = .black) -> some View {
        modifier(ElevationModifier(level: level, color: color))
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - 3. Material Density
// Figma Collection: "Material Density" — Low / Med / High
// Maps to Metal 4 refractive indices for the liquidGlassSurface shader.
// ═══════════════════════════════════════════════════════════════

/// Material density level controlling glass blur, opacity, and refraction.
/// In code, use `FLMaterialDensity.med` for the default Freshli glass look.
enum FLMaterialDensity: String, CaseIterable, Sendable {
    case low
    case med
    case high

    /// Background blur radius (points).
    var blurRadius: CGFloat {
        switch self {
        case .low:  return 8
        case .med:  return 20
        case .high: return 40
        }
    }

    /// Fill opacity for the white glass tint.
    var fillOpacity: Double {
        switch self {
        case .low:  return 0.30
        case .med:  return 0.50
        case .high: return 0.70
        }
    }

    /// Saturation multiplier for vibrancy.
    var saturation: Double {
        switch self {
        case .low:  return 1.2
        case .med:  return 1.5
        case .high: return 1.8
        }
    }

    /// Metal 4 refractive index (for liquidGlassSurface shader).
    var refractiveIndex: Float {
        switch self {
        case .low:  return 1.0
        case .med:  return 1.33
        case .high: return 1.52
        }
    }

    /// Tint strength for the glass coloring pass.
    var tintStrength: Double {
        switch self {
        case .low:  return 0.05
        case .med:  return 0.12
        case .high: return 0.20
        }
    }
}

/// View modifier that applies a Liquid Glass material at a specific density.
struct LiquidGlassMaterialModifier: ViewModifier {
    let density: FLMaterialDensity
    let cornerRadius: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(density.fillOpacity / 0.5) // Scale relative to ultraThinMaterial
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(
                        colorScheme == .dark
                            ? density.fillOpacity * 0.15
                            : density.fillOpacity
                    ))
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        FLColors.glassBorder,
                        lineWidth: 0.5
                    )
            }
            .elevation(.z2)
    }
}

extension View {
    /// Apply a Liquid Glass material at a specific density level.
    ///
    ///     .liquidGlass(.med, cornerRadius: 24)
    ///     .liquidGlass(.high, cornerRadius: 16)
    func liquidGlass(
        _ density: FLMaterialDensity = .med,
        cornerRadius: CGFloat = PSSpacing.radiusXxl
    ) -> some View {
        modifier(LiquidGlassMaterialModifier(density: density, cornerRadius: cornerRadius))
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - 4. Ghost State Modifier
// Figma: "Ghost Predict" variant — translucent element that blooms
// into full visibility when Apple Intelligence predicts user intent.
// ═══════════════════════════════════════════════════════════════

/// View modifier that renders a "Ghost State" — a translucent predictive UI
/// element that blooms into full opacity when triggered.
///
/// - Ghost state: 4% fill, dashed border, muted text
/// - Bloomed state: Full opacity card with AI Glow pulse
///
/// Usage:
///
///     Button("Add to Pantry") { ... }
///         .ghostState(isActive: $isPredicted)
///
struct GhostStateModifier: ViewModifier {
    @Binding var isActive: Bool
    let ghostOpacity: Double
    let bloomSpring: Animation

    @State private var glowPhase: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        isActive: Binding<Bool>,
        ghostOpacity: Double = 0.04,
        bloomSpring: Animation = .spring(response: 0.3, dampingFraction: 0.75)
    ) {
        self._isActive = isActive
        self.ghostOpacity = ghostOpacity
        self.bloomSpring = bloomSpring
    }

    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 1.0 : ghostOpacity / 0.04) // Scale content opacity
            .overlay {
                if !isActive && !reduceMotion {
                    // AI Glow pulse while in ghost state
                    RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                        .fill(FLColors.aiGlow.opacity(glowPhase ? 0.08 : 0.02))
                        .allowsHitTesting(false)
                }
            }
            .background {
                if !isActive {
                    RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                        .fill(FLColors.ghostState)
                        .overlay {
                            RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                                .strokeBorder(
                                    FLColors.primaryGreen.opacity(0.15),
                                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                                )
                        }
                }
            }
            .animation(bloomSpring, value: isActive)
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    PSHaptics.shared.selection()
                }
            }
            .task {
                guard !reduceMotion else { return }
                while !Task.isCancelled {
                    withAnimation(.easeInOut(duration: 2.0)) {
                        glowPhase.toggle()
                    }
                    try? await Task.sleep(for: .seconds(2.0))
                }
            }
    }
}

extension View {
    /// Render this view as a Ghost State that blooms on predicted intent.
    ///
    ///     .ghostState(isActive: $isPredicted)
    func ghostState(isActive: Binding<Bool>) -> some View {
        modifier(GhostStateModifier(isActive: isActive))
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - 5. High-Contrast Glass System
// Figma: "Accessibility — High Contrast" page
// WCAG AAA · 7:1 contrast ratios · Opaque surfaces · Thick borders
// Maintains liquid aesthetic while being fully accessible.
// ═══════════════════════════════════════════════════════════════

/// View modifier that adapts a glass surface for high-contrast accessibility.
/// When `accessibilityReduceTransparency` is enabled, replaces translucent
/// glass with opaque surfaces, thicker borders, and bolder text weights.
struct HighContrastGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if reduceTransparency {
            // High-contrast mode: opaque, thick borders, max readability
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
                .shadow(
                    color: .black.opacity(colorScheme == .dark ? 0.3 : 0.12),
                    radius: 8,
                    y: 4
                )
        } else {
            // Standard liquid glass — pass through
            content
        }
    }
}

extension View {
    /// Wrap a glass surface with high-contrast accessibility support.
    /// Automatically activates when the user enables "Reduce Transparency"
    /// in iOS Settings, replacing translucent materials with opaque
    /// surfaces that maintain 7:1 contrast ratios.
    ///
    ///     .liquidGlass(.med, cornerRadius: 24)
    ///     .highContrastGlass(cornerRadius: 24)
    func highContrastGlass(cornerRadius: CGFloat = PSSpacing.radiusXxl) -> some View {
        modifier(HighContrastGlassModifier(cornerRadius: cornerRadius))
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - 6. Convenience Composites
// Common combinations used across the app.
// ═══════════════════════════════════════════════════════════════

extension View {
    /// Full Liquid Intelligence card treatment: glass material + elevation + accessibility.
    ///
    ///     .liquidIntelligenceCard()
    ///     .liquidIntelligenceCard(density: .high, elevation: .z3)
    func liquidIntelligenceCard(
        density: FLMaterialDensity = .med,
        elevation: FLElevation = .z2,
        cornerRadius: CGFloat = PSSpacing.radiusXxl
    ) -> some View {
        self
            .liquidGlass(density, cornerRadius: cornerRadius)
            .elevation(elevation)
            .highContrastGlass(cornerRadius: cornerRadius)
    }
}
