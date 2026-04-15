import SwiftUI

// MARK: - Adaptive Color Helper

extension Color {
    nonisolated init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    nonisolated init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

enum FLColors {
    // MARK: - Brand (Figma: Tailwind green palette, NOT emerald)
    // green-500=#22C55E, green-600=#16A34A, green-700=#15803D
    // green-100=#DCFCE7, green-50=#F0FDF4

    nonisolated static let primaryGreen = Color(light: Color(hex: 0x22C55E), dark: Color(hex: 0x4ADE80))
    nonisolated static let primaryGreenDark = Color(light: Color(hex: 0x15803D), dark: Color(hex: 0x22C55E))
    nonisolated static let green100 = Color(light: Color(hex: 0xDCFCE7), dark: Color(hex: 0x14532D).opacity(0.3))
    nonisolated static let green50 = Color(light: Color(hex: 0xF0FDF4), dark: Color(hex: 0x14532D).opacity(0.15))
    nonisolated static let secondaryAmber = Color(light: Color(hex: 0xF59E0B), dark: Color(hex: 0xFBBF24))
    nonisolated static let accentTeal = Color(light: Color(hex: 0x14B8A6), dark: Color(hex: 0x2DD4BF))

    // Figma: Home header bg-green-600/rounded-b-[40px]
    nonisolated static let headerGreen = Color(light: Color(hex: 0x16A34A), dark: Color(hex: 0x15803D))
    nonisolated static let headerGreenLight = Color(light: Color(hex: 0x22C55E), dark: Color(hex: 0x16A34A))
    // Figma: green-400 for success celebration icon container
    nonisolated static let green400 = Color(light: Color(hex: 0x4ADE80), dark: Color(hex: 0x22C55E))
    // Figma: Profile/Add emerald palette (pages/ versions use emerald)
    nonisolated static let emeraldSurface = Color(light: Color(hex: 0xECFDF5), dark: Color(hex: 0x064E3B).opacity(0.2))
    nonisolated static let emeraldLight = Color(light: Color(hex: 0xD1FAE5), dark: Color(hex: 0x065F46))
    nonisolated static let emeraldMuted = Color(light: Color(hex: 0xA7F3D0), dark: Color(hex: 0x047857))
    nonisolated static let emerald600 = Color(light: Color(hex: 0x059669), dark: Color(hex: 0x10B981))

    // MARK: - Semantic

    nonisolated static let freshGreen = Color(light: Color(hex: 0x22C55E), dark: Color(hex: 0x4ADE80))
    nonisolated static let warningAmber = Color(light: Color(hex: 0xF59E0B), dark: Color(hex: 0xFBBF24))
    nonisolated static let expiredRed = Color(light: Color(hex: 0xD4183D), dark: Color(hex: 0xF87171))
    nonisolated static let infoBlue = Color(light: Color(hex: 0x3B82F6), dark: Color(hex: 0x60A5FA))

    // MARK: - Surfaces

    nonisolated static let backgroundPrimary = Color(light: .white, dark: Color(hex: 0x0A0A0A))
    nonisolated static let backgroundSecondary = Color(light: Color(hex: 0xF3F3F5), dark: Color(hex: 0x1C1C1E))
    nonisolated static let backgroundTertiary = Color(light: Color(hex: 0xECECF0), dark: Color(hex: 0x2C2C2E))
    nonisolated static let surfaceCard = Color(light: .white, dark: Color(hex: 0x1C1C1E))
    nonisolated static let surfaceElevated = Color(light: .white, dark: Color(hex: 0x2C2C2E))

    // MARK: - Text

    nonisolated static let textPrimary = Color(light: Color(hex: 0x030213), dark: Color(hex: 0xFAFAFA))
    nonisolated static let textSecondary = Color(light: Color(hex: 0x717182), dark: Color(hex: 0x98989F))
    nonisolated static let textTertiary = Color(light: Color(hex: 0xAEAEB2), dark: Color(hex: 0x636366))
    nonisolated static let textOnPrimary = Color.white
    nonisolated static let textOnDark = Color.white

    // MARK: - Borders

    // Figma: --border: rgba(0,0,0,0.1)
    nonisolated static let border = Color(light: Color.black.opacity(0.1), dark: Color.white.opacity(0.1))
    // Figma: neutral-100=#F5F5F5, neutral-200=#E5E5E5
    nonisolated static let borderLight = Color(light: Color(hex: 0xF5F5F5), dark: Color(hex: 0x262626))
    nonisolated static let neutral200 = Color(light: Color(hex: 0xE5E5E5), dark: Color(hex: 0x404040))
    nonisolated static let divider = Color(light: Color.black.opacity(0.05), dark: Color.white.opacity(0.08))

    // MARK: - Category Colors

    nonisolated static func categoryColor(for category: FoodCategory) -> Color {
        switch category {
        case .fruits: return Color(hex: 0xF5923E)
        case .vegetables: return Color(hex: 0x4CAF50)
        case .dairy: return Color(hex: 0x42A5F5)
        case .meat: return Color(hex: 0xEF5350)
        case .seafood: return Color(hex: 0x26C6DA)
        case .grains: return Color(hex: 0xA1887F)
        case .bakery: return Color(hex: 0xFFCA28)
        case .frozen: return Color(hex: 0x7E57C2)
        case .canned: return Color(hex: 0xAB47BC)
        case .condiments: return Color(hex: 0x66BB6A)
        case .snacks: return Color(hex: 0xEC407A)
        case .beverages: return Color(hex: 0x29B6F6)
        case .other: return Color(hex: 0x9E9E9E)
        }
    }

    // MARK: - Expiry Colors

    nonisolated static func expiryColor(for status: ExpiryStatus) -> Color {
        switch status {
        case .fresh: return freshGreen
        case .expiringSoon: return warningAmber
        case .expiringToday: return expiredRed.opacity(0.85)
        case .expired: return expiredRed
        }
    }

    nonisolated static func expiryBackground(for status: ExpiryStatus) -> Color {
        expiryColor(for: status).opacity(0.12)
    }
}

// MARK: - Backward Compatibility
typealias PSColors = FLColors
