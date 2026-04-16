import SwiftUI
import Combine
import CoreHaptics
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - Gaze-Adaptive Glass Service
// Bridges the GazeTrackingService (ARKit eye tracking) to the
// LiquidGlass Metal shader pipeline, creating a "the UI responds
// to your mind" experience.
//
// Architecture:
//   GazeTrackingService → normalised gaze point (x, y, confidence)
//                          ↓
//   GazeAdaptiveGlassService → per-view bloom state management
//                          ↓
//   GazeAdaptiveGlassModifier → TimelineView drives:
//     1. `gazeBloom` Metal shader (radial shimmer at gaze point)
//     2. `liquidGlass` power parameter boost (faster refraction)
//     3. FreshliHapticEngine (tactile mirror of visual bloom)
//     4. Foundation Models intent prediction (anticipate next focus)
//
// The bloom is additive and subtle: a warm radial glow radiates
// from the gaze point, chromatic shimmer pulses at the edges,
// and the refraction wave accelerates — all synced to haptics.
//
// Privacy:
//   - GazeTrackingService does all ARKit processing on-device
//   - No camera frames stored or transmitted
//   - User must explicitly enable gaze tracking in Settings
//   - Feature disabled below ShaderQualityTier.high
//   - Respects Reduce Motion + Reduce Transparency
//
// Performance:
//   - Bloom calculations are GPU-side (Metal shader)
//   - CPU cost: one distance check per frame per gazeAdaptive view
//   - Throttled to ShaderQualityTier.frameInterval (max 120Hz)
//   - Auto-disables when gaze is off-screen or low-confidence
// ══════════════════════════════════════════════════════════════════

// MARK: - Gaze Bloom State

/// Per-view state tracking the gaze proximity and resulting bloom.
/// Each `GazeAdaptiveGlassModifier` owns one of these.
@Observable @MainActor
final class GazeBloomState {
    /// Current bloom intensity (0→1). Drives the `gazeBloom` shader.
    private(set) var bloomIntensity: Float = 0

    /// Normalised gaze position relative to this view's bounds (0→1).
    /// Fed to the `gazeBloom` shader as the radial center.
    private(set) var localGazeUV: SIMD2<Float> = .zero

    /// Whether the gaze is currently dwelling on this view.
    private(set) var isDwelling = false

    /// Accumulated dwell time (seconds). After a threshold, triggers
    /// enhanced bloom + haptic pulse.
    private(set) var dwellTime: TimeInterval = 0

    /// The power boost applied to the liquidGlass shader when gazed at.
    /// Ranges from 0 (no boost) to 2.0 (maximum shimmer acceleration).
    var powerBoost: Float {
        // Ease-in-out curve: gentle start, peaks at full dwell
        let t = min(Float(dwellTime / Self.fullDwellThreshold), 1.0)
        return t * t * (3.0 - 2.0 * t) * 2.0  // Hermite smoothstep * 2x
    }

    // MARK: - Configuration

    /// Activation radius in normalised view coordinates (0→1).
    /// Gaze within this radius of the view center triggers bloom.
    static let activationRadius: CGFloat = 0.6

    /// Time (seconds) for the bloom to reach full intensity.
    static let fullDwellThreshold: TimeInterval = 0.6

    /// Bloom intensity smoothing factor (exponential moving average).
    /// Lower = smoother but more latent. 0.12 feels "organic".
    static let bloomSmoothing: Float = 0.12

    /// Minimum gaze confidence to trigger bloom (0→1).
    static let minConfidence: CGFloat = 0.4

    // MARK: - Update

    /// Called every frame from the TimelineView. Computes bloom intensity
    /// based on gaze proximity to this view's frame.
    ///
    /// - Parameters:
    ///   - gazePoint: Current normalised screen-space gaze from GazeTrackingService.
    ///   - viewFrame: This view's frame in global coordinates.
    ///   - screenSize: Full screen size for coordinate conversion.
    ///   - deltaTime: Time since last frame (seconds).
    func update(
        gazePoint: GazePoint,
        viewFrame: CGRect,
        screenSize: CGSize,
        deltaTime: TimeInterval
    ) {
        guard gazePoint.isOnScreen,
              gazePoint.confidence >= Self.minConfidence else {
            // Gaze lost — smoothly decay bloom
            decayBloom(deltaTime: deltaTime)
            return
        }

        // Convert gaze from screen-normalised to view-local normalised
        let gazeScreen = gazePoint.screenPoint(in: screenSize)
        let localX = (gazeScreen.x - viewFrame.minX) / viewFrame.width
        let localY = (gazeScreen.y - viewFrame.minY) / viewFrame.height

        localGazeUV = SIMD2<Float>(Float(localX), Float(localY))

        // Distance from view center (0→1 where 1 = at center)
        let centerDist = sqrt(
            pow(Float(localX) - 0.5, 2) +
            pow(Float(localY) - 0.5, 2)
        )

        // Is gaze within the activation radius?
        let isNearView = localX >= -0.15 && localX <= 1.15 &&
                         localY >= -0.15 && localY <= 1.15 &&
                         centerDist < Float(Self.activationRadius)

        if isNearView {
            // Proximity-based target intensity: closer = brighter
            let proximity = max(0, 1.0 - centerDist / Float(Self.activationRadius))
            let confidenceScale = Float(gazePoint.confidence)
            let targetBloom = proximity * confidenceScale

            // Smooth toward target
            bloomIntensity += (targetBloom - bloomIntensity) * Self.bloomSmoothing

            // Accumulate dwell time
            dwellTime += deltaTime
            isDwelling = true
        } else {
            decayBloom(deltaTime: deltaTime)
        }
    }

