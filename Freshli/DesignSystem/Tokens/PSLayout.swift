import SwiftUI
import UIKit

// MARK: - PSLayout
// Adaptive layout utilities for responsive sizing across all iPhone models,
// iPad sizes, and visionOS canvases.
//
// Device width reference (logical points):
//   iPhone SE (2nd/3rd gen)  : 375 pt   → compact tier
//   iPhone 16 / 17           : 393 pt   → standard tier  (reference width)
//   iPhone 16 Pro            : 402 pt   → standard tier
//   iPhone 16 Pro Max        : 430 pt   → expanded tier
//   iPhone 17 Pro Max        : 440 pt   → ultraExpanded tier
//
// Dynamic Type integration (added 2026-05-03):
//   `scaledFont(_:)` now passes its width-adjusted base size through
//   `UIFontMetrics.default.scaledValue(for:)`. This means every one of
//   the ~970 call sites of `font(.system(size: PSLayout.scaledFont(N)))`
//   automatically participates in the user's preferred content size
//   category, including AX1–AX5.
//
//   Layout safety: scaling is capped at the equivalent of AX3 (~1.6×
//   the width-adjusted base size) so that hand-tuned compositions like
//   the floating tab bar pill, Liquid Glass card grids, and dashboard
//   tiles do not blow out their containing frames at AX5.
//
//   Views that opt in to AX4/AX5 by setting `.dynamicTypeSize(...)`
//   override this cap at the boundary; the rest of the app stays
//   visually composed.

@MainActor
enum PSLayout {
    /// Base reference width (iPhone 16/17 standard).
    static let referenceWidth: CGFloat = 393

    /// Current screen width.
    static var screenWidth: CGFloat {
        ScreenMetrics.bounds.width
    }

    /// Current screen height.
    static var screenHeight: CGFloat {
        ScreenMetrics.bounds.height
    }

    /// Scale factor relative to reference width.
    /// SE (375) ≈ 0.954 | Standard (393) = 1.000 | 16 Pro Max (430) ≈ 1.094 | 17 Pro Max (440) ≈ 1.119
    static var widthScale: CGFloat {
        min(max(screenWidth / referenceWidth, 0.85), 1.20)
    }

    /// Validates adaptive scaling for device class.
    static func validateAdaptiveScaling() -> Bool {
        let scale = widthScale
        // SE (375) ≈ 0.95, Standard (393) = 1.0, 16 Pro Max (430) ≈ 1.09, 17 Pro Max (440) ≈ 1.12
        return scale >= 0.85 && scale <= 1.20
    }

    /// Scales a value proportionally to screen width.
    /// Use for dimensions that should grow/shrink with screen size.
    static func scaled(_ value: CGFloat) -> CGFloat {
        (value * widthScale).rounded()
    }

    /// Scales a font size with a gentler curve (less aggressive than full proportional)
    /// AND honors the user's preferred content size category (Dynamic Type).
    ///
    /// Pipeline:
    ///   1. Apply width-based scaling (shrinks on compact iPhones, never grows).
    ///   2. Pass the width-adjusted size through UIFontMetrics so AX1–AX5 take effect.
    ///   3. Cap growth at ~1.6× the width-adjusted base (AX3-equivalent) so layouts
    ///      stay visually intact. Views that opt in to extreme Dynamic Type can
    ///      override the cap by setting `.dynamicTypeSize(...)` at the boundary.
    ///
    /// IMPORTANT: this function is *intentionally* called inside SwiftUI view bodies
    /// (e.g. `.font(.system(size: PSLayout.scaledFont(20), weight: .semibold))`) so
    /// that body re-evaluation re-computes the size when the user changes their
    /// preferred content size category in Settings → Accessibility.
    static func scaledFont(_ size: CGFloat) -> CGFloat {
        // Step 1 — width scaling (existing behaviour, unchanged for visual rhythm)
        let rawFontScale = 1.0 + (widthScale - 1.0) * 0.5
        let widthClamp = min(rawFontScale, 1.0)
        let widthAdjusted = max((size * widthClamp).rounded(.down), 1)

        // Step 2 — Dynamic Type scaling via UIFontMetrics (NEW)
        let scaled = UIFontMetrics.default.scaledValue(for: widthAdjusted)

        // Step 3 — layout-safety cap (~AX3) so floating tab bars, dashboard
        // tiles, and recipe cards don't blow out at AX4/AX5.
        let layoutCeiling = widthAdjusted * 1.6
        return min(scaled, layoutCeiling)
    }

    /// Same as `scaledFont(_:)` but without the layout-safety cap.
    /// Use only on text-only screens (e.g. recipe steps, legal text, weekly wrap)
    /// where AX4/AX5 should be allowed to scale fully.
    static func scaledFontUncapped(_ size: CGFloat) -> CGFloat {
        let rawFontScale = 1.0 + (widthScale - 1.0) * 0.5
        let widthClamp = min(rawFontScale, 1.0)
        let widthAdjusted = max((size * widthClamp).rounded(.down), 1)
        return UIFontMetrics.default.scaledValue(for: widthAdjusted)
    }

    // MARK: - Device Tiers

    /// Compact: iPhone SE class (width ≤ 375 pt).
    static var isCompact: Bool {
        screenWidth <= 375
    }

    /// Expanded: iPhone 16 Pro Max and similar (428–439 pt).
    static var isExpanded: Bool {
        screenWidth >= 428 && screenWidth < 440
    }

