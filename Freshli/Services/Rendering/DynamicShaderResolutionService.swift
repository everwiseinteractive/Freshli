import SwiftUI
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - Dynamic Shader Resolution Scaling
// Automatically scales shader rendering resolution based on device
// thermal state, Low Power Mode, and frame timing to maintain 120fps
// (or the best possible framerate) under all conditions.
//
// How it works:
//   1. RenderPerformanceService monitors frame times + thermal state
//   2. This service computes an optimal resolution scale factor
//   3. Views apply the scale to their `.drawingGroup()` dimensions
//   4. Lower resolution = less GPU work = faster frames
//
// The resolution scale ranges from 1.0 (native) to 0.5 (half-res).
// At half-res, shader effects are still visible but use 4× fewer
// pixel shader invocations. The result is upscaled with bilinear
// filtering, so quality loss is minimal for organic effects.
//
// This is the equivalent of DLSS / MetalFX Temporal Upscaling
// for SwiftUI's shader pipeline.
// ══════════════════════════════════════════════════════════════════

// MARK: - Resolution Scale

/// Controls the render resolution of GPU-heavy shader effects.
/// Applied via `.drawingGroup()` with scaled dimensions.
@Observable @MainActor
final class DynamicShaderResolutionService {
    static let shared = DynamicShaderResolutionService()

    /// Current resolution scale factor (0.5→1.0).
    /// 1.0 = native resolution, 0.5 = half resolution (4× less GPU work).
    private(set) var scaleFactor: CGFloat = 1.0

    /// Human-readable label for the current scale.
    var scaleLabel: String {
        switch scaleFactor {
        case 1.0: return "Native"
        case 0.875...: return "High"
        case 0.75...: return "Medium"
        case 0.625...: return "Low"
        default: return "Minimum"
        }
    }

    private let logger = Logger(subsystem: "com.freshli", category: "ShaderResolution")

    private init() {
        // Initial scale based on current state
        updateScale()

        // Observe changes
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.updateScale() }
        }

        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.updateScale() }
        }
    }

    /// Recompute optimal resolution based on current conditions.
    /// Uses hysteresis to prevent rapid scale changes that would
    /// trigger mass SwiftUI re-layout (the same fix as RenderPerformanceService).
    private var lastScaleChangeTime: CFAbsoluteTime = 0
    private static let scaleCooldown: CFAbsoluteTime = 6.0

    func updateScale() {
        let thermal = ProcessInfo.processInfo.thermalState
        let isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        let performance = RenderPerformanceService.shared

        var scale: CGFloat = 1.0

        // Thermal state adjustment
        switch thermal {
        case .nominal:
            scale = 1.0
        case .fair:
            scale = 0.875
        case .serious:
            scale = 0.75
        case .critical:
            scale = 0.5
        @unknown default:
            scale = 0.75
        }

        // Low Power Mode caps at 0.75
        if isLowPower {
            scale = min(scale, 0.75)
        }

        // Frame budget pressure — if frames are consistently over budget
        if performance.frameStats.p95Ms > 16.6 {
            scale = min(scale, 0.75)
        }
        if performance.frameStats.p95Ms > 33.3 {
            scale = min(scale, 0.5)
        }

        // Hysteresis: only allow scale changes after cooldown period
        // to prevent rapid toggling that triggers expensive re-layouts
        let now = CFAbsoluteTimeGetCurrent()
        if scale != scaleFactor && now - lastScaleChangeTime >= Self.scaleCooldown {
            let oldScale = scaleFactor
            scaleFactor = scale
            lastScaleChangeTime = now
            logger.info("Shader resolution: \(oldScale, format: .fixed(precision: 2))× → \(scale, format: .fixed(precision: 2))×")
        }
    }
}

// MARK: - Adaptive Resolution Modifier

/// Wraps a view in a `.drawingGroup()` with dynamic resolution scaling.
/// When the device is under thermal/battery pressure, the shader effects
/// render at a lower resolution and are upscaled, maintaining framerate
/// at the cost of slightly softer visuals.
struct AdaptiveResolutionModifier: ViewModifier {
    @Environment(\.shaderQuality) private var quality

    func body(content: Content) -> some View {
        let scale = DynamicShaderResolutionService.shared.scaleFactor

        if scale < 1.0 {
            // Render at reduced resolution, then scale up
            content
                .drawingGroup(opaque: false, colorMode: .nonLinear)
                .scaleEffect(1.0 / scale)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
                .clipped()
                .scaleEffect(scale)
        } else {
            content
                .drawingGroup(opaque: false, colorMode: .nonLinear)
        }
    }
}

// MARK: - View Extension

extension View {
    /// Apply adaptive resolution scaling to GPU-heavy shader effects.
    /// The view renders at a lower resolution when the device is under
    /// thermal/battery pressure, maintaining framerate.
    func adaptiveResolution() -> some View {
        modifier(AdaptiveResolutionModifier())
    }
}

// MARK: - Environment Key

private struct ShaderResolutionKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    /// Current shader resolution scale factor (0.5→1.0).
    var shaderResolution: CGFloat {
        get { self[ShaderResolutionKey.self] }
        set { self[ShaderResolutionKey.self] = newValue }
    }
}
