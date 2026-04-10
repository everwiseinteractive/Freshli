//
//  FLMotionModifiers.swift
//  Freshli
//
//  Central catalogue of reusable motion modifiers that give Freshli its
//  Duolingo-style delight + Apple-polish feel. EXTENDS the existing FLMotion
//  tokens in PSMotion.swift — do not duplicate spring/duration constants here.
//
//  All modifiers:
//    • Read @Environment(\.accessibilityReduceMotion) and provide graceful
//      fallbacks (typically: skip decorative motion, keep fades short).
//    • Respect @MainActor and Sendable (Swift 6.3 strict concurrency).
//    • Derive every spring, delay, and offset from the FLMotion token layer so
//      the whole app speaks one motion language.
//
//  NOTE ON FIGMA TOKENS: When this file was written there was no specific
//  Figma frame URL mounted via MCP. All values here are grounded in the
//  existing FLMotion tokens (already sourced from Figma in PSMotion.swift),
//  Apple HIG guidance, and Duolingo-style motion defaults. If / when a Figma
//  motion-tokens frame is wired up, the constants below should be swapped to
//  token lookups without touching the modifier call sites.
//

import SwiftUI

// MARK: - Motion Presets (semantic, not raw)
//
// These are *presets* that compose on top of the raw FLMotion springs.
// Call sites should prefer these semantic names so intent stays legible.

extension FLMotion {

    // MARK: Motion Presets — Semantic

    /// Button press / release spring. Snappy, no overshoot.
    static let buttonPress: Animation = .spring(response: 0.26, dampingFraction: 0.72)

    /// Card entrance — bouncy but controlled, good for stacked cards.
    static let cardEntrance: Animation = .spring(response: 0.42, dampingFraction: 0.78)

    /// Stat count-up / progress reveal — smooth, not springy.
    static let statReveal: Animation = .easeOut(duration: 0.9)

    /// Celebration pop — punchy overshoot that feels rewarding.
    static let celebrationPop: Animation = .spring(response: 0.38, dampingFraction: 0.55)

    /// Sheet / full screen cover presentation.
    static let sheetPresent: Animation = .spring(response: 0.45, dampingFraction: 0.82)

    /// Sheet dismissal — slightly faster than present.
    static let sheetDismiss: Animation = .spring(response: 0.36, dampingFraction: 0.88)

    /// Navigation push / pop hierarchy motion.
    static let navigation: Animation = .spring(response: 0.38, dampingFraction: 0.86)

    /// Error shake — fast, tight, non-springy so it reads as "wrong".
    static let errorShake: Animation = .easeInOut(duration: 0.08)

    /// Success flash — celebratory but brief.
    static let successFlash: Animation = .spring(response: 0.32, dampingFraction: 0.6)

    /// Matched-hero geometry transition.
    static let heroMatch: Animation = .spring(response: 0.48, dampingFraction: 0.82)

    // MARK: - Stagger Helpers

    /// Grid / row stagger delay with an upper cap so late items don't feel
    /// stuck. `cap` mirrors the "no longer than N * base" Duolingo rule.
    static func cappedStaggerDelay(index: Int, base: Double = 0.05, cap: Int = 8) -> Double {
        Double(min(index, cap)) * base
    }

    // MARK: - Adaptive Animation

    /// Returns the supplied animation, or a short fade, or nil (no animation)
    /// depending on Reduce Motion preference. Prefer this in ad-hoc
    /// `withAnimation` call sites so every surface respects the setting.
    static func adaptive(
        _ animation: Animation,
        reduceMotion: Bool,
        reducedFallback: Animation? = .easeInOut(duration: 0.2)
    ) -> Animation? {
        reduceMotion ? reducedFallback : animation
    }
}

// MARK: - BounceButtonModifier
//
// View-modifier variant of the existing `BounceButtonStyle`, usable on
// non-Button surfaces (cards, chips, row taps). Combines scale + optional
// subtle rotation on press, plus an optional haptic tick when pressed.

