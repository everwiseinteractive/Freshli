import SwiftUI

// ══════════════════════════════════════════════════════════════════
// MARK: - FLText (Atom)
// Typographic atom. Every text element in the app must use one of
// these semantic styles. SF Pro Rounded with -0.2 tracking throughout.
//
// Usage:
//   FLText("Dashboard", .displayLarge)
//   FLText("12 items", .stat)
//   FLText("Expires tomorrow", .caption, color: .warning)
// ══════════════════════════════════════════════════════════════════

// MARK: - Text Style

enum FLTextStyle: Sendable {
    case displayLarge   // 32pt black — page titles
    case displayMedium  // 24pt bold — section heroes
    case displaySmall   // 20pt bold — card titles
    case headline       // 17pt bold — row titles
    case body           // 15pt regular — primary copy
    case bodyMedium     // 15pt medium — emphasized copy
    case callout        // 14pt semibold — buttons, labels
    case subheadline    // 13pt medium — secondary info
    case caption        // 12pt medium — timestamps, metadata
    case footnote       // 11pt regular — legal, fine print
    case stat           // 48pt black — hero stat counters
    case statSmall      // 28pt black — inline stat numbers
    case sectionLabel   // 10pt black uppercase — section overlines

    var size: CGFloat {
        switch self {
        case .displayLarge:  return 32
        case .displayMedium: return 24
        case .displaySmall:  return 20
        case .headline:      return 17
        case .body:          return 15
        case .bodyMedium:    return 15
        case .callout:       return 14
        case .subheadline:   return 13
        case .caption:       return 12
        case .footnote:      return 11
        case .stat:          return 48
        case .statSmall:     return 28
        case .sectionLabel:  return 10
        }
    }

    var weight: Font.Weight {
        switch self {
        case .displayLarge, .stat, .statSmall, .sectionLabel: return .black
        case .displayMedium, .displaySmall, .headline:        return .bold
        case .callout:                                         return .semibold
        case .bodyMedium, .subheadline, .caption:             return .medium
        case .body, .footnote:                                 return .regular
        }
    }

    var isUppercased: Bool {
        self == .sectionLabel
    }

    var tracking: CGFloat {
        switch self {
        case .sectionLabel: return 1.0
        default:            return -0.2
        }
    }
}

// MARK: - Semantic Color

enum FLTextColor: Sendable {
    case primary
    case secondary
    case tertiary
    case onDark
    case green
    case amber
    case red
    case blue
    case custom(Color)

    var color: Color {
        switch self {
        case .primary:       return PSColors.textPrimary
        case .secondary:     return PSColors.textSecondary
        case .tertiary:      return PSColors.textTertiary
        case .onDark:        return .white
        case .green:         return PSColors.primaryGreen
        case .amber:         return PSColors.secondaryAmber
        case .red:           return PSColors.expiredRed
        case .blue:          return PSColors.infoBlue
        case .custom(let c): return c
        }
    }
}

// MARK: - FLText View

struct FLText: View {
    let text: String
    let style: FLTextStyle
    let color: FLTextColor

    init(_ text: String, _ style: FLTextStyle = .body, color: FLTextColor = .primary) {
        self.text = text
        self.style = style
        self.color = color
    }

    var body: some View {
        Text(style.isUppercased ? text.uppercased() : text)
            .font(.system(
                size: PSLayout.scaledFont(style.size),
                weight: style.weight,
                design: .rounded
            ))
            .tracking(style.tracking)
            .foregroundStyle(color.color)
    }
}

// MARK: - Localised Convenience

extension FLText {
    init(localized key: String, _ style: FLTextStyle = .body, color: FLTextColor = .primary) {
        self.text = String(localized: String.LocalizationValue(key))
        self.style = style
        self.color = color
    }
}
