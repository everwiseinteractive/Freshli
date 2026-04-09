import SwiftUI

enum PSTypography {
    // MARK: - Display

    static let largeTitle: Font = .largeTitle.weight(.bold)
    static let title1: Font = .title.weight(.bold)
    static let title2: Font = .title2.weight(.semibold)
    static let title3: Font = .title3.weight(.semibold)

    // MARK: - Body

    static let headline: Font = .headline
    static let body: Font = .body
    static let bodyMedium: Font = .body.weight(.medium)
    static let callout: Font = .callout
    static let calloutMedium: Font = .callout.weight(.medium)
    static let subheadline: Font = .subheadline
    static let subheadlineMedium: Font = .subheadline.weight(.medium)

    // MARK: - Small

    static let footnote: Font = .footnote
    static let footnoteMedium: Font = .footnote.weight(.medium)
    static let caption1: Font = .caption
    static let caption1Medium: Font = .caption.weight(.medium)
    static let caption2: Font = .caption2
    static let caption2Medium: Font = .caption2.weight(.medium)

    // MARK: - Numeric

    static let statLarge: Font = .system(size: 34, weight: .bold, design: .rounded)
    static let statMedium: Font = .system(size: 24, weight: .bold, design: .rounded)
    static let statSmall: Font = .system(size: 18, weight: .semibold, design: .rounded)
}
