import SwiftUI
import CoreMotion
import Combine

// ══════════════════════════════════════════════════════════════════
// MARK: - Device Motion Service
// Lightweight CMMotionManager wrapper that publishes normalised
// device attitude for the specular-sparkle shader. Gyroscope
// pitch/roll drive the light direction so Liquid Glass surfaces
// "catch the light" as the user tilts the device.
//
// 30 Hz updates — low enough to be power-efficient, high enough
// to track hand micro-movements for that Apple-award sparkle.
//
// ENERGY: Automatically stops on willResignActive, resumes on
// didBecomeActive. CMMotionManager NEVER runs in background.
// ══════════════════════════════════════════════════════════════════

@Observable @MainActor
final class DeviceMotionService {
    static let shared = DeviceMotionService()

    /// Normalised device roll  (-1…+1). Maps to specular light X.
    private(set) var normalizedRoll: Double = 0
    /// Normalised device pitch (-1…+1). Maps to specular light Y.
    private(set) var normalizedPitch: Double = 0

    private let motionManager = CMMotionManager()
    private var isActive = false
    /// Whether start was requested — tracks intent across background/foreground cycles.
    private var isRequested = false

    private init() {
        observeAppLifecycle()
    }

    // MARK: - App Lifecycle (Energy Safety)

    private func observeAppLifecycle() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.suspendUpdates()
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.resumeIfRequested()
            }
        }
    }

    /// Pause updates when app resigns active (background/inactive).
    /// Does NOT clear `isRequested` so we can resume automatically.
    private func suspendUpdates() {
        guard isActive else { return }
        motionManager.stopDeviceMotionUpdates()
        isActive = false
        normalizedRoll  = 0
        normalizedPitch = 0
    }

    /// Resume updates if they were previously requested.
    private func resumeIfRequested() {
        guard isRequested else { return }
        startIfNeeded()
    }

    // MARK: - Public API

    /// Begin device motion updates (idempotent — safe to call repeatedly).
    func startIfNeeded() {
        isRequested = true
        guard !isActive, motionManager.isDeviceMotionAvailable else { return }
        isActive = true
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion, let self else { return }
            MainActor.assumeIsolated {
                // ±45° tilt maps to ±1.0
                self.normalizedPitch = max(-1, min(1, motion.attitude.pitch / (.pi / 4)))
                self.normalizedRoll  = max(-1, min(1, motion.attitude.roll  / (.pi / 4)))
            }
        }
    }

    func stop() {
        isRequested = false
        suspendUpdates()
        NotificationCenter.default.removeObserver(self)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// ══════════════════════════════════════════════════════════════════
// MARK: - Living Menu Modifier
// The "wow factor": when a user's gaze dwells on a card for >0.6 s
// a phaseAnimator cycles through bloom phases that:
//   1. Increase the liquidGlass shader power by 25 %
//   2. Overlay a specular ray-traced sparkle that follows the
//      device gyroscope, making glass "catch the light"
//   3. Apply a subtle 4 % scale bloom for physical depth
//
// ENERGY: Timer.publish runs only while the view is in the hierarchy.
// Background observer resets dwell state immediately on app resign.
// ══════════════════════════════════════════════════════════════════

struct LivingMenuModifier: ViewModifier {
    @State private var isDwelling = false
    @State private var viewFrame: CGRect = .zero
    @State private var dwellAccumulator: TimeInterval = 0
    @State private var lastCheck: Date = .now
    @State private var isAppActive = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let dwellThreshold: TimeInterval = 0.6

    func body(content: Content) -> some View {
        if reduceMotion || !ShaderWarmUpService.shadersAvailable {
            content
        } else {
            livingContent(content)
        }
    }

    @ViewBuilder
    private func livingContent(_ content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { viewFrame = geo.frame(in: .global) }
                        .onChange(of: geo.frame(in: .global)) { _, f in viewFrame = f }
                }
            }
            .phaseAnimator(
                isDwelling ? [DwellPhase.idle, .bloom, .settle] : [.idle],
                trigger: isDwelling
            ) { view, phase in
                let roll = DeviceMotionService.shared.normalizedRoll
                let pitch = DeviceMotionService.shared.normalizedPitch
                let sparkle = phase.sparkleIntensity
                view
                    .scaleEffect(1.0 + phase.scaleBoost)
                    // Do NOT use .drawingGroup() — child content may have
                    // .glassEffect() which is a compositor-level effect that
                    // cannot be rasterized into a Metal texture.
                    .visualEffect { v, proxy in
                        v.colorEffect(
                            ShaderLibrary.specularSparkle(
                                .float2(proxy.safeShaderSize),
                                .float(Float(roll)),
                                .float(Float(pitch)),
                                .float(sparkle)
                            )
                        )
                    }
            } animation: { phase in
                switch phase {
                case .idle:   .spring(duration: 0.5, bounce: 0.1)
                case .bloom:  .spring(duration: 0.8, bounce: 0.2)
                case .settle: .spring(duration: 0.6, bounce: 0.15)
                }
            }
            // Timer runs at 15 Hz ONLY while view is in hierarchy.
            // SwiftUI's .onReceive auto-cancels the subscription when
            // the view is removed from the hierarchy.
            .onReceive(
                Timer.publish(every: 1.0 / 15.0, on: .main, in: .common).autoconnect()
            ) { _ in
                guard isAppActive else { return }
                trackDwell()
            }
            .onAppear { DeviceMotionService.shared.startIfNeeded() }
            .onDisappear { resetDwell() }
            // Immediately freeze dwell tracking when app backgrounds
            .onReceive(
                NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            ) { _ in
                isAppActive = false
                resetDwell()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            ) { _ in
                isAppActive = true
                lastCheck = .now
            }
    }

    // MARK: - Dwell Tracking

    private func trackDwell() {
        let gaze = GazeTrackingService.shared
        guard gaze.isTracking else { resetDwell(); return }

        let screen = (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen.bounds.size) ?? CGSize(width: 393, height: 852)
        let gazeScreen = CGPoint(
            x: gaze.gazePoint.x * screen.width,
            y: gaze.gazePoint.y * screen.height
        )

        let now = Date.now
        // Expand hit area slightly so micro-saccades don't break dwell
        if viewFrame.insetBy(dx: -20, dy: -20).contains(gazeScreen) {
            dwellAccumulator += now.timeIntervalSince(lastCheck)
            lastCheck = now
            if dwellAccumulator >= dwellThreshold && !isDwelling {
                isDwelling = true
                PSHaptics.shared.lightTap()
            }
        } else {
            resetDwell()
        }
    }

    private func resetDwell() {
        dwellAccumulator = 0
        lastCheck = .now
        if isDwelling { isDwelling = false }
    }
}

// MARK: - Dwell Phases

private enum DwellPhase: CaseIterable {
    case idle, bloom, settle

    var scaleBoost: CGFloat {
        switch self {
        case .idle:   0
        case .bloom:  0.04   // 4 % scale-up at peak
        case .settle: 0.015  // settle to subtle elevation
        }
    }

    var sparkleIntensity: Float {
        switch self {
        case .idle:   0
        case .bloom:  0.25   // 25 % power/density boost
        case .settle: 0.12
        }
    }
}

// MARK: - View Extension

extension View {
    /// Activates the "Living Menu" effect: gaze-dwell phaseAnimator bloom
    /// with gyroscope-tracked specular sparkle.
    func livingMenu() -> some View {
        modifier(LivingMenuModifier())
    }
}
