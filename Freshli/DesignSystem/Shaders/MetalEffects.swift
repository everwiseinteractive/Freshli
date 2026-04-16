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
// Freshli — Metal Effect View Modifiers (MSL 3.2+)
// SwiftUI wrappers around the GPU shaders in FreshliShaders.metal.
// Each modifier respects accessibilityReduceMotion and falls back
// gracefully on unsupported hardware.
//
// IMPORTANT: All shaders that normalise coordinates via `position / size`
// MUST receive the actual view size via `.visualEffect { view, proxy in … }`.
// Passing `.float2(0, 0)` causes division-by-zero → black output.
//
// Performance: Heavy continuous-animation modifiers apply .drawingGroup()
// to flatten the view into a single Metal render pass before the shader
// runs — this eliminates SwiftUI overdraw and enables 120Hz ProMotion.
// ──────────────────────────────────────────────────────────

// MARK: - GPU Shimmer Effect

/// Metal-powered shimmer sweep — replaces CPU LinearGradient shimmer
/// with a smooth GPU diagonal light band. Used by PSShimmerView and
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
        if reduceMotion || !ShaderWarmUpService.shadersAvailable {
            content
        } else {
            let capturedPhase = phase
            content
                .visualEffect { view, proxy in
                    view.colorEffect(
                        ShaderLibrary.gpuShimmer(
                            .float2(proxy.safeShaderSize),
                            .float(Float(capturedPhase))
                        )
                    )
                }
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

/// Adds a subtle caustic light play to card surfaces, giving them
/// a premium frosted-glass feel. Very subtle — designed to be
/// noticed subconsciously rather than consciously.
struct MetalCardGlassModifier: ViewModifier {
    @State private var startDate = Date.now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let intensity: Float

    init(intensity: Float = 0.5) {
        self.intensity = intensity
    }

    func body(content: Content) -> some View {
        if reduceMotion || !ShaderWarmUpService.shadersAvailable {
            content
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                let time = Float(timeline.date.timeIntervalSince(startDate))
                content
                    // Do NOT use .drawingGroup() here — callers like
                    // .glassCardStyle() apply .glassEffect() before this
                    // modifier. .drawingGroup() would try to flatten the
                    // compositor-level glass into a Metal texture, which
                    // fails and produces a blank/broken view on device.
                    .visualEffect { view, proxy in
                        view.colorEffect(
                            ShaderLibrary.cardGlass(
                                .float2(proxy.safeShaderSize),
                                .float(time),
                                .float(intensity)
                            )
                        )
                    }
            }
        }
    }
}

// MARK: - Impact Shimmer (Metal Upgrade)

/// Drop-in replacement for the existing SwiftUI-based ShimmerModifier
/// used on Impact cards. GPU-accelerated diagonal light sweep.
struct MetalImpactShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -0.3
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion || !ShaderWarmUpService.shadersAvailable {
            content
        } else {
            let capturedPhase = phase
            content
                .visualEffect { view, proxy in
                    view.colorEffect(
                        ShaderLibrary.gpuShimmer(
                            .float2(proxy.safeShaderSize),
                            .float(Float(capturedPhase))
                        )
                    )
                }
                .task {
                    while !Task.isCancelled {
                        phase = -0.3
                        withAnimation(.easeInOut(duration: 1.6)) {
                            phase = 1.3
                        }
                        try? await Task.sleep(for: .seconds(4.0))
                    }
                }
        }
    }
}

// MARK: - Expiry Pulse Effect

/// Soft breathing glow on expiry badges — amber for "expiring soon",
/// red for "expired". Draws attention without being alarming.
struct MetalExpiryPulseModifier: ViewModifier {
    let pulseColor: Color
    @State private var startDate = Date.now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion || !ShaderWarmUpService.shadersAvailable {
            content
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                let time = Float(timeline.date.timeIntervalSince(startDate))
                let resolved = resolveColor(pulseColor)
                content
                    .visualEffect { view, proxy in
                        view.colorEffect(
                            ShaderLibrary.expiryPulse(
                                .float2(proxy.safeShaderSize),
                                .float(time),
                                .float(resolved.r),
                                .float(resolved.g),
                                .float(resolved.b)
                            )
                        )
                    }
            }
        }
    }
}

// MARK: - Celebration Radiance

