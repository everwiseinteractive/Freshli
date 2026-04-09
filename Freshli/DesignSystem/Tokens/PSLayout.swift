import SwiftUI

// MARK: - PSLayout
// Adaptive layout utilities for responsive sizing across all iPhone models.
//
// Device width reference (logical points):
//   iPhone SE (2nd/3rd gen)  : 375 pt   → compact tier
//   iPhone 16 / 17           : 393 pt   → standard tier  (reference width)
//   iPhone 16 Pro            : 402 pt   → standard tier
//   iPhone 16 Pro Max        : 430 pt   → expanded tier
//   iPhone 17 Pro Max (est.) : 440 pt   → ultraExpanded tier
//
// iPhone 17 Pro Max specs (estimated):
//   Logical resolution : ~440 × 956 pt
//   Physical display   : ~6.9 inch
//   Refresh rate       : ProMotion 120 Hz
//   Notch style        : Dynamic Island

enum PSLayout {
    /// Base reference width (iPhone 16/17 standard).
    static let referenceWidth: CGFloat = 393

    /// Current screen width.
    static var screenWidth: CGFloat {
        UIScreen.main.bounds.width
    }

    /// Current screen height.
    static var screenHeight: CGFloat {
        UIScreen.main.bounds.height
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

    /// Scales a font size with a gentler curve (less aggressive than full proportional).
    /// Fonts scale down on compact screens but barely grow on expanded — prevents text overflow.
    static func scaledFont(_ size: CGFloat) -> CGFloat {
        let rawFontScale = 1.0 + (widthScale - 1.0) * 0.5
        let fontScale = min(rawFontScale, 1.0)  // Never scale fonts UP — only shrink on compact
        return max((size * fontScale).rounded(.down), 1)
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
        scaled(220)
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
    static var featuredHeight: CGFloat {
        let fraction: CGFloat
        if isUltraExpanded {
            fraction = 0.36
        } else if isCompact {
            fraction = 0.30
        } else {
            fraction = 0.35
        }
        return (screenHeight * fraction).rounded()
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

    /// Bottom padding to clear the custom tab bar.
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
