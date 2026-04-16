import SwiftUI

enum FLMotion {
    // MARK: - Springs (Figma: Duolingo-style, converted from stiffness/damping/mass)

    static let springQuick = Animation.spring(response: 0.28, dampingFraction: 0.67)   // fast: stiffness 500, damping 30
    static let springDefault = Animation.spring(response: 0.36, dampingFraction: 0.72) // medium: stiffness 300, damping 25
    static let springGentle = Animation.spring(response: 0.44, dampingFraction: 0.71)  // slow: stiffness 200, damping 20
    static let springBouncy = Animation.spring(response: 0.31, dampingFraction: 0.375) // bouncy: stiffness 400, damping 15
    static let springSnappy = Animation.spring(response: 0.25, dampingFraction: 0.8)

    // MARK: - Unified Freshli Curve (Apple Design Award-level)
    /// Standardized spring for all major UI transitions — duration 0.6, bounce 0.3
    static let freshliCurve = Animation.spring(duration: 0.6, bounce: 0.3)

    /// Tab switching transition — slide + subtle scale, faster than freshliCurve
    static let tabTransition = Animation.spring(duration: 0.45, bounce: 0.2)

    // MARK: - Tab Slide & Scale Transition
    /// Jitter-free tab transition — subtle horizontal fade only.
    /// Scale was removed: combining .scale with complex child layouts
    /// triggers expensive re-layout passes that cause visible jitter,
    /// especially when celebration overlays are in the hierarchy.
    static func tabSlideTransition(direction: TabSlideDirection) -> AnyTransition {
        .asymmetric(
            insertion: .offset(x: direction == .forward ? 20 : -20).combined(with: .opacity),
            removal: .offset(x: direction == .forward ? -20 : 20).combined(with: .opacity)
        )
    }

    enum TabSlideDirection {
        case forward, backward
    }

    // MARK: - Accessibility Helpers

    /// Returns the animation or nil if reduce motion is preferred (for use with conditional animation).
    /// Use in views that check reduce motion to conditionally apply animations.
    static func flAdaptive(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }

    // MARK: - Eased

    static let easeDefault = Animation.easeInOut(duration: 0.25)
    static let easeSlow = Animation.easeInOut(duration: 0.4)
    static let easeQuick = Animation.easeOut(duration: 0.15)

    // MARK: - Stagger Delay

    static func staggerDelay(index: Int, base: Double = 0.05) -> Double {
        Double(index) * base
    }

    // MARK: - Transitions

    static var slideUp: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        )
    }

    static var scaleIn: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.8).combined(with: .opacity),
            removal: .scale(scale: 0.95).combined(with: .opacity)
        )
    }

    static var fadeSlide: AnyTransition {
        .asymmetric(
            insertion: .offset(y: 12).combined(with: .opacity),
            removal: .opacity
        )
    }
}

// MARK: - Button Styles (with Reduce Motion support)

/// Standard press style — 0.93× scale + Metal 4 liquid glass refraction ripple.
/// All 100+ button usages across the app inherit the ripple automatically.
/// Pass `density` to control refraction intensity per surface type.
struct PressableButtonStyle: ButtonStyle {
    var density: FLMaterialDensity = .med

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        PressableContent(
            configuration: configuration,
            density: density,
            reduceMotion: reduceMotion
        )
    }
}

/// Inner view holding @State for ripple progress binding.
private struct PressableContent: View {
    let configuration: ButtonStyleConfiguration
    let density: FLMaterialDensity
    let reduceMotion: Bool

    @State private var isPressed = false

    var body: some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.93 : 1.0)
            .animation(reduceMotion ? .none : FLMotion.springQuick, value: configuration.isPressed)
            .metalLiquidGlassRipple(isPressed: $isPressed, density: density)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    isPressed = true
                    FreshliHapticManager.shared.glassRipple(density: density)
                    MotionVocabularyService.shared.speakMotion(.glassRipple(density: density))
                } else {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(500))
                        isPressed = false
                    }
                }
            }
    }
}

/// Convenience alias — same as PressableButtonStyle with density param.
typealias LiquidGlassPressStyle = PressableButtonStyle

struct BounceButtonStyle: ButtonStyle {
    var density: FLMaterialDensity = .low

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        BounceContent(
            configuration: configuration,
            density: density,
            reduceMotion: reduceMotion
        )
    }
}

