import SwiftUI
import CoreHaptics
import AVFoundation
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - Motion Vocabulary Service
// Translates visual shader effects into synchronized haptic pulses
// and synthesized soundscapes for users who cannot see the screen.
//
// Every visual "ripple", "depth change", and "glow" in Freshli's
// Liquid Glass design system has a corresponding haptic + audio
// representation. This creates a rich, non-visual experience that
// preserves the app's premium feel across all accessibility modes.
//
// Motion Vocabulary Lexicon:
//
//   Visual Effect          → Haptic                    → Audio
//   ─────────────────────────────────────────────────────────────
//   Glass Ripple (press)   → Density-mapped thock      → Glass chime (pitch ∝ density)
//   Shadow Deepen (hover)  → Gentle pressure swell     → Low hum fade-in
//   Elevation Rise (lift)  → Rising sharpness pulse    → Ascending tone (2 semitones)
//   Elevation Drop (set)   → Soft thud + decay         → Descending tone
//   OLED Glow (dark mode)  → Warm sustained rumble     → Warm pad (low-pass filtered)
//   Specular Flash (light) → Sharp bright tap          → Bright ping
//   Tab Switch (slide)     → Selection tick + sweep    → Whoosh (pitch ∝ direction)
//   Freshness Gradient     → Intensity ∝ freshness     → Tone pitch ∝ freshness
//   Item Rescue (consume)  → Crisp Snap + celebration  → Arpeggio shimmer
//   Data Prefetch (warm)   → Subtle pulse              → (silent)
//
// Usage:
//   MotionVocabularyService.shared.speakMotion(.glassRipple(density: .high))
//   MotionVocabularyService.shared.speakMotion(.elevationChange(from: .z1, to: .z3))
//
// Accessibility:
//   - Active only when VoiceOver is running OR user enables in Settings
//   - Respects Reduce Motion (simplifies patterns to single taps)
//   - Respects silent mode (haptic-only fallback)
//   - Audio volume scales with system accessibility volume
// ══════════════════════════════════════════════════════════════════

// MARK: - Motion Vocabulary Event

/// A visual motion event that needs tactile/audio representation.
enum MotionEvent: Sendable {
    /// Liquid Glass button press ripple with material density.
    case glassRipple(density: FLMaterialDensity)

    /// Element elevation change (shadow depth shift).
    case elevationChange(from: FLElevation, to: FLElevation)

    /// OLED glow pulse in dark environment.
    case oledGlow(intensity: Float)

    /// High-key specular flash in bright environment.
    case specularFlash(intensity: Float)

    /// Tab navigation slide (direction: positive = forward, negative = back).
    case tabSlide(direction: Int)

    /// Freshness level encountered while scrolling items.
    case freshnessEncounter(level: FreshnessLevel)

    /// Item rescue celebration.
    case itemRescue

    /// Shadow direction change (ambient light shift).
    case shadowShift(fromX: Float, toX: Float)

    /// Scan detection (Freshli Vision identified an item).
    case scanDetection(confidence: Double)

    /// Data prefetch complete (subtle confirmation).
    case prefetchWarm
}

// MARK: - Motion Vocabulary Service

@Observable @MainActor
final class MotionVocabularyService {
    static let shared = MotionVocabularyService()

    // MARK: - Configuration

    /// Whether motion vocabulary is active.
    /// Auto-enabled when VoiceOver is running; can be manually toggled.
    var isEnabled: Bool {
        get {
            manuallyEnabled || UIAccessibility.isVoiceOverRunning
        }
        set {
            manuallyEnabled = newValue
            UserDefaults.standard.set(newValue, forKey: "motionVocabularyEnabled")
        }
    }

    /// Whether to include audio alongside haptics (respects silent mode).
    var includeAudio: Bool {
        get { UserDefaults.standard.bool(forKey: "motionVocabularyAudio") }
        set { UserDefaults.standard.set(newValue, forKey: "motionVocabularyAudio") }
    }

    /// Whether reduce motion simplifies patterns to single taps.
    var useSimplifiedPatterns: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    // MARK: - State

    /// Last motion event for debugging / HUD display.
    private(set) var lastEvent: String = ""

    // MARK: - Private

    private var manuallyEnabled: Bool
    private var hapticEngine: CHHapticEngine?
    private var audioEngine: AVAudioEngine?
    private let logger = Logger(subsystem: "com.freshli", category: "MotionVocabulary")

