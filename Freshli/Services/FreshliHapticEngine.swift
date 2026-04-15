import CoreHaptics
import UIKit
import SwiftUI
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - FreshliHapticEngine
// Frame-synced haptic engine that maps the LiquidGlass Metal shader
// parameters (density + power) to CHHapticPattern curves in real-time.
//
// Architecture:
//   Metal shader → density (refraction weight) + power (animated phase)
//                  ↓                              ↓
//   CHHapticAdvancedPatternPlayer                 ↓
//   .hapticIntensity ← density mapping            ↓
//   .hapticSharpness ← inverse density            ↓
//   modulation curve ← sin(power) matches shader refraction
//
// The engine uses sendParameters(at:) to update a running continuous
// haptic pattern every animation frame, creating a 1:1 tactile mirror
// of the visual refraction. Heavy glass bends → heavy haptic. Light
// glass shimmer → crisp, airy tap.
//
// Design Awards standard: every photon of refraction has a matching
// haptic wavelet.
// ══════════════════════════════════════════════════════════════════

@Observable @MainActor
final class FreshliHapticEngine {
    static let shared = FreshliHapticEngine()

    // MARK: - Public State

    /// Whether the engine is currently playing a synced haptic track.
    private(set) var isPlaying = false

    /// Last density value sent to the haptic player.
    private(set) var currentDensity: Float = 0

    /// Last power value sent to the haptic player.
    private(set) var currentPower: Float = 0

    // MARK: - Configuration

    /// Maximum continuous haptic duration (seconds). Prevents battery drain
    /// from runaway interactions. The engine auto-stops after this.
    static let maxContinuousDuration: TimeInterval = 2.0

    /// Minimum interval between sendParameters calls (seconds).
    /// Prevents overwhelming the Taptic Engine with updates faster than
    /// it can physically respond (~120Hz matches ProMotion frame rate).
    private static let minUpdateInterval: TimeInterval = 1.0 / 120.0

    // MARK: - Density → Haptic Mapping
    //
    // Maps the shader's `density` float to haptic character:
    //   Low  density (0.02) → light, crisp, airy  (thin glass / air)
    //   Med  density (0.05) → moderate, warm      (water-like)
    //   High density (0.10) → heavy, viscous, thuddy (thick glass)
    //
    // These map directly to the MaterialDensity enum values:
    //   .low  → refractionIndex 0.02
    //   .medium → refractionIndex 0.05
    //   .high → refractionIndex 0.10

    /// Maps raw shader density (0.0–0.15) to haptic intensity (0.0–1.0).
    /// Higher density = heavier haptic.
    nonisolated static func intensityForDensity(_ density: Float) -> Float {
        // Clamp to expected range and normalize to 0–1
        let normalized = min(max(density, 0.0), 0.15) / 0.15
        // Quadratic curve: feels more natural — gentle at low, punchy at high
        let curved = normalized * normalized
        // Map to haptic range [0.15, 0.95]
        return 0.15 + curved * 0.80
    }

    /// Maps raw shader density to haptic sharpness (0.0–1.0).
    /// Higher density = LESS sharp (viscous, heavy glass is dull/thuddy).
    /// Lower density = MORE sharp (thin glass is crisp/airy).
    nonisolated static func sharpnessForDensity(_ density: Float) -> Float {
        let normalized = min(max(density, 0.0), 0.15) / 0.15
        // Inverse curve: low density → high sharpness
        return 0.85 - normalized * 0.65
    }

    /// Maps the shader's `power` (animated time phase) to a modulation
    /// factor that mirrors the visual refraction wave.
    /// The shader uses: sin(dist * 10.0 - power) * (density * 0.05)
    /// We replicate the same sin wave for haptic intensity modulation.
    nonisolated static func modulationForPower(_ power: Float, density: Float) -> Float {
        // Mirror the shader's refraction calculation
        let refraction = sin(5.0 - power) * (density * 0.05)
        // Normalize to ±0.15 modulation range
        return refraction * 3.0
    }

    // MARK: - Private

    private var hapticEngine: CHHapticEngine?
    private var advancedPlayer: CHHapticAdvancedPatternPlayer?
    private var lastUpdateTime: CFAbsoluteTime = 0
    private var interactionStartTime: Date?
    private let logger = Logger(subsystem: "com.freshli.app", category: "HapticEngine")

    private init() {
        prepareEngine()
    }

    // MARK: - Engine Lifecycle

