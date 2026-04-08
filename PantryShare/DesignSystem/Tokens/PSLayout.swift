import SwiftUI

// MARK: - PSLayout
// Adaptive layout utilities for responsive sizing across all iPhone models.
// Reference widths: iPhone SE = 375pt, iPhone 17 = 393pt, iPhone 17 Pro Max = 430pt

enum PSLayout {
    /// Base reference width (iPhone 17 / standard).
    static let referenceWidth: CGFloat = 393

    /// Current screen width.
    static var screenWidth: CGFloat {
        UIScreen.main.bounds.width
    }

    /// Current screen height.
    static var screenHeight: CGFloat {
        UIScreen.main.bounds.height
    }

    /// Scale factor relative to reference width (0.95 on SE, 1.0 on standard, 1.09 on Max).
    static var widthScale: CGFloat {
        min(max(screenWidth / referenceWidth, 0.85), 1.15)
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

    /// Returns true on smaller phones (SE-class, width ≤ 375pt).
    static var isCompact: Bool {
        screenWidth <= 375
    }

    /// Returns true on larger phones (Pro Max class, width ≥ 428pt).
    static var isExpanded: Bool {
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
        isCompact ? scaled(160) : scaled(192)
    }

    /// Featured/hero content height that adapts to screen height.
    static var featuredHeight: CGFloat {
        let fraction: CGFloat = isCompact ? 0.30 : 0.35
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
        isCompact ? scaled(96) : scaled(112)
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
