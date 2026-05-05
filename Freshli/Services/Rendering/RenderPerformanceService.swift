import SwiftUI
import QuartzCore
import Combine
import Metal
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - Render Performance Service
// Real-time frame timing, adaptive shader quality, and Metal
// Performance HUD for the Freshli SwiftUI shader pipeline.
//
// SwiftUI manages the GPU pipeline internally via ShaderLibrary +
// [[ stitchable ]] MSL shaders. We can't access MTLDevice directly,
// but we CAN monitor frame cadence, thermal state, and Low Power
// Mode to dynamically scale shader complexity — the SwiftUI
// equivalent of Metal 4 Argument Tables / Residency Sets.
//
// Architecture:
//   1. CADisplayLink tracks frame delivery timestamps
//   2. ProcessInfo monitors thermal state + Low Power Mode
//   3. AdaptiveShaderQuality environment key propagates quality tier
//   4. Each shader modifier reads the tier and adjusts frequency/detail
//
// Usage:
//   @Environment(\.shaderQuality) private var quality
//   TimelineView(.animation(minimumInterval: quality.frameInterval)) { ... }
// ══════════════════════════════════════════════════════════════════

// MARK: - Shader Quality Tier

/// Adaptive quality level that controls shader complexity across the app.
/// Propagated via SwiftUI Environment for per-view consumption.
enum ShaderQualityTier: Int, Comparable, Sendable {
    case ultra = 4    // Full 120Hz, all effects at max detail
    case high = 3     // 60Hz cap, all effects enabled
    case medium = 2   // 30Hz cap, reduce particle density + disable caustics
    case low = 1      // 15Hz cap, disable complex shaders, basic effects only
    case minimal = 0  // Static rendering only — no TimelineView animations

    static func < (lhs: ShaderQualityTier, rhs: ShaderQualityTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Minimum frame interval for TimelineView animations at this tier.
    var frameInterval: TimeInterval {
        switch self {
        case .ultra:   return 1.0 / 120.0  // 8.3ms — ProMotion
        case .high:    return 1.0 / 60.0   // 16.6ms
        case .medium:  return 1.0 / 30.0   // 33.3ms
        case .low:     return 1.0 / 15.0   // 66.6ms
        case .minimal: return 1.0          // Static
        }
    }

    /// Whether complex multi-pass shaders should run.
    var enableComplexShaders: Bool {
        self >= .medium
    }

    /// Whether particle / caustic effects should render.
    var enableParticles: Bool {
        self >= .high
    }

    /// Whether distortion effects (vertex displacement) should run.
    var enableDistortion: Bool {
        self >= .medium
    }

    /// Particle density multiplier (1.0 = full, 0.0 = none).
    var particleDensity: Float {
        switch self {
        case .ultra:   return 1.0
        case .high:    return 0.8
        case .medium:  return 0.4
        case .low:     return 0.0
        case .minimal: return 0.0
        }
    }
}

// MARK: - Environment Key

private struct ShaderQualityKey: EnvironmentKey {
    static let defaultValue: ShaderQualityTier = .high
}

extension EnvironmentValues {
    /// Current adaptive shader quality tier — read in views to scale effects.
    var shaderQuality: ShaderQualityTier {
        get { self[ShaderQualityKey.self] }
        set { self[ShaderQualityKey.self] = newValue }
    }
}

// MARK: - Frame Timing Statistics

/// Rolling statistics for the last N frames.
struct FrameTimingStats: Sendable {
    let averageMs: Double
    let p95Ms: Double
    let p99Ms: Double
    let maxMs: Double
    let droppedFrames: Int
    let totalFrames: Int

    /// Whether we're consistently hitting the 8.3ms ProMotion budget.
    var hitsProMotionBudget: Bool { p95Ms <= 8.3 }
    /// Whether we're consistently hitting the 16.6ms 60Hz budget.
    var hits60HzBudget: Bool { p95Ms <= 16.6 }
}

// MARK: - Render Performance Service

@Observable @MainActor
final class RenderPerformanceService {
    static let shared = RenderPerformanceService()

