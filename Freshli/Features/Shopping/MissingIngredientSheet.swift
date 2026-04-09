import SwiftUI
import Observation

struct MissingIngredientSheet: View {
    let item: ShoppingItem
    let viewModel: ShoppingListViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedPartner: DeliveryPartner?

    var availablePartners: [DeliveryPartner] {
        DeliveryPartner.allCases
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: PSSpacing.lg) {
                // Header
                VStack(spacing: PSSpacing.md) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(PSColors.expiredRed)

                    VStack(spacing: PSSpacing.sm) {
                        Text("Missing Ingredient")
                            .font(PSTypography.title2)
                            .foregroundStyle(PSColors.textPrimary)

                        Text("You need this to complete your Rescue Chef mission")
                            .font(PSTypography.callout)
                            .foregroundStyle(PSColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(PSSpacing.lg)

                // Ingredient Display
                PSCard {
                    HStack(spacing: PSSpacing.md) {
                        VStack(alignment: .leading, spacing: PSSpacing.xs) {
                            Text(item.name)
                                .font(PSTypography.headline)
                                .foregroundStyle(PSColors.textPrimary)

                            Text("\(String(format: "%.1f", item.quantity)) \(item.unit)")
                                .font(PSTypography.callout)
                                .foregroundStyle(PSColors.textSecondary)
                        }

                        Spacer()

                        PSBadge(text: item.category.uppercased(), variant: .expiringSoon)
                    }
                    .padding(PSSpacing.lg)
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)

                ScrollView {
                    VStack(spacing: PSSpacing.xl) {
                        // Get It Now Section
                        VStack(alignment: .leading, spacing: PSSpacing.md) {
                            Text("Get It Now")
                                .font(PSTypography.headline)
                                .foregroundStyle(PSColors.textPrimary)
                                .padding(.horizontal, PSSpacing.screenHorizontal)

                            VStack(spacing: PSSpacing.sm) {
                                ForEach(availablePartners, id: \.self) { partner in
                                    DeliveryOptionCard(
                                        partner: partner,
                                        isSelected: selectedPartner == partner,
                                        onTap: { selectedPartner = partner }
                                    )
                                    .padding(.horizontal, PSSpacing.screenHorizontal)
                                }
                            }
                        }

                        // Add to Shopping List Option
                        VStack(spacing: PSSpacing.md) {
                            Divider()
                                .padding(.horizontal, PSSpacing.screenHorizontal)

                            PSButton(
                                title: "Add to Shopping List",
                                icon: "plus.circle.fill",
                                style: .secondary,
                                size: .medium,
                                isFullWidth: true,
                                action: {
                                    // Add to shopping list
                                    viewModel.service.currentList.items.append(item)
                                    viewModel.service.toggleUrgent(id: item.id)
                                    PSHaptics.shared.success()
                                    dismiss()
                                }
                            )
                            .padding(.horizontal, PSSpacing.screenHorizontal)
                        }

                        // Skip Option
                        Button(action: { dismiss() }) {
                            Text("Skip — I'll manage without it")
                                .font(PSTypography.callout)
                                .foregroundStyle(PSColors.textSecondary)
                        }
                        .padding(PSSpacing.screenHorizontal)
                    }
                    .padding(.vertical, PSSpacing.lg)
                }
            }
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
            .safeAreaInset(edge: .bottom) {
                if let partner = selectedPartner {
                    VStack(spacing: PSSpacing.md) {
                        PSButton(
                            title: "Order from \(partner.displayName)",
                            icon: partner.icon,
                            style: .primary,
                            size: .medium,
                            isFullWidth: true,
                            action: {
                                // Open affiliate link
                                if let url = URL(string: partner.affiliateURL) {
                                    UIApplication.shared.open(url)
                                }
                                dismiss()
                            }
                        )

                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .font(PSTypography.callout)
                                .foregroundStyle(PSColors.textSecondary)
                        }
                    }
                    .padding(PSSpacing.screenHorizontal)
                    .padding(.vertical, PSSpacing.lg)
                    .background(PSColors.backgroundPrimary)
                }
            }
        }
        .onAppear {
            // Auto-select fastest delivery option
            selectedPartner = viewModel.service.suggestDeliveryPartner(for: [item])
        }
    }
}

// MARK: - Delivery Option Card

struct DeliveryOptionCard: View {
    let partner: DeliveryPartner
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            PSCard {
                HStack(spacing: PSSpacing.md) {
                    VStack(alignment: .leading, spacing: PSSpacing.xs) {
                        Text(partner.displayName)
                            .font(PSTypography.headline)
                            .foregroundStyle(PSColors.textPrimary)

                        HStack(spacing: PSSpacing.sm) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(PSColors.infoBlue)

                            Text(partner.estimatedDelivery)
                                .font(PSTypography.caption1)
                                .foregroundStyle(PSColors.textSecondary)
                        }

                        Text("Available now")
                            .font(PSTypography.caption2)
                            .foregroundStyle(PSColors.textTertiary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: PSSpacing.xs) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(isSelected ? PSColors.primaryGreen : PSColors.textTertiary)

                        Spacer()

                        Text("$3.99")
                            .font(PSTypography.caption1)
                            .foregroundStyle(PSColors.textSecondary)
                    }
                }
                .padding(PSSpacing.lg)
            }
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

#Preview {
    MissingIngredientSheet(
        item: ShoppingItem(
            name: "Fresh Basil",
            quantity: 1,
            unit: "bunch",
            category: "vegetables",
            isUrgent: true,
            source: "rescueMission"
        ),
        viewModel: ShoppingListViewModel()
    )
}

#Preview("Selected Partner") {
    var preview = MissingIngredientSheet(
        item: ShoppingItem(
            name: "Parmesan Cheese",
            quantity: 100,
            unit: "grams",
            category: "dairy",
            isUrgent: true,
            source: "rescueMission"
        ),
        viewModel: ShoppingListViewModel()
    )
    return preview
}
