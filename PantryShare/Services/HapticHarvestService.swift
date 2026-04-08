import CoreHaptics
import UIKit
import os

/// SparkleIntensity controls the number of particles and duration of sparkle animations.
enum SparkleIntensity {
    case gentle       // 3-5 particles, 1.5s duration
    case standard     // 10-15 particles, 2s duration
    case celebration  // 25+ particles, 2.5s duration
}

/// HapticHarvestService provides custom haptic patterns for the Haptic Harvest feature.
/// Uses CoreHaptics for complex patterns with UIImpactFeedbackGenerator as fallback.
@Observable
final class HapticHarvestService {
    static let shared = HapticHarvestService()

    private let logger = PSLogger(category: .pantry)
    private var hapticEngine: CHHapticEngine?

    init() {
        prepareCoreHaptics()
    }

    // MARK: - CoreHaptics Setup

    private func prepareCoreHaptics() {
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            logger.debug("CoreHaptics engine initialized successfully")
        } catch {
            logger.warning("CoreHaptics not available: \(error.localizedDescription), falling back to UIImpactFeedbackGenerator")
            hapticEngine = nil
        }
    }

    // MARK: - Harvest Celebration Pattern

    /// Plays a satisfying multi-stage haptic pattern simulating plucking a fruit from a tree.
    /// Stage 1: Gentle tap (initial pluck)
    /// Stage 2: Crescendo (acceleration)
    /// Stage 3: Burst (harvest success)
    func harvestCelebration() {
        guard let engine = hapticEngine else {
            // Fallback: use PSHaptics
            PSHaptics.shared.success()
            return
        }

        do {
            var events: [CHHapticEvent] = []

            // Stage 1: Gentle initial tap (0ms)
            let gentleTap = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                ],
                relativeTime: 0.0
            )
            events.append(gentleTap)

            // Stage 2: Medium tap at 80ms (crescendo building)
            let crescendoTap = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                ],
                relativeTime: 0.08
            )
            events.append(crescendoTap)

            // Stage 3: Strong burst at 140ms (celebration peak)
            let burstTap = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ],
                relativeTime: 0.14
            )
            events.append(burstTap)

            // Gentle decay at 200ms (settling)
            let decayTap = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0.20
            )
            events.append(decayTap)

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)

            logger.debug("Harvest celebration haptic pattern played")
        } catch {
            logger.warning("Harvest celebration haptic error: \(error.localizedDescription)")
            PSHaptics.shared.success()
        }
    }

    /// Lighter version of harvest celebration for rapid-fire marking multiple items.
    /// Reduced intensity to avoid overwhelming feedback.
    func quickHarvest() {
        guard let engine = hapticEngine else {
            PSHaptics.shared.mediumTap()
            return
        }

        do {
            var events: [CHHapticEvent] = []

            // Quick double-tap pattern
            let firstTap = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0.0
            )
            events.append(firstTap)

            let secondTap = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                ],
                relativeTime: 0.06
            )
            events.append(secondTap)

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)

            logger.debug("Quick harvest haptic pattern played")
        } catch {
            logger.warning("Quick harvest haptic error: \(error.localizedDescription)")
            PSHaptics.shared.mediumTap()
        }
    }

    /// Special haptic pattern for streak milestones and achievement unlocks.
    /// Longer, more pronounced pattern to celebrate significant accomplishments.
    func streakMilestone() {
        guard let engine = hapticEngine else {
            PSHaptics.shared.celebrate()
            return
        }

        do {
            var events: [CHHapticEvent] = []

            // Build-up sequence (0-100ms)
            for i in 0..<3 {
                let tap = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(0.3) + Float(i) * 0.2),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                    ],
                    relativeTime: Double(i) * 0.04
                )
                events.append(tap)
            }

            // Peak celebration at 120ms
            let peakTap = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                ],
                relativeTime: 0.12
            )
            events.append(peakTap)

            // Aftershock at 160ms
            let aftershock = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                ],
                relativeTime: 0.16
            )
            events.append(aftershock)

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)

            logger.debug("Streak milestone haptic pattern played")
        } catch {
            logger.warning("Streak milestone haptic error: \(error.localizedDescription)")
            PSHaptics.shared.celebrate()
        }
    }

    // MARK: - Engine Lifecycle

    /// Prepares the haptic engine for future patterns (useful when resuming from background).
    func prepare() {
        prepareCoreHaptics()
    }

    /// Stops the haptic engine (called on app background).
    func stop() {
        hapticEngine?.stop(completionHandler: nil)
        logger.debug("Haptic engine stopped")
    }
}
