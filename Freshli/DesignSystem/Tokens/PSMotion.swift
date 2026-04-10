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
    /// Custom asymmetric transition for tab switching that feels organic
    static func tabSlideTransition(direction: TabSlideDirection) -> AnyTransition {
        .asymmetric(
            insertion: .offset(x: direction == .forward ? 40 : -40)
                .combined(with: .scale(scale: 0.94))
                .combined(with: .opacity),
            removal: .offset(x: direction == .forward ? -40 : 40)
                .combined(with: .scale(scale: 0.94))
                .combined(with: .opacity)
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

struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.93 : 1.0)
            .animation(reduceMotion ? .none : FLMotion.springQuick, value: configuration.isPressed)
    }
}

struct BounceButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.93 : 1.0)
            .animation(reduceMotion ? .none : FLMotion.springBouncy, value: configuration.isPressed)
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

    func refreshBounce(isRefreshing: Binding<Bool>) -> some View {
        modifier(RefreshBounceModifier(isRefreshing: isRefreshing))
    }

    /// Adds sensory feedback (.selection) triggered by a value change
    func tabFeedback<V: Hashable>(trigger: V) -> some View {
        modifier(TabSensoryFeedbackModifier(trigger: AnyHashable(trigger)))
    }
}

// MARK: - Backward Compatibility
typealias PSMotion = FLMotion
