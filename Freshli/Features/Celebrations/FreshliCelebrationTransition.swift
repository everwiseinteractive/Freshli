import SwiftUI

// MARK: - Freshli Celebration Transition
// matchedGeometryEffect transitions that expand from Claim/Consume buttons
// to full screen, respecting Dynamic Island safe area and device corners.

// MARK: - Namespace Keys

enum FreshliCelebrationNamespace {
    static let buttonToFullscreen = "freshliCelebration"
}

// MARK: - Source Button Anchor Modifier
// Apply this to Claim/Consume buttons to register them as animation origins

struct FreshliCelebrationSourceModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .matchedGeometryEffect(
                id: id,
                in: namespace,
                properties: .frame,
                isSource: !isActive
            )
    }
}

extension View {
    /// Mark a button as the origin for a celebration expand transition.
    /// - Parameters:
    ///   - id: Unique identifier for this source (e.g. item ID)
    ///   - namespace: Shared Namespace from the parent
    ///   - isActive: Whether the celebration is currently showing (flips source)
    func freshliCelebrationSource(
        id: String,
        namespace: Namespace.ID,
        isActive: Bool
    ) -> some View {
        modifier(FreshliCelebrationSourceModifier(
            id: id,
            namespace: namespace,
            isActive: isActive
        ))
    }
}

// MARK: - Full-Screen Destination Container
// Expands from the matched button to fill the screen with device-aware corners

struct FreshliExpandingCelebrationContainer<Content: View>: View {
    let sourceID: String
    let namespace: Namespace.ID
    let backgroundColor: Color
    let isPresented: Bool
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if isPresented {
            ZStack {
                // Background that expands from button
                RoundedRectangle(cornerRadius: deviceCornerRadius, style: .continuous)
                    .fill(backgroundColor)
                    .matchedGeometryEffect(
                        id: sourceID,
                        in: namespace,
                        properties: .frame,
                        isSource: true
                    )
                    .ignoresSafeArea()

                // Content layered on top
                content()
                    .transition(.opacity.animation(
                        reduceMotion ? .none : .easeIn(duration: 0.2).delay(0.15)
                    ))
            }
            .transition(
                reduceMotion
                    ? .opacity
                    : .asymmetric(
                        insertion: .scale(scale: 0.3).combined(with: .opacity),
                        removal: .scale(scale: 1.05).combined(with: .opacity)
                    )
            )
            // Respect Dynamic Island and safe areas
            .ignoresSafeArea(.container)
            .statusBarHidden(true)
        }
    }

    /// Device corner radius — matches physical display corners
    private var deviceCornerRadius: CGFloat {
        // iOS 18+ UIScreen corner radius via displayCornerRadius
        // Falls back to 44pt (iPhone 15/16 family standard)
        let screen = UIScreen.main
        let key = "_displayCornerRadius"
        if let radius = screen.value(forKey: key) as? CGFloat, radius > 0 {
            return radius
        }
        return 44
    }
}

// MARK: - Celebration Expand Transition Modifier
// Convenience modifier that wraps the full expand-from-button flow

struct FreshliCelebrationExpandModifier: ViewModifier {
    let isPresented: Bool
    let sourceID: String
    let namespace: Namespace.ID
    let backgroundColor: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    // Dimming backdrop
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .animation(
                reduceMotion ? .none : PSMotion.springBouncy,
                value: isPresented
            )
    }
}

extension View {
    /// Adds a dimming backdrop when a celebration is expanding from a button.
    func freshliCelebrationBackdrop(
        isPresented: Bool,
        sourceID: String,
        namespace: Namespace.ID,
        backgroundColor: Color
    ) -> some View {
        modifier(FreshliCelebrationExpandModifier(
            isPresented: isPresented,
            sourceID: sourceID,
            namespace: namespace,
            backgroundColor: backgroundColor
        ))
    }
}

// MARK: - Dynamic Island Safe Area Helper

struct DynamicIslandAwarePadding: ViewModifier {
    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: 0)
            }
    }
}

extension View {
    /// Ensures content respects Dynamic Island notch area
    func dynamicIslandAware() -> some View {
        modifier(DynamicIslandAwarePadding())
    }
}
