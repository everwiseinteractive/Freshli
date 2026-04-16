import SwiftUI

// MARK: - Safe Shader Geometry

extension GeometryProxy {
    /// Size guaranteed to have non-zero dimensions, preventing division-by-zero
    /// in Metal shaders that normalise coordinates via `position / size`.
    /// Without this guard, views that haven't completed layout pass (0, 0) to
    /// the GPU, producing NaN/Inf which causes SwiftUI rendering failures.
    nonisolated var safeShaderSize: CGSize {
        CGSize(width: max(size.width, 1), height: max(size.height, 1))
    }
}

// ──────────────────────────────────────────────────────────
// Freshli — Pure SwiftUI Effect View Modifiers
// Replaces Metal GPU shaders with native SwiftUI animations.
// Each modifier respects accessibilityReduceMotion and degrades
// gracefully without any GPU shader dependencies.
// ──────────────────────────────────────────────────────────

// MARK: - Shimmer Effect

/// Diagonal shimmer sweep — a moving clear-white-clear gradient band
/// that sweeps across the view. Used by PSShimmerView and
/// the .metalShimmer() modifier for cards.
struct MetalShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -0.3
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let duration: Double
    let pauseDuration: Double

    init(duration: Double = 1.4, pauseDuration: Double = 0.6) {
        self.duration = duration
        self.pauseDuration = pauseDuration
    }

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .overlay {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: max(0, phase - 0.15)),
                                        .init(color: .white.opacity(0.12), location: phase),
                                        .init(color: .clear, location: min(1, phase + 0.15))
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blendMode(.overlay)
                    }
                }
                .clipped()
                .task {
                    while !Task.isCancelled {
                        phase = -0.3
                        withAnimation(.easeInOut(duration: duration)) {
                            phase = 1.3
                        }
                        try? await Task.sleep(for: .seconds(duration + pauseDuration))
                    }
                }
        }
    }
}

// MARK: - Card Glass Effect

/// Adds a subtle caustic-like light play to card surfaces, giving them
/// a premium frosted-glass feel. Very subtle — designed to be
/// noticed subconsciously rather than consciously.
struct MetalCardGlassModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let intensity: Float

    init(intensity: Float = 0.5) {
        self.intensity = intensity
    }

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .overlay {
                    GeometryReader { geo in
                        let w = geo.size.width
                        let h = geo.size.height
                        // Slowly drifting caustic-like highlight
                        Ellipse()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(Double(intensity) * 0.08),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: max(w, h) * 0.5
                                )
                            )
                            .frame(width: w * 0.6, height: h * 0.4)
                            .offset(
                                x: cos(phase * .pi * 2) * w * 0.15,
                                y: sin(phase * .pi * 2) * h * 0.1
                            )
                            .blendMode(.overlay)
                    }
                    .allowsHitTesting(false)
                }
                .clipped()
                .task {
                    while !Task.isCancelled {
                        withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true)) {
                            phase = 1.0
                        }
                        try? await Task.sleep(for: .seconds(12.0))
                    }
                }
        }
    }
}

// MARK: - Impact Shimmer

/// Drop-in replacement for the existing shimmer used on Impact cards.
/// Delegates to MetalShimmerModifier with longer duration and pause.
struct MetalImpactShimmerModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.modifier(MetalShimmerModifier(duration: 1.6, pauseDuration: 4.0))
    }
}

// MARK: - Expiry Pulse Effect

/// Soft breathing glow on expiry badges — amber for "expiring soon",
/// red for "expired". Draws attention without being alarming.
struct MetalExpiryPulseModifier: ViewModifier {
    let pulseColor: Color
    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .shadow(
                    color: pulseColor.opacity(isPulsing ? 0.5 : 0.15),
                    radius: isPulsing ? 8 : 3
                )
                .scaleEffect(isPulsing ? 1.03 : 1.0)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: isPulsing
                )
                .onAppear { isPulsing = true }
        }
    }
}

