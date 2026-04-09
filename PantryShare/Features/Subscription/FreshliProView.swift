import SwiftUI

struct FreshliProView: View {
    @Environment(SubscriptionService.self) var subscriptionService
    @State private var selectedTier: SubscriptionTier = .pro
    @State private var showRestoreAlert = false

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
                subscriptionService.restorePurchases()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Restore your previous purchases from the App Store.")
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
                // Pro Tier
                pricingCard(
                    tier: .pro,
                    monthlyPrice: 4.99,
                    annualPrice: 39.99,
                    annualSavings: 20,
                    description: "For individuals"
                )

                // Family Pro Tier
                pricingCard(
                    tier: .familyPro,
                    monthlyPrice: 7.99,
                    annualPrice: 59.99,
                    annualSavings: 36,
                    description: "For families up to 6 members"
                )
            }
        }
    }

    private func pricingCard(
        tier: SubscriptionTier,
        monthlyPrice: Double,
        annualPrice: Double,
        annualSavings: Int,
        description: String
    ) -> some View {
        VStack(spacing: PSSpacing.md) {
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

                if annualSavings > 0 {
                    PSBadge(text: "Save \(annualSavings)%", variant: .fresh)
                }
            }

            // Price options
            HStack(spacing: PSSpacing.md) {
                priceOption(
                    price: monthlyPrice,
                    period: "/month",
                    isSelected: selectedTier == tier
                ) {
                    selectedTier = tier
                }

                priceOption(
                    price: annualPrice,
                    period: "/year",
                    isSelected: selectedTier == tier
                ) {
                    selectedTier = tier
                }
            }
        }
        .padding(PSSpacing.lg)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                .stroke(
                    selectedTier == tier ? PSColors.primaryGreen : PSColors.border,
                    lineWidth: selectedTier == tier ? 2 : 1
                )
        )
    }

    private func priceOption(
        price: Double,
        period: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: PSSpacing.xxs) {
                Text(String(format: "$%.2f", price))
                    .font(PSTypography.title2)
                    .foregroundStyle(PSColors.textPrimary)

                Text(period)
                    .font(PSTypography.caption1)
                    .foregroundStyle(PSColors.textSecondary)
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
        PSButton(
            title: subscriptionService.isProUser ? "You're Subscribed" : "Start Free Trial",
            style: subscriptionService.isProUser ? .secondary : .primary,
            size: .large,
            isFullWidth: true,
            action: {
                if !subscriptionService.isProUser {
                    subscriptionService.upgradeToPro(tier: selectedTier)
                }
            }
        )
        .disabled(subscriptionService.isProUser)
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
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var subscriptionService = SubscriptionService()

    FreshliProView()
        .environment(subscriptionService)
}
