import SwiftUI

// MARK: - PSLayout (Pantry Saver Design System - Layout & Adaptive Sizing)
/// Adaptive layout utilities for different screen sizes

struct PSLayout {
    
    // MARK: - Screen Size Detection
    
    /// Returns true if device is iPhone SE size or smaller
    static var isCompact: Bool {
        UIScreen.main.bounds.width <= 375
    }
    
    /// Returns true if device is iPad or larger
    static var isRegular: Bool {
        UIScreen.main.bounds.width >= 768
    }
    
    /// Current screen width
    static var screenWidth: CGFloat {
        UIScreen.main.bounds.width
    }
    
    /// Current screen height
    static var screenHeight: CGFloat {
        UIScreen.main.bounds.height
    }
    
    // MARK: - Adaptive Scaling
    
    /// Scale a value based on screen size (SE = 0.9x, Plus = 1.1x)
    static func scaled(_ value: CGFloat) -> CGFloat {
        let baseWidth: CGFloat = 390 // iPhone 14 Pro base
        let scaleFactor = screenWidth / baseWidth
        return value * scaleFactor
    }
    
    /// Scale font size adaptively
    static func scaledFont(_ size: CGFloat) -> CGFloat {
        if isCompact {
            return size * 0.95
        } else if isRegular {
            return size * 1.1
        }
        return size
    }
    
    // MARK: - Component Sizes
    
    /// Tab bar icon size
    static let tabIconSize: CGFloat = 24
    
    /// Icon button size (40x40)
    static let iconButtonSize: CGFloat = 40
    
    /// Avatar size in header (48x48)
    static let avatarSize: CGFloat = 48
    
    /// Emoji circle size (56x56)
    static let emojiCircleSize: CGFloat = 56
    
    /// Community avatar circle (56x56)
    static let communityAvatarSize: CGFloat = 56
    
    /// Expiring item pill width
    static let pillWidth: CGFloat = 144
    
    /// FAB size (64x64)
    static let fabSize: CGFloat = 64
    
    // MARK: - Layout Heights
    
    /// Header height with curved bottom
    static let headerHeight: CGFloat = 280
    
    /// Tab bar content bottom padding
    static let tabBarContentPadding: CGFloat = 100
    
    /// Recipe card image height
    static let recipeCardImageHeight: CGFloat = 160
    
    // MARK: - Adaptive Padding
    
    /// Horizontal screen padding (adaptive)
    static var adaptiveHorizontalPadding: CGFloat {
        if isCompact {
            return 16
        } else if isRegular {
            return 32
        }
        return 20
    }
    
    /// Vertical section spacing (adaptive)
    static var adaptiveSectionSpacing: CGFloat {
        if isCompact {
            return 20
        } else if isRegular {
            return 32
        }
        return 24
    }
}

// MARK: - Adaptive View Modifiers

extension View {
    
    /// Apply adaptive card padding
    func adaptiveCardPadding() -> some View {
        self.padding(PSLayout.isCompact ? 16 : 20)
    }
    
    /// Apply adaptive frame with scaling
    func adaptiveFrame(width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        self.frame(
            width: width.map { PSLayout.scaled($0) },
            height: height.map { PSLayout.scaled($0) }
        )
    }
}