// MARK: - Celebration Radiance

/// Radial glow burst for celebration overlays — color-shifting
/// pulsing radial gradient from the center.
struct MetalCelebrationRadianceModifier: ViewModifier {
    let glowColor: Color
    let intensity: Float
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(glowColor: Color, intensity: Float = 0.8) {
        self.glowColor = glowColor
        self.intensity = intensity
    }

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .overlay {
                    RadialGradient(
                        colors: [
                            glowColor.opacity(Double(intensity) * 0.3 * (0.5 + phase * 0.5)),
                            glowColor.opacity(Double(intensity) * 0.1 * phase),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                    .blendMode(.overlay)
                    .allowsHitTesting(false)
                }
                .task {
                    while !Task.isCancelled {
                        withAnimation(.easeInOut(duration: 1.5)) {
                            phase = 1.0
                        }
                        try? await Task.sleep(for: .seconds(1.5))
                        withAnimation(.easeInOut(duration: 1.5)) {
                            phase = 0.3
                        }
                        try? await Task.sleep(for: .seconds(1.5))
                    }
                }
        }
    }
}

// MARK: - Streak Flame Glow

/// Warm flickering fire glow behind the streak flame icon.
/// Intensity scales with streak length (1-7+ days).
struct MetalStreakFlameModifier: ViewModifier {
    let streakDays: Int
    @State private var flicker: CGFloat = 0.5
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion || streakDays <= 0 {
            content
        } else {
            let warmth = min(CGFloat(streakDays) / 7.0, 1.0)
            content
                .overlay {
                    RadialGradient(
                        colors: [
                            Color.orange.opacity(0.25 * warmth * flicker),
                            Color.red.opacity(0.1 * warmth * flicker),
                            Color.clear
                        ],
                        center: .bottom,
                        startRadius: 5,
                        endRadius: 80
                    )
                    .blendMode(.overlay)
                    .allowsHitTesting(false)
                }
                .task {
                    while !Task.isCancelled {
                        withAnimation(.easeInOut(duration: 0.8 + Double.random(in: 0...0.5))) {
                            flicker = CGFloat.random(in: 0.6...1.0)
                        }
                        try? await Task.sleep(for: .seconds(0.8 + Double.random(in: 0...0.5)))
                    }
                }
        }
    }
}

// MARK: - Ambient Particles

/// Ambient particle field placeholder — particles are too complex
/// for pure SwiftUI and not critical. Passes content through.
struct MetalAmbientParticlesModifier: ViewModifier {
    let density: Float
    let brightness: Float

    init(density: Float = 2.0, brightness: Float = 0.6) {
        self.density = density
        self.brightness = brightness
    }

    func body(content: Content) -> some View {
        content // Pure SwiftUI — ambient particles effect removed
    }
}

// MARK: - Button Ripple

/// Press ripple effect for PSButton — expanding overlay circle on tap.
struct MetalButtonRippleModifier: ViewModifier {
    @Binding var isPressed: Bool
    @State private var rippleScale: CGFloat = 0.3
    @State private var rippleOpacity: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                Circle()
                    .fill(Color.white.opacity(rippleOpacity * 0.15))
                    .scaleEffect(rippleScale)
                    .allowsHitTesting(false)
            }
            .clipped()
            .onChange(of: isPressed) { _, pressed in
                if pressed {
                    rippleScale = 0.3
                    rippleOpacity = 1.0
                    withAnimation(.easeOut(duration: 0.5)) {
                        rippleScale = 2.5
                        rippleOpacity = 0
                    }
                }
            }
    }
}

// MARK: - Subtle Film Grain

/// Film grain placeholder — effect cannot be replicated in pure
/// SwiftUI. Passes content through.
struct MetalNoiseModifier: ViewModifier {
    let intensity: Float
    init(intensity: Float = 0.5) { self.intensity = intensity }

    func body(content: Content) -> some View {
        content // Pure SwiftUI — film grain removed
    }
}