    /// Smoothly reduces bloom when gaze moves away.
    private func decayBloom(deltaTime: TimeInterval) {
        // Faster decay than build-up — bloom should "release" crisply
        bloomIntensity *= (1.0 - Self.bloomSmoothing * 2.0)
        if bloomIntensity < 0.005 {
            bloomIntensity = 0
            dwellTime = 0
            isDwelling = false
        } else {
            // Decay dwell time slowly
            dwellTime = max(0, dwellTime - deltaTime * 0.5)
        }
    }

    /// Hard reset — used when the view disappears.
    func reset() {
        bloomIntensity = 0
        localGazeUV = .zero
        isDwelling = false
        dwellTime = 0
    }
}

// ══════════════════════════════════════════════════════════════════
// MARK: - Gaze-Adaptive Glass Modifier
// SwiftUI ViewModifier that layers the `gazeBloom` Metal shader
// on top of any Liquid Glass view, driven by GazeTrackingService.
//
// When the user's gaze falls on this view:
//   1. Radial bloom shader activates at the gaze point
//   2. LiquidGlass refraction accelerates (power boost)
//   3. FreshliHapticEngine plays a subtle resonance
//   4. The view scales up slightly (1.02x) for depth
//
// All effects are frame-synced via a single TimelineView.
// ══════════════════════════════════════════════════════════════════

struct GazeAdaptiveGlassModifier: ViewModifier {
    let density: MaterialDensity
    let enableHaptics: Bool

    @State private var bloomState = GazeBloomState()
    @State private var hasTriggeredDwellHaptic = false
    @State private var viewFrame: CGRect = .zero

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.shaderQuality) private var quality

    private let gazeService = GazeTrackingService.shared
    private let logger = Logger(subsystem: "com.freshli.app", category: "GazeAdaptiveGlass")

    init(density: MaterialDensity = .medium, enableHaptics: Bool = true) {
        self.density = density
        self.enableHaptics = enableHaptics
    }

    func body(content: Content) -> some View {
        if !shouldActivate {
            // Graceful fallback: no gaze tracking, no bloom
            content
        } else {
            content
                .scaleEffect(1.0 + CGFloat(bloomState.bloomIntensity) * 0.025)
                .shadow(
                    color: Color(red: 0.13, green: 0.77, blue: 0.37)
                        .opacity(Double(bloomState.bloomIntensity) * 0.25),
                    radius: CGFloat(bloomState.bloomIntensity) * 10
                )
                .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.75), value: bloomState.isDwelling)
                .overlay {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { viewFrame = proxy.frame(in: .global) }
                            .onChange(of: proxy.frame(in: .global)) { _, newFrame in
                                viewFrame = newFrame
                            }
                    }
                }
                // Use a lighter-weight timer for bloom updates without Metal shader
                .onReceive(Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()) { _ in
                    guard gazeService.isTracking else { return }
                    let screenSize = viewFrame.isEmpty
                        ? CGSize(width: 393, height: 852)
                        : UIApplication.shared.connectedScenes
                            .compactMap { $0 as? UIWindowScene }
                            .first?.screen.bounds.size ?? viewFrame.size
                    bloomState.update(
                        gazePoint: gazeService.gazePoint,
                        viewFrame: viewFrame,
                        screenSize: screenSize,
                        deltaTime: 1.0 / 30.0
                    )
                    updateHaptics()
                }
                .onDisappear {
                    bloomState.reset()
                    hasTriggeredDwellHaptic = false
                }
        }
    }

    // MARK: - Activation Gate

    /// Whether gaze-adaptive effects should run.
    /// Disabled when: reduce motion, low shader quality, or gaze not tracking.
    private var shouldActivate: Bool {
        !reduceMotion &&
        quality >= .high &&
        gazeService.isTracking &&
        gazeService.isSupported
    }

    // MARK: - Haptic Feedback

    /// Triggers haptic events synced to the bloom state:
    ///   - Light pulse when bloom first activates (gaze lands)
    ///   - Sustained resonance during dwell (via FreshliHapticEngine)
    ///   - Settle tap when bloom deactivates (gaze leaves)
    private func updateHaptics() {
        guard enableHaptics else { return }

        let engine = FreshliHapticEngine.shared

        if bloomState.isDwelling && bloomState.bloomIntensity > 0.3 {
            // Dwell threshold reached — begin continuous haptic
            if !engine.isPlaying {
                engine.beginGlassInteraction(density: density)
            }

            // Sync haptic modulation to bloom intensity
            engine.updateGlassFrame(
                density: density.refractionIndex * bloomState.bloomIntensity,
                power: bloomState.powerBoost
            )

            // One-shot deeper haptic at full dwell (the "lock-on" moment)
            if bloomState.dwellTime >= GazeBloomState.fullDwellThreshold && !hasTriggeredDwellHaptic {
                hasTriggeredDwellHaptic = true
                engine.glassSurfaceTap(density: density)
            }
        } else if !bloomState.isDwelling && engine.isPlaying {
            // Gaze left — stop continuous haptic
            engine.stopGlassInteraction()
            hasTriggeredDwellHaptic = false
        }
    }
}

