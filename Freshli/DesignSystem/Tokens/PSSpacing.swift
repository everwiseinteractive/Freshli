import SwiftUI

enum PSSpacing {
    static let xxxs: CGFloat = 2
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 6
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
    static let xxxxl: CGFloat = 40
    static let jumbo: CGFloat = 48

    // MARK: - Screen Insets

    // Figma: px-6 = 24 consistently across all screens
    static let screenHorizontal: CGFloat = 24
    static let screenVertical: CGFloat = 16

    static var screenInsets: EdgeInsets {
        EdgeInsets(top: screenVertical, leading: screenHorizontal, bottom: screenVertical, trailing: screenHorizontal)
    }

    // MARK: - Card

    // Figma: p-6 = 24 on most cards
    static let cardPadding: CGFloat = 24
    static let cardSpacing: CGFloat = 12
    static let cardInnerSpacing: CGFloat = 8

    // MARK: - Radius (Figma: rounded-* Tailwind classes)

    static let radiusSm: CGFloat = 8     // rounded-lg
    static let radiusMd: CGFloat = 12    // rounded-xl
    static let radiusLg: CGFloat = 16    // rounded-2xl (buttons)
    static let radiusXl: CGFloat = 20    // rounded-[1.25rem] (FAB, items)
    static let radiusXxl: CGFloat = 24   // rounded-3xl (cards)
    static let radiusHero: CGFloat = 40  // rounded-[2.5rem] (bottom sheet, icons)
    static let radiusFull: CGFloat = 999
}