    // MARK: - Published State

    /// Current adaptive quality tier (drives shader complexity).
    private(set) var currentTier: ShaderQualityTier = .high

    /// Latest frame timing stats (updated every 60 frames).
    private(set) var frameStats: FrameTimingStats = FrameTimingStats(
        averageMs: 0, p95Ms: 0, p99Ms: 0, maxMs: 0,
        droppedFrames: 0, totalFrames: 0
    )

    /// Whether the Metal Performance HUD overlay is visible.
    var showPerformanceHUD = false

    /// Current thermal state description.
    var thermalStateLabel: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:  return "Cool"
        case .fair:     return "Warm"
        case .serious:  return "Hot"
        case .critical: return "Throttled"
        @unknown default: return "Unknown"
        }
    }

    // MARK: - Private

    private var displayLink: CADisplayLink?
    private var frameTimes: [Double] = []
    private var lastTimestamp: CFTimeInterval = 0
    private var droppedCount = 0
    private let sampleWindow = 120  // ~2 seconds at 60Hz
    private let logger = Logger(subsystem: "com.freshli", category: "RenderPerformance")

    // Hysteresis state — prevents rapid tier oscillation that cascades
    // environment changes through the entire view hierarchy.
    private var lastTierChangeTime: CFAbsoluteTime = 0
    private var consecutiveUpVotes = 0
    private static let tierChangeCooldown: CFAbsoluteTime = 8.0  // seconds
    private static let requiredUpVotes = 3  // consecutive good windows before stepping up

    /// Whether the device has a Metal GPU that supports our shader pipeline.
    /// Older devices without Apple GPU Family 4+ fall back to static glass.
    let supportsAdvancedShaders: Bool

    private init() {
        // Metal device capability gate — ensures graceful fallback on
        // older hardware that can't run our [[ stitchable ]] MSL pipeline.
        if let device = MTLCreateSystemDefaultDevice() {
            // Apple GPU Family 4 (A11+) supports all features we use:
            // compute shaders, SIMD-scoped operations, read-write textures.
            supportsAdvancedShaders = device.supportsFamily(.apple4)
            if !supportsAdvancedShaders {
                logger.warning("Metal GPU family < apple4 — shader pipeline disabled, using static glass fallback")
            }
        } else {
            // No Metal device (Simulator without GPU, very old hardware)
            supportsAdvancedShaders = false
            logger.warning("No Metal device available — all shaders disabled")
        }

        // If device can't run shaders, lock to minimal quality
        if !supportsAdvancedShaders {
            currentTier = .minimal
        }

        startMonitoring()
        observeThermalState()
        observeLowPowerMode()
    }

    // Note: displayLink is invalidated when the service is deallocated via
    // the CADisplayLink target's weak reference going nil. No explicit deinit needed.

    // MARK: - CADisplayLink Frame Monitoring

    private func startMonitoring() {
        let link = CADisplayLink(target: DisplayLinkTarget(service: self),
                                 selector: #selector(DisplayLinkTarget.tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    fileprivate func handleFrame(_ link: CADisplayLink) {
        let now = link.timestamp
        guard lastTimestamp > 0 else {
            lastTimestamp = now
            return
        }

        let dt = (now - lastTimestamp) * 1000.0  // ms
        lastTimestamp = now

        // Detect dropped frames (> 2× expected interval)
        let expectedInterval = link.targetTimestamp - link.timestamp
        if dt > expectedInterval * 1000.0 * 2.0 {
            droppedCount += 1
        }

        frameTimes.append(dt)

        // Compute stats every sampleWindow frames
        if frameTimes.count >= sampleWindow {
            computeStats()
            adaptQuality()
            frameTimes.removeAll(keepingCapacity: true)
            droppedCount = 0
        }
    }

    private func computeStats() {
        let sorted = frameTimes.sorted()
        let count = sorted.count
        guard count > 0 else { return }

        let avg = sorted.reduce(0, +) / Double(count)
        let p95Index = Int(Double(count) * 0.95)
        let p99Index = Int(Double(count) * 0.99)

        frameStats = FrameTimingStats(
            averageMs: avg,
            p95Ms: sorted[min(p95Index, count - 1)],
            p99Ms: sorted[min(p99Index, count - 1)],
            maxMs: sorted.last ?? 0,
            droppedFrames: droppedCount,
            totalFrames: count
        )
    }

    // MARK: - Adaptive Quality (with Hysteresis)
    //
    // Rapid tier changes trigger SwiftUI environment propagation which
    // re-evaluates every view body in the hierarchy — the very thing
    // that causes the frame budget to be exceeded. Without hysteresis
    // we enter a feedback loop:
    //   slow frame → step down → env change → mass re-layout → slow frame → step up → repeat
    //
    // The fix: asymmetric thresholds + cooldown + consecutive-vote gating.

    private func adaptQuality() {
        // Devices that can't run our Metal pipeline stay locked at minimal.
        guard supportsAdvancedShaders else { return }

        let thermal = ProcessInfo.processInfo.thermalState
        let isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

        // Start from ultra, downgrade based on conditions
        var targetTier: ShaderQualityTier = .ultra

        // Thermal pressure
        switch thermal {
        case .nominal:
            break  // Keep ultra
        case .fair:
            targetTier = .high
        case .serious:
            targetTier = .medium
        case .critical:
            targetTier = .low
        @unknown default:
            targetTier = .medium
        }

        // Low Power Mode caps at medium
        if isLowPower && targetTier > .medium {
            targetTier = .medium
        }

        // Frame budget pressure — asymmetric thresholds to prevent oscillation.
        // Step DOWN aggressively (react to bad frames fast) but step UP slowly
        // (require sustained good performance before increasing quality).
        if frameStats.p95Ms > 16.6 && targetTier > .medium {
            targetTier = .medium
        }
        if frameStats.p95Ms > 33.3 && targetTier > .low {
            targetTier = .low
        }

        // ── Hysteresis gating ──────────────────────────────────────
        let now = CFAbsoluteTimeGetCurrent()

        if targetTier < currentTier {
            // Stepping DOWN — allow immediately (protect frame budget)
            // but respect cooldown to avoid rapid flapping
            if now - lastTierChangeTime >= Self.tierChangeCooldown {
                let oldTier = currentTier
                currentTier = targetTier
                lastTierChangeTime = now
                consecutiveUpVotes = 0
                logger.info("Shader quality ↓ \(oldTier.rawValue) → \(targetTier.rawValue) (p95: \(self.frameStats.p95Ms, format: .fixed(precision: 1))ms)")
            }
        } else if targetTier > currentTier {
            // Stepping UP — require multiple consecutive good sample windows
            // AND a generous cooldown to avoid the up/down feedback loop.
            // Only step up if p95 is well below budget (12ms, not 16.6ms).
            if frameStats.p95Ms < 12.0 {
                consecutiveUpVotes += 1
            } else {
                consecutiveUpVotes = 0
            }

            if consecutiveUpVotes >= Self.requiredUpVotes &&
               now - lastTierChangeTime >= Self.tierChangeCooldown {
                let oldTier = currentTier
                currentTier = targetTier
                lastTierChangeTime = now
                consecutiveUpVotes = 0
                logger.info("Shader quality ↑ \(oldTier.rawValue) → \(targetTier.rawValue) (sustained p95: \(self.frameStats.p95Ms, format: .fixed(precision: 1))ms)")
            }
        } else {
            // At target — reset up-vote counter
            consecutiveUpVotes = 0
        }
    }

    // MARK: - Thermal & Power Observers

    private func observeThermalState() {
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.adaptQuality()
            }
        }
    }

    private func observeLowPowerMode() {
        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.adaptQuality()
            }
        }
    }
}

