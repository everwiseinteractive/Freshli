import SwiftUI

// ══════════════════════════════════════════════════════════════════
// MARK: - FLQuickActions (Organism)
// Grid of quick-action buttons on the home dashboard. Each action
// is a glass pill with icon + label. No background boxes.
// ══════════════════════════════════════════════════════════════════

struct FLQuickActions: View {
    let onScanFridge: () -> Void
    let onAddItem: () -> Void
    let onViewRecipes: () -> Void
    let onSwitchTab: (AppTab) -> Void

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: PSSpacing.md
        ) {
            quickAction(
                icon: "camera.fill",
                label: String(localized: "Scan Fridge"),
                color: PSColors.primaryGreen,
                action: onScanFridge
            )

            quickAction(
                icon: "plus.circle.fill",
                label: String(localized: "Add Item"),
                color: PSColors.accentTeal,
                action: onAddItem
            )

            quickAction(
                icon: "frying.pan.fill",
                label: String(localized: "Rescue Recipes"),
                color: PSColors.secondaryAmber,
                action: { onSwitchTab(.recipes) }
            )

            quickAction(
                icon: "person.2.fill",
                label: String(localized: "Community"),
                color: FreshliBrand.planetBlue,
                action: { onSwitchTab(.community) }
            )
        }
    }

    // MARK: - Single Action

    private func quickAction(
        icon: String,
        label: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            PSHaptics.shared.lightTap()
            action()
        }) {
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: PSLayout.scaledFont(18), weight: .semibold))
                    .foregroundStyle(color)

                Text(label)
                    .font(.system(size: PSLayout.scaledFont(14), weight: .bold, design: .rounded))
                    .foregroundStyle(PSColors.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(PSSpacing.md)
            .flGlass(.subtle, tint: .none)
        }
        .buttonStyle(PressableButtonStyle())
    }
}
