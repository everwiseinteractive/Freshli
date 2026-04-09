import SwiftUI
import StoreKit

struct FreshliProView: View {
    @Environment(SubscriptionService.self) var subscriptionService
    @State private var selectedProduct: Product?
    @State private var showRestoreAlert = false
    @State private var showErrorAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PSSpacing.xxxl) {
                    // MARK: - Hero Section
                    heroSection

                    // MARK: - Feature Comparison
                    featureComparisonSection

                    // MARK: - Pricing Section
                    pricingSection

                    // MARK: - CTA Button
                    ctaButton

                    // MARK: - Restore Purchases Link
                    restorePurchasesButton
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.vertical, PSSpacing.screenVertical)
            }
            .navigationTitle("Freshli+")
            .navigationBarTitleDisplayMode(.inline)
            .background(PSColors.backgroundPrimary)
        }
        .alert("Restore Purchases", isPresented: $showRestoreAlert) {
            Button("Restore") {
                Task {
                    await subscriptionService.restorePurchases()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Restore your previous purchases from the App Store.")
        }
        .alert("Purchase Error", isPresented: $showErrorAlert, presenting: subscriptionService.error) { _ in
            Button("OK") {
                subscriptionService.error = nil
            }
        } message: { error in
            Text(error.localizedDescription)
        }
        .task {
            await subscriptionService.loadProducts()
        }
        .onChange(of: subscriptionService.error) {
            if subscriptionService.error != nil {
                showErrorAlert = true
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: PSSpacing.lg) {
            VStack(spacing: PSSpacing.md) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                PSColors.primaryGreen,
                                PSColors.accentTeal
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: PSSpacing.sm) {
                    Text("Freshli+")
                        .font(PSTypography.title1)
                        .foregroundStyle(PSColors.textPrimary)

                    Text("Unlock the full power of food preservation")
                        .font(PSTypography.subheadline)
                        .foregroundStyle(PSColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            // Badge highlighting trial
            if subscriptionService.isInTrial {
                VStack(spacing: PSSpacing.xs) {
                    PSBadge(text: "FREE TRIAL", variant: .fresh)
                    Text("\(subscriptionService.trialDaysRemaining) days remaining")
                        .font(PSTypography.caption1)
                        .foregroundStyle(PSColors.textSecondary)
                }
            }
        }
        .padding(PSSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    PSColors.primaryGreen.opacity(0.1),
                    PSColors.accentTeal.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
    }

    // MARK: - Feature Comparison Section

    private var featureComparisonSection: some View {
        VStack(spacing: PSSpacing.lg) {
            Text("Compare Plans")
                .font(PSTypography.title2)
                .foregroundStyle(PSColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: PSSpacing.md) {
                // Pro features
                ForEach([
                    SubscriptionFeature.familySharing,
                    SubscriptionFeature.unlimitedRescue,
                    SubscriptionFeature.advancedAnalytics,
                    SubscriptionFeature.donationExport,
                    SubscriptionFeature.prioritySupport
                ], id: \.self) { feature in
                    featureCard(feature)
                }
            }
        }
    }

    private func featureCard(_ feature: SubscriptionFeature) -> some View {
        PSCard {
            HStack(spacing: PSSpacing.md) {
                VStack(alignment: .leading, spacing: PSSpacing.xxs) {
                    Text(feature.displayName)
                        .font(PSTypography.headline)
                        .foregroundStyle(PSColors.textPrimary)

                    Text(feature.description)
                        .font(PSTypography.caption1)
                        .foregroundStyle(PSColors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                VStack(spacing: PSSpacing.xs) {
                    tierBadge("Free", included: false)
                    tierBadge("Pro", included: true)
                    tierBadge("Family", included: true)
                }
                .font(PSTypography.caption2)
            }
        }
    }

    private func tierBadge(_ tier: String, included: Bool) -> some View {
        HStack(spacing: PSSpacing.xxs) {
            Image(systemName: included ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(included ? PSColors.freshGreen : PSColors.textTertiary)
            Text(tier)
                .foregroundStyle(PSColors.textSecondary)
        }
        .font(.system(size: 11, weight: .medium))
    }

    // MARK: - Pricing Section

    private var pricingSection: some View {
        VStack(spacing: PSSpacing.lg) {
            Text("Simple, Transparent Pricing")
                .font(PSTypography.title2)
                .foregroundStyle(PSColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: PSSpacing.md) {
                // Pro products
                let proMonthly = subscriptionService.products.first { $0.id == SubscriptionProductID.proMonthly.rawValue }
                let proYearly = subscriptionService.products.first { $0.id == SubscriptionProductID.proYearly.rawValue }

                if let proMonthly, let proYearly {
                    pricingCard(
                        monthlyProduct: proMonthly,
                        yearlyProduct: proYearly,
                        tier: .pro,
                        description: "For individuals"
                    )
                }

                // Family Pro product
                let familyMonthly = subscriptionService.products.first { $0.id == SubscriptionProductID.familyMonthly.rawValue }

                if let familyMonthly {
                    familyPricingCard(
                        product: familyMonthly,
                        description: "For families up to 6 members"
                    )
                }

                if subscriptionService.products.isEmpty && !subscriptionService.isLoading {
                    Text("Unable to load pricing. Please check your connection and try again.")
                        .font(PSTypography.caption1)
                        .foregroundStyle(PSColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(PSSpacing.lg)
                }
            }
        }
    }

    private func pricingCard(
        monthlyProduct: Product,
        yearlyProduct: Product,
        tier: SubscriptionTier,
        description: String
    ) -> some View {
        let monthlyCost = monthlyProduct.price
        let yearlyCost = yearlyProduct.price
        let monthlySavings = (monthlyCost * 12 - yearlyCost) / (monthlyCost * 12) * 100

        return VStack(spacing: PSSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                    Text(tier.displayName)
                        .font(PSTypography.headline)
                        .foregroundStyle(PSColors.textPrimary)

                    Text(description)
                        .font(PSTypography.caption1)
                        .foregroundStyle(PSColors.textSecondary)
                }

                Spacer()

                if monthlySavings > 0 {
                    PSBadge(
                        text: "Save \(NSDecimalNumber(decimal: monthlySavings).intValue)%",
                        variant: .fresh
                    )
                }
            }

            // Price options
            HStack(spacing: PSSpacing.md) {
                priceOptionButton(
                    product: monthlyProduct,
                    isSelected: selectedProduct?.id == monthlyProduct.id
                ) {
                    selectedProduct = monthlyProduct
                }

                priceOptionButton(
                    product: yearlyProduct,
                    isSelected: selectedProduct?.id == yearlyProduct.id
                ) {
                    selectedProduct = yearlyProduct
                }
            }
        }
        .padding(PSSpacing.lg)
        .background(
            selectedProduct?.id == monthlyProduct.id || selectedProduct?.id == yearlyProduct.id ?
                PSColors.primaryGreen.opacity(0.05) :
                PSColors.surfaceCard
        )
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                .stroke(
                    selectedProduct?.id == monthlyProduct.id || selectedProduct?.id == yearlyProduct.id ?
                        PSColors.primaryGreen : PSColors.border,
                    lineWidth: selectedProduct?.id == monthlyProduct.id || selectedProduct?.id == yearlyProduct.id ? 2 : 1
                )
        )
    }

    private func familyPricingCard(
        product: Product,
        description: String
    ) -> some View {
        VStack(spacing: PSSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                    Text("Freshli+ Family")
                        .font(PSTypography.headline)
                        .foregroundStyle(PSColors.textPrimary)

                    Text(description)
                        .font(PSTypography.caption1)
                        .foregroundStyle(PSColors.textSecondary)
                }

                Spacer()

                PSBadge(text: "Best Value", variant: .fresh)
            }

            VStack(spacing: PSSpacing.xs) {
                Text("\(product.displayPrice)")
                    .font(PSTypography.title2)
                    .foregroundStyle(PSColors.textPrimary)

                Text("/month")
                    .font(PSTypography.caption1)
                    .foregroundStyle(PSColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(PSSpacing.md)
            .background(selectedProduct?.id == product.id ? PSColors.primaryGreen.opacity(0.1) : PSColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
        }
        .padding(PSSpacing.lg)
        .background(
            selectedProduct?.id == product.id ?
                PSColors.primaryGreen.opacity(0.05) :
                PSColors.surfaceCard
        )
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                .stroke(
                    selectedProduct?.id == product.id ? PSColors.primaryGreen : PSColors.border,
                    lineWidth: selectedProduct?.id == product.id ? 2 : 1
                )
        )
        .onTapGesture {
            selectedProduct = product
        }
    }

    private func priceOptionButton(
        product: Product,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: PSSpacing.xxs) {
                Text(product.displayPrice)
                    .font(PSTypography.title2)
                    .foregroundStyle(PSColors.textPrimary)

                if let subscription = product.subscription {
                    Text(product.localizedPeriod)
                        .font(PSTypography.caption1)
                        .foregroundStyle(PSColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(PSSpacing.md)
            .background(isSelected ? PSColors.primaryGreen.opacity(0.1) : PSColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        let isDisabled = subscriptionService.isProUser || selectedProduct == nil || subscriptionService.isLoading

        return PSButton(
            title: subscriptionService.isProUser ? "You're Subscribed" : "Subscribe Now",
            style: subscriptionService.isProUser ? .secondary : .primary,
            size: .large,
            isFullWidth: true,
            isLoading: subscriptionService.isLoading,
            action: {
                if let selectedProduct {
                    Task {
                        await subscriptionService.purchase(selectedProduct)
                    }
                }
            }
        )
        .disabled(isDisabled)
        .accessibilityLabel(subscriptionService.isProUser ? "You're already subscribed to Freshli+" : "Subscribe to Freshli+")
    }

    // MARK: - Restore Purchases Button

    private var restorePurchasesButton: some View {
        Button {
            showRestoreAlert = true
        } label: {
            Text("Restore Purchases")
                .font(PSTypography.subheadline)
                .foregroundStyle(PSColors.primaryGreen)
        }
        .frame(maxWidth: .infinity)
        .padding(PSSpacing.md)
        .accessibilityLabel("Restore previous purchases from the App Store")
    }
}

// MARK: - Preview

#Preview("FreshliProView - Not Subscribed") {
    @Previewable @State var subscriptionService = SubscriptionService()

    FreshliProView()
        .environment(subscriptionService)
}

#Preview("FreshliProView - Subscribed") {
    @Previewable @State var subscriptionService = SubscriptionService()

    FreshliProView()
        .environment(subscriptionService)
        .onAppear {
            subscriptionService.currentTier = .pro
            subscriptionService.subscriptionStatus = .pro
        }
}
