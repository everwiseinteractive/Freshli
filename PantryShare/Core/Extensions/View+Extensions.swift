import SwiftUI

extension View {
    func screenPadding() -> some View {
        padding(.horizontal, PSSpacing.screenHorizontal)
    }

    func cardStyle() -> some View {
        background(PSColors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    func elevatedCardStyle() -> some View {
        background(PSColors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }

    /// Emerald surface card style (profile, add item screens)
    func emeraldCardStyle() -> some View {
        background(PSColors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                    .strokeBorder(PSColors.emeraldSurface, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 8, y: 4)
    }

    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    func accessibilityAction(_ label: String, action: @escaping () -> Void) -> some View {
        self.accessibilityAction(named: Text(label), action)
    }

    func reduceMotion() -> Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    /// Subtle scale animation on tap for interactive cards
    func interactiveCard() -> some View {
        self.buttonStyle(PressableButtonStyle())
    }

    /// Gentle pulse animation for attention-grabbing elements
    func attentionPulse(_ active: Bool = true) -> some View {
        self.symbolEffect(.pulse, isActive: active)
    }
}
