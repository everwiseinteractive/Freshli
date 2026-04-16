import SwiftUI
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - Shader Warm-Up Service (Legacy — Metal Shaders Removed)
// Metal stitchable shaders have been replaced with pure SwiftUI
// animations to eliminate iOS 26 rendering prohibition issues.
// This service is retained as a compatibility shim — `shadersAvailable`
// always returns `false` so any remaining Metal code paths are
// safely bypassed, and `warmUpAll()` is a no-op.
// ══════════════════════════════════════════════════════════════════

@MainActor
enum ShaderWarmUpService {
    private static let logger = Logger(subsystem: "com.freshli", category: "ShaderWarmUp")

    /// Always returns `false` — Metal stitchable shaders have been
    /// replaced with pure SwiftUI animations. Any remaining code that
    /// checks this property will use its non-Metal fallback path.
    nonisolated static let shadersAvailable: Bool = false

    /// No-op — Metal shader pre-compilation is no longer needed.
    /// Retained for call-site compatibility (FreshliApp.swift).
    static func warmUpAll() {
        logger.info("Shader warm-up: skipped (Metal shaders replaced with SwiftUI animations)")
    }
}