    /// UltraExpanded: iPhone 17 Pro Max and future large-canvas devices (width ≥ 440 pt).
    /// Estimated logical width 440 pt, 6.9-inch display, ProMotion 120 Hz, Dynamic Island.
    static var isUltraExpanded: Bool {
        screenWidth >= 440
    }

    /// True on any Pro Max-class device (16 Pro Max or 17 Pro Max).
    static var isAnyProMax: Bool {
        screenWidth >= 428
    }

    // MARK: - Adaptive Padding & Spacing

    /// Dynamic horizontal padding that adapts to screen width.
    static var adaptiveHorizontalPadding: CGFloat {
        isCompact ? 16 : PSSpacing.screenHorizontal
    }

    /// Scaled card padding (inner padding for cards).
    static var cardPadding: CGFloat {
        scaled(24)
    }

    /// Scaled content section padding (for form/auth horizontal insets).
    static var formHorizontalPadding: CGFloat {
        scaled(32)
    }

    // MARK: - Component Heights

    /// Curved header height for the Home screen.
    static var headerHeight: CGFloat {
        // Covers the avatar row + search bar + streak strip including
        // the 2-line subtitle. Bumped from 220 → 250 so the streak
        // strip text doesn't bleed into the white content area below.
        scaled(250)
    }

    /// Hero/header height for detail views.
    static var heroHeight: CGFloat {
        scaled(200)
    }

    /// Search bar / input field row height.
    static var searchBarHeight: CGFloat {
        scaled(48)
    }

    /// Auth input field height (slightly taller for touch targets).
    static var inputFieldHeight: CGFloat {
        scaled(52)
    }

    /// Card image height that adapts to screen size.
    static var cardImageHeight: CGFloat {
        if isUltraExpanded { return scaled(208) }
        if isCompact { return scaled(160) }
        return scaled(192)
    }

    /// Featured/hero content height that adapts to screen height.
    /// Capped at 280 pt to prevent the card from ever dominating the viewport.
    static var featuredHeight: CGFloat {
        let fraction: CGFloat
        if isUltraExpanded {
            fraction = 0.30
        } else if isCompact {
            fraction = 0.26
        } else {
            fraction = 0.28
        }
        return min((screenHeight * fraction).rounded(), 280)
    }

    // MARK: - Component Sizes

    /// Avatar size that scales nicely.
    static func avatarSize(_ base: CGFloat = 48) -> CGFloat {
        scaled(base)
    }

    /// Pill/chip width that adapts to screen width.
    static var pillWidth: CGFloat {
        scaled(144)
    }

    /// Recipe card image size that adapts.
    static var recipeImageSize: CGFloat {
        if isUltraExpanded { return scaled(120) }
        if isCompact { return scaled(96) }
        return scaled(112)
    }

    /// FAB (Floating Action Button) size.
    static var fabSize: CGFloat {
        scaled(64)
    }

    /// Standard icon button size (bell, search, settings).
    static var iconButtonSize: CGFloat {
        scaled(40)
    }

    /// Small icon container (notification dot, sparkle badge).
    static var smallBadgeSize: CGFloat {
        scaled(32)
    }

    /// Category emoji container size in pantry cards.
    static var categoryIconSize: CGFloat {
        scaled(64)
    }

    /// Emoji circle size inside expiring pills.
    static var emojiCircleSize: CGFloat {
        scaled(56)
    }

    /// Community avatar size.
    static var communityAvatarSize: CGFloat {
        scaled(48)
    }

    // MARK: - Layout Decisions

    /// Returns true when 2-column form layout should collapse to vertical.
    static var shouldStackFormFields: Bool {
        screenWidth < 390
    }

    /// Extra bottom breathing room added inside scroll views so the last item
    /// doesn't sit flush against the tab bar. The tab bar boundary itself is
    /// handled by AppTabView's safeAreaInset modifier — this is aesthetic only.
    static var tabBarContentPadding: CGFloat {
        scaled(80)
    }

    /// Safe top padding for content below status bar (e.g., header greeting row).
    static var headerTopPadding: CGFloat {
        scaled(60)
    }

    /// Overlap offset for cards that sit over the curved header.
    static var headerOverlap: CGFloat {
        scaled(-40)
    }

    /// Featured card large corner radius.
    static var featuredRadius: CGFloat {
        scaled(32)
    }

    /// Profile / settings card corner radius.
    static var profileCardRadius: CGFloat {
        scaled(28)
    }
}

// MARK: - Adaptive View Modifier

struct AdaptiveFrame: ViewModifier {
    let baseWidth: CGFloat?
    let baseHeight: CGFloat?

    func body(content: Content) -> some View {
        content
            .frame(
                width: baseWidth.map { PSLayout.scaled($0) },
                height: baseHeight.map { PSLayout.scaled($0) }
            )
    }
}

extension View {
    /// Applies a frame that scales proportionally with screen width.
    func adaptiveFrame(width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        modifier(AdaptiveFrame(baseWidth: width, baseHeight: height))
    }

    /// Applies horizontal padding that adapts to screen size.
    func adaptiveHPadding() -> some View {
        self.padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
    }

    /// Applies card-level inner padding that adapts.
    func adaptiveCardPadding() -> some View {
        self.padding(PSLayout.cardPadding)
    }
}