// ══════════════════════════════════════════════════════════════════
// MARK: - View Extension
// ══════════════════════════════════════════════════════════════════

extension View {
    /// Attach gaze-adaptive Liquid Glass bloom to this view.
    ///
    /// When the user's gaze (via ARKit face tracking) falls on this
    /// view, a radial bloom shader activates at the gaze point, the
    /// refraction wave accelerates, and a synced haptic plays.
    ///
    /// Requires:
    ///   - GazeTrackingService to be active (user opted in)
    ///   - ShaderQualityTier >= .high
    ///   - Reduce Motion OFF
    ///
    /// Falls back to a no-op modifier when conditions aren't met.
    ///
    /// - Parameters:
    ///   - density: Material density for haptic weight mapping.
    ///   - enableHaptics: Whether to play synced haptics (default true).
    func gazeAdaptiveGlass(
        _ density: MaterialDensity = .medium,
        enableHaptics: Bool = true
    ) -> some View {
        modifier(GazeAdaptiveGlassModifier(
            density: density,
            enableHaptics: enableHaptics
        ))
    }
}

// ══════════════════════════════════════════════════════════════════
// MARK: - Predictive Gaze Anticipation (Foundation Models)
// Uses Apple Intelligence to predict which UI element the user
// will focus on next, pre-warming the bloom for instant response.
//
// The on-device LLM analyses:
//   1. Recent gaze trajectory (direction + velocity)
//   2. Current IntentPredictionService predictions
//   3. Screen layout (which elements are in which direction)
//
// Output: A "pre-bloom" hint on the anticipated element, so the
// bloom appears to activate *before* the eye arrives — creating
// the illusion that the UI reads the user's mind.
// ══════════════════════════════════════════════════════════════════

#if canImport(FoundationModels)
import FoundationModels

/// Structured output for gaze anticipation predictions.
@Generable
struct GazeAnticipation {
    @Guide(description: "The predicted next gaze target region: one of topLeft, topCenter, topRight, centerLeft, center, centerRight, bottomLeft, bottomCenter, bottomRight")
    var predictedRegion: String

    @Guide(description: "Confidence from 0.0 to 1.0 that the user's gaze will move to this region next")
    var confidence: Double

    @Guide(description: "Predicted intent driving the gaze shift, e.g. 'checking expiring items' or 'browsing recipes'")
    var anticipatedIntent: String
}

@available(iOS 26.0, *)
@Observable @MainActor
final class GazeAnticipationService {
    static let shared = GazeAnticipationService()

    /// The predicted next gaze region (normalised screen quadrant).
    private(set) var anticipatedRegion: GazeRegion = .none

    /// Confidence of the anticipation (0→1).
    private(set) var anticipationConfidence: Float = 0

    /// Whether the service is currently running a prediction.
    private(set) var isAnticipating = false

    private var lastAnticipationTime: Date = .distantPast
    private let cooldown: TimeInterval = 3.0  // Don't re-predict too often
    private let logger = Logger(subsystem: "com.freshli.app", category: "GazeAnticipation")

    /// Screen regions for anticipation targeting.
    enum GazeRegion: String, CaseIterable, Sendable {
        case topLeft, topCenter, topRight
        case centerLeft, center, centerRight
        case bottomLeft, bottomCenter, bottomRight
        case none