struct BounceButtonModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    var pressedScale: CGFloat = 0.94
    var haptic: Bool = true

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed && !reduceMotion ? pressedScale : 1.0)
            .animation(FLMotion.adaptive(FLMotion.buttonPress, reduceMotion: reduceMotion), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            if haptic { PSHaptics.shared.lightTap() }
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

// MARK: - CardEntranceModifier
//
// Replaces ad-hoc "opacity + offset + scale on appear" code across Features/.
// Use for cards inside lists, grids, and any hero surface that mounts.
// For the Dashboard cascade the more specialised `dashboardEntrance(index:)`
// modifier already exists — this is the general case.

struct CardEntranceModifier: ViewModifier {
    let index: Int
    var yOffset: CGFloat = 22
    var initialScale: CGFloat = 0.96

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared || reduceMotion ? 1 : initialScale)
            .offset(y: appeared || reduceMotion ? 0 : yOffset)
            .onAppear {
                guard !appeared else { return }
                if reduceMotion {
                    withAnimation(.easeOut(duration: 0.2)) { appeared = true }
                } else {
                    let delay = FLMotion.cappedStaggerDelay(index: index)
                    withAnimation(FLMotion.cardEntrance.delay(delay)) {
                        appeared = true
                    }
                }
            }
    }
}

// MARK: - StatRevealModifier
//
// Animates a numeric stat from 0 → `value` on appear. Use via
// `.statReveal(value: 84, format: "%.0f")` on a Text-driving view.
// Reduce Motion skips the count-up and snaps to the final value.

struct StatRevealModifier: ViewModifier {
    let value: Double
    var duration: Double = 0.9
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var current: Double = 0

    func body(content: Content) -> some View {
        content
            .modifier(CountUpModifier(value: current, format: "%.0f"))
            .onAppear {
                if reduceMotion {
                    current = value
                } else {
                    withAnimation(.easeOut(duration: duration)) {
                        current = value
                    }
                }
            }
            .onChange(of: value) { _, newValue in
                if reduceMotion {
                    current = newValue
                } else {
                    withAnimation(.easeOut(duration: duration)) {
                        current = newValue
                    }
                }
            }
    }
}

// MARK: - CelebrationPopModifier
//
// Quick scale-pop used to reward a success moment: saving an item, completing
// onboarding, finishing a streak day. Pairs with PSHaptics.celebrate().
// This is deliberately lighter than the full `FreshliCelebrationView` — use
// `CelebrationManager` for milestone-grade moments, and this modifier for
// "nice-little-win" feedback.

struct CelebrationPopModifier: ViewModifier {
    @Binding var trigger: Bool
    var haptic: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 1
    @State private var glow: Double = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(PSColors.primaryGreen.opacity(glow), lineWidth: 3)
                    .blur(radius: 6)
                    .allowsHitTesting(false)
            )
            .onChange(of: trigger) { _, newValue in
                guard newValue else { return }
                if haptic { PSHaptics.shared.celebrate() }
                if reduceMotion {
                    Task { @MainActor in
                        withAnimation(.easeOut(duration: 0.2)) { glow = 0.6 }
                        try? await Task.sleep(for: .milliseconds(250))
                        withAnimation(.easeIn(duration: 0.2)) { glow = 0 }
                        trigger = false
                    }
                } else {
                    Task { @MainActor in
                        withAnimation(FLMotion.celebrationPop) {
                            scale = 1.12
                            glow = 0.85
                        }
                        try? await Task.sleep(for: .milliseconds(180))
                        withAnimation(FLMotion.springDefault) { scale = 1.0 }
                        withAnimation(.easeOut(duration: 0.45)) { glow = 0 }
                        try? await Task.sleep(for: .milliseconds(500))
                        trigger = false
                    }
                }
            }
    }
}

// MARK: - SheetTransitionModifier
//
// Used on sheet *content* to give it a polished entrance that matches the
// Freshli motion language. Sheets still use `.sheet` / `.fullScreenCover`
// for presentation — this layer adds the fade + lift + scale that's hard to
// achieve with the default sheet animation alone.

