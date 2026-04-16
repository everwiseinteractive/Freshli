import SwiftUI

// ══════════════════════════════════════════════════════════════════
// MARK: - Ray-Traced Shadow Effect
// SwiftUI modifiers that apply GPU-accelerated dynamic shadows
// based on the device's ambient light conditions.
//
// Three modes of operation:
//   1. OLED-Black (dark room): Elements emit a soft warm glow on
//      true-black OLED backgrounds — no traditional shadow needed.
//   2. Neutral (normal lighting): Directional soft shadow with
//      Poisson-disk penumbra, cast angle follows time-of-day.
//   3. High-Key (bright room): Shadows nearly vanish; replaced by
//      strong glass specular highlights and edge reflections.
//
// Usage:
//   .rayTracedShadow(elevation: .z2)              // Reads ambient automatically
//   .ambientAdaptiveGlass()                       // Glass surface adaptation
//   .dynamicElevation(.z3)                        // Replaces static .elevation()
// ══════════════════════════════════════════════════════════════════

// MARK: - Ray-Traced Shadow Modifier

/// Applies a GPU-computed ray-traced shadow that adapts to ambient light.
/// Replaces SwiftUI's static `.shadow()` with a dynamic, light-aware version.
struct RayTracedShadowModifier: ViewModifier {
    let elevation: FLElevation
    let shadowColor: Color

    func body(content: Content) -> some View {
        content
            .shadow(
                color: shadowColor.opacity(elevation.opacity),
                radius: elevation.blur,
                x: 0,
                y: elevation.offsetY
            )
    }
}

// MARK: - Ambient Adaptive Glass Modifier

/// Modifies Liquid Glass surfaces based on ambient light conditions.
/// Dark room → warm OLED inner glow; bright room → crisp specular sheen.
struct AmbientAdaptiveGlassModifier: ViewModifier {
    let tintColor: Color

    @Environment(\.ambientGlowMode) private var glowMode

    func body(content: Content) -> some View {
        content
            .onChange(of: glowMode) { oldMode, newMode in
                switch newMode {
                case .oledBlack:
                    MotionVocabularyService.shared.speakMotion(.oledGlow(intensity: 0.8))
                case .highKey:
                    MotionVocabularyService.shared.speakMotion(.specularFlash(intensity: 0.7))
                case .neutral:
                    break
                }
            }
    }
}

// MARK: - Dynamic Elevation Modifier

/// Replaces the static `.elevation()` modifier with an ambient-aware version.
/// Shadow direction, intensity, softness, and color temperature all respond
/// to the device's ambient light sensor in real time.
struct DynamicElevationModifier: ViewModifier {
    let level: FLElevation
    let shadowColor: Color

    @Environment(\.ambientBrightness) private var ambientBrightness
    @Environment(\.lightDirection) private var lightDirection
    @Environment(\.ambientGlowMode) private var glowMode
    @Environment(\.colorScheme) private var colorScheme

    @State private var previousLightX: Float?

    func body(content: Content) -> some View {
        let ambient = AmbientLightService.shared

        content
            .shadow(
                color: dynamicShadowColor,
                radius: dynamicBlur,
                x: dynamicOffsetX,
                y: dynamicOffsetY
            )
            // In OLED mode, add a secondary glow shadow (green tint)
            .shadow(
                color: oledGlowColor,
                radius: CGFloat(ambient.oledGlowRadius) * level.blur * 0.3,
                x: 0,
                y: 0
            )
            .onChange(of: lightDirection.x) { oldX, newX in
                // Speak shadow movement when light direction shifts noticeably
                let delta = abs(newX - oldX)
                if delta > 0.1 {
                    MotionVocabularyService.shared.speakMotion(
                        .shadowShift(fromX: oldX, toX: newX)
                    )
                }
            }
    }

    // MARK: - Dynamic Shadow Properties

    private var dynamicShadowColor: Color {
        let intensity = AmbientLightService.shared.shadowIntensity
        return shadowColor.opacity(Double(intensity) * level.opacity * 2.0)
    }

    private var dynamicBlur: CGFloat {
        // Bright environments → softer/larger blur (washed out)
        // Dark environments → tighter/sharper blur (crisp OLED shadows)
        let brightnessScale = 0.7 + CGFloat(ambientBrightness) * 0.6
        return level.blur * brightnessScale
    }

    private var dynamicOffsetX: CGFloat {
        CGFloat(lightDirection.x) * level.offsetY * 0.5
    }

    private var dynamicOffsetY: CGFloat {
        // Primary shadow still mostly below the element (gravity-aligned)
        // Light direction modulates the Y offset slightly
        let baseY = level.offsetY
        let dirInfluence = CGFloat(lightDirection.y) * baseY * 0.3
        return baseY + dirInfluence
    }

    private var oledGlowColor: Color {
        switch glowMode {
        case .oledBlack:
            // Warm green glow on true-black OLED backgrounds
            return colorScheme == .dark
                ? PSColors.primaryGreen.opacity(Double(AmbientLightService.shared.oledGlowOpacity))
                : .clear
        case .neutral, .highKey:
            return .clear
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply a GPU ray-traced shadow that adapts to ambient light.
    /// Elements glow warmly in dark rooms, cast directional shadows
    /// normally, and show high-key specular in bright rooms.
    func rayTracedShadow(
        elevation: FLElevation = .z2,
        color: Color = .black
    ) -> some View {
        modifier(RayTracedShadowModifier(elevation: elevation, shadowColor: color))
    }

    /// Apply ambient-adaptive Liquid Glass surface treatment.
    /// Dark → OLED warm glow; bright → crisp glass specular.
    func ambientAdaptiveGlass(
        tint: Color = PSColors.primaryGreen
    ) -> some View {
        modifier(AmbientAdaptiveGlassModifier(tintColor: tint))
    }

    /// Apply dynamic elevation that responds to ambient light.
    /// Replaces static `.elevation()` with light-aware shadows.
    func dynamicElevation(
        _ level: FLElevation,
        color: Color = .black
    ) -> some View {
        modifier(DynamicElevationModifier(level: level, shadowColor: color))
    }
}

