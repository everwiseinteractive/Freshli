import SwiftUI

// MARK: - PSColors (Pantry Saver Design System - Colors)
/// Freshli color palette following Figma design specifications
/// Supports light/dark mode automatically via @Environment(\.colorScheme)

struct PSColors {
    
    // MARK: - Primary Brand Colors
    
    /// Primary green - bg-green-600
    static let primaryGreen = Color(hex: 0x16A34A)
    
    /// Header green - bg-green-600
    static let headerGreen = Color(hex: 0x16A34A)
    
    /// Header green light - for decorative blobs
    static let headerGreenLight = Color(hex: 0x22C55E)
    
    /// Green 100 - bg-green-100 for active tab
    static let green100 = Color(hex: 0xDCFCE7)
    
    /// Green 900/30 - dark mode variant
    static let green900_30 = Color(hex: 0x14532D).opacity(0.3)
    
    /// Emerald surface - bg-emerald-50
    static let emeraldSurface = Color(hex: 0xECFDF5)
    
    // MARK: - Status Colors
    
    /// Fresh green - checkmark.circle.fill
    static let freshGreen = Color(hex: 0x22C55E)
    
    /// Expiring soon amber - exclamationmark.triangle.fill
    static let warnAmber = Color(hex: 0xF59E0B)
    
    /// Expiring today orange
    static let urgentOrange = Color(hex: 0xF97316)
    
    /// Expired red - xmark.circle.fill
    static let expiredRed = Color(hex: 0xEF4444)
    
    /// Secondary amber for icons
    static let secondaryAmber = Color(hex: 0xFBBF24)
    
    // MARK: - Text Colors
    
    /// Primary text - text-neutral-900
    static let textPrimary = Color.primary
    
    /// Secondary text - text-neutral-600
    static let textSecondary = Color(hex: 0x525252)
    
    /// Tertiary text - text-neutral-400 (inactive tabs)
    static let textTertiary = Color(hex: 0xA3A3A3)
    
    /// Text on dark backgrounds
    static let textOnDark = Color.white
    
    // MARK: - Background Colors
    
    /// Main background - bg-neutral-50
    static let backgroundPrimary = Color(hex: 0xFAFAFA)
    
    /// Secondary background
    static let backgroundSecondary = Color(hex: 0xF5F5F5)
    
    /// Surface card - bg-white
    static let surfaceCard = Color.white
    
    /// Dark surface for dark mode
    static let surfaceDark = Color(hex: 0x1F1F1F)
    
    // MARK: - Category Colors
    
    /// Returns a category-specific color for visual grouping
    static func categoryColor(for category: FoodCategory) -> Color {
        switch category {
        case .fruits: return Color(hex: 0xFF6B6B) // Red
        case .vegetables: return Color(hex: 0x4ECB71) // Green
        case .dairy: return Color(hex: 0x95E1F5) // Light blue
        case .meat: return Color(hex: 0xE63946) // Dark red
        case .seafood: return Color(hex: 0x457B9D) // Ocean blue
        case .grains: return Color(hex: 0xF4A261) // Tan
        case .bakery: return Color(hex: 0xE9C46A) // Golden
        case .frozen: return Color(hex: 0xA8DADC) // Ice blue
        case .canned: return Color(hex: 0xC1666B) // Rust
        case .condiments: return Color(hex: 0xFFBE0B) // Yellow
        case .snacks: return Color(hex: 0xFB8500) // Orange
        case .beverages: return Color(hex: 0x8ECAE6) // Sky blue
        case .other: return Color(hex: 0xBCBCBC) // Gray
        }
    }
    
    /// Returns expiry status color
    static func statusColor(for status: ExpiryStatus) -> Color {
        switch status {
        case .fresh: return freshGreen
        case .expiringSoon: return warnAmber
        case .expiringToday: return urgentOrange
        case .expired: return expiredRed
        }
    }
}

// MARK: - Color Hex Initializer

extension Color {
    /// Initialize Color from hex value
    /// Example: Color(hex: 0x16A34A)
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