/// Radial glow burst for celebration overlays — color-shifting
/// expanding rings that pulse from the center.
struct MetalCelebrationRadianceModifier: ViewModifier {
    let glowColor: Color
    let intensity: Float
    @State private var startDate = Date.now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.shaderQuality) private var quality

    init(glowColor: Color, intensity: Float = 0.8) {
        self.glowColor = glowColor
        self.intensity = intensity
    }

    func body(content: Content) -> some View {
        if reduceMotion || !ShaderWarmUpService.shadersAvailable || !quality.enableComplexShaders {
            content
        } else {
            TimelineView(.animation(minimumInterval: max(quality.frameInterval, 1.0 / 60.0), paused: false)) { timeline in
                let time = Float(timeline.date.timeIntervalSince(startDate))
                let resolved = resolveColor(glowColor)
                content
                    .visualEffect { view, proxy in
                        view.colorEffect(
                            ShaderLibrary.celebrationRadiance(
                                .float2(proxy.safeShaderSize),
                                .float(time),
                                .float(intensity),
                                .float(resolved.r),
                                .float(resolved.g),
                                .float(resolved.b)
                            )
                        )
                    }
                    .drawingGroup()
            }
        }
    }
}

// MARK: - Streak Flame Glow

/// Warm flickering fire glow behind the streak flame icon.
/// Intensity scales with streak length (1–7+ days).
struct MetalStreakFlameModifier: ViewModifier {
    let streakDays: Int
    @State private var startDate = Date.now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion || !ShaderWarmUpService.shadersAvailable || streakDays <= 0 {
            content
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                let time = Float(timeline.date.timeIntervalSince(startDate))
                content
                    .visualEffect { view, proxy in
                        view.colorEffect(
                            ShaderLibrary.streakFlameGlow(
                                .float2(proxy.safeShaderSize),
                                .float(time),
                                .float(Float(streakDays))
                            )
                        )
                    }
                    .drawingGroup()
            }
        }
    }
}

// MARK: - Ambient Particles

/// GPU-computed floating particle field for backgrounds.
/// Firefly-like spores drift upward for organic depth.
/// Respects ShaderQualityTier — disabled below .high, density scaled.
struct MetalAmbientParticlesModifier: ViewModifier {
    let density: Float
    let brightness: Float
    @State private var startDate = Date.now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.shaderQuality) private var quality
    @Environment(\.shaderVisible) private var isVisible

    init(density: Float = 2.0, brightness: Float = 0.6) {
        self.density = density
        self.brightness = brightness
    }

    func body(content: Content) -> some View {
        if reduceMotion || !ShaderWarmUpService.shadersAvailable || !quality.enableParticles {
            content
        } else {
            let capturedDensity = density * quality.particleDensity
            TimelineView(.animation(minimumInterval: quality.frameInterval, paused: !isVisible)) { timeline in
                let time = Float(timeline.date.timeIntervalSince(startDate))
                content
                    .visualEffect { view, proxy in
                        view.colorEffect(
                            ShaderLibrary.ambientParticles(
                                .float2(proxy.safeShaderSize),
                                .float(time),
                                .float(capturedDensity),
                                .float(brightness)
                            )
                        )
                    }
            }
        }
    }
}

// MARK: - Button Ripple

/// Metal-powered press ripple effect for PSButton.
/// Expanding concentric highlight ring on tap.
struct MetalButtonRippleModifier: ViewModifier {
    @Binding var isPressed: Bool
    @State private var rippleProgress: CGFloat = 0

    func body(content: Content) -> some View {
        if ShaderWarmUpService.shadersAvailable {
            let capturedRippleProgress = rippleProgress
            content
                .visualEffect { view, proxy in
                    view.colorEffect(
                        ShaderLibrary.buttonRipple(
                            .float2(proxy.safeShaderSize),
                            .float(Float(capturedRippleProgress))
                        )
                    )
                }
                .onChange(of: isPressed) { _, pressed in
                    if pressed {
                        rippleProgress = 0
                        withAnimation(.easeOut(duration: 0.5)) {
                            rippleProgress = 1.0
                        }
                    }
                }
        } else {
            content
        }
    }
}

// MARK: - Subtle Film Grain

/// Adds film-grain texture for tactile depth on dark surfaces.
struct MetalNoiseModifier: ViewModifier {
    let intensity: Float
    @State private var startDate = Date.now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(intensity: Float = 0.5) {
        self.intensity = intensity
    }

    func body(content: Content) -> some View {
        if reduceMotion || !ShaderWarmUpService.shadersAvailable {
            content
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: false)) { timeline in
                let time = Float(timeline.date.timeIntervalSince(startDate))
                content
                    .visualEffect { view, proxy in
                        view.colorEffect(
                            ShaderLibrary.subtleNoise(
                                .float2(proxy.safeShaderSize),
                                .float(time),
                                .float(intensity)
                            )
                        )
                    }
            }
        }
    }
}

