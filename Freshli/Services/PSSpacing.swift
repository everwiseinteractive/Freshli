import SwiftUI

// MARK: - PSSpacing (Pantry Saver Design System - Spacing & Radius)
/// Consistent spacing values following Figma design specifications

struct PSSpacing {
    
    // MARK: - Spacing Scale
    
    /// 2pt - minimal spacing
    static let xxs: CGFloat = 2
    
    /// 4pt - tight spacing
    static let xs: CGFloat = 4
    
    /// 8pt - small spacing
    static let sm: CGFloat = 8
    
    /// 12pt - medium spacing
    static let md: CGFloat = 12
    
    /// 16pt - default spacing
    static let lg: CGFloat = 16
    
    /// 20pt - large spacing
    static let xl: CGFloat = 20
    
    /// 24pt - extra large spacing
    static let xxl: CGFloat = 24
    
    /// 32pt - section spacing
    static let xxxl: CGFloat = 32
    
    /// 48pt - hero spacing
    static let hero: CGFloat = 48
    
    // MARK: - Border Radius
    
    /// 8pt - small radius
    static let radiusSm: CGFloat = 8
    
    /// 12pt - medium radius (default)
    static let radiusMd: CGFloat = 12
    
    /// 16pt - large radius - rounded-2xl
    static let radiusLg: CGFloat = 16
    
    /// 20pt - extra large radius
    static let radiusXl: CGFloat = 20
    
    /// 24pt - rounded-3xl
    static let radiusXxl: CGFloat = 24
    
    /// 40pt - hero curved header - rounded-b-[40px]
    static let radiusHero: CGFloat = 40
    
    // MARK: - Component-Specific Spacing
    
    /// Card internal padding
    static let cardPadding: CGFloat = 20
    
    /// Tab bar internal padding
    static let tabBarPadding: CGFloat = 16
    
    /// Header padding
    static let headerPadding: CGFloat = 20
}