    private init() {
        manuallyEnabled = UserDefaults.standard.bool(forKey: "motionVocabularyEnabled")
        prepareEngines()
        observeVoiceOver()
    }

    // MARK: - Public API

    /// Speak a visual motion event through haptic + audio channels.
    /// Call this from shader modifiers, elevation changes, and interactions.
    func speakMotion(_ event: MotionEvent) {
        guard isEnabled else { return }

        lastEvent = "\(event)"

        if useSimplifiedPatterns {
            speakSimplified(event)
        } else {
            speakFull(event)
        }
    }

    // MARK: - Full Patterns

    private func speakFull(_ event: MotionEvent) {
        switch event {
        case .glassRipple(let density):
            playGlassRippleHaptic(density: density)
            if includeAudio { playGlassChime(density: density) }

        case .elevationChange(let from, let to):
            let rising = to.rawValue > from.rawValue
            playElevationHaptic(rising: rising, magnitude: abs(to.rawValue - from.rawValue))
            if includeAudio { playElevationTone(rising: rising) }

        case .oledGlow(let intensity):
            playWarmRumble(intensity: intensity)
            if includeAudio { playWarmPad(intensity: intensity) }

        case .specularFlash(let intensity):
            playBrightTap(intensity: intensity)
            if includeAudio { playBrightPing(intensity: intensity) }

        case .tabSlide(let direction):
            playTabSweep(direction: direction)
            if includeAudio { playWhoosh(direction: direction) }

        case .freshnessEncounter(let level):
            playFreshnessHaptic(level: level)
            if includeAudio { playFreshnessTone(level: level) }

        case .itemRescue:
            FreshliHapticManager.shared.crispSnap()
            if includeAudio {
                FreshliCelebrationAudio.shared.playShimmer(
                    anchoredTo: 0.5, flavor: .consumed
                )
            }

        case .shadowShift(_, let toX):
            playShadowShiftHaptic(direction: toX)

        case .scanDetection(let confidence):
            playScanHaptic(confidence: confidence)
            if includeAudio { playScanTone(confidence: confidence) }

        case .prefetchWarm:
            playSubtlePulse()
        }
    }

    // MARK: - Simplified Patterns (Reduce Motion)

    private func speakSimplified(_ event: MotionEvent) {
        switch event {
        case .glassRipple:
            PSHaptics.shared.lightTap()

        case .elevationChange(_, let to):
            if to.rawValue > 2 {
                PSHaptics.shared.mediumTap()
            } else {
                PSHaptics.shared.softBounce()
            }

        case .oledGlow:
            PSHaptics.shared.softBounce()

        case .specularFlash:
            PSHaptics.shared.lightTap()

        case .tabSlide:
            PSHaptics.shared.selection()

        case .freshnessEncounter(let level):
            // Single tap with intensity proportional to freshness
            switch level {
            case .expired, .critical: PSHaptics.shared.warning()
            case .wilting, .fair:     PSHaptics.shared.lightTap()
            case .fresh, .peak:       PSHaptics.shared.success()
            }

        case .itemRescue:
            PSHaptics.shared.celebrate()

        case .shadowShift:
            break // No haptic for shadow shift in simplified mode

        case .scanDetection:
            PSHaptics.shared.mediumTap()

        case .prefetchWarm:
            break
        }
    }

    // MARK: - Haptic Patterns

    private func playGlassRippleHaptic(density: FLMaterialDensity) {
        // Delegate to existing glass ripple pattern
        FreshliHapticManager.shared.glassRipple(density: density)
    }