    private func prepareEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            logger.debug("FreshliHapticEngine: Device does not support haptics")
            return
        }

        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            engine.isAutoShutdownEnabled = true

            engine.resetHandler = { [weak self] in
                Task { @MainActor in
                    self?.prepareEngine()
                }
            }

            engine.stoppedHandler = { [weak self] reason in
                Task { @MainActor in
                    self?.isPlaying = false
                    self?.advancedPlayer = nil
                }
            }

            try engine.start()
            hapticEngine = engine
            logger.debug("FreshliHapticEngine ready")
        } catch {
            logger.warning("FreshliHapticEngine init failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Interaction Start (Touch Down)

    /// Call when the user touches a Liquid Glass surface.
    /// Creates a continuous haptic pattern calibrated to the surface's density
    /// and starts the advanced player for real-time parameter updates.
    ///
    /// - Parameter density: The MaterialDensity of the glass surface being touched.
    func beginGlassInteraction(density: MaterialDensity) {
        guard let engine = hapticEngine else {
            // Fallback to simple UIKit haptic
            PSHaptics.shared.lightTap()
            return
        }

        // Stop any existing interaction
        stopGlassInteraction()

        let baseDensity = density.refractionIndex
        let baseIntensity = Self.intensityForDensity(baseDensity)
        let baseSharpness = Self.sharpnessForDensity(baseDensity)

        do {
            // ── Transient: Initial glass touch ──────────────────────
            // The "thock" when finger meets glass. Weight scales with density.
            let touchDown = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: baseIntensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: baseSharpness)
                ],
                relativeTime: 0.0
            )

            // ── Continuous: Refraction resonance ────────────────────
            // A sustained haptic bed that the sendParameters calls modulate
            // in sync with the shader's animated refraction wave.
            // Duration is maxContinuousDuration — we'll stop it manually.
            let resonance = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: baseIntensity * 0.4),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: baseSharpness * 0.7)
                ],
                relativeTime: 0.03,
                duration: Self.maxContinuousDuration
            )

            // ── Intensity curve: Glass "settling in" ────────────────
            // Quick swell as refraction starts, then sustains at a lower
            // level for the real-time modulation to ride on top of.
            let settlingCurve = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    .init(relativeTime: 0.03, value: baseIntensity * 0.5),
                    .init(relativeTime: 0.12, value: baseIntensity * 0.65),
                    .init(relativeTime: 0.30, value: baseIntensity * 0.35),
                    .init(relativeTime: Self.maxContinuousDuration, value: 0.0)
                ],
                relativeTime: 0.0
            )

            let pattern = try CHHapticPattern(
                events: [touchDown, resonance],
                parameterCurves: [settlingCurve]
            )

            // Use advanced player for real-time parameter updates
            let player = try engine.makeAdvancedPlayer(with: pattern)

            // Mute completion — engine is auto-shutdown enabled
            player.completionHandler = { [weak self] _ in
                Task { @MainActor in
                    self?.isPlaying = false
                    self?.advancedPlayer = nil
                }
            }

            try player.start(atTime: CHHapticTimeImmediate)

            self.advancedPlayer = player
            self.isPlaying = true
            self.currentDensity = baseDensity
            self.currentPower = 0
            self.interactionStartTime = .now
            self.lastUpdateTime = CFAbsoluteTimeGetCurrent()

            logger.debug("Glass interaction started: density=\(baseDensity)")

        } catch {
            logger.warning("beginGlassInteraction error: \(error.localizedDescription)")
            PSHaptics.shared.lightTap()
        }
    }

    // MARK: - Frame Update (Synced with Metal)

    /// Call every animation frame from the TimelineView that drives the
    /// LiquidGlass shader. This modulates the running haptic pattern
    /// to match the shader's visual refraction in real-time.
    ///
    /// - Parameters:
    ///   - density: Current shader `density` parameter (0.02–0.10).
    ///   - power: Current shader `power` parameter (animated time phase).
    func updateGlassFrame(density: Float, power: Float) {
        guard isPlaying, let player = advancedPlayer else { return }

        // Throttle: don't update faster than the Taptic Engine can respond
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastUpdateTime >= Self.minUpdateInterval else { return }
        lastUpdateTime = now

        // Auto-stop after max duration
        if let start = interactionStartTime,
           Date.now.timeIntervalSince(start) >= Self.maxContinuousDuration {
            stopGlassInteraction()
            return
        }

        // ── Map shader params to haptic params ──────────────────────
        let baseIntensity = Self.intensityForDensity(density)
        let modulation = Self.modulationForPower(power, density: density)

        // Final intensity: base + wave modulation, clamped to [0, 1]
        let finalIntensity = min(max(baseIntensity * 0.4 + modulation, 0.0), 1.0)
        let finalSharpness = Self.sharpnessForDensity(density)

        currentDensity = density
        currentPower = power

        // ── Send real-time parameter update to running player ────────
        do {
            try player.sendParameters(
                [
                    CHHapticDynamicParameter(
                        parameterID: .hapticIntensityControl,
                        value: finalIntensity,
                        relativeTime: 0
                    ),
                    CHHapticDynamicParameter(
                        parameterID: .hapticSharpnessControl,
                        value: finalSharpness,
                        relativeTime: 0
                    )
                ],
                atTime: CHHapticTimeImmediate
            )
        } catch {
            // Silently swallow frame update errors — non-critical
        }
    }

    // MARK: - Interaction End (Touch Up)

    /// Call when the user lifts their finger from a Liquid Glass surface.
    /// Plays a resolution transient (the glass "settling") then stops the
    /// continuous pattern.
    func stopGlassInteraction() {
        guard isPlaying else { return }

        // Play a settling transient — the glass resolving back to rest
        let settleDensity = currentDensity
        let settleIntensity = Self.intensityForDensity(settleDensity) * 0.3
        let settleSharpness = Self.sharpnessForDensity(settleDensity) * 1.2

        if let engine = hapticEngine {
            do {
                let settle = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: min(settleIntensity, 1.0)),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: min(settleSharpness, 1.0))
                    ],
                    relativeTime: 0.0
                )
                let pattern = try CHHapticPattern(events: [settle], parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: CHHapticTimeImmediate)
            } catch {
                // Non-critical
            }
        }

        // Stop the continuous pattern
        do {
            try advancedPlayer?.stop(atTime: CHHapticTimeImmediate)
        } catch {
            // Already stopped or errored — safe to ignore
        }

        advancedPlayer = nil
        isPlaying = false
        interactionStartTime = nil

        logger.debug("Glass interaction stopped")
    }

    // MARK: - One-Shot Glass Tap

    /// Fire-and-forget transient for quick glass surface taps (buttons, cards).
    /// Maps the surface's MaterialDensity to a single weighted haptic event.
    /// Use this instead of `beginGlassInteraction` for non-sustained touches.
    func glassSurfaceTap(density: MaterialDensity) {
        guard let engine = hapticEngine else {
            PSHaptics.shared.lightTap()
            return
        }

        let d = density.refractionIndex
        let intensity = Self.intensityForDensity(d)
        let sharpness = Self.sharpnessForDensity(d)

        do {
            let events: [CHHapticEvent] = [
                // Primary touch — density-weighted thock
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                    ],
                    relativeTime: 0.0
                ),
                // Glass resonance tail — brief hum matching density
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * 0.25),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness * 0.6)
                    ],
                    relativeTime: 0.03,
                    duration: TimeInterval(0.06 + d * 1.5)  // longer tail for heavier glass
                ),
                // Settle click — the glass returning to rest
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * 0.12),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: min(sharpness * 1.3, 1.0))
                    ],
                    relativeTime: TimeInterval(0.10 + d * 1.0)
                )
            ]

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            logger.warning("glassSurfaceTap error: \(error.localizedDescription)")
            PSHaptics.shared.lightTap()
        }
    }
}

// ══════════════════════════════════════════════════════════════════
// MARK: - LiquidGlassHapticModifier
// SwiftUI ViewModifier that wires the FreshliHapticEngine to any
// view with a .liquidGlass() modifier. On press, begins the
// continuous synced haptic. On release, stops it.
// ══════════════════════════════════════════════════════════════════

struct LiquidGlassHapticModifier: ViewModifier {
    let density: MaterialDensity

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed, !reduceMotion else { return }
                        isPressed = true
                        FreshliHapticEngine.shared.beginGlassInteraction(density: density)
                    }
                    .onEnded { _ in
                        guard isPressed else { return }
                        isPressed = false
                        FreshliHapticEngine.shared.stopGlassInteraction()
                    }
            )
    }
}

extension View {
    /// Attaches frame-synced Liquid Glass haptics to this view.
    /// On touch-down, begins a continuous haptic that mirrors the
    /// LiquidGlass shader refraction. On release, plays a settling tap.
    func liquidGlassHaptic(_ density: MaterialDensity = .medium) -> some View {
        modifier(LiquidGlassHapticModifier(density: density))
    }
}