struct SheetTransitionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 18)
            .scaleEffect(appeared || reduceMotion ? 1 : 0.985, anchor: .bottom)
            .onAppear {
                guard !appeared else { return }
                if reduceMotion {
                    withAnimation(.easeOut(duration: 0.2)) { appeared = true }
                } else {
                    withAnimation(FLMotion.sheetPresent) { appeared = true }
                }
            }
    }
}

// MARK: - SuccessFlashModifier / ErrorShakeModifier
//
// Lightweight feedback states for form fields, inline actions, and banner
// surfaces. These avoid pulling in the full celebration stack for tiny moments.

struct SuccessFlashModifier: ViewModifier {
    @Binding var trigger: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 1
    @State private var tint: Double = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(PSColors.freshGreen.opacity(tint))
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            )
            .sensoryFeedback(.success, trigger: trigger)
            .onChange(of: trigger) { _, newValue in
                guard newValue else { return }
                if reduceMotion {
                    Task { @MainActor in
                        withAnimation(.easeOut(duration: 0.2)) { tint = 0.25 }
                        try? await Task.sleep(for: .milliseconds(300))
                        withAnimation(.easeIn(duration: 0.2)) { tint = 0 }
                        trigger = false
                    }
                    return
                }
                Task { @MainActor in
                    withAnimation(FLMotion.successFlash) {
                        scale = 1.03
                        tint = 0.28
                    }
                    try? await Task.sleep(for: .milliseconds(180))
                    withAnimation(FLMotion.springDefault) { scale = 1.0 }
                    withAnimation(.easeOut(duration: 0.45)) { tint = 0 }
                    try? await Task.sleep(for: .milliseconds(500))
                    trigger = false
                }
            }
    }
}

struct ErrorShakeModifier: ViewModifier {
    @Binding var trigger: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .sensoryFeedback(.error, trigger: trigger)
            .onChange(of: trigger) { _, newValue in
                guard newValue else { return }
                if reduceMotion {
                    // No shake — reduced motion users get haptic + a single
                    // subtle opacity blink via the trigger sensory feedback.
                    trigger = false
                    return
                }
                // Haptic comes from `.sensoryFeedback(.error, trigger:)` above
                // — don't double-fire it here.
                let sequence: [CGFloat] = [-8, 8, -6, 6, -3, 3, 0]
                Task { @MainActor in
                    for dx in sequence {
                        withAnimation(FLMotion.errorShake) { offset = dx }
                        try? await Task.sleep(for: .milliseconds(55))
                    }
                    trigger = false
                }
            }
    }
}

// MARK: - LoadingPulseModifier
//
// Gentle breathing pulse for skeletons / loading states that don't warrant
// the full shimmer. Reduce Motion → static.

struct LoadingPulseModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(pulsing ? 0.6 : 1.0)
            .scaleEffect(pulsing ? 0.985 : 1.0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
    }
}

// MARK: - ListChangeAnimationModifier
//
// Wraps a view's list data so insert / remove / filter / sort transitions
// all share the same spring. Call on the container, not on each row.

struct ListChangeAnimationModifier<V: Equatable>: ViewModifier {
    let value: V
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .animation(
                FLMotion.adaptive(FLMotion.springDefault, reduceMotion: reduceMotion),
                value: value
            )
    }
}

// MARK: - View Extension Sugar

extension View {

    /// Bouncy tap feedback for non-Button tappable surfaces (cards, rows, chips).
    func bounceButtonModifier(pressedScale: CGFloat = 0.94, haptic: Bool = true) -> some View {
        modifier(BounceButtonModifier(pressedScale: pressedScale, haptic: haptic))
    }

    /// General-purpose card entrance animation. For the dashboard hero
    /// cascade prefer `dashboardEntrance(index:)`.
    func cardEntrance(index: Int = 0, yOffset: CGFloat = 22, initialScale: CGFloat = 0.96) -> some View {
        modifier(CardEntranceModifier(index: index, yOffset: yOffset, initialScale: initialScale))
    }

