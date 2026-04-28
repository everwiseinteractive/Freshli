import AVFoundation
import UIKit

// MARK: - Freshli Celebration Audio
// AVAudioEngine integration for celebratory "shimmer" sound
// spatially anchored to the Impact Card being updated.
// Generates a synthesized shimmer using layered sine tones with envelopes.

@MainActor
final class FreshliCelebrationAudio {
    static let shared = FreshliCelebrationAudio()

    private var engine: AVAudioEngine?
    private var isPlaying = false

    private init() {}

    // MARK: - Play Shimmer

    /// Plays a celebratory shimmer sound anchored toward the given screen position.
    /// - Parameters:
    ///   - position: Normalized horizontal position (0 = left, 1 = right) for stereo panning
    ///   - flavor: Celebration type — affects pitch and duration
    func playShimmer(
        anchoredTo position: CGFloat = 0.5,
        flavor: FreshliCelebrationFlavor = .consumed
    ) {
        guard !isPlaying else { return }

        // Respect system silent mode
        guard !isSilentMode() else { return }

        isPlaying = true

        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.generateAndPlayShimmer(pan: position, flavor: flavor)
            } catch {
                // Audio failure is non-critical — silently degrade
            }
            self.isPlaying = false
        }
    }

    // MARK: - Shimmer Synthesis

    private nonisolated func generateAndPlayShimmer(
        pan: CGFloat,
        flavor: FreshliCelebrationFlavor
    ) async throws {
        let sampleRate: Double = 44100
        let duration: Double = shimmerDuration(for: flavor)
        let frameCount = Int(sampleRate * duration)

        // Shimmer frequencies — ascending arpeggio based on flavor
        let frequencies = shimmerFrequencies(for: flavor)

        // Generate stereo PCM buffer.
        // AVAudioFormat returns Optional — guard so the function exits
        // cleanly if the format can't be created (unusual hardware/OS state).
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 2
        ) else { return }
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(frameCount)
        ) else { return }
        buffer.frameLength = AVAudioFrameCount(frameCount)

        guard let leftChannel = buffer.floatChannelData?[0],
              let rightChannel = buffer.floatChannelData?[1] else { return }

        // Spatial panning: 0 = full left, 1 = full right
        let panValue = min(max(pan, 0), 1)
        let leftGain = Float(cos(panValue * .pi / 2)) // cos(0)=1, cos(π/2)=0
        let rightGain = Float(sin(panValue * .pi / 2))

        // Synthesize layered shimmer tones
        for frame in 0..<frameCount {
            let t = Double(frame) / sampleRate
            let normalizedT = t / duration

            // Envelope: quick attack, sustained shimmer, gentle fade
            let envelope = shimmerEnvelope(t: normalizedT)

            // Sum multiple sine tones with staggered onsets
            var sample: Float = 0
            for (i, freq) in frequencies.enumerated() {
                let onset = Double(i) * 0.06 // Stagger each tone by 60ms
                guard t >= onset else { continue }

                let localT = t - onset
                let localNorm = localT / (duration - onset)

                // Each tone has its own mini-envelope
                let toneEnv = toneEnvelope(t: localNorm)

                // Sine with subtle vibrato
                let vibrato = sin(2.0 * .pi * 5.5 * t) * 0.003
                let phase = 2.0 * .pi * (freq + vibrato) * localT
                sample += Float(sin(phase)) * toneEnv * 0.15
            }

            // Add sparkle noise (filtered random bursts)
            let sparkle = sparkleNoise(t: normalizedT, frame: frame)

            let finalSample = (sample + sparkle) * envelope * 0.6

            leftChannel[frame] = finalSample * leftGain
            rightChannel[frame] = finalSample * rightGain
        }

        // Play via AVAudioEngine
        let engine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)

        try engine.start()
        playerNode.play()
        _ = await playerNode.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack)

        playerNode.stop()
        engine.stop()
    }

    // MARK: - Shimmer Parameters by Flavor

    private nonisolated func shimmerFrequencies(for flavor: FreshliCelebrationFlavor) -> [Double] {
        switch flavor {
        case .consumed:
            // C major arpeggio — uplifting, fresh
            return [523.25, 659.25, 783.99, 1046.50, 1318.51]
        case .shared:
            // D major arpeggio — warm, connected
            return [587.33, 739.99, 880.00, 1174.66, 1479.98]
        case .milestone:
            // E major with sparkle — triumphant
            return [659.25, 830.61, 987.77, 1318.51, 1661.22, 1975.53]
        case .community:
            // F major — community warmth
            return [698.46, 880.00, 1046.50, 1396.91, 1760.00]
        }
    }

    private nonisolated func shimmerDuration(for flavor: FreshliCelebrationFlavor) -> Double {
        switch flavor {
        case .consumed: return 0.8
        case .shared: return 0.9
        case .milestone: return 1.2
        case .community: return 1.0
        }
    }

    private nonisolated func shimmerEnvelope(t: Double) -> Float {
        // Quick attack (0→0.1), sustain (0.1→0.6), fade (0.6→1.0)
        if t < 0.1 {
            return Float(t / 0.1)
        } else if t < 0.6 {
            return 1.0
        } else {
            return Float(1.0 - (t - 0.6) / 0.4)
        }
    }

    private nonisolated func toneEnvelope(t: Double) -> Float {
        // Each tone: attack 0→0.15, sustain, fade 0.7→1.0
        if t < 0.15 {
            return Float(t / 0.15)
        } else if t < 0.7 {
            return 1.0
        } else {
            return Float(max(0, 1.0 - (t - 0.7) / 0.3))
        }
    }

    private nonisolated func sparkleNoise(t: Double, frame: Int) -> Float {
        // Periodic micro-bursts that sound like sparkles
        let burstRate = 12.0 // bursts per second
        let burstPhase = (t * burstRate).truncatingRemainder(dividingBy: 1.0)
        guard burstPhase < 0.1 else { return 0 }

        // Simple pseudo-random using frame index
        let pseudo = sin(Double(frame) * 12.9898 + 78.233)
        let noise = Float(pseudo.truncatingRemainder(dividingBy: 1.0))
        let sparkleEnv = Float(1.0 - burstPhase / 0.1) * 0.03

        // Fade sparkle over time
        let timeFade = Float(max(0, 1.0 - t * 0.8))

        return noise * sparkleEnv * timeFade
    }

    // MARK: - Silent Mode Check

    private nonisolated func isSilentMode() -> Bool {
        // Check audio session category to respect silent switch
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
            return false
        } catch {
            return true
        }
    }
}
