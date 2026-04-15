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
    /// Duration of "The Glass Tap" pattern in seconds.
    static let glassTapDuration: TimeInterval = 0.22
    /// Duration of "The Glass Morph" pattern in seconds.
    static let glassMorphDuration: TimeInterval = 0.55

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

    // MARK: - Signature Pattern: The Glass Tap
    // Viscous, weighty transient when tapping a Liquid Glass surface.
    // A medium-sharp "thock" followed by a brief resonant hum — like
    // tapping a thick glass slab. Synced with Metal glass card effects.

    func glassTap() {
        guard let engine = hapticEngine else {
            PSHaptics.shared.lightTap()
            return
        }
        do {
            let events: [CHHapticEvent] = [
                // Primary thock — medium sharpness, moderate intensity
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.55)
                    ],
                    relativeTime: 0.0
                ),
                // Resonant hum — low-frequency glass vibration
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.35),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25)
                    ],
                    relativeTime: 0.04,
                    duration: 0.14
                ),
                // Subtle ring-off
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.15),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.65)
                    ],
                    relativeTime: 0.18
                )
            ]

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            logger.warning("glassTap haptic error: \(error.localizedDescription)")
            PSHaptics.shared.lightTap()
        }
    }

    // MARK: - Signature Pattern: The Glass Morph
    // Slow viscous transformation haptic for glass elements that reshape.
    // A gentle swell that rises, peaks, then resolves — matching the
    // Liquid Glass SDF morph animations. Think of thick honey flowing
    // through glass.

    func glassMorph() {
        guard let engine = hapticEngine else {
            PSHaptics.shared.softBounce()
            return
        }
        do {
            let events: [CHHapticEvent] = [
                // Subtle onset — the glass starts to move
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.25),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                    ],
                    relativeTime: 0.0
                ),
                // Rising swell — continuous viscous drag
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                    ],
                    relativeTime: 0.06,
                    duration: 0.32
                ),
                // Resolution snap — the glass settles into new shape
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.55),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.65)
                    ],
                    relativeTime: 0.40
                ),
                // Soft afterglow ring
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.12),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                    ],
                    relativeTime: 0.44,
                    duration: 0.11
                )
            ]

            // Intensity curve — rise, peak, settle
            let curve = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    CHHapticParameterCurve.ControlPoint(relativeTime: 0.06, value: 0.25),
                    CHHapticParameterCurve.ControlPoint(relativeTime: 0.22, value: 0.55),
                    CHHapticParameterCurve.ControlPoint(relativeTime: 0.38, value: 0.35),
                    CHHapticParameterCurve.ControlPoint(relativeTime: 0.55, value: 0.0)
                ],
                relativeTime: 0.0
            )

            let pattern = try CHHapticPattern(events: events, parameterCurves: [curve])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            logger.warning("glassMorph haptic error: \(error.localizedDescription)")
            PSHaptics.shared.softBounce()
        }
    }

    // MARK: - Signature Pattern: Glass Ripple (Viscosity Track)
    // Density-driven haptic that syncs with the Metal liquidGlassRipple
    // distortion shader. Duration matches the 0.45s ripple animation.
    //
    // Mapping from FLMaterialDensity → haptic character:
    //   low  (1.0)  — sharp, snappy click  (thin glass / air)
    //   med  (1.33) — medium thock + warm resonance (water-like)
    //   high (1.52) — heavy, thuddy impact + slow viscous swell (thick glass)
    //
    // The intensity curve tracks the ripple's radial expansion, peaking
    // at ~40% progress then decaying to zero as the ripple fades out.

    /// Duration of the Glass Ripple pattern in seconds.
    static let glassRippleDuration: TimeInterval = 0.45

    func glassRipple(density: FLMaterialDensity) {
        guard let engine = hapticEngine else {
            PSHaptics.shared.lightTap()
            return
        }

        let initialIntensity: Float
        let initialSharpness: Float
        let swellIntensity: Float
        let swellSharpness: Float
        let swellDuration: TimeInterval
        let decayTail: Bool

        switch density {
        case .low:
            // Thin glass — sharp, quick click
            initialIntensity = 0.55
            initialSharpness = 0.85
            swellIntensity = 0.15
            swellSharpness = 0.6
            swellDuration = 0.08
            decayTail = false

        case .med:
            // Water-like — medium thock with warm resonance
            initialIntensity = 0.7
            initialSharpness = 0.55
            swellIntensity = 0.4
            swellSharpness = 0.3
            swellDuration = 0.18
            decayTail = true

        case .high:
            // Thick glass — heavy thud with slow viscous swell
            initialIntensity = 0.85
            initialSharpness = 0.3
            swellIntensity = 0.55
            swellSharpness = 0.15
            swellDuration = 0.28
            decayTail = true
        }

        do {
            var events: [CHHapticEvent] = [
                // Primary impact at touch point
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: initialIntensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: initialSharpness)
                    ],
                    relativeTime: 0.0
                ),
                // Viscous swell — tracks the expanding ripple wavefront
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: swellIntensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: swellSharpness)
                    ],
                    relativeTime: 0.04,
                    duration: swellDuration
                )
            ]

            // High density gets an extra tail — the "glass settling" micro-vibration
            if decayTail {
                events.append(
                    CHHapticEvent(
                        eventType: .hapticContinuous,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.1),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                        ],
                        relativeTime: 0.04 + swellDuration,
                        duration: 0.10
                    )
                )
            }

            // Intensity curve synced to ripple expansion:
            // Quick rise → peak at ~40% ripple → gradual decay
            let peakTime = 0.04 + swellDuration * 0.4
            let endTime = 0.04 + swellDuration + (decayTail ? 0.10 : 0.0)

            let curve = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    CHHapticParameterCurve.ControlPoint(relativeTime: 0.0, value: initialIntensity),
                    CHHapticParameterCurve.ControlPoint(relativeTime: peakTime, value: swellIntensity * 1.1),
                    CHHapticParameterCurve.ControlPoint(relativeTime: endTime, value: 0.0)
                ],
                relativeTime: 0.0
            )

            let pattern = try CHHapticPattern(events: events, parameterCurves: [curve])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            logger.warning("glassRipple haptic error: \(error.localizedDescription)")
            PSHaptics.shared.lightTap()
        }
    }

    // MARK: - Glass Slide Haptic (Continuous)
    // Played during drag gestures on glass surfaces.
    // Creates a subtle "friction" feel that scales with velocity.

    func glassSlide(intensity: Float) {
        guard let engine = hapticEngine else { return }
        let clampedIntensity = min(max(intensity, 0.0), 1.0)
        do {
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: clampedIntensity * 0.4),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.15 + clampedIntensity * 0.3)
                ],
                relativeTime: 0.0,
                duration: 0.08
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Non-critical — swallow slide haptic errors
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
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
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

    // MARK: - Melt Dissolve (Tab Transition Haptic)
    /// Haptic accompaniment for the Metal melt-dissolve tab transition.
    /// Phase 1: Medium-intensity rumble that decays as pixels dissolve.
    /// Phase 2: Sharp crystallisation "click" when the new tab solidifies.
    /// Phase 3: Settling resonance — the glass finding its shape.
    func meltDissolve() {
        guard let engine = hapticEngine else { return }
        do {
            var events: [CHHapticEvent] = []

            // Phase 1 — dissolve rumble (decaying continuous)
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.55),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.20)
                ],
                relativeTime: 0,
                duration: 0.40
            ))

            // Phase 2 — crystallisation click (sharp transient)
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.75),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.85)
                ],
                relativeTime: 0.42
            ))

            // Phase 3 — settling resonance
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.15),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.50)
                ],
                relativeTime: 0.44,
                duration: 0.08
            ))

            // Intensity decay curve for the dissolve rumble
            let decay = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    .init(relativeTime: 0,    value: 0.55),
                    .init(relativeTime: 0.15, value: 0.40),
                    .init(relativeTime: 0.30, value: 0.18),
                    .init(relativeTime: 0.40, value: 0.0)
                ],
                relativeTime: 0
            )

            let pattern = try CHHapticPattern(events: events, parameterCurves: [decay])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Non-critical — swallow melt haptic errors silently
        }
    }
}
