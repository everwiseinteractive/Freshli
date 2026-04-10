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
                VStack(spacing: FLSpacing.xxxl) {
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
                .padding(.horizontal, FLSpacing.screenHorizontal)
                .padding(.vertical, FLSpacing.screenVertical)
            }
            .navigationTitle("Freshli+")
            .navigationBarTitleDisplayMode(.inline)
            .background(FLColors.backgroundPrimary)
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
        VStack(spacing: FLSpacing.lg) {
            VStack(spacing: FLSpacing.md) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                FLColors.primaryGreen,
                                FLColors.accentTeal
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: FLSpacing.sm) {
                    Text("Freshli+")
                        .font(FLTypography.title1)
                        .foregroundStyle(FLColors.textPrimary)

                    Text("Unlock the full power of food preservation")
                        .font(FLTypography.subheadline)
                        .foregroundStyle(FLColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            // Badge highlighting trial
            if subscriptionService.isInTrial {
                VStack(spacing: FLSpacing.xs) {
                    FLBadge(text: "FREE TRIAL", variant: .fresh)
                    Text("\(subscriptionService.trialDaysRemaining) days remaining")
                        .font(FLTypography.caption1)
                        .foregroundStyle(FLColors.textSecondary)
                }
            }
        }
        .padding(FLSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    FLColors.primaryGreen.opacity(0.1),
                    FLColors.accentTeal.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: FLSpacing.radiusXxl, style: .continuous))
    }

    // MARK: - Feature Comparison Section

    private var featureComparisonSection: some View {
        VStack(spacing: FLSpacing.lg) {
            Text("Compare Plans")
                .font(FLTypography.title2)
                .foregroundStyle(FLColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: FLSpacing.md) {
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
        FLCard {
            HStack(spacing: FLSpacing.md) {
                VStack(alignment: .leading, spacing: FLSpacing.xxs) {
                    Text(feature.displayName)
                        .font(FLTypography.headline)
                        .foregroundStyle(FLColors.textPrimary)

                    Text(feature.description)
                        .font(FLTypography.caption1)
                        .foregroundStyle(FLColors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                VStack(spacing: FLSpacing.xs) {
                    tierBadge("Free", included: false)
                    tierBadge("Pro", included: true)
                    tierBadge("Family", included: true)
                }
                .font(FLTypography.caption2)
            }
        }
    }

    private func tierBadge(_ tier: String, included: Bool) -> some View {
        HStack(spacing: FLSpacing.xxs) {
            Image(systemName: included ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(included ? FLColors.freshGreen : FLColors.textTertiary)
            Text(tier)
                .foregroundStyle(FLColors.textSecondary)
        }
        .font(.system(size: 11, weight: .medium))
    }

    // MARK: - Pricing Section

    private var pricingSection: some View {
        VStack(spacing: FLSpacing.lg) {
            Text("Simple, Transparent Pricing")
                .font(FLTypography.title2)
                .foregroundStyle(FLColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: FLSpacing.md) {
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
                        .font(FLTypography.caption1)
                        .foregroundStyle(FLColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(FLSpacing.lg)
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

        return VStack(spacing: FLSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: FLSpacing.xs) {
                    Text(tier.displayName)
                        .font(FLTypography.headline)
                        .foregroundStyle(FLColors.textPrimary)

                    Text(description)
                        .font(FLTypography.caption1)
                        .foregroundStyle(FLColors.textSecondary)
                }

                Spacer()

                if monthlySavings > 0 {
                    FLBadge(
                        text: "Save \(NSDecimalNumber(decimal: monthlySavings).intValue)%",
                        variant: .fresh
                    )
                }
            }

            // Price options
            HStack(spacing: FLSpacing.md) {
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
        .padding(FLSpacing.lg)
        .background(
            selectedProduct?.id == monthlyProduct.id || selectedProduct?.id == yearlyProduct.id ?
                FLColors.primaryGreen.opacity(0.05) :
                FLColors.surfaceCard
        )
        .clipShape(RoundedRectangle(cornerRadius: FLSpacing.radiusLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FLSpacing.radiusLg, style: .continuous)
                .stroke(
                    selectedProduct?.id == monthlyProduct.id || selectedProduct?.id == yearlyProduct.id ?
                        FLColors.primaryGreen : FLColors.border,
                    lineWidth: selectedProduct?.id == monthlyProduct.id || selectedProduct?.id == yearlyProduct.id ? 2 : 1
                )
        )
    }

    private func familyPricingCard(
        product: Product,
        description: String
    ) -> some View {
        VStack(spacing: FLSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: FLSpacing.xs) {
                    Text("Freshli+ Family")
                        .font(FLTypography.headline)
                        .foregroundStyle(FLColors.textPrimary)

                    Text(description)
                        .font(FLTypography.caption1)
                        .foregroundStyle(FLColors.textSecondary)
                }

                Spacer()

                FLBadge(text: "Best Value", variant: .fresh)
            }

            VStack(spacing: FLSpacing.xs) {
                Text("\(product.displayPrice)")
                    .font(FLTypography.title2)
                    .foregroundStyle(FLColors.textPrimary)

                Text("/month")
                    .font(FLTypography.caption1)
                    .foregroundStyle(FLColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(FLSpacing.md)
            .background(selectedProduct?.id == product.id ? FLColors.primaryGreen.opacity(0.1) : FLColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: FLSpacing.radiusMd, style: .continuous))
        }
        .padding(FLSpacing.lg)
        .background(
            selectedProduct?.id == product.id ?
                FLColors.primaryGreen.opacity(0.05) :
                FLColors.surfaceCard
        )
        .clipShape(RoundedRectangle(cornerRadius: FLSpacing.radiusLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FLSpacing.radiusLg, style: .continuous)
                .stroke(
                    selectedProduct?.id == product.id ? FLColors.primaryGreen : FLColors.border,
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
            VStack(spacing: FLSpacing.xxs) {
                Text(product.displayPrice)
                    .font(FLTypography.title2)
                    .foregroundStyle(FLColors.textPrimary)

                if let subscription = product.subscription {
                    Text(product.localizedPeriod)
                        .font(FLTypography.caption1)
                        .foregroundStyle(FLColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(FLSpacing.md)
            .background(isSelected ? FLColors.primaryGreen.opacity(0.1) : FLColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: FLSpacing.radiusMd, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        let isDisabled = subscriptionService.isProUser || selectedProduct == nil || subscriptionService.isLoading

        return FLButton(
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
                .font(FLTypography.subheadline)
                .foregroundStyle(FLColors.primaryGreen)
        }
        .frame(maxWidth: .infinity)
        .padding(FLSpacing.md)
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
