import SwiftUI

// MARK: - Replenish Delivery Sheet
// "Purchase with Delivery" — simulated affiliate integration
// structured for Instacart / Ocado / Amazon Fresh / Apple Pay
// with placeholder URLs.

struct ReplenishDeliverySheet: View {
    let item: ReplenishItem
    @Environment(\.dismiss) private var dismiss
    @State private var selectedOption: ReplenishDeliveryOption?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: PSSpacing.xl) {
                        // Item Header
                        itemHeaderSection

                        // Link Preview (if item has a URL)
                        if let urlString = item.linkURL, let url = URL(string: urlString) {
                            LinkPreviewCard(url: url, itemName: item.name)
                                .padding(.horizontal, PSSpacing.screenHorizontal)
                        }

                        // Delivery Options
                        deliveryOptionsSection

                        // Price Summary
                        if let estimated = item.estimatedPrice {
                            priceSummarySection(estimated: estimated)
                        }
                    }
                    .padding(.vertical, PSSpacing.lg)
                }

                // Bottom Action
                if let option = selectedOption {
                    bottomActionBar(option: option)
                }
            }
            .navigationTitle("Purchase with Delivery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(PSColors.textTertiary)
                    }
                }
            }
        }
        .onAppear {
            // Auto-select fastest option
            selectedOption = ReplenishDeliveryOption.allOptions.first
        }
    }

    // MARK: - Sections

    private var itemHeaderSection: some View {
        PSCard {
            HStack(spacing: PSSpacing.md) {
                // Category icon
                Image(systemName: categoryIcon(for: item.category))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(PSColors.primaryGreen)
                    .frame(width: 48, height: 48)
                    .background(PSColors.primaryGreen.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm))

                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                    Text(item.name)
                        .font(PSTypography.headline)
                        .foregroundStyle(PSColors.textPrimary)

                    HStack(spacing: PSSpacing.sm) {
                        Text("\(String(format: "%.1f", item.quantity)) \(item.unit)")
                            .font(PSTypography.callout)
                            .foregroundStyle(PSColors.textSecondary)

                        PSBadge(text: item.source.displayName.uppercased(), variant: .default, style: .subtle)
                    }
                }

                Spacer()

                if let price = item.estimatedPrice {
                    Text(String(format: "$%.2f", price))
                        .font(PSTypography.statSmall)
                        .foregroundStyle(PSColors.primaryGreen)
                }
            }
        }
        .padding(.horizontal, PSSpacing.screenHorizontal)
    }

    private var deliveryOptionsSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            Text("Delivery Options")
                .font(PSTypography.headline)
                .foregroundStyle(PSColors.textPrimary)
                .padding(.horizontal, PSSpacing.screenHorizontal)

            VStack(spacing: PSSpacing.sm) {
                ForEach(ReplenishDeliveryOption.allOptions) { option in
                    DeliveryOptionRow(
                        option: option,
                        isSelected: selectedOption?.id == option.id,
                        onTap: {
                            withAnimation(PSMotion.springQuick) {
                                selectedOption = option
                            }
                            PSHaptics.shared.lightTap()
                        }
                    )
                    .padding(.horizontal, PSSpacing.screenHorizontal)
                }
            }
        }
    }

    private func priceSummarySection(estimated: Double) -> some View {
        PSGlassCard {
            VStack(spacing: PSSpacing.md) {
                HStack {
                    Text("Item")
                        .font(PSTypography.callout)
                        .foregroundStyle(PSColors.textSecondary)
                    Spacer()
                    Text(String(format: "$%.2f", estimated))
                        .font(PSTypography.calloutMedium)
                        .foregroundStyle(PSColors.textPrimary)
                }

                if let option = selectedOption {
                    HStack {
                        Text("Delivery")
                            .font(PSTypography.callout)
                            .foregroundStyle(PSColors.textSecondary)
                        Spacer()
                        Text(option.deliveryFee == 0
                             ? "Free"
                             : String(format: "$%.2f", option.deliveryFee))
                            .font(PSTypography.calloutMedium)
                            .foregroundStyle(option.deliveryFee == 0 ? PSColors.primaryGreen : PSColors.textPrimary)
                    }

                    Divider()

                    HStack {
                        Text("Total")
                            .font(PSTypography.headline)
                            .foregroundStyle(PSColors.textPrimary)
                        Spacer()
                        Text(String(format: "$%.2f", estimated + option.deliveryFee))
                            .font(PSTypography.statSmall)
                            .foregroundStyle(PSColors.primaryGreen)
                    }
                }

                if let lastPaid = item.lastPricePaid, lastPaid > 0 {
                    HStack(spacing: PSSpacing.sm) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 12))
                            .foregroundStyle(PSColors.textTertiary)

                        Text("Last paid: \(String(format: "$%.2f", lastPaid))")
                            .font(PSTypography.caption1)
                            .foregroundStyle(PSColors.textTertiary)

                        Spacer()

                        let diff = estimated - lastPaid
                        if diff != 0 {
                            Text(String(format: "%@$%.2f", diff > 0 ? "+" : "-", abs(diff)))
                                .font(PSTypography.caption1Medium)
                                .foregroundStyle(diff > 0 ? PSColors.expiredRed : PSColors.primaryGreen)
                        }
                    }
                }
            }
            .padding(PSSpacing.cardPadding)
        }
        .padding(.horizontal, PSSpacing.screenHorizontal)
    }

    private func bottomActionBar(option: ReplenishDeliveryOption) -> some View {
        VStack(spacing: PSSpacing.md) {
            PSButton(
                title: "Purchase with \(option.name)",
                icon: option.icon,
                style: .primary,
                size: .medium,
                isFullWidth: true,
                action: {
                    PSHaptics.shared.mediumTap()
                    if let url = option.buildURL(for: item.name) {
                        UIApplication.shared.open(url)
                    }
                    dismiss()
                }
            )

            Button(action: { dismiss() }) {
                Text("Add to list instead")
                    .font(PSTypography.callout)
                    .foregroundStyle(PSColors.textSecondary)
            }
        }
        .padding(.horizontal, PSSpacing.screenHorizontal)
        .padding(.vertical, PSSpacing.lg)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    // MARK: - Helpers

    private func categoryIcon(for category: String) -> String {
        FoodCategory(rawValue: category)?.icon ?? "basket.fill"
    }
}