// MARK: - Hero Gradient (Animated Metal)

/// Metal-powered animated gradient for the HomeView hero header.
/// Organic wave-based color shifting through the Freshli green palette.
struct MetalHeroGradientModifier: ViewModifier {
    @State private var startDate = Date.now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion || !ShaderWarmUpService.shadersAvailable {
            content
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                let time = Float(timeline.date.timeIntervalSince(startDate))
                content
                    .visualEffect { view, proxy in
                        view.colorEffect(
                            ShaderLibrary.heroGradient(
                                .float2(proxy.safeShaderSize),
                                .float(time)
                            )
                        )
                    }
            }
        }
    }
}

// MARK: - Impact Plasma Background

/// Metal plasma background for Impact Dashboard.
/// Replaces MeshGradient with GPU-computed organic color movement.
struct MetalImpactPlasmaModifier: ViewModifier {
    let intensityMix: Float
    @State private var startDate = Date.now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(intensityMix: Float = 0.5) {
        self.intensityMix = intensityMix
    }

    func body(content: Content) -> some View {
        if reduceMotion || !ShaderWarmUpService.shadersAvailable {
            content
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                let time = Float(timeline.date.timeIntervalSince(startDate))
                content
                    .visualEffect { view, proxy in
                        view.colorEffect(
                            ShaderLibrary.impactPlasma(
                                .float2(proxy.safeShaderSize),
                                .float(time),
                                .float(intensityMix)
                            )
                        )
                    }
            }
        }
    }
}

// MARK: - Chef Silhouette (Cooking Mode Background)

/// Animated luminous chef figure for the CookingScreenView.
/// Five-phase 14-second cycle: appear → stir → steam → sparkle → breathe.
/// The silhouette is intentionally abstract — soft gaussian shapes that
/// suggest a chef rather than depicting one literally.
struct MetalChefSilhouetteModifier: ViewModifier {
    let opacity: Float
    @State private var startDate = Date.now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(opacity: Float = 1.0) {
        self.opacity = opacity
    }

    func body(content: Content) -> some View {
        if reduceMotion || !ShaderWarmUpService.shadersAvailable {
            content
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                let time = Float(timeline.date.timeIntervalSince(startDate))
                content
                    .visualEffect { view, proxy in
                        view.colorEffect(
                            ShaderLibrary.chefSilhouette(
                                .float2(proxy.safeShaderSize),
                                .float(time),
                                .float(opacity)
                            )
                        )
                    }
            }
        }
    }
}

// MARK: - Freshli Aura (Home Header Emitter)

/// Themed particle emitter that replaces generic ambient particles.
/// Floating leaf shapes and seed/droplet particles create a living,
/// breathing Freshli-branded header experience.
struct MetalFreshliAuraModifier: ViewModifier {
    @State private var startDate = Date.now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion || !ShaderWarmUpService.shadersAvailable {
            content
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                let time = Float(timeline.date.timeIntervalSince(startDate))
                content
                    .visualEffect { view, proxy in
                        view.colorEffect(
                            ShaderLibrary.freshliAura(
                                .float2(proxy.safeShaderSize),
                                .float(time)
                            )
                        )
                    }
            }
        }
    }
}

// MARK: - Intent Glow (Apple Intelligence Adaptive Surface)

/// Ambient glow applied to UI elements predicted as the user's next
/// interaction target. The intensity ramps from 0→1 as the AI model's
/// confidence increases, creating a "living" surface that guides
/// the user's attention without explicit prompts.
struct MetalIntentGlowModifier: ViewModifier {
    let intensity: Float
    let glowColor: Color
    @State private var startDate = Date.now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(intensity: Float, glowColor: Color = Color(red: 0.16, green: 0.77, blue: 0.42)) {
        self.intensity = intensity
        self.glowColor = glowColor
    }

    func body(content: Content) -> some View {
        if reduceMotion || !ShaderWarmUpService.shadersAvailable || intensity < 0.01 {
            content
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                let time = Float(timeline.date.timeIntervalSince(startDate))
                let resolved = resolveColor(glowColor)
                content
                    .visualEffect { view, proxy in
                        view.colorEffect(
                            ShaderLibrary.intentGlow(
                                .float2(proxy.safeShaderSize),
                                .float(time),
                                .float(intensity),
                                .float(resolved.r),
                                .float(resolved.g),
                                .float(resolved.b)
                            )
                        )
                    }
            }
        }
    }
}


