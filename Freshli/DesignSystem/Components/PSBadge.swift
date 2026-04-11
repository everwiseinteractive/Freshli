import SwiftUI

// Figma: badgeVariants — rounded-full px-2.5 py-0.5 text-[10px] font-bold uppercase tracking-wider

enum PSBadgeVariant {
    case fresh
    case expiringSoon
    case expired
    case shared
    case donated
    case claimed
    case pendingPickup
    case `default`

    var foregroundColor: Color {
        switch self {
        case .fresh: return Color(hex: 0x065F46)       // emerald-800
        case .expiringSoon: return Color(hex: 0x92400E) // amber-800
        case .expired: return Color(hex: 0x991B1B)      // red-800
        case .shared: return Color(hex: 0x1E40AF)       // blue-800
        case .donated: return Color(hex: 0x3730A3)      // indigo-800
        case .claimed: return Color(hex: 0x1F2937)      // neutral-800
        case .pendingPickup: return Color(hex: 0x9A3412) // orange-800
        case .default: return .white
        }
    }

    var backgroundColor: Color {
        switch self {
        case .fresh: return Color(hex: 0xD1FAE5)       // emerald-100
        case .expiringSoon: return Color(hex: 0xFEF3C7) // amber-100
        case .expired: return Color(hex: 0xFEE2E2)      // red-100
        case .shared: return Color(hex: 0xDBEAFE)       // blue-100
        case .donated: return Color(hex: 0xE0E7FF)      // indigo-100
        case .claimed: return Color(hex: 0xE5E7EB)      // neutral-200
        case .pendingPickup: return Color(hex: 0xFFEDD5) // orange-100
        case .default: return Color(hex: 0x171717)       // neutral-900
        }
    }
}

struct PSBadge: View {
    let text: String
    var variant: PSBadgeVariant = .default
    var color: Color?
    var style: PSBadgeStyle = .filled

    enum PSBadgeStyle {
        case filled
        case outlined
        case subtle
    }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(0.8)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .foregroundStyle(effectiveForeground)
            .background(effectiveBackground)
            .clipShape(Capsule())
            .overlay {
                if style == .outlined, let color {
                    Capsule().strokeBorder(color, lineWidth: 1)
                }
            }
    }

    private var effectiveForeground: Color {
        if let color {
            switch style {
            case .filled: return .white
            case .outlined, .subtle: return color
            }
        }
        return variant.foregroundColor
    }

    private var effectiveBackground: Color {
        if let color {
            switch style {
            case .filled: return color
            case .outlined: return color.opacity(0.08)
            case .subtle: return color.opacity(0.12)
            }
        }
        return variant.backgroundColor
    }
}

struct PSExpiryBadge: View {
    let status: ExpiryStatus

    private var variant: PSBadgeVariant {
        switch status {
        case .fresh: return .fresh
        case .expiringSoon: return .expiringSoon
        case .expiringToday: return .expired
        case .expired: return .expired
        }
    }

    var body: some View {
        PSBadge(text: status.displayName, variant: variant)
    }
}

#Preview {
    VStack(spacing: 12) {
        HStack {
            PSBadge(text: "Fresh", variant: .fresh)
            PSBadge(text: "Expiring", variant: .expiringSoon)
            PSBadge(text: "Expired", variant: .expired)
        }
        HStack {
            PSBadge(text: "Shared", variant: .shared)
            PSBadge(text: "Donated", variant: .donated)
            PSBadge(text: "Giveaway", variant: .default)
        }
        HStack {
            PSExpiryBadge(status: .fresh)
            PSExpiryBadge(status: .expiringSoon)
            PSExpiryBadge(status: .expired)
        }
    }
    .padding()
}