// MARK: - Delivery Option Row

private struct DeliveryOptionRow: View {
    let option: ReplenishDeliveryOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            PSCard {
                HStack(spacing: PSSpacing.md) {
                    Image(systemName: option.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSelected ? PSColors.primaryGreen : PSColors.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(
                            isSelected
                                ? PSColors.primaryGreen.opacity(0.12)
                                : PSColors.backgroundSecondary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm))

                    VStack(alignment: .leading, spacing: PSSpacing.xxs) {
                        Text(option.name)
                            .font(PSTypography.calloutMedium)
                            .foregroundStyle(PSColors.textPrimary)

                        HStack(spacing: PSSpacing.sm) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(PSColors.infoBlue)

                            Text(option.estimatedDelivery)
                                .font(PSTypography.caption1)
                                .foregroundStyle(PSColors.textSecondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: PSSpacing.xxs) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(isSelected ? PSColors.primaryGreen : PSColors.textTertiary)

                        Text(option.deliveryFee == 0
                             ? "Free"
                             : String(format: "$%.2f", option.deliveryFee))
                            .font(PSTypography.caption1)
                            .foregroundStyle(
                                option.deliveryFee == 0
                                    ? PSColors.primaryGreen
                                    : PSColors.textSecondary
                            )
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusLg)
                    .stroke(
                        isSelected ? PSColors.primaryGreen.opacity(0.4) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    ReplenishDeliverySheet(
        item: ReplenishItem(
            name: "Organic Whole Milk",
            category: "dairy",
            quantity: 1,
            unit: "gallon",
            source: .consumed,
            estimatedPrice: 5.99,
            lastPricePaid: 6.49
        )
    )
}
