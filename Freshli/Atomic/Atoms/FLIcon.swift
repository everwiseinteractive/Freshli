import SwiftUI

// ══════════════════════════════════════════════════════════════════
// MARK: - FLIcon (Atom)
// SF Symbol atom. Renders icons at consistent sizes with NO background
// boxes, circles, or rounded rectangles. Just the icon and its color.
//
// Usage:
//   FLIcon("flame.fill", .medium, color: .amber)
//   FLIcon("globe.europe.africa.fill", .large, color: .onDark)
//   FLIcon("leaf.fill", .hero, color: .green)
// ══════════════════════════════════════════════════════════════════

// MARK: - Icon Size

enum FLIconSize: Sendable {
    case small      // 14pt — inline, captions
    case medium     // 18pt — list rows, labels
    case large      // 24pt — section headers, cards
    case xlarge     // 32pt — hero sections
    case hero       // 48pt — splash, empty states
    case display    // 64pt — full-screen heroes

    var pointSize: CGFloat {
        switch self {
        case .small:   return 14
        case .medium:  return 18
        case .large:   return 24
        case .xlarge:  return 32
        case .hero:    return 48
        case .display: return 64
        }
    }

    var weight: Font.Weight {
        switch self {
        case .small, .medium: return .semibold
        case .large, .xlarge: return .medium
        case .hero, .display: return .regular
        }
    }
}

// MARK: - FLIcon View

struct FLIcon: View {
    let systemName: String
    let size: FLIconSize
    let color: FLTextColor

    init(_ systemName: String, _ size: FLIconSize = .medium, color: FLTextColor = .primary) {
        self.systemName = systemName
        self.size = size
        self.color = color
    }

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: PSLayout.scaledFont(size.pointSize), weight: size.weight))
            .foregroundStyle(color.color)
    }
}
