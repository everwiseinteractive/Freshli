import SwiftUI
import UIKit

// MARK: - Circle Haptics
// Distinct tactile signatures for circle interactions.
// Uses SwiftUI SensoryFeedback API (iOS 17+) with UIImpactFeedbackGenerator fallback.

enum CircleHaptics {

    // MARK: - Item Claimed by Family Member

    /// Strong, satisfying feedback when a family member claims an item.
    /// Uses SensoryFeedback.impact(weight: .heavy, intensity:) when available.
    @MainActor
    static func itemClaimed() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred(intensity: 0.9)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let light = UIImpactFeedbackGenerator(style: .light)
            light.impactOccurred(intensity: 0.6)
        }
    }

    // MARK: - Circle Created

    /// Celebration-style feedback for creating a new circle.
    @MainActor
    static func circleCreated() {
        PSHaptics.shared.celebrate()
    }

    // MARK: - Member Joined

    /// Warm welcome tap when a new member joins the circle.
    @MainActor
    static func memberJoined() {
        PSHaptics.shared.success()
    }

    // MARK: - Global Share Toggle

    /// Selection-style feedback when toggling global share on a listing.
    @MainActor
    static func globalShareToggled() {
        PSHaptics.shared.selection()
    }

    // MARK: - Invite Code Copied

    @MainActor
    static func inviteCodeCopied() {
        PSHaptics.shared.mediumTap()
    }

    // MARK: - SharePlay Started

    @MainActor
    static func sharePlayStarted() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred(intensity: 1.0)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let soft = UIImpactFeedbackGenerator(style: .soft)
            soft.impactOccurred(intensity: 0.7)
        }
    }
}

// MARK: - SensoryFeedback View Modifier

/// Applies SensoryFeedback for item claim events in views that support it.
struct ClaimSensoryFeedbackModifier: ViewModifier {
    let trigger: Bool

    func body(content: Content) -> some View {
        content
            .sensoryFeedback(.impact(weight: .heavy, intensity: 0.9), trigger: trigger)
    }
}

extension View {
    /// Attaches SensoryFeedback for item claim events. Pair with CircleHaptics.itemClaimed()
    /// as a UIKit fallback for non-view contexts.
    func claimFeedback(trigger: Bool) -> some View {
        modifier(ClaimSensoryFeedbackModifier(trigger: trigger))
    }
}