    private func playElevationHaptic(rising: Bool, magnitude: Int) {
        guard let engine = hapticEngine else {
            PSHaptics.shared.lightTap()
            return
        }

        let intensity = Float(min(magnitude, 5)) / 5.0
        let sharpness: Float = rising ? 0.7 : 0.3

        do {
            var events: [CHHapticEvent] = []

            if rising {
                // Rising: sharpness increases over 150ms
                events.append(CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * 0.4),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                    ],
                    relativeTime: 0, duration: 0.15
                ))
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                    ],
                    relativeTime: 0.15
                ))
            } else {
                // Dropping: starts sharp, fades to soft thud
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: 0
                ))
                events.append(CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * 0.3),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.15)
                    ],
                    relativeTime: 0.05, duration: 0.12
                ))
            }

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            PSHaptics.shared.lightTap()
        }
    }

    private func playWarmRumble(intensity: Float) {
        guard let engine = hapticEngine else { return }

        do {
            let events: [CHHapticEvent] = [
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * 0.35),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
                    ],
                    relativeTime: 0, duration: 0.4
                )
            ]
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch { logger.debug("CHHaptic playback skipped: \(error.localizedDescription, privacy: .public)") }
    }

    private func playBrightTap(intensity: Float) {
        guard let engine = hapticEngine else {
            PSHaptics.shared.lightTap()
            return
        }

        do {
            let events: [CHHapticEvent] = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * 0.8),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.95)
                    ],
                    relativeTime: 0
                ),
                // Bright shimmer tail
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * 0.3),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.85)
                    ],
                    relativeTime: 0.04
                )
            ]
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            PSHaptics.shared.lightTap()
        }
    }

    private func playTabSweep(direction: Int) {
        guard let engine = hapticEngine else {
            PSHaptics.shared.selection()
            return
        }

        do {
            // Sweeping haptic — 3 ticks with increasing/decreasing sharpness
            let baseSharpness: Float = direction > 0 ? 0.3 : 0.7
            let sharpnessStep: Float = direction > 0 ? 0.2 : -0.2

            var events: [CHHapticEvent] = []
            for i in 0..<3 {
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4 + Float(i) * 0.1),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: baseSharpness + Float(i) * sharpnessStep)
                    ],
                    relativeTime: Double(i) * 0.03
                ))
            }

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            PSHaptics.shared.selection()
        }
    }

    private func playFreshnessHaptic(level: FreshnessLevel) {
        guard let engine = hapticEngine else { return }

        do {
            let events: [CHHapticEvent] = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: level.hapticIntensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: level.hapticSharpness)
                    ],
                    relativeTime: 0
                )
            ]
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch { logger.debug("CHHaptic playback skipped: \(error.localizedDescription, privacy: .public)") }
    }

    private func playShadowShiftHaptic(direction: Float) {
        guard let engine = hapticEngine else { return }

        do {
            let events: [CHHapticEvent] = [
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.15),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                    ],
                    relativeTime: 0, duration: 0.2
                )
            ]
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch { logger.debug("CHHaptic playback skipped: \(error.localizedDescription, privacy: .public)") }
    }

    private func playScanHaptic(confidence: Double) {
        guard let engine = hapticEngine else {
            PSHaptics.shared.mediumTap()
            return
        }

        do {
            let intensity = Float(confidence)
            let events: [CHHapticEvent] = [
                // Detection ping
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                    ],
                    relativeTime: 0
                ),
                // Confirmation swell
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                    ],
                    relativeTime: 0.05, duration: 0.2
                )
            ]
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            PSHaptics.shared.mediumTap()
        }
    }

    private func playSubtlePulse() {
        guard let engine = hapticEngine else { return }

        do {
            let events: [CHHapticEvent] = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.15),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                    ],
                    relativeTime: 0
                )
            ]
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch { logger.debug("CHHaptic playback skipped: \(error.localizedDescription, privacy: .public)") }
    }

    // MARK: - Audio Synthesis

    /// Glass chime — pitch scales with density (low=air, high=thick glass).
    private func playGlassChime(density: FLMaterialDensity) {
        let frequency: Double = switch density {
        case .low:  880.0    // A5 — light, airy
        case .med:  659.25   // E5 — warm, resonant
        case .high: 440.0    // A4 — deep, glassy
        }
        playTone(frequency: frequency, duration: 0.25, attack: 0.01, decay: 0.2, volume: 0.15)
    }

    /// Ascending or descending tone for elevation changes.
    private func playElevationTone(rising: Bool) {
        let freq: Double = rising ? 698.46 : 523.25  // F5 up, C5 down
        playTone(frequency: freq, duration: 0.15, attack: 0.02, decay: 0.12, volume: 0.1)
    }

    /// Warm pad for OLED glow — low-frequency hum.
    private func playWarmPad(intensity: Float) {
        playTone(
            frequency: 220.0,  // A3 — warm, low
            duration: 0.3,
            attack: 0.1,
            decay: 0.2,
            volume: Double(intensity) * 0.08
        )
    }

    /// Bright ping for specular flash.
    private func playBrightPing(intensity: Float) {
        playTone(
            frequency: 1318.51,  // E6 — bright, crystalline
            duration: 0.12,
            attack: 0.005,
            decay: 0.1,
            volume: Double(intensity) * 0.12
        )
    }

    /// Whoosh for tab transitions.
    private func playWhoosh(direction: Int) {
        let baseFreq: Double = direction > 0 ? 300 : 500
        playTone(frequency: baseFreq, duration: 0.1, attack: 0.01, decay: 0.08, volume: 0.06)
    }

    /// Freshness tone — pitch maps to freshness level.
    private func playFreshnessTone(level: FreshnessLevel) {
        let frequency: Double = switch level {
        case .expired:  220.0    // A3 — low, dull
        case .critical: 293.66   // D4
        case .wilting:  392.0    // G4
        case .fair:     523.25   // C5
        case .fresh:    659.25   // E5
        case .peak:     880.0    // A5 — bright, alive
        }
        let volume = Double(level.hapticIntensity) * 0.1
        playTone(frequency: frequency, duration: 0.15, attack: 0.02, decay: 0.12, volume: volume)
    }

    /// Scan detection confirmation tone.
    private func playScanTone(confidence: Double) {
        let freq = 523.25 + confidence * 400  // C5 → ~F#6
        playTone(frequency: freq, duration: 0.2, attack: 0.01, decay: 0.15, volume: 0.12)
    }

    // MARK: - Tone Generator

    /// Generates and plays a single sine tone with envelope.
    private func playTone(
        frequency: Double,
        duration: Double,
        attack: Double,
        decay: Double,
        volume: Double
    ) {
        Task.detached { [weak self] in
            guard self != nil else { return }

            let sampleRate: Double = 44100
            let frameCount = Int(sampleRate * duration)

            let format = AVAudioFormat(
                standardFormatWithSampleRate: sampleRate,
                channels: 1
            )!
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(frameCount)
            ) else { return }
            buffer.frameLength = AVAudioFrameCount(frameCount)

            guard let channel = buffer.floatChannelData?[0] else { return }

            for frame in 0..<frameCount {
                let t = Double(frame) / sampleRate
                let normalizedT = t / duration

                // Envelope: attack → sustain → decay
                let env: Double
                if normalizedT < attack / duration {
                    env = normalizedT / (attack / duration)
                } else if normalizedT > 1.0 - (decay / duration) {
                    env = (1.0 - normalizedT) / (decay / duration)
                } else {
                    env = 1.0
                }

                let sample = sin(2.0 * .pi * frequency * t) * env * volume
                channel[frame] = Float(sample)
            }

            // Play via AVAudioEngine
            let engine = AVAudioEngine()
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)

            do {
                try engine.start()
                player.play()
                _ = await player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack)
                player.stop()
                engine.stop()
            } catch {
                // Audio failure is non-critical
            }
        }
    }

    // MARK: - Engine Management

    private func prepareEngines() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            let engine = try CHHapticEngine()
            engine.resetHandler = { [weak self] in
                Task { @MainActor in self?.prepareEngines() }
            }
            try engine.start()
            hapticEngine = engine
        } catch {
            logger.warning("Motion Vocabulary haptic engine failed: \(error.localizedDescription)")
        }
    }

    private func observeVoiceOver() {
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                if UIAccessibility.isVoiceOverRunning {
                    self?.logger.info("VoiceOver enabled — Motion Vocabulary auto-activated")
                }
            }
        }
    }
}

