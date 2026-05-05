import SwiftUI

// ══════════════════════════════════════════════════════════════════
// MARK: - CelebrationType → Popup adapter
//
// Translates the existing `CelebrationType` taxonomy into a `Popup`
// descriptor so every celebration renders through the centralised
// `PopupCenter` (which guarantees top-most rendering above sheets,
// staggered entrance animations, an explicit acknowledge button, and
// adaptive sizing across every iOS device class).
//
// The colour mapping respects the prior theme per celebration type
// (green for first-item / first-save, violet for recipe match, blue
// for share, teal for donation, amber for streak, etc.) but expresses
// it through `PopupTint` so the popup system stays loosely coupled.
// ══════════════════════════════════════════════════════════════════

extension CelebrationType {

    /// Convert into a `Popup` ready to hand to `PopupCenter.shared.present`.
    /// The `onAcknowledge` callback is invoked on the main actor when
    /// the user taps the popup's CTA button.
    func asPopup(onAcknowledge: @escaping @MainActor @Sendable () -> Void) -> Popup {
        Popup(
            icon: icon,
            title: title,
            message: subtitle,
            primaryCTA: ctaLabel,
            backgroundTint: popupTint,
            confettiCount: confettiCount,
            intensity: popupIntensity,
            onAcknowledge: onAcknowledge
        )
    }

    // MARK: - Mappings

    private var popupTint: PopupTint {
        switch self {
        case .firstItemAdded, .firstFoodSaved, .impactMilestone:
            return .green
        case .recipeMatchSuccess:
            return .purple
        case .shareCompleted:
            return .blue
        case .donationCompleted:
            return .blue        // teal-ish — closest is .blue in the popup palette
        case .expiryRescueStreak, .achievementUnlock:
            return .amber
        case .weeklyRecap:
            return .purple      // dark slate background → purple feels closest
        case .communityImpact:
            return .green
        }
    }

    private var popupIntensity: PopupIntensity {
        switch intensity {
        case .small:  return .low
        case .medium: return .standard
        case .hero:   return .high
        }
    }
}
