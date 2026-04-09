import CoreHaptics
import UIKit
import os

// MARK: - Freshli Haptic Design System
// Signature haptic patterns built on CHHapticEngine for branded tactile feedback.
// Extends PSHaptics (UIKit generators) and HapticHarvestService (harvest patterns)
// with richer, multi-event patterns unique to the Freshli identity.

/// Freshness level for accessibility haptic feedback.
/// Maps item freshness (0–1) to distinct haptic intensities so users
/// with visual impairments can "feel" freshness while scrolling.
enum FreshnessLevel: Comparable {
    case expired      // 0.0
    case critical     // 0.01–0.15
    case wilting      // 0.16–0.40
    case fair         // 0.41–0.65
    case fresh        // 0.66–0.85
    case peak         // 0.86–1.0

    init(fraction: Double) {
        switch fraction {
        case ...0.0:        self = .expired
        case 0.01...0.15:   self = .critical
        case 0.16...0.40:   self = .wilting
        case 0.41...0.65:   self = .fair
        case 0.66...0.85:   self = .fresh
        default:            self = .peak
        }
    }

    /// Haptic intensity for this freshness level (0.0–1.0).
    var hapticIntensity: Float {
        switch self {
        case .expired:  return 0.1
        case .critical: return 0.25
        case .wilting:  return 0.4
        case .fair:     return 0.6
        case .fresh:    return 0.8
        case .peak:     return 1.0
        }
    }

    /// Haptic sharpness — fresh items feel crisp, wilting items feel dull.
    var hapticSharpness: Float {
        switch self {
        case .expired:  return 0.1
        case .critical: return 0.2
        case .wilting:  return 0.3
        case .fair:     return 0.5
        case .fresh:    return 0.7
        case .peak:     return 0.9
        }
    }
}

@Observable @MainActor
final class FreshliHapticManager {
    static let shared = FreshliHapticManager()

    // MARK: - Accessibility

    /// When true, haptic feedback encodes freshness information for users
    /// with visual impairments. Each scroll past a food item triggers a
    /// distinct haptic pulse based on its freshness level.
    var hapticAccessibilityMode = false

    // MARK: - Pattern Durations (for animation sync)

    /// Duration of "The Crisp Snap" pattern in seconds.
    static let crispSnapDuration: TimeInterval = 0.18
    /// Duration of "The Soft Wilt" pattern in seconds.
    static let softWiltDuration: TimeInterval = 0.50
    /// Duration of "The Community Heartbeat" pattern in seconds.
    static let communityHeartbeatDuration: TimeInterval = 0.36

    // MARK: - Private

    private var hapticEngine: CHHapticEngine?
    private let logger = PSLogger(category: .pantry)

    private init() {
        startEngine()
    }

    // MARK: - Engine Lifecycle