// MARK: - Hero Gradient (Animated)

/// Animated gradient for the HomeView hero header.
/// Organic wave-based color shifting through the Freshli green palette.
struct MetalHeroGradientModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .overlay {
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.55, blue: 0.28).opacity(0.15 + phase * 0.08),
                            Color(red: 0.13, green: 0.77, blue: 0.37).opacity(0.08 + phase * 0.05),
                            Color(red: 0.08, green: 0.62, blue: 0.42).opacity(0.12 + (1 - phase) * 0.06)
                        ],
                        startPoint: UnitPoint(x: phase * 0.3, y: 0),
                        endPoint: UnitPoint(x: 0.7 + phase * 0.3, y: 1)
                    )
                    .blendMode(.overlay)
                    .allowsHitTesting(false)
                }
                .task {
                    while !Task.isCancelled {
                        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                            phase = 1.0
                        }
                        try? await Task.sleep(for: .seconds(8.0))
                    }
                }
        }
    }
}

// MARK: - Impact Plasma Background

/// Animated plasma background for Impact Dashboard.
/// Multi-color gradient overlay with organic color movement.
struct MetalImpactPlasmaModifier: ViewModifier {
    let intensityMix: Float
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(intensityMix: Float = 0.5) {
        self.intensityMix = intensityMix
    }

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .overlay {
                    LinearGradient(
                        colors: [
                            Color(red: 0.05, green: 0.25, blue: 0.15).opacity(Double(intensityMix) * 0.4),
                            Color(red: 0.1, green: 0.45, blue: 0.25).opacity(Double(intensityMix) * 0.3 * (0.8 + phase * 0.2)),
                            Color(red: 0.02, green: 0.18, blue: 0.12).opacity(Double(intensityMix) * 0.35)
                        ],
                        startPoint: UnitPoint(x: phase * 0.4, y: 0),
                        endPoint: UnitPoint(x: 0.6 + phase * 0.4, y: 1)
                    )
                    .blendMode(.overlay)
                    .allowsHitTesting(false)
                }
                .task {
                    while !Task.isCancelled {
                        withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                            phase = 1.0
                        }
                        try? await Task.sleep(for: .seconds(10.0))
                    }
                }
        }
    }
}

// MARK: - Chef Silhouette (Cooking Mode Background)

/// Chef silhouette placeholder — abstract shapes cannot be replicated
/// in pure SwiftUI. Passes content through.
struct MetalChefSilhouetteModifier: ViewModifier {
    let opacity: Float
    init(opacity: Float = 1.0) { self.opacity = opacity }

    func body(content: Content) -> some View {
        content // Pure SwiftUI — chef silhouette effect removed
    }
}

// MARK: - Freshli Aura (Home Header Emitter)

/// Themed aura effect — subtle animated green-toned radial gradient
/// that creates a living, breathing Freshli-branded header experience.
struct MetalFreshliAuraModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .overlay {
                    RadialGradient(
                        colors: [
                            Color(red: 0.13, green: 0.77, blue: 0.37).opacity(0.06 + phase * 0.04),
                            Color(red: 0.08, green: 0.55, blue: 0.28).opacity(0.03 + (1 - phase) * 0.03),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.5 + phase * 0.1, y: 0.3),
                        startRadius: 20,
                        endRadius: 300
                    )
                    .blendMode(.overlay)
                    .allowsHitTesting(false)
                }
                .task {
                    while !Task.isCancelled {
                        withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                            phase = 1.0
                        }
                        try? await Task.sleep(for: .seconds(10.0))
                    }
                }
        }
    }
}

// MARK: - Intent Glow (Apple Intelligence Adaptive Surface)

/// Animated shadow glow applied to UI elements predicted as the user's
/// next interaction target. Intensity ramps from 0-1 as the AI model's
/// confidence increases.
struct MetalIntentGlowModifier: ViewModifier {
    let intensity: Float
    let glowColor: Color
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(intensity: Float, glowColor: Color = Color(red: 0.16, green: 0.77, blue: 0.42)) {
        self.intensity = intensity
        self.glowColor = glowColor
    }