// MARK: - Liquid Glass Surface

/// Brings the Liquid Glass aesthetic from the splash screen to
/// everyday card surfaces. Adds Fresnel rim, moving caustics,
/// directional specular, and chromatic edge shifts — all in a
/// single GPU pass via .colorEffect.
struct MetalLiquidGlassSurfaceModifier: ViewModifier {
    let intensity: Float
    @State private var startDate = Date.now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(intensity: Float = 0.6) {
        self.intensity = intensity
    }

    func body(content: Content) -> some View {
        if reduceMotion || !ShaderWarmUpService.shadersAvailable {
            content
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                let time = Float(timeline.date.timeIntervalSince(startDate))
                content
                    .visualEffect { view, proxy in
                        view.colorEffect(
                            ShaderLibrary.liquidGlassSurface(
                                .float2(proxy.safeShaderSize),
                                .float(time),
                                .float(intensity)
                            )
                        )
                    }
            }
        }
    }
}


// MARK: - Predictive Surface (Apple Intelligence Adaptive Card)

/// Metal-powered adaptive glow and geometry morphing for the Predictive
/// Surface card. The shader responds to the Foundation Models engine's
/// confidence level — at low confidence the card barely glimmers; as
/// confidence rises, edge morphing intensifies, orbiting filaments
/// brighten, and the radial aura deepens.
struct MetalPredictiveSurfaceModifier: ViewModifier {
    let confidence: Float
    let glowColor: Color
    @State private var startDate = Date.now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.shaderQuality) private var quality
    @Environment(\.shaderVisible) private var isVisible

    init(confidence: Float, glowColor: Color = FLColors.aiGlow) {
        self.confidence = confidence
        self.glowColor = glowColor
    }

    func body(content: Content) -> some View {
        if reduceMotion || confidence < 0.01 || !quality.enableComplexShaders {
            content
        } else {
            TimelineView(.animation(minimumInterval: quality.frameInterval, paused: !isVisible)) { timeline in
                let time = Float(timeline.date.timeIntervalSince(startDate))
                let resolved = resolveColor(glowColor)
                content
                    .visualEffect { view, proxy in
                        view.colorEffect(
                            ShaderLibrary.predictiveSurface(
                                .float2(proxy.safeShaderSize),
                                .float(time),
                                .float(confidence),
                                .float(resolved.r),
                                .float(resolved.g),
                                .float(resolved.b)
                            )
                        )
                    }
            }
        }
    }
}

// MARK: - Liquid Glass Refraction Ripple (Distortion + Color)

/// Metal-powered refraction ripple for button and list presses.
/// Uses `.distortionEffect` to physically displace pixels behind a
/// glass surface, creating a real refraction wavefront that expands
/// from the touch point. A companion `.colorEffect` adds the specular
/// highlight ring and Fresnel rim.
///
/// Density-driven: the distortion amplitude scales with
/// `FLMaterialDensity.refractiveIndex` — low (air) barely ripples,
/// high (glass) produces thick, viscous distortion.
struct MetalLiquidGlassRippleModifier: ViewModifier {
    @Binding var isPressed: Bool
    let density: FLMaterialDensity
    let touchCenter: CGPoint  // Normalized 0→1

    @State private var rippleProgress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var schemeContrast
    @Environment(\.shaderQuality) private var quality

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
        if reduceMotion || !ShaderWarmUpService.shadersAvailable || schemeContrast == .increased || !quality.enableDistortion {
            // Increased Contrast disables translucent glass distortion
            // to preserve text legibility (WCAG AAA).
            content
        } else {
            let capturedRippleProgress = rippleProgress
            let capturedTouchCenter = touchCenter
            let capturedRefractiveIndex = density.refractiveIndex
            content
                // Pass 1: Distortion — pixel displacement for refraction
                .visualEffect { view, proxy in
                    view.distortionEffect(
                        ShaderLibrary.liquidGlassRipple(
                            .float2(proxy.safeShaderSize),
                            .float(Float(capturedRippleProgress)),
                            .float(capturedRefractiveIndex),
                            .float(Float(capturedTouchCenter.x)),
                            .float(Float(capturedTouchCenter.y))
                        ),
                        maxSampleOffset: CGSize(
                            width: CGFloat(capturedRefractiveIndex) * 12,
                            height: CGFloat(capturedRefractiveIndex) * 12
                        )
                    )
                }
                // Pass 2: Color — specular highlight ring + Fresnel rim
                .visualEffect { view, proxy in
                    view.colorEffect(
                        ShaderLibrary.liquidGlassRippleColor(
                            .float2(proxy.safeShaderSize),
                            .float(Float(capturedRippleProgress)),
                            .float(capturedRefractiveIndex),
                            .float(Float(capturedTouchCenter.x)),
                            .float(Float(capturedTouchCenter.y))
                        )
                    )
                }
                .onChange(of: isPressed) { _, pressed in
                    if pressed {
                        rippleProgress = 0
                        withAnimation(.easeOut(duration: 0.45)) {
                            rippleProgress = 1.0
                        }
                    }
                }
        }
    }
}