    private func startEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            logger.debug("Device does not support haptics")
            return
        }
        do {
            let engine = try CHHapticEngine()
            engine.resetHandler = { [weak self] in
                Task { @MainActor in
                    self?.startEngine()
                }
            }
            engine.stoppedHandler = { reason in
                // Engine stopped — will restart on next play attempt
            }
            try engine.start()
            hapticEngine = engine
            logger.debug("FreshliHapticManager engine started")
        } catch {
            logger.warning("FreshliHapticManager engine failed: \(error.localizedDescription)")
        }
    }

    func prepare() {
        if hapticEngine == nil { startEngine() }
    }

    func stop() {
        hapticEngine?.stop(completionHandler: nil)
        hapticEngine = nil
    }

    // MARK: - Signature Pattern: The Crisp Snap
    // Sharp, high-intensity transient when a fresh item is added.
    // Two rapid taps: a bright "crack" followed by a ringing shimmer.

    func crispSnap() {
        guard let engine = hapticEngine else {
            PSHaptics.shared.success()
            return
        }
        do {
            let events: [CHHapticEvent] = [
                // Primary snap — maximum sharpness
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                    ],
                    relativeTime: 0.0
                ),
                // Bright ring — slightly softer, offset 60ms
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                    ],
                    relativeTime: 0.06
                ),
                // Subtle shimmer tail at 120ms
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.25),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                    ],
                    relativeTime: 0.12,
                    duration: 0.06
                )
            ]

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            logger.warning("crispSnap haptic error: \(error.localizedDescription)")
            PSHaptics.shared.success()
        }
    }

    // MARK: - Signature Pattern: The Soft Wilt
    // Low-frequency, heavy continuous vibration when item marked Wasted.
    // A slow, sad rumble that fades out — tactile regret.

    func softWilt() {
        guard let engine = hapticEngine else {
            PSHaptics.shared.warning()
            return
        }
        do {
            let events: [CHHapticEvent] = [
                // Heavy initial thud
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.15)
                    ],
                    relativeTime: 0.0
                ),
                // Low rumble body — long, dull vibration
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
                    ],
                    relativeTime: 0.06,
                    duration: 0.30
                )
            ]

            // Fade the continuous rumble to zero
            let curve = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    CHHapticParameterCurve.ControlPoint(relativeTime: 0.06, value: 0.6),
                    CHHapticParameterCurve.ControlPoint(relativeTime: 0.36, value: 0.15),
                    CHHapticParameterCurve.ControlPoint(relativeTime: 0.50, value: 0.0)
                ],
                relativeTime: 0.0
            )

            let pattern = try CHHapticPattern(events: events, parameterCurves: [curve])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            logger.warning("softWilt haptic error: \(error.localizedDescription)")
            PSHaptics.shared.warning()
        }
    }

    // MARK: - Signature Pattern: The Community Heartbeat
    // Rhythmic dual-pulse when a neighbor Likes a donation.
    // Two beats mimicking a heartbeat — ba-DUM.

    func communityHeartbeat() {
        guard let engine = hapticEngine else {
            PSHaptics.shared.mediumTap()
            return
        }
        do {
            let events: [CHHapticEvent] = [
                // First beat (soft "ba")
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.45),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                    ],
                    relativeTime: 0.0
                ),
                // Second beat (strong "DUM")
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.85),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.55)
                    ],
                    relativeTime: 0.12
                ),
                // Warm afterglow
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.2),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                    ],
                    relativeTime: 0.20,
                    duration: 0.16
                )
            ]

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            logger.warning("communityHeartbeat haptic error: \(error.localizedDescription)")
            PSHaptics.shared.mediumTap()
        }
    }

    // MARK: - Accessibility: Freshness Haptic

    /// Plays a single haptic pulse whose intensity and sharpness encode freshness.
    /// Call this when the user scrolls past a food item in haptic accessibility mode.
    func freshnessHaptic(fraction: Double) {
        guard hapticAccessibilityMode else { return }

        let level = FreshnessLevel(fraction: fraction)

        guard let engine = hapticEngine else {
            // Fallback to UIKit generators with scaled intensity
            let generator = UIImpactFeedbackGenerator(style: level >= .fresh ? .rigid : .soft)
            generator.impactOccurred(intensity: CGFloat(level.hapticIntensity))
            return
        }

        do {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: level.hapticIntensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: level.hapticSharpness)
                ],
                relativeTime: 0.0
            )

            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            logger.warning("freshnessHaptic error: \(error.localizedDescription)")
        }
    }

    /// Plays a continuous haptic that maps freshness to a sustained texture.
    /// Useful for long-press inspection of an item's freshness state.
    func freshnessInspect(fraction: Double, duration: TimeInterval = 0.4) {
        guard hapticAccessibilityMode else { return }

        let level = FreshnessLevel(fraction: fraction)

        guard let engine = hapticEngine else {
            PSHaptics.shared.lightTap()
            return
        }

        do {
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: level.hapticIntensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: level.hapticSharpness)
                ],
                relativeTime: 0.0,
                duration: duration
            )

            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            logger.warning("freshnessInspect error: \(error.localizedDescription)")
        }
    }

    // MARK: - Celebration Sync Helpers

    /// Plays the appropriate haptic for a celebration intensity tier,
    /// timed to sync with the overlay's entrance animation.
    /// Returns the pattern duration so callers can coordinate Canvas animations.
    @discardableResult
    func celebrationHaptic(intensity: CelebrationIntensity) -> TimeInterval {
        switch intensity {
        case .small:
            PSHaptics.shared.success()
            return 0.1

        case .medium:
            crispSnap()
            return Self.crispSnapDuration

        case .hero:
            crispSnap()
            // Second burst offset to land on the confetti peak
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [self] in
                communityHeartbeat()
            }
            return Self.crispSnapDuration + 0.25 + Self.communityHeartbeatDuration
        }
    }

    /// Plays a haptic pattern timed to a Canvas animation frame.
    /// `phase` is 0.0–1.0, representing progress through the animation.
    /// Fires haptics at key animation moments (entry, peak, settle).
    func animationSyncPulse(phase: Double) {
        guard let engine = hapticEngine else { return }

        let intensity: Float
        let sharpness: Float

        switch phase {
        case 0.0..<0.1:
            // Animation start — light tap
            intensity = 0.3
            sharpness = 0.5
        case 0.4..<0.6:
            // Animation peak — strong pulse
            intensity = 0.8
            sharpness = 0.7
        case 0.9...1.0:
            // Animation settle — soft landing
            intensity = 0.2
            sharpness = 0.3
        default:
            return
        }

        do {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: 0.0
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Non-critical — swallow animation sync errors silently
        }
    }
}
