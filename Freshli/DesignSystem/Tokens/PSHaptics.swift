import UIKit

// MARK: - Centralized Haptic Feedback
// Semantic haptic patterns for premium, consistent tactile feedback across Freshli.
// Pre-warms generators for instant response. Respects system haptic settings.

final class PSHaptics {
    static let shared = PSHaptics()

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()

    private init() {
        lightImpact.prepare()
        mediumImpact.prepare()
        selectionFeedback.prepare()
    }

    // MARK: - Selection & Navigation

    /// Tab switch, chip toggle, picker change, minor state transition
    func selection() {
        selectionFeedback.selectionChanged()
        selectionFeedback.prepare()
    }

    // MARK: - Taps & Actions

    /// Button tap, card press, minor action confirmation
    func lightTap() {
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }

    /// Save, confirm, moderate importance action
    func mediumTap() {
        mediumImpact.impactOccurred()
        mediumImpact.prepare()
    }

    /// Delete, destructive action, critical confirmation
    func heavyTap() {
        heavyImpact.impactOccurred()
        heavyImpact.prepare()
    }

    /// Soft bounce for gentle, ambient feedback
    func softBounce() {
        softImpact.impactOccurred(intensity: 0.6)
        softImpact.prepare()
    }

    // MARK: - Notification Patterns

    /// Item saved, food rescued, action succeeded
    func success() {
        notificationFeedback.notificationOccurred(.success)
        notificationFeedback.prepare()
    }

    /// Item expiring, attention needed
    func warning() {
        notificationFeedback.notificationOccurred(.warning)
        notificationFeedback.prepare()
    }

    /// Action failed, validation error
    func error() {
        notificationFeedback.notificationOccurred(.error)
        notificationFeedback.prepare()
    }

    // MARK: - Special Patterns

    /// Celebration: milestone, streak, achievement unlock
    func celebrate() {
        heavyImpact.impactOccurred(intensity: 0.9)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [self] in
            mediumImpact.impactOccurred(intensity: 1.0)
            mediumImpact.prepare()
        }
        heavyImpact.prepare()
    }

    /// Swipe action threshold crossed
    func swipeThreshold() {
        rigidImpact.impactOccurred(intensity: 0.6)
        rigidImpact.prepare()
    }

    /// Pull-to-refresh snap
    func refreshSnap() {
        rigidImpact.impactOccurred(intensity: 0.4)
        rigidImpact.prepare()
    }

    /// Counting / scrolling through items
    func tick() {
        lightImpact.impactOccurred(intensity: 0.3)
    }
}