// MARK: - Convenience View Extensions

extension View {
    /// Metal GPU shimmer sweep — premium loading placeholder effect
    func metalShimmer(duration: Double = 1.4, pause: Double = 0.6) -> some View {
        modifier(MetalShimmerModifier(duration: duration, pauseDuration: pause))
    }

    /// Metal card glass — subtle caustic light play on card surfaces
    func metalCardGlass(intensity: Float = 0.5) -> some View {
        modifier(MetalCardGlassModifier(intensity: intensity))
    }

    /// Metal impact shimmer — GPU diagonal sweep for stat cards
    func metalImpactShimmer() -> some View {
        modifier(MetalImpactShimmerModifier())
    }

    /// Metal expiry pulse — breathing glow for expiry badges
    func metalExpiryPulse(color: Color) -> some View {
        modifier(MetalExpiryPulseModifier(pulseColor: color))
    }

    /// Metal celebration radiance — radial glow burst
    func metalCelebrationRadiance(color: Color, intensity: Float = 0.8) -> some View {
        modifier(MetalCelebrationRadianceModifier(glowColor: color, intensity: intensity))
    }

    /// Metal streak flame — warm flickering fire glow
    func metalStreakFlame(streakDays: Int) -> some View {
        modifier(MetalStreakFlameModifier(streakDays: streakDays))
    }

    /// Metal ambient particles — floating firefly spores
    func metalAmbientParticles(density: Float = 2.0, brightness: Float = 0.6) -> some View {
        modifier(MetalAmbientParticlesModifier(density: density, brightness: brightness))
    }

    /// Metal hero gradient — animated green palette for header
    func metalHeroGradient() -> some View {
        modifier(MetalHeroGradientModifier())
    }

    /// Metal impact plasma — animated background
    func metalImpactPlasma(intensity: Float = 0.5) -> some View {
        modifier(MetalImpactPlasmaModifier(intensityMix: intensity))
    }

    /// Metal subtle noise — film grain texture for depth
    func metalNoise(intensity: Float = 0.5) -> some View {
        modifier(MetalNoiseModifier(intensity: intensity))
    }

    /// Metal chef silhouette — luminous abstract chef for cooking mode
    func metalChefSilhouette(opacity: Float = 1.0) -> some View {
        modifier(MetalChefSilhouetteModifier(opacity: opacity))
    }

    /// Metal Freshli aura — floating leaves & seeds for the hero header
    func metalFreshliAura() -> some View {
        modifier(MetalFreshliAuraModifier())
    }

    /// Metal intent glow — adaptive AI-driven ambient glow for predicted actions
    func metalIntentGlow(intensity: Float, color: Color = Color(red: 0.16, green: 0.77, blue: 0.42)) -> some View {
        modifier(MetalIntentGlowModifier(intensity: intensity, glowColor: color))
    }

    /// Metal liquid glass surface — Fresnel rim, caustics, specular for cards
    func metalLiquidGlassSurface(intensity: Float = 0.6) -> some View {
        modifier(MetalLiquidGlassSurfaceModifier(intensity: intensity))
    }

    /// Metal predictive surface — adaptive glow + geometry morphing driven by AI confidence
    func metalPredictiveSurface(confidence: Float, color: Color = FLColors.aiGlow) -> some View {
        modifier(MetalPredictiveSurfaceModifier(confidence: confidence, glowColor: color))
    }

    /// Metal liquid glass ripple — distortion-based refraction on press.
    /// Density controls distortion amplitude via FLMaterialDensity.refractiveIndex.
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

// MARK: - Color Resolution Helper

/// Resolves a SwiftUI Color to RGB floats for Metal shader uniforms.
/// Uses UIColor conversion for reliable color space handling.
private func resolveColor(_ color: Color) -> (r: Float, g: Float, b: Float) {
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
    return (Float(r), Float(g), Float(b))
}
