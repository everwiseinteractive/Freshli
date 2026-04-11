import SwiftUI

struct FoodItemCard: View {
    let item: FreshliItem
    var compact: Bool = false
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: PSSpacing.md) {
                categoryIcon

                VStack(alignment: .leading, spacing: PSSpacing.xxxs) {
                    Text(item.name)
                        .font(compact ? PSTypography.calloutMedium : PSTypography.bodyMedium)
                        .foregroundStyle(PSColors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: PSSpacing.sm) {
                        Text(item.quantityDisplay)
                            .font(PSTypography.caption1)
                            .foregroundStyle(PSColors.textSecondary)

                        Text("·")
                            .foregroundStyle(PSColors.textTertiary)

                        Label(item.storageLocation.displayName, systemImage: item.storageLocation.icon)
                            .font(PSTypography.caption1)
                            .foregroundStyle(PSColors.textSecondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: PSSpacing.xxxs) {
                    PSExpiryBadge(status: item.expiryStatus)
                    Text(item.expiryDate.expiryDisplayText)
                        .font(PSTypography.caption2)
                        .foregroundStyle(PSColors.expiryColor(for: item.expiryStatus))
                }
            }
            .padding(PSSpacing.cardPadding)
            .cardStyle()
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), \(item.quantityDisplay), \(item.expiryStatus.displayName)")
        .accessibilityHint(String(localized: "Double tap to view details"))
    }

    private var categoryIcon: some View {
        FoodItemImage(
            name: item.name,
            category: item.category,
            size: compact ? 36 : 42,
            cornerRadius: PSSpacing.radiusSm
        )
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous)
                .strokeBorder(PSColors.categoryColor(for: item.category).opacity(0.22), lineWidth: 1)
        )
    }
}

struct FoodItemCardCompact: View {
    let item: FreshliItem
    var onTap: (() -> Void)?

    var body: some View {
        Button { onTap?() } label: {
            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                HStack {
                    FoodItemImage(
                        name: item.name,
                        category: item.category,
                        size: 28,
                        cornerRadius: 6
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(PSColors.categoryColor(for: item.category).opacity(0.22), lineWidth: 1)
                    )

                    Spacer()

                    PSExpiryBadge(status: item.expiryStatus)
                }

                Text(item.name)
                    .font(PSTypography.calloutMedium)
                    .foregroundStyle(PSColors.textPrimary)
                    .lineLimit(1)

                Text(item.expiryDate.expiryDisplayText)
                    .font(PSTypography.caption2)
                    .foregroundStyle(PSColors.expiryColor(for: item.expiryStatus))
            }
            .padding(PSSpacing.md)
            .frame(width: 140)
            .cardStyle()
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), \(item.expiryDate.expiryDisplayText)")
    }
}