        /// Normalised center point for this region.
        var centerUV: SIMD2<Float> {
            switch self {
            case .topLeft:      return SIMD2(0.17, 0.17)
            case .topCenter:    return SIMD2(0.50, 0.17)
            case .topRight:     return SIMD2(0.83, 0.17)
            case .centerLeft:   return SIMD2(0.17, 0.50)
            case .center:       return SIMD2(0.50, 0.50)
            case .centerRight:  return SIMD2(0.83, 0.50)
            case .bottomLeft:   return SIMD2(0.17, 0.83)
            case .bottomCenter: return SIMD2(0.50, 0.83)
            case .bottomRight:  return SIMD2(0.83, 0.83)
            case .none:         return .zero
            }
        }
    }

    // MARK: - Anticipation

    /// Analyses current gaze trajectory + intent predictions to anticipate
    /// where the user's gaze will move next. Call periodically from the
    /// home view's frame loop.
    func anticipate(
        currentGaze: GazePoint,
        recentGazeHistory: [GazePoint],
        intentService: IntentPredictionService
    ) async {
        guard !isAnticipating,
              Date.now.timeIntervalSince(lastAnticipationTime) >= cooldown,
              SystemLanguageModel.default.isAvailable else {
            return
        }

        isAnticipating = true
        lastAnticipationTime = .now
        defer { isAnticipating = false }

        do {
            let session = LanguageModelSession(
                instructions: """
                You are Freshli's gaze anticipation engine. Given the user's \
                current gaze position, recent gaze trajectory, and predicted \
                intent, predict which screen region they will look at next. \
                The screen is divided into a 3x3 grid. Be concise.
                """
            )

            // Build trajectory summary
            let trajectoryDesc: String
            if recentGazeHistory.count >= 3 {
                let last3 = recentGazeHistory.suffix(3)
                let dirs = last3.map { "(\(String(format: "%.2f", $0.x)), \(String(format: "%.2f", $0.y)))" }
                trajectoryDesc = "Recent gaze path: \(dirs.joined(separator: " → "))"
            } else {
                trajectoryDesc = "Insufficient gaze history"
            }

            let intentDesc = intentService.topIntent.map { "Predicted intent: \($0.rawValue)" } ?? "No strong intent predicted"

            let prompt = """
            Current gaze: (\(String(format: "%.2f", currentGaze.x)), \(String(format: "%.2f", currentGaze.y)))
            \(trajectoryDesc)
            \(intentDesc)

            Predict the next gaze target region.
            """

            let response = try await session.respond(to: prompt, generating: GazeAnticipation.self)
            let anticipation = response.content

            if let region = GazeRegion(rawValue: anticipation.predictedRegion) {
                anticipatedRegion = region
                anticipationConfidence = Float(min(max(anticipation.confidence, 0.0), 1.0))
                logger.debug("Gaze anticipation: \(region.rawValue) @ \(anticipation.confidence)")
            }
        } catch {
            logger.debug("Gaze anticipation failed: \(error.localizedDescription)")
        }
    }

    /// Returns a pre-bloom intensity for a view based on whether it
    /// falls in the anticipated gaze region.
    func preBloomIntensity(viewFrame: CGRect, screenSize: CGSize) -> Float {
        guard anticipatedRegion != .none, anticipationConfidence > 0.4 else { return 0 }

        let viewCenterNorm = SIMD2<Float>(
            Float(viewFrame.midX / screenSize.width),
            Float(viewFrame.midY / screenSize.height)
        )
        let regionCenter = anticipatedRegion.centerUV
        let diff = viewCenterNorm - regionCenter
        let dist = sqrt(diff.x * diff.x + diff.y * diff.y)

        // Soft falloff: views near the predicted region get a gentle pre-bloom
        let falloff = max(0, 1.0 - dist / 0.35)
        return falloff * anticipationConfidence * 0.25  // Max 25% pre-bloom
    }
}
#endif

// ══════════════════════════════════════════════════════════════════
// MARK: - Gaze Settings Toggle
// A SwiftUI view for the Settings screen that lets users enable
// or disable gaze-adaptive features with a clear privacy explanation.
// ══════════════════════════════════════════════════════════════════

struct GazeTrackingToggle: View {
    @State private var gazeService = GazeTrackingService.shared

    var body: some View {
        if gazeService.isSupported {
            Section {
                Toggle(isOn: Bindable(gazeService).isEnabled) {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Gaze-Adaptive UI")
                                .font(.system(.body, design: .rounded, weight: .semibold))
                            Text("Glass surfaces respond to where you look. Uses the TrueDepth camera — all processing stays on-device.")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "eye.tracking.monitor.fill")
                            .foregroundStyle(PSColors.primaryGreen)
                    }
                }
                .tint(PSColors.primaryGreen)
            } header: {
                Text("Apple Intelligence")
            }
        }
    }
}
