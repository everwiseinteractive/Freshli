import SwiftUI

// MARK: - Tab Bar Visibility Service
// Tracks the floating tab bar's visibility state based on scroll direction.
// Views push scroll-offset changes via trackScroll(oldOffset:newOffset:) and
// the service accumulates a small delta buffer to avoid flicker from tiny
// scroll wobbles. Near the top of any screen the tab bar always re-appears.
//
// The actual animation of the tab bar in/out is performed by AppTabView,
// which observes `isVisible` and applies a buttery spring transition.

@MainActor
@Observable
final class TabBarVisibilityService {
    static let shared = TabBarVisibilityService()

    /// True when the floating tab bar should be visible.
    private(set) var isVisible: Bool = true

    /// Accumulated scroll delta — prevents flickering from small jitters.
    private var accumulatedDelta: CGFloat = 0

    /// Below this offset the tab bar is always visible (top of screen rule).
    private let topThreshold: CGFloat = 60

    /// How far the user must deliberately scroll in one direction before
    /// we commit to hiding/showing. Tuned to feel responsive but not twitchy.
    private let commitThreshold: CGFloat = 22

    private init() {}

    // MARK: - Scroll Tracking

    /// Called by each scroll container's onScrollGeometryChange modifier.
    /// The accumulator ensures micro-wobbles (e.g. a sub-pixel momentum
    /// rebound) don't flip the bar state.
    func trackScroll(oldOffset: CGFloat, newOffset: CGFloat) {
        // Near the top: always re-show, reset accumulator.
        if newOffset < topThreshold {
            if !isVisible { show() }
            accumulatedDelta = 0
            return
        }

        let delta = newOffset - oldOffset
        guard delta != 0 else { return }

        // Direction change: reset the accumulator so we measure a fresh
        // committed intent rather than summing across reversals.
        if (delta > 0 && accumulatedDelta < 0) || (delta < 0 && accumulatedDelta > 0) {
            accumulatedDelta = 0
        }
        accumulatedDelta += delta

        if accumulatedDelta >= commitThreshold, isVisible {
            hide()
            accumulatedDelta = 0
        } else if accumulatedDelta <= -commitThreshold, !isVisible {
            show()
            accumulatedDelta = 0
        }
    }

    // MARK: - Explicit Control

    func show() {
        guard !isVisible else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            isVisible = true
        }
    }

    func hide() {
        guard isVisible else { return }
        withAnimation(.spring(response: 0.48, dampingFraction: 0.85)) {
            isVisible = false
        }
    }

    /// Force-reset to visible without animation — used when switching tabs
    /// so each tab starts in a predictable state.
    func resetImmediate() {
        accumulatedDelta = 0
        if !isVisible {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                isVisible = true
            }
        }
    }
}