    /// Count-up reveal for a numeric stat. Applies to Text views produced by
    /// the `CountUpModifier` — i.e. pass an empty Text() then call this.
    func statReveal(value: Double, duration: Double = 0.9) -> some View {
        modifier(StatRevealModifier(value: value, duration: duration))
    }

    /// Pop + glow reward reaction. Pair with PSHaptics.celebrate(). For big
    /// milestone moments use `CelebrationManager` instead.
    func celebrationPop(trigger: Binding<Bool>, haptic: Bool = true) -> some View {
        modifier(CelebrationPopModifier(trigger: trigger, haptic: haptic))
    }

    /// Entrance transition for sheet/full-screen-cover content bodies.
    func sheetTransition() -> some View {
        modifier(SheetTransitionModifier())
    }

    /// Brief green tint + scale pulse used as inline success feedback.
    func successFlash(trigger: Binding<Bool>) -> some View {
        modifier(SuccessFlashModifier(trigger: trigger))
    }

    /// Classic iOS error shake. Reduced Motion → haptic only.
    func errorShake(trigger: Binding<Bool>) -> some View {
        modifier(ErrorShakeModifier(trigger: trigger))
    }

    /// Gentle breathing pulse for loading / skeleton states.
    func loadingPulse() -> some View {
        modifier(LoadingPulseModifier())
    }

    /// Unified spring-based animation for list mutation (insert/remove/sort/filter).
    /// Call on the container view, not individual rows.
    func listChangeAnimation<V: Equatable>(_ value: V) -> some View {
        modifier(ListChangeAnimationModifier(value: value))
    }

    /// Convenience that applies either the supplied animation or its Reduce
    /// Motion fallback at the call site. Use in place of bare
    /// `.animation(x, value: y)` for consistency.
    func flAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(AdaptiveAnimationModifier(animation: animation, value: value))
    }
}

// MARK: - AdaptiveAnimationModifier (backing for `.flAnimation`)

private struct AdaptiveAnimationModifier<V: Equatable>: ViewModifier {
    let animation: Animation
    let value: V
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(
            FLMotion.adaptive(animation, reduceMotion: reduceMotion),
            value: value
        )
    }
}

// MARK: - Matched-hero helper
//
// Simple wrapper that standardises the matchedGeometryEffect id format and
// couples it to the Freshli hero-match animation. Usage:
//
//     @Namespace private var heroNS
//     ItemCard(item).matchedHero(id: item.id, in: heroNS)
//     ItemDetailHero(item).matchedHero(id: item.id, in: heroNS)

extension View {
    func matchedHero<ID: Hashable>(
        id: ID,
        in namespace: Namespace.ID,
        properties: MatchedGeometryProperties = .frame,
        anchor: UnitPoint = .center,
        isSource: Bool = true
    ) -> some View {
        self.matchedGeometryEffect(
            id: id,
            in: namespace,
            properties: properties,
            anchor: anchor,
            isSource: isSource
        )
    }
}

// MARK: - Reduce-Motion Aware Transition helpers

extension AnyTransition {

    /// Asymmetric "rise from bottom" used by sheets and toasts. Falls back to
    /// plain opacity when Reduce Motion is on (handled at call site via
    /// `@Environment`).
    static var flSheetRise: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.98, anchor: .bottom)),
            removal: .opacity.combined(with: .move(edge: .bottom))
        )
    }

    /// Hero card transition used in list → detail matched-geometry flows.
    static var flHeroRise: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.94).combined(with: .opacity),
            removal: .scale(scale: 0.98).combined(with: .opacity)
        )
    }

    /// Celebration pop transition for small reward badges.
    static var flCelebrationPop: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.6).combined(with: .opacity),
            removal: .scale(scale: 1.15).combined(with: .opacity)
        )
    }
}
