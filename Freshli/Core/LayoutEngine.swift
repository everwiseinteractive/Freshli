import SwiftUI
import UIKit

// MARK: - ScreenMetrics (iOS 26+ replacement for UIScreen.main)
// In iOS 26 `UIScreen.main` is deprecated; callers must derive the screen
// from the active `UIWindowScene`. This helper centralises that lookup so
// the rest of the app can keep using a single, concise call site.

@MainActor
enum ScreenMetrics {
    /// Bounds of the screen backing the currently-active window scene.
    /// Falls back to a sensible iPhone-sized rectangle if no scene is active
    /// yet (e.g. during very early launch or in certain previews).
    static var bounds: CGRect {
        if let scene = activeWindowScene {
            return scene.screen.bounds
        }
        return CGRect(x: 0, y: 0, width: 390, height: 844)
    }

    static var size: CGSize { bounds.size }
    static var width: CGFloat { bounds.width }
    static var height: CGFloat { bounds.height }

    private static var activeWindowScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}

// MARK: - LayoutEngine
// Universal Scaling Engine for Freshli.
// @Observable + @MainActor for concurrency-safe geometry tracking during
// orientation changes, window resizing (iPad/Stage Manager), and Dynamic Type.
//
// Provides a single source of truth for device geometry that views can read
// through the SwiftUI environment. Prefer this over raw UIScreen access when
// you need reactive updates (e.g., rotation).

@Observable
@MainActor
final class LayoutEngine {

    // MARK: - Singleton

    static let shared = LayoutEngine()

    // MARK: - Published Geometry

    /// Current viewport width (updated by GeometryReader or scene phase).
    private(set) var viewportWidth: CGFloat = ScreenMetrics.width
    /// Current viewport height.
    private(set) var viewportHeight: CGFloat = ScreenMetrics.height
    /// Safe area insets captured from the root GeometryReader.
    private(set) var safeArea: EdgeInsets = .init()

    // MARK: - Reference Dimensions (Base-4 grid, iPhone 17 standard)

    /// Design reference width — all proportional math anchors here.
    static let referenceWidth: CGFloat = 392  // 392 = 98 × 4 (base-4 aligned, ≈ iPhone 17)
    /// Design reference height.
    static let referenceHeight: CGFloat = 852

    // MARK: - Derived Scale Factors

    /// Width scale factor clamped to a sane range.
    var widthScale: CGFloat {
        let raw = viewportWidth / Self.referenceWidth
        return min(max(raw, 0.85), 1.20)
    }

    /// Height scale factor (useful for vertical rhythm adjustments).
    var heightScale: CGFloat {
        let raw = viewportHeight / Self.referenceHeight
        return min(max(raw, 0.85), 1.20)
    }

    /// Geometric mean of width & height scales — good for icons/avatars.
    var uniformScale: CGFloat {
        sqrt(widthScale * heightScale)
    }

    // MARK: - Device Class

    enum DeviceClass: Sendable {
        case compact   // SE-class, width ≤ 375
        case standard  // iPhone 15/16/17, 376–419
        case expanded  // Pro Max / iPad compact, ≥ 420
    }

    var deviceClass: DeviceClass {
        if viewportWidth <= 375 { return .compact }
        if viewportWidth >= 420 { return .expanded }
        return .standard
    }

    var isCompact: Bool { deviceClass == .compact }
    var isExpanded: Bool { deviceClass == .expanded }

    // MARK: - Base-4 Dynamic Spacing

    /// Scales a base-4 spacing token proportionally to viewport width.
    /// Input should be a base-4 value (4, 8, 12, 16, 20, 24, 32, 40, 48…).
    /// Output is rounded to the nearest multiple of 4 to preserve pixel crispness.
    func spacing(_ base: CGFloat) -> CGFloat {
        let scaled = base * widthScale
        return (scaled / 4).rounded() * 4
    }

    /// Scales a dimension proportionally (not snapped to base-4 grid).
    func scaled(_ value: CGFloat) -> CGFloat {
        (value * widthScale).rounded()
    }

    /// Scales font size with a gentler curve — fonts shrink on compact but
    /// barely grow on expanded to prevent text overflow.
    func scaledFont(_ size: CGFloat) -> CGFloat {
        let curve = 1.0 + (widthScale - 1.0) * 0.5
        let clamped = min(curve, 1.02)  // near-zero upscale
        return max((size * clamped).rounded(.down), 1)
    }

    // MARK: - Dynamic Padding Helpers

    /// Screen-edge horizontal padding that adapts per device class.
    var screenHorizontalPadding: CGFloat {
        switch deviceClass {
        case .compact:  return spacing(16)
        case .standard: return spacing(24)
        case .expanded: return spacing(28)
        }
    }

    /// Vertical section spacing between major content blocks.
    var sectionSpacing: CGFloat { spacing(24) }

    /// Inner card padding.
    var cardPadding: CGFloat { spacing(24) }

    /// Grid gap for dashboard tiles.
    var gridGap: CGFloat { spacing(12) }

    // MARK: - Safe Area Helpers

    /// Top inset including status bar.
    var safeTop: CGFloat { safeArea.top }
    /// Bottom inset including home indicator.
    var safeBottom: CGFloat { safeArea.bottom }

    /// Whether the bottom safe area is large enough to indicate a home-indicator device.
    var hasHomeIndicator: Bool { safeArea.bottom > 20 }

    // MARK: - Geometry Update

    /// Call from a root-level GeometryReader to keep the engine in sync.
    func update(size: CGSize, safeArea: EdgeInsets) {
        guard size.width > 0, size.height > 0 else { return }
        if self.viewportWidth != size.width {
            self.viewportWidth = size.width
        }
        if self.viewportHeight != size.height {
            self.viewportHeight = size.height
        }
        if self.safeArea != safeArea {
            self.safeArea = safeArea
        }
    }

    /// Lightweight update from the active window scene's screen.
    /// Prefer the GeometryReader path when possible.
    func syncFromScreen() {
        let bounds = ScreenMetrics.bounds
        if viewportWidth != bounds.width || viewportHeight != bounds.height {
            viewportWidth = bounds.width
            viewportHeight = bounds.height
        }
    }
}

// MARK: - EnvironmentValues Integration

extension EnvironmentValues {
    /// Access the shared LayoutEngine from any view via `@Environment(\.layoutEngine)`.
    @Entry var layoutEngine: LayoutEngine = .shared
}

// MARK: - Root Geometry Reader

/// Attach at the app root (inside WindowGroup) to feed live geometry into the engine.
/// Renders as a clear background — zero layout cost.
struct LayoutEngineReader: ViewModifier {
    @Environment(\.layoutEngine) private var engine

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            engine.update(size: proxy.size, safeArea: proxy.safeAreaInsets)
                        }
                        .onChange(of: proxy.size) { _, newSize in
                            engine.update(size: newSize, safeArea: proxy.safeAreaInsets)
                        }
                }
            }
    }
}

extension View {
    /// Installs the LayoutEngine geometry reader at this level of the view hierarchy.
    /// Typically called once on the root view inside WindowGroup.
    func installLayoutEngine() -> some View {
        modifier(LayoutEngineReader())
            .environment(\.layoutEngine, LayoutEngine.shared)
    }
}
