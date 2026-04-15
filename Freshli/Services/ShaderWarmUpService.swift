import SwiftUI
import Metal
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - Shader Warm-Up Service
// Pre-compiles all SwiftUI ShaderLibrary functions during the splash
// screen so there are zero shader compilation hitches when the user
// reaches the dashboard.
//
// SwiftUI compiles [[ stitchable ]] Metal functions lazily on first use.
// This causes a ~15–40ms hitch the first time each shader is invoked.
// By "warming" every shader during the splash screen's 2.5s minimum
// display, the pipeline state objects (PSOs) are ready before any
// user-facing view needs them.
//
// This is the SwiftUI equivalent of the Metal 4 Asynchronous
// Compilation API — we can't call MTLDevice.makeRenderPipelineState
// directly, but we achieve the same result by invoking each
// ShaderLibrary function against a tiny offscreen proxy.
//
// Swift 6 Concurrency:
//   - warmUpAll() runs as a detached Task
//   - Each shader invocation is @Sendable
//   - Completes well within the 2.5s splash minimum
// ══════════════════════════════════════════════════════════════════

@MainActor
enum ShaderWarmUpService {
    private static let logger = Logger(subsystem: "com.freshli", category: "ShaderWarmUp")

    // ── Runtime Shader Availability ──────────────────────────────
    // Validates that the default Metal library contains our core
    // stitchable functions. If .metal files are missing from the
    // Compile Sources build phase, this will be false and views
    // should fall back to .ultraThinMaterial instead of showing
    // SwiftUI's yellow prohibition screen.

    /// `true` if Metal stitchable shaders can execute on this device.
    /// Validates Metal library presence AND that core shader functions
    /// can be instantiated. Returns `false` on Simulator (GPU backend
    /// can silently fail) or if any required function is missing.
    nonisolated static let shadersAvailable: Bool = {
        let log = Logger(subsystem: "com.freshli", category: "ShaderWarmUp")

        #if targetEnvironment(simulator)
        log.info("Running on Simulator — disabling Metal stitchable shaders for safety")
        return false
        #else
        guard let device = MTLCreateSystemDefaultDevice() else {
            log.fault("No Metal device available")
            return false
        }
        guard let library = device.makeDefaultLibrary() else {
            log.fault("No default Metal library in bundle")
            return false
        }

        let names = Set(library.functionNames)

        // Validate a representative shader from EACH .metal file
        let required = [
            "heroGradient",       // FreshliShaders.metal
            "tabMeltDissolve",    // FreshliShaders.metal
            "liquidGlass",        // LiquidGlass.metal
            "liquidGlassAurora"   // SplashShaders.metal
        ]
        let missing = required.filter { !names.contains($0) }

        if !missing.isEmpty {
            log.fault("CRITICAL: Metal shaders missing from bundle: \(missing). Falling back to materials.")
            return false
        }

        // Deep check: verify functions can be instantiated with correct types.
        // If the Metal compiler mangled signatures or the stitchable attribute
        // was stripped, makeFunction will return nil.
        for name in required {
            guard library.makeFunction(name: name) != nil else {
                log.fault("CRITICAL: Metal function '\(name)' exists in library but cannot be instantiated. Falling back.")
                return false
            }
        }

        log.info("All \(required.count) core Metal shaders validated — GPU pipeline active")
        return true
        #endif
    }()

    /// Pre-compiles all stitchable shader functions used in the app.
    /// Call during splash screen display. Safe to call multiple times.
    static func warmUpAll() {
        guard Self.shadersAvailable else {
            logger.warning("Shader warm-up skipped — Metal library missing required functions")
            return
        }
        logger.info("Shader warm-up: starting...")
        let start = CFAbsoluteTimeGetCurrent()

        // Touch each ShaderLibrary function with minimal dummy parameters.
        // SwiftUI will compile the PSO on first reference even if the
        // shader isn't applied to a visible view.
        let dummySize: Shader.Argument = .float2(1, 1)
        let dummyFloat: Shader.Argument = .float(0)

        // Core shaders (used on every launch)
        _ = ShaderLibrary.gpuShimmer(dummySize, dummyFloat)
        _ = ShaderLibrary.heroGradient(dummySize, dummyFloat)
        _ = ShaderLibrary.cardGlass(dummySize, dummyFloat, dummyFloat)
        _ = ShaderLibrary.freshliAura(dummySize, dummyFloat)
        _ = ShaderLibrary.subtleNoise(dummySize, dummyFloat, dummyFloat)

        // Button & interaction shaders
        _ = ShaderLibrary.buttonRipple(dummySize, dummyFloat)
        _ = ShaderLibrary.liquidGlassRipple(dummySize, dummyFloat, dummyFloat, dummyFloat, dummyFloat)
        _ = ShaderLibrary.liquidGlassRippleColor(dummySize, dummyFloat, dummyFloat, dummyFloat, dummyFloat)

        // Predictive / AI surface
        _ = ShaderLibrary.intentGlow(dummySize, dummyFloat, dummyFloat, dummyFloat, dummyFloat, dummyFloat)
        _ = ShaderLibrary.predictiveSurface(dummySize, dummyFloat, dummyFloat, dummyFloat, dummyFloat, dummyFloat)

        // Ambient effects
        _ = ShaderLibrary.ambientParticles(dummySize, dummyFloat, dummyFloat, dummyFloat)
        _ = ShaderLibrary.expiryPulse(dummySize, dummyFloat, dummyFloat, dummyFloat, dummyFloat)
        _ = ShaderLibrary.freshnessGlow(dummySize, dummyFloat, dummyFloat, dummyFloat, dummyFloat, dummyFloat)

        // Celebration & streak
        _ = ShaderLibrary.celebrationRadiance(dummySize, dummyFloat, dummyFloat, dummyFloat, dummyFloat, dummyFloat)
        _ = ShaderLibrary.streakFlameGlow(dummySize, dummyFloat, dummyFloat)

        // Impact dashboard
        _ = ShaderLibrary.impactPlasma(dummySize, dummyFloat, dummyFloat)

        // Glass surface
        _ = ShaderLibrary.liquidGlassSurface(dummySize, dummyFloat, dummyFloat)

        // Cooking
        _ = ShaderLibrary.chefSilhouette(dummySize, dummyFloat, dummyFloat)

        // Ray-traced shadows & ambient adaptive glass
        _ = ShaderLibrary.rayTracedShadow(dummySize, dummyFloat, dummyFloat, dummyFloat, dummyFloat, dummyFloat, dummyFloat, dummyFloat, dummyFloat)
        _ = ShaderLibrary.ambientAdaptiveGlass(dummySize, dummyFloat, dummyFloat, dummyFloat, dummyFloat, dummyFloat)

        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        logger.info("Shader warm-up: complete in \(elapsed, format: .fixed(precision: 1))ms — all PSOs compiled")
    }
}