// MARK: - CADisplayLink Target (prevents retain cycle)

private class DisplayLinkTarget {
    weak var service: RenderPerformanceService?

    init(service: RenderPerformanceService) {
        self.service = service
    }

    @objc func tick(_ link: CADisplayLink) {
        Task { @MainActor in
            service?.handleFrame(link)
        }
    }
}

// MARK: - Metal Performance HUD Overlay

/// Debug overlay showing real-time frame timing statistics.
/// Toggle via `RenderPerformanceService.shared.showPerformanceHUD = true`
/// or triple-tap the version label in ProfileView.
struct MetalPerformanceHUD: View {
    let service: RenderPerformanceService

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Metal Performance")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                statColumn(label: "AVG", value: service.frameStats.averageMs)
                statColumn(label: "P95", value: service.frameStats.p95Ms)
                statColumn(label: "P99", value: service.frameStats.p99Ms)
                statColumn(label: "MAX", value: service.frameStats.maxMs)
            }

            HStack(spacing: 12) {
                Text("Drops: \(service.frameStats.droppedFrames)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.yellow)

                Text("Tier: \(tierLabel)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(tierColor)

                Text("Res: \(DynamicShaderResolutionService.shared.scaleLabel)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.cyan)

                Text(service.thermalStateLabel)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(thermalColor)

                if ProcessInfo.processInfo.isLowPowerModeEnabled {
                    Text("LPM")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.orange)
                }
            }

            // Prefetch & TTI stats
            HStack(spacing: 12) {
                let prefetch = PrefetchCoordinator.shared
                let _ = TTIService.shared

                Text("Warm: \(prefetch.warmTabs.count)/4")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(prefetch.warmTabs.count >= 4 ? .green : .yellow)

                Text("TTI: \(String(format: "%.0f", prefetch.averageTTI))ms")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(prefetch.allTabsWithinBudget ? .green : .red)

                Text("Gen: \(FreshliDataStore.shared.generation)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.gray)

                if let cold = ColdLaunchTracker.shared.coldLaunchMs {
                    Text("Cold: \(String(format: "%.0f", cold))ms")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(cold <= 3000 ? .green : .red)
                }
            }
        }
        .padding(8)
        .background(.black.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .allowsHitTesting(false)
    }

    private func statColumn(label: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(.gray)
            Text(String(format: "%.1fms", value))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(value <= 8.3 ? .green : value <= 16.6 ? .yellow : .red)
        }
    }

    private var tierLabel: String {
        switch service.currentTier {
        case .ultra: return "ULTRA"
        case .high: return "HIGH"
        case .medium: return "MED"
        case .low: return "LOW"
        case .minimal: return "MIN"
        }
    }

    private var tierColor: Color {
        switch service.currentTier {
        case .ultra: return .green
        case .high: return .cyan
        case .medium: return .yellow
        case .low: return .orange
        case .minimal: return .red
        }
    }

    private var thermalColor: Color {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        @unknown default: return .gray
        }
    }
}

// MARK: - Visibility-Based Timeline Pausing

/// Modifier that pauses shader TimelineViews when the view scrolls offscreen.
/// Prevents GPU work for invisible shader animations — the SwiftUI equivalent
/// of Metal Residency Sets (only resident textures/buffers consume GPU memory;
/// only visible shaders consume GPU cycles).
struct ShaderVisibilityModifier: ViewModifier {
    @State private var isVisible = true

    func body(content: Content) -> some View {
        content
            .environment(\.shaderVisible, isVisible)
            .onScrollVisibilityChange { visible in
                isVisible = visible
            }
    }
}

private struct ShaderVisibleKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Whether the current view is visible on screen (for shader pausing).
    var shaderVisible: Bool {
        get { self[ShaderVisibleKey.self] }
        set { self[ShaderVisibleKey.self] = newValue }
    }
}

extension View {
    /// Pause shader TimelineViews when this view scrolls offscreen.
    func shaderVisibilityTracking() -> some View {
        modifier(ShaderVisibilityModifier())
    }
}
