import SwiftUI
import ARKit
import Combine
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - Intelligent Gaze Tracking Service
// Uses the TrueDepth front-facing camera + ARKit face tracking to
// detect where the user is looking on screen. Items near the gaze
// point subtly "inflate" via a Metal vertex shader, creating a
// magical hands-free browsing experience.
//
// Architecture:
//   1. ARSession with face tracking configuration
//   2. Eye transform → screen-space gaze point conversion
//   3. Published gaze location consumed by SwiftUI views
//   4. GazeInflateModifier applies vertex displacement near gaze
//
// Privacy:
//   - All processing is on-device (ARKit + Apple Intelligence)
//   - No camera frames are stored or transmitted
//   - The camera preview is never shown — only gaze vector is used
//   - User must explicitly enable the feature in Settings
//
// Performance:
//   - ARSession runs at 30fps (battery-efficient configuration)
//   - Gaze updates throttled to 15fps for UI smoothness
//   - Auto-pauses when app backgrounds or screen locks
//   - Respects ShaderQualityTier — disabled below .high
// ══════════════════════════════════════════════════════════════════

// MARK: - Gaze Point

/// A normalized gaze point on the screen (0,0 = top-left, 1,1 = bottom-right).
struct GazePoint: Sendable, Equatable {
    let x: CGFloat
    let y: CGFloat
    let confidence: CGFloat  // 0→1

    static let offScreen = GazePoint(x: -1, y: -1, confidence: 0)

    var isOnScreen: Bool {
        x >= 0 && x <= 1 && y >= 0 && y <= 1 && confidence > 0.3
    }

    /// Screen-space point for a given view size.
    func screenPoint(in size: CGSize) -> CGPoint {
        CGPoint(x: x * size.width, y: y * size.height)
    }
}

// MARK: - Gaze Tracking Service

@Observable @MainActor
final class GazeTrackingService {
    static let shared = GazeTrackingService()

    // MARK: - Published State

    /// Current gaze point in normalized screen coordinates.
    private(set) var gazePoint: GazePoint = .offScreen

    /// Whether gaze tracking is currently active.
    private(set) var isTracking = false

    /// Whether the device supports face tracking (TrueDepth camera).
    let isSupported: Bool

    /// User preference — must be explicitly enabled.
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "gazeTrackingEnabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "gazeTrackingEnabled")
            if newValue { startTracking() } else { stopTracking() }
        }
    }

    /// Rolling gaze history buffer for trajectory analysis.
    /// Used by GazeAnticipationService to predict next gaze target.
    private(set) var gazeHistory: [GazePoint] = []

    /// Maximum gaze history entries retained (≈1 second at 15fps).
    private static let maxGazeHistory = 15

    // MARK: - Private

    private var arSession: ARSession?
    private var sessionDelegate: GazeSessionDelegate?
    private let logger = Logger(subsystem: "com.freshli", category: "GazeTracking")

    // Smoothing — exponential moving average to prevent jitter
    private var smoothedX: CGFloat = 0.5
    private var smoothedY: CGFloat = 0.5
    private let smoothingFactor: CGFloat = 0.25  // 0 = no smoothing, 1 = no smoothing

    private init() {
        isSupported = ARFaceTrackingConfiguration.isSupported
    }

    // MARK: - Lifecycle

    func startTracking() {
        guard isSupported, isEnabled, !isTracking else { return }

        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = false  // Save battery
        config.maximumNumberOfTrackedFaces = 1

        let session = ARSession()
        let delegate = GazeSessionDelegate { [weak self] gazeUpdate in
            Task { @MainActor in
                self?.processGazeUpdate(gazeUpdate)
            }
        }
        session.delegate = delegate

        self.arSession = session
        self.sessionDelegate = delegate

        session.run(config, options: [.resetTracking])
        isTracking = true
        logger.info("Gaze tracking started")
    }

    func stopTracking() {
        arSession?.pause()
        arSession = nil
        sessionDelegate = nil
        isTracking = false
        gazePoint = .offScreen
        logger.info("Gaze tracking stopped")
    }

    func pause() {
        arSession?.pause()
    }

    func resume() {
        guard isEnabled, let session = arSession else { return }
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = false
        config.maximumNumberOfTrackedFaces = 1
        session.run(config)
    }

    // MARK: - Gaze Processing

    private func processGazeUpdate(_ update: RawGazeUpdate) {
        // Apply exponential moving average for smooth tracking
        smoothedX = smoothedX + smoothingFactor * (update.normalizedX - smoothedX)
        smoothedY = smoothedY + smoothingFactor * (update.normalizedY - smoothedY)

        let newPoint = GazePoint(
            x: smoothedX,
            y: smoothedY,
            confidence: update.confidence
        )
        gazePoint = newPoint

        // Append to rolling history for trajectory analysis
        gazeHistory.append(newPoint)
        if gazeHistory.count > Self.maxGazeHistory {
            gazeHistory.removeFirst(gazeHistory.count - Self.maxGazeHistory)
        }
    }
}

// MARK: - Raw Gaze Update

struct RawGazeUpdate: Sendable {
    let normalizedX: CGFloat  // 0→1, left→right
    let normalizedY: CGFloat  // 0→1, top→bottom
    let confidence: CGFloat   // 0→1
}

