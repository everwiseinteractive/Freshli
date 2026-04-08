import SwiftUI

enum PSMotion {
    // MARK: - Springs (Figma: Duolingo-style, converted from stiffness/damping/mass)

    static let springQuick = Animation.spring(response: 0.28, dampingFraction: 0.67)   // fast: stiffness 500, damping 30
    static let springDefault = Animation.spring(response: 0.36, dampingFraction: 0.72) // medium: stiffness 300, damping 25
    static let springGentle = Animation.spring(response: 0.44, dampingFraction: 0.71)  // slow: stiffness 200, damping 20
    static let springBouncy = Animation.spring(response: 0.31, dampingFraction: 0.375) // bouncy: stiffness 400, damping 15
    static let springSnappy = Animation.spring(response: 0.25, dampingFraction: 0.8)

    // MARK: - Accessibility Helpers

    /// Returns the animation or nil if reduce motion is preferred (for use with conditional animation).
    /// Use in views that check reduce motion to conditionally apply animations.
    static func psAdaptive(_ animation: Animation, reduceMotion: Bool) -> Animation? {
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
            .animation(reduceMotion ? .none : PSMotion.springQuick, value: configuration.isPressed)
    }
}

struct BounceButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.93 : 1.0)
            .animation(reduceMotion ? .none : PSMotion.springBouncy, value: configuration.isPressed)
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
                    withAnimation(PSMotion.springDefault) {
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
                    withAnimation(PSMotion.springDefault.delay(PSMotion.staggerDelay(index: index))) {
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
            .animation(reduceMotion ? .none : PSMotion.springBouncy, value: isRefreshing)
    }
}

extension View {
    func screenTransition() -> some View {
        modifier(ScreenTransitionModifier())
    }

    func staggeredAppearance(index: Int) -> some View {
        modifier(StaggeredAppearModifier(index: index))
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
}