private struct BounceContent: View {
    let configuration: ButtonStyleConfiguration
    let density: FLMaterialDensity
    let reduceMotion: Bool

    @State private var isPressed = false

    var body: some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.93 : 1.0)
            .animation(reduceMotion ? .none : FLMotion.springBouncy, value: configuration.isPressed)
            .metalLiquidGlassRipple(isPressed: $isPressed, density: density)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    isPressed = true
                    FreshliHapticManager.shared.glassRipple(density: density)
                    MotionVocabularyService.shared.speakMotion(.glassRipple(density: density))
                } else {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(500))
                        isPressed = false
                    }
                }
            }
    }
}

// MARK: - Screen Transition (Figma: screenTransition — scale 0.98, y 15)

struct ScreenTransitionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared || reduceMotion ? 1 : 0.98)
            .offset(y: appeared || reduceMotion ? 0 : 15)
            .onAppear {
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(FLMotion.springDefault) {
                        appeared = true
                    }
                }
            }
    }
}

// MARK: - Staggered Appearance (Figma: cardEntrance — scale 0.95, y 20, delay index*0.05)

struct StaggeredAppearModifier: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared || reduceMotion ? 1 : 0.95)
            .offset(y: appeared || reduceMotion ? 0 : 20)
            .onAppear {
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(FLMotion.springDefault.delay(FLMotion.staggerDelay(index: index))) {
                        appeared = true
                    }
                }
            }
    }
}

struct CountUpModifier: AnimatableModifier {
    var value: Double
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }
    let format: String

    func body(content: Content) -> some View {
        Text(String(format: format, value))
    }
}

// MARK: - Swipe Action Transition

struct SwipeActionModifier: ViewModifier {
    let edge: HorizontalEdge

    func body(content: Content) -> some View {
        content
            .transition(
                .asymmetric(
                    insertion: .move(edge: edge == .leading ? .leading : .trailing).combined(with: .opacity),
                    removal: .move(edge: edge == .leading ? .leading : .trailing).combined(with: .opacity)
                )
            )
    }
}

// MARK: - Pull-to-Refresh Bounce

struct RefreshBounceModifier: ViewModifier {
    @Binding var isRefreshing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isRefreshing && !reduceMotion ? 0.98 : 1.0)
            .animation(reduceMotion ? .none : FLMotion.springBouncy, value: isRefreshing)
    }
}

// MARK: - Dashboard Card Entrance Animation (Staggered Cascade)

struct DashboardEntranceModifier: ViewModifier {
    let index: Int
    let totalCards: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared || reduceMotion ? 1 : 0.92)
            .offset(y: appeared || reduceMotion ? 0 : 30)
            .blur(radius: appeared || reduceMotion ? 0 : 2)
            .onAppear {
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(FLMotion.freshliCurve.delay(FLMotion.staggerDelay(index: index))) {
                        appeared = true
                    }
                }
            }
    }
}

// MARK: - GPU-Offloaded Cell Modifier (for complex list rows)

struct GPUOffloadedCellModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .drawingGroup(opaque: false, colorMode: .nonLinear)
    }
}

// MARK: - Sensory Feedback Tab Modifier (iOS 17+)

struct TabSensoryFeedbackModifier: ViewModifier {
    let trigger: AnyHashable

    func body(content: Content) -> some View {
        content
            .sensoryFeedback(.selection, trigger: trigger)
    }
}

extension View {
    func screenTransition() -> some View {
        modifier(ScreenTransitionModifier())
    }

    func staggeredAppearance(index: Int) -> some View {
        modifier(StaggeredAppearModifier(index: index))
    }

    /// Dashboard card entrance with 0.05s staggered delay — uses the Freshli Curve
    func dashboardEntrance(index: Int, totalCards: Int = 4) -> some View {
        modifier(DashboardEntranceModifier(index: index, totalCards: totalCards))
    }

    /// Offload complex cell rendering to the GPU to eliminate jitter in lists
    func gpuOffloaded() -> some View {
        modifier(GPUOffloadedCellModifier())
    }

    func pressable() -> some View {
        buttonStyle(PressableButtonStyle())
    }

    func bouncy() -> some View {
        buttonStyle(BounceButtonStyle())
    }