// MARK: - View Modifier for Freshness Haptic

/// Automatically triggers freshness haptic feedback when VoiceOver
/// users scroll past food items. Encodes item freshness as tactile intensity.
struct FreshnessMotionVocabularyModifier: ViewModifier {
    let freshnessLevel: FreshnessLevel

    func body(content: Content) -> some View {
        content
            .onAppear {
                if UIAccessibility.isVoiceOverRunning {
                    MotionVocabularyService.shared.speakMotion(
                        .freshnessEncounter(level: freshnessLevel)
                    )
                }
            }
            .accessibilityValue(freshnessAccessibilityValue)
    }

    private var freshnessAccessibilityValue: String {
        switch freshnessLevel {
        case .peak:     return String(localized: "Peak freshness")
        case .fresh:    return String(localized: "Fresh")
        case .fair:     return String(localized: "Fair freshness")
        case .wilting:  return String(localized: "Starting to wilt")
        case .critical: return String(localized: "Critical, use immediately")
        case .expired:  return String(localized: "Expired")
        }
    }
}

extension View {
    /// Encode freshness as Motion Vocabulary haptic + audio for VoiceOver users.
    func freshnessMotionVocabulary(level: FreshnessLevel) -> some View {
        modifier(FreshnessMotionVocabularyModifier(freshnessLevel: level))
    }
}