    func body(content: Content) -> some View {
        if reduceMotion || intensity < 0.01 {
            content
        } else {
            content
                .shadow(
                    color: glowColor.opacity(Double(intensity) * 0.3 * (0.7 + phase * 0.3)),
                    radius: CGFloat(intensity) * 12 * (0.8 + phase * 0.2)
                )
                .task {
                    while !Task.isCancelled {
                        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                            phase = 1.0
                        }
                        try? await Task.sleep(for: .seconds(4.0))
                    }
                }
        }
    }
}

// MARK: - Liquid Glass Surface

/// Brings the Liquid Glass aesthetic to everyday card surfaces.
/// Adds a Fresnel-like rim highlight via animated stroke border.
struct MetalLiquidGlassSurfaceModifier: ViewModifier {
    let intensity: Float
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(intensity: Float = 0.6) {
        self.intensity = intensity
    }

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .overlay {
                    // Fresnel-like rim highlight
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(Double(intensity) * 0.15 * (0.8 + phase * 0.2)),
                                    Color.white.opacity(Double(intensity) * 0.05),
                                    Color.white.opacity(Double(intensity) * 0.1 * (0.9 + (1 - phase) * 0.1))
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .allowsHitTesting(false)
                }
                .task {
                    while !Task.isCancelled {
                        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                            phase = 1.0
                        }
                        try? await Task.sleep(for: .seconds(8.0))
                    }
                }
        }
    }
}

// MARK: - Predictive Surface (Apple Intelligence Adaptive Card)

/// Adaptive glow and border for the Predictive Surface card.
/// Responds to the Foundation Models engine's confidence level.
struct MetalPredictiveSurfaceModifier: ViewModifier {
    let confidence: Float
    let glowColor: Color
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(confidence: Float, glowColor: Color = FLColors.aiGlow) {
        self.confidence = confidence
        self.glowColor = glowColor
    }

    func body(content: Content) -> some View {
        if reduceMotion || confidence < 0.01 {
            content
        } else {
            content
                .shadow(
                    color: glowColor.opacity(Double(confidence) * 0.35 * (0.7 + phase * 0.3)),
                    radius: CGFloat(confidence) * 15 * (0.8 + phase * 0.2)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            glowColor.opacity(Double(confidence) * 0.2 * (0.6 + phase * 0.4)),
                            lineWidth: 1.5
                        )
                        .allowsHitTesting(false)
                }
                .task {
                    while !Task.isCancelled {
                        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                            phase = 1.0
                        }
                        try? await Task.sleep(for: .seconds(5.0))
                    }
                }
        }
    }
}

// MARK: - Liquid Glass Refraction Ripple

/// Refraction ripple for button and list presses.
/// Uses SwiftUI scale + overlay animation on press to simulate
/// the expanding wavefront from the touch point.
struct MetalLiquidGlassRippleModifier: ViewModifier {
    @Binding var isPressed: Bool
    let density: FLMaterialDensity
    let touchCenter: CGPoint

    @State private var rippleScale: CGFloat = 0.0
    @State private var rippleOpacity: CGFloat = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        isPressed: Binding<Bool>,
        density: FLMaterialDensity = .med,
        touchCenter: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) {
        self._isPressed = isPressed
        self.density = density
        self.touchCenter = touchCenter
    }

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .overlay {
                    Circle()
                        .fill(Color.white.opacity(rippleOpacity * 0.12))
                        .scaleEffect(rippleScale)
                        .position(x: touchCenter.x, y: touchCenter.y)
                        .allowsHitTesting(false)
                }
                .clipped()
                .onChange(of: isPressed) { _, pressed in
                    if pressed {
                        rippleScale = 0.0
                        rippleOpacity = 1.0
                        withAnimation(.easeOut(duration: 0.45)) {
                            rippleScale = 3.0
                            rippleOpacity = 0.0
                        }
                    }
                }
        }
    }
}