    /// Liquid Glass button press — Metal 4 refraction ripple + viscosity haptic.
    func liquidGlassPress(density: FLMaterialDensity = .med) -> some View {
        buttonStyle(LiquidGlassPressStyle(density: density))
    }

    func refreshBounce(isRefreshing: Binding<Bool>) -> some View {
        modifier(RefreshBounceModifier(isRefreshing: isRefreshing))
    }

    /// Adds sensory feedback (.selection) triggered by a value change
    func tabFeedback<V: Hashable>(trigger: V) -> some View {
        modifier(TabSensoryFeedbackModifier(trigger: AnyHashable(trigger)))
    }

    /// Subtle shimmer sweep for Impact cards — draws eye toward sustainability stats
    func impactShimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Shimmer Effect (Impact Cards — Metal GPU-powered)
// Upgraded from CPU LinearGradient overlay to Metal shader for
// smoother diagonal sweep with zero main-thread layout cost.

struct ShimmerModifier: ViewModifier {
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
                    // Initial delay so shimmer doesn't fire instantly on scroll
                    try? await Task.sleep(for: .seconds(1.0))
                    while !Task.isCancelled {
                        phase = -0.3
                        withAnimation(.easeInOut(duration: 2.0)) {
                            phase = 1.3
                        }
                        try? await Task.sleep(for: .seconds(3.5))
                    }
                }
        }
    }
}

// MARK: - SensoryFeedback Button Modifier (primary buttons)

struct PrimarySensoryFeedbackModifier: ViewModifier {
    let trigger: Bool

    func body(content: Content) -> some View {
        content
            .sensoryFeedback(.impact(weight: .light), trigger: trigger)
    }
}

struct SuccessSensoryFeedbackModifier: ViewModifier {
    let trigger: Bool

    func body(content: Content) -> some View {
        content
            .sensoryFeedback(.success, trigger: trigger)
    }
}

// MARK: - Metal Tab Melt Transition
// GPU-powered noise-dissolve for tab switches — content melts
// away with a luminous green edge glow instead of a flat slide.
// Falls back to simple opacity when Reduce Motion is enabled.

struct TabMeltModifier: ViewModifier, Animatable {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        // ────────────────────────────────────────────────────────────
        // CRITICAL: The view structure must be IDENTICAL on every
        // animation frame. The previous implementation had 4 branches
        // (identity / hidden / shader / opacity) gated by `progress`.
        // During the insertion transition (progress 1→0), SwiftUI
        // interpolates through all branches, causing the view tree to
        // mutate mid-animation. Each branch change destroys and
        // recreates the NavigationStack inside, producing a rendering
        // failure (the "error sign") on device.
        //
        // Fix: a single branch on `shadersAvailable` (constant for
        // the app lifetime). The Metal shader already handles the
        // extremes (progress < 0.001 → passthrough, > 0.999 → alpha 0).
        //
        // Do NOT use .drawingGroup() — NavigationStack is UIKit-backed
        // and cannot be rasterized into a Metal texture.
        // ────────────────────────────────────────────────────────────
        if ShaderWarmUpService.shadersAvailable {
            content
                .compositingGroup()
                .visualEffect { view, proxy in
                    view.colorEffect(
                        ShaderLibrary.tabMeltDissolve(
                            .float2(proxy.safeShaderSize),
                            .float(Float(progress))
                        )
                    )
                }
        } else {
            content
                .opacity(Double(1 - progress))
        }
    }
}

extension FLMotion {
    /// Metal-backed melt transition for tab switches.
    /// When reduceMotion is true, gracefully degrades to a simple fade.
    static func tabMeltTransition(reduceMotion: Bool) -> AnyTransition {
        // On Simulator, Metal shaders are unavailable and the custom
        // TabMeltModifier's Animatable interpolation can fail to complete,
        // leaving inserted views stuck at opacity 0. Use a plain .opacity
        // transition as the safe fallback for both reduceMotion AND Simulator.
        if reduceMotion || !ShaderWarmUpService.shadersAvailable {
            return .opacity
        }
        return .modifier(
            active: TabMeltModifier(progress: 1),
            identity: TabMeltModifier(progress: 0)
        )
    }
}

// MARK: - Backward Compatibility
typealias PSMotion = FLMotion