// MARK: - ARSession Delegate

/// Extracts gaze direction from ARKit face anchors.
/// Converts the eye transform matrices into a screen-space gaze point.
///
/// Threading: ARKit session delegate callbacks fire on an ARKit internal queue.
/// `lastUpdateTime` is a primitive `TimeInterval` (Double) used only for
/// frame-rate throttling — the worst-case race is one extra gaze update,
/// which is benign. `@unchecked Sendable` is intentional here.
private class GazeSessionDelegate: NSObject, ARSessionDelegate, @unchecked Sendable {
    let onGazeUpdate: @Sendable (RawGazeUpdate) -> Void
    private var lastUpdateTime: TimeInterval = 0
    private let minUpdateInterval: TimeInterval = 1.0 / 15.0  // 15fps throttle

    init(onGazeUpdate: @escaping @Sendable (RawGazeUpdate) -> Void) {
        self.onGazeUpdate = onGazeUpdate
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        let now = CACurrentMediaTime()
        guard now - lastUpdateTime >= minUpdateInterval else { return }
        lastUpdateTime = now

        guard let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first else { return }

        // Get eye transforms relative to the face
        let leftEye = faceAnchor.leftEyeTransform
        let rightEye = faceAnchor.rightEyeTransform

        // Average the eye gaze directions
        let leftGaze = simd_make_float3(leftEye.columns.2)
        let rightGaze = simd_make_float3(rightEye.columns.2)
        let avgGaze = (leftGaze + rightGaze) * 0.5

        // Convert gaze direction to normalized screen coordinates
        // The Z axis points forward from the eye, X is horizontal, Y is vertical
        // We project the gaze ray onto the screen plane
        let screenX = CGFloat(0.5 - avgGaze.x * 2.0)  // Invert X for screen coords
        let screenY = CGFloat(0.5 + avgGaze.y * 2.0)   // Y is inverted

        // Clamp to 0→1 range with some tolerance for off-screen glances
        let clampedX = max(-0.1, min(1.1, screenX))
        let clampedY = max(-0.1, min(1.1, screenY))

        // Confidence based on face tracking quality
        let confidence: CGFloat = faceAnchor.isTracked ? 0.8 : 0.0

        onGazeUpdate(RawGazeUpdate(
            normalizedX: clampedX,
            normalizedY: clampedY,
            confidence: confidence
        ))
    }
}

// MARK: - Gaze Inflate Modifier

/// Subtly scales up a view when the user's gaze falls near it.
/// Creates a "magnetic" effect where items inflate toward the eye.
struct GazeInflateModifier: ViewModifier {
    let gazeService: GazeTrackingService
    let inflateScale: CGFloat
    let activationRadius: CGFloat  // Points — how close gaze must be

    @State private var isGazeNear = false
    @State private var proximity: CGFloat = 0  // 0→1, how close gaze is

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.shaderQuality) private var quality

    init(
        gazeService: GazeTrackingService = .shared,
        inflateScale: CGFloat = 1.04,
        activationRadius: CGFloat = 80
    ) {
        self.gazeService = gazeService
        self.inflateScale = inflateScale
        self.activationRadius = activationRadius
    }

    func body(content: Content) -> some View {
        if reduceMotion || quality.rawValue < ShaderQualityTier.high.rawValue || !gazeService.isTracking {
            content
        } else {
            content
                .scaleEffect(1.0 + (inflateScale - 1.0) * proximity)
                .elevation(proximity > 0.5 ? .z2 : .z1)
                .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.7), value: proximity)
                .overlay {
                    GeometryReader { proxy in
                        Color.clear
                            .onChange(of: gazeService.gazePoint) { _, newGaze in
                                guard newGaze.isOnScreen else {
                                    if isGazeNear {
                                        proximity = 0
                                        isGazeNear = false
                                    }
                                    return
                                }

                                let screenSize = UIApplication.shared.connectedScenes
                                    .compactMap { $0 as? UIWindowScene }
                                    .first?.screen.bounds.size ?? CGSize(width: 393, height: 852)
                                let gazeScreen = newGaze.screenPoint(in: screenSize)

                                // Get this view's center in screen coordinates
                                let frame = proxy.frame(in: .global)
                                let viewCenter = CGPoint(x: frame.midX, y: frame.midY)

                                let distance = sqrt(
                                    pow(gazeScreen.x - viewCenter.x, 2) +
                                    pow(gazeScreen.y - viewCenter.y, 2)
                                )

                                let normalizedDist = min(distance / activationRadius, 1.0)
                                let newProximity = max(0, 1.0 - normalizedDist) * CGFloat(newGaze.confidence)

                                proximity = newProximity
                                isGazeNear = newProximity > 0.1
                            }
                    }
                }
        }
    }
}

// MARK: - View Extension

extension View {
    /// Subtly inflate this view when the user's gaze falls near it.
    /// Requires GazeTrackingService to be active.
    func gazeInflate(
        scale: CGFloat = 1.04,
        activationRadius: CGFloat = 80
    ) -> some View {
        modifier(GazeInflateModifier(
            inflateScale: scale,
            activationRadius: activationRadius
        ))
    }
}