// MARK: - Convenience View Extensions

extension View {
    /// Shimmer sweep — premium loading placeholder effect
    func metalShimmer(duration: Double = 1.4, pause: Double = 0.6) -> some View {
        modifier(MetalShimmerModifier(duration: duration, pauseDuration: pause))
    }

    /// Card glass — subtle caustic light play on card surfaces
    func metalCardGlass(intensity: Float = 0.5) -> some View {
        modifier(MetalCardGlassModifier(intensity: intensity))
    }

    /// Impact shimmer — diagonal sweep for stat cards
    func metalImpactShimmer() -> some View {
        modifier(MetalImpactShimmerModifier())
    }

    /// Expiry pulse — breathing glow for expiry badges
    func metalExpiryPulse(color: Color) -> some View {
        modifier(MetalExpiryPulseModifier(pulseColor: color))
    }

    /// Celebration radiance — radial glow burst
    func metalCelebrationRadiance(color: Color, intensity: Float = 0.8) -> some View {
        modifier(MetalCelebrationRadianceModifier(glowColor: color, intensity: intensity))
    }

    /// Streak flame — warm flickering fire glow
    func metalStreakFlame(streakDays: Int) -> some View {
        modifier(MetalStreakFlameModifier(streakDays: streakDays))
    }

    /// Ambient particles — floating firefly spores (no-op in pure SwiftUI)
    func metalAmbientParticles(density: Float = 2.0, brightness: Float = 0.6) -> some View {
        modifier(MetalAmbientParticlesModifier(density: density, brightness: brightness))
    }

    /// Hero gradient — animated green palette for header
    func metalHeroGradient() -> some View {
        modifier(MetalHeroGradientModifier())
    }

    /// Impact plasma — animated background
    func metalImpactPlasma(intensity: Float = 0.5) -> some View {
        modifier(MetalImpactPlasmaModifier(intensityMix: intensity))
    }

    /// Subtle noise — film grain texture for depth (no-op in pure SwiftUI)
    func metalNoise(intensity: Float = 0.5) -> some View {
        modifier(MetalNoiseModifier(intensity: intensity))
    }

    /// Chef silhouette — luminous abstract chef for cooking mode (no-op in pure SwiftUI)
    func metalChefSilhouette(opacity: Float = 1.0) -> some View {
        modifier(MetalChefSilhouetteModifier(opacity: opacity))
    }

    /// Freshli aura — floating leaves & seeds for the hero header
    func metalFreshliAura() -> some View {
        modifier(MetalFreshliAuraModifier())
    }

    /// Intent glow — adaptive AI-driven ambient glow for predicted actions
    func metalIntentGlow(intensity: Float, color: Color = Color(red: 0.16, green: 0.77, blue: 0.42)) -> some View {
        modifier(MetalIntentGlowModifier(intensity: intensity, glowColor: color))
    }

    /// Liquid glass surface — Fresnel rim highlight for cards
    func metalLiquidGlassSurface(intensity: Float = 0.6) -> some View {
        modifier(MetalLiquidGlassSurfaceModifier(intensity: intensity))
    }

    /// Predictive surface — adaptive glow + border driven by AI confidence
    func metalPredictiveSurface(confidence: Float, color: Color = FLColors.aiGlow) -> some View {
        modifier(MetalPredictiveSurfaceModifier(confidence: confidence, glowColor: color))
    }

    /// Liquid glass ripple — refraction-like ripple on press.
    /// Density controls ripple amplitude via FLMaterialDensity.
    func metalLiquidGlassRipple(
        isPressed: Binding<Bool>,
        density: FLMaterialDensity = .med,
        touchCenter: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) -> some View {
        modifier(MetalLiquidGlassRippleModifier(
            isPressed: isPressed,
            density: density,
            touchCenter: touchCenter
        ))
    }
}
