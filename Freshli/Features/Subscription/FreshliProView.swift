import SwiftUI
import StoreKit

// MARK: - Freshli+ Subscription Screen
// Apple App Review Requirements:
//   ✓ Auto-renewal disclosure (prominently displayed)
//   ✓ Cancellation instructions (link to Apple subscription management)
//   ✓ Terms of Use / Terms of Service link
//   ✓ Privacy Policy link
//   ✓ Price and billing period clearly stated
//   ✓ Free trial terms disclosed

struct FreshliProView: View {
    @Environment(SubscriptionService.self) var subscriptionService
    @State private var selectedProduct: Product?
    @State private var showRestoreAlert = false
    @State private var showErrorAlert = false
    @State private var appeared = false
    @State private var selectedTier: PlanTier = .pro
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum PlanTier: String, CaseIterable {
        case pro = "Pro"
        case family = "Family"
    }

    private let features: [(icon: String, color: Color, title: String, subtitle: String, proOnly: Bool)] = [
        ("sparkles", Color(hex: 0x22C55E), "AI Rescue Chef", "Personalised recipes for expiring food — save meals, not waste", true),
        ("person.2.fill", Color(hex: 0x3B82F6), "Family Sharing", "Share pantry & shopping lists with up to 6 family members", true),
        ("chart.line.uptrend.xyaxis", Color(hex: 0xF59E0B), "Advanced Analytics", "Monthly waste reports, savings tracker & sustainability score", true),
        ("arrow.up.doc.fill", Color(hex: 0x8B5CF6), "Export & Reports", "Export donation records & impact reports as CSV or PDF", true),
        ("bell.badge.fill", Color(hex: 0xEF4444), "Smart Expiry Alerts", "Hyper-personalised notifications — never waste food again", false),
        ("cart.fill", Color(hex: 0x14B8A6), "Shopping Integration", "Auto-generate shopping lists based on pantry gaps", false),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero
                    heroSection
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 30)

                    // Plan toggle + pricing
                    planSection
                        .padding(.top, PSSpacing.xxl)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)

                    // Features
                    featuresSection
                        .padding(.top, PSSpacing.xxxl)
                        .opacity(appeared ? 1 : 0)

                    // CTA
                    ctaSection
                        .padding(.top, PSSpacing.xxl)
                        .opacity(appeared ? 1 : 0)

                    // Legal disclosures — required for Apple App Review
                    legalDisclosures
                        .padding(.top, PSSpacing.xxl)
                        .padding(.bottom, PSSpacing.xxxxl)
                }
                .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
            }
            .background(legalBackground)
            .background(PSColors.backgroundPrimary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(PSColors.textSecondary)
                    }
                }
            }
        }
        .onAppear {
            let anim: Animation = reduceMotion ? .easeOut(duration: 0.15) : PSMotion.springDefault.delay(0.08)
            withAnimation(anim) { appeared = true }
        }
        .alert("Restore Purchases", isPresented: $showRestoreAlert) {
            Button("Restore") {
                Task { await subscriptionService.restorePurchases() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Restore your previous Freshli+ purchases from the App Store.")
        }
        .alert("Purchase Error", isPresented: $showErrorAlert, presenting: subscriptionService.error) { _ in
            Button("OK") { subscriptionService.error = nil }
        } message: { error in
            Text(error.localizedDescription)
        }
        .task { await subscriptionService.loadProducts() }
        .onChange(of: subscriptionService.error) {
            if subscriptionService.error != nil { showErrorAlert = true }
        }
    }

    // MARK: - Subtle gradient overlay behind legal text

    private var legalBackground: some View {
        VStack {
            Spacer()
            LinearGradient(
                colors: [PSColors.backgroundPrimary.opacity(0), PSColors.backgroundPrimary],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: PSSpacing.xl) {
            // Crown badge
            ZStack {
                // Glow ring
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [PSColors.primaryGreen.opacity(0.25), .clear],
                            center: .center,
                            startRadius: 30,
                            endRadius: 80
                        )
                    )
                    .frame(width: PSLayout.scaled(160), height: PSLayout.scaled(160))

                // Badge background
                RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [PSColors.primaryGreen, Color(hex: 0x059652)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: PSLayout.scaled(90), height: PSLayout.scaled(90))
                    .shadow(color: PSColors.primaryGreen.opacity(0.55), radius: 24, x: 0, y: 10)

                Image(systemName: "crown.fill")
                    .font(.system(size: PSLayout.scaledFont(40), weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: PSSpacing.sm) {
                Text("Freshli+")
                    .font(.system(size: PSLayout.scaledFont(38), weight: .black))
                    .tracking(-1.0)
                    .foregroundStyle(PSColors.textPrimary)

                Text("Stop wasting food.\nStart saving money.")
                    .font(.system(size: PSLayout.scaledFont(17), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            // Trial badge
            if subscriptionService.isInTrial {
                HStack(spacing: PSSpacing.xs) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                    Text(String(localized: "\(subscriptionService.trialDaysRemaining) days free trial remaining"))
                        .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, PSSpacing.xl)
                .padding(.vertical, PSSpacing.sm)
                .background(
                    LinearGradient(
                        colors: [PSColors.primaryGreen, Color(hex: 0x059652)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: PSColors.primaryGreen.opacity(0.4), radius: 10, y: 4)
            }
        }
        .padding(.top, PSSpacing.xl)
    }

    // MARK: - Plan Selection + Pricing

    private var planSection: some View {
        VStack(spacing: PSSpacing.lg) {
            // Tier toggle
            HStack(spacing: 0) {
                ForEach(PlanTier.allCases, id: \.self) { tier in
                    Button {
                        PSHaptics.shared.selection()
                        withAnimation(FLMotion.springQuick) { selectedTier = tier }
                    } label: {
                        Text(tier.rawValue)
                            .font(.system(size: PSLayout.scaledFont(15), weight: .bold))
                            .foregroundStyle(selectedTier == tier ? .white : PSColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, PSSpacing.md)
                            .background {
                                if selectedTier == tier {
                                    Capsule()
                                        .fill(PSColors.primaryGreen)
                                        .shadow(color: PSColors.primaryGreen.opacity(0.4), radius: 8, y: 3)
                                }
                            }
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(5)
            .background(PSColors.backgroundSecondary)
            .clipShape(Capsule())

            // Pricing cards
            if selectedTier == .pro {
                proCards
            } else {
                familyCard
            }
        }
    }

    private var proCards: some View {
        let monthly = subscriptionService.products.first { $0.id == SubscriptionProductID.proMonthly.rawValue }
        let yearly  = subscriptionService.products.first { $0.id == SubscriptionProductID.proYearly.rawValue }

        return VStack(spacing: PSSpacing.md) {
            if let monthly {
                pricingOption(
                    product: monthly,
                    label: "Monthly",
                    sublabel: nil,
                    savingsPercent: nil,
                    isBestValue: false
                )
            }
            if let yearly {
                let savePct: Int? = {
                    guard let m = monthly else { return nil }
                    let s = (m.price * 12 - yearly.price) / (m.price * 12) * 100
                    return s > 0 ? NSDecimalNumber(decimal: s).intValue : nil
                }()
                pricingOption(
                    product: yearly,
                    label: "Yearly",
                    sublabel: monthly.map { "Just \(formatMonthlyFromYearly($0, yearly: yearly))/mo" },
                    savingsPercent: savePct,
                    isBestValue: true
                )
            }
            if subscriptionService.products.isEmpty && !subscriptionService.isLoading {
                Text("Unable to load pricing. Check your connection and try again.")
                    .font(PSTypography.caption1)
                    .foregroundStyle(PSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(PSSpacing.xl)
            }
        }
    }

    private var familyCard: some View {
        let product = subscriptionService.products.first { $0.id == SubscriptionProductID.familyMonthly.rawValue }
        return Group {
            if let product {
                Button { selectedProduct = product } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: PSSpacing.xs) {
                            HStack(spacing: PSSpacing.xs) {
                                Text("Family Pro")
                                    .font(.system(size: PSLayout.scaledFont(17), weight: .black))
                                    .foregroundStyle(PSColors.textPrimary)
                                Text("UP TO 6 MEMBERS")
                                    .font(.system(size: PSLayout.scaledFont(10), weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, PSSpacing.sm)
                                    .padding(.vertical, PSSpacing.xxs)
                                    .background(PSColors.primaryGreen)
                                    .clipShape(Capsule())
                            }
                            Text("Share everything with your household")
                                .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                                .foregroundStyle(PSColors.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(product.displayPrice)
                                .font(.system(size: PSLayout.scaledFont(22), weight: .black))
                                .foregroundStyle(PSColors.textPrimary)
                            Text("/month")
                                .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                                .foregroundStyle(PSColors.textTertiary)
                        }
                    }
                    .padding(PSSpacing.xl)
                    .background(
                        RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                            .fill(selectedProduct?.id == product.id
                                ? PSColors.primaryGreen.opacity(0.06)
                                : PSColors.surfaceCard)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                            .stroke(selectedProduct?.id == product.id
                                ? PSColors.primaryGreen
                                : PSColors.border,
                                lineWidth: selectedProduct?.id == product.id ? 2 : 1)
                    )
                    .shadow(color: selectedProduct?.id == product.id
                        ? PSColors.primaryGreen.opacity(0.15) : .black.opacity(0.04),
                        radius: 12, y: 4)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    private func pricingOption(
        product: Product,
        label: String,
        sublabel: String?,
        savingsPercent: Int?,
        isBestValue: Bool
    ) -> some View {
        Button { selectedProduct = product } label: {
            HStack(spacing: PSSpacing.md) {
                // Radio
                ZStack {
                    Circle()
                        .stroke(selectedProduct?.id == product.id
                            ? PSColors.primaryGreen : PSColors.border, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if selectedProduct?.id == product.id {
                        Circle()
                            .fill(PSColors.primaryGreen)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: PSSpacing.xs) {
                        Text(label)
                            .font(.system(size: PSLayout.scaledFont(15), weight: .bold))
                            .foregroundStyle(PSColors.textPrimary)
                        if let pct = savingsPercent {
                            Text("SAVE \(pct)%")
                                .font(.system(size: PSLayout.scaledFont(10), weight: .black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, PSSpacing.sm)
                                .padding(.vertical, 2)
                                .background(PSColors.primaryGreen)
                                .clipShape(Capsule())
                        }
                        if isBestValue && savingsPercent == nil {
                            Text("BEST VALUE")
                                .font(.system(size: PSLayout.scaledFont(10), weight: .black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, PSSpacing.sm)
                                .padding(.vertical, 2)
                                .background(PSColors.primaryGreen)
                                .clipShape(Capsule())
                        }
                    }
                    if let sub = sublabel {
                        Text(sub)
                            .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                            .foregroundStyle(PSColors.textTertiary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.system(size: PSLayout.scaledFont(20), weight: .black))
                        .foregroundStyle(PSColors.textPrimary)
                    Text(product.localizedPeriod)
                        .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                        .foregroundStyle(PSColors.textTertiary)
                }
            }
            .padding(PSSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                    .fill(selectedProduct?.id == product.id
                        ? PSColors.primaryGreen.opacity(0.05)
                        : PSColors.surfaceCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                    .stroke(selectedProduct?.id == product.id
                        ? PSColors.primaryGreen : PSColors.border,
                        lineWidth: selectedProduct?.id == product.id ? 2 : 1)
            )
            .shadow(
                color: selectedProduct?.id == product.id
                    ? PSColors.primaryGreen.opacity(0.12) : .black.opacity(0.03),
                radius: 10, y: 3)
            .animation(FLMotion.springQuick, value: selectedProduct?.id)
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.lg) {
            VStack(alignment: .leading, spacing: PSSpacing.xxs) {
                Text("Everything in Freshli+")
                    .font(.system(size: PSLayout.scaledFont(22), weight: .black))
                    .foregroundStyle(PSColors.textPrimary)
                Text("Designed to help you waste less & save more")
                    .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
            }

            VStack(spacing: PSSpacing.md) {
                ForEach(Array(features.enumerated()), id: \.offset) { idx, feature in
                    featureRow(feature: feature)
                        .staggeredAppearance(index: idx)
                }
            }
        }
    }

    private func featureRow(feature: (icon: String, color: Color, title: String, subtitle: String, proOnly: Bool)) -> some View {
        HStack(spacing: PSSpacing.lg) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous)
                    .fill(feature.color.opacity(0.12))
                    .frame(width: PSLayout.scaled(46), height: PSLayout.scaled(46))
                Image(systemName: feature.icon)
                    .font(.system(size: PSLayout.scaledFont(20), weight: .semibold))
                    .foregroundStyle(feature.color)
            }

            VStack(alignment: .leading, spacing: PSSpacing.xxs) {
                HStack(spacing: PSSpacing.xs) {
                    Text(feature.title)
                        .font(.system(size: PSLayout.scaledFont(15), weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                    if feature.proOnly {
                        Text("PRO")
                            .font(.system(size: PSLayout.scaledFont(9), weight: .black))
                            .foregroundStyle(PSColors.primaryGreen)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(PSColors.primaryGreen.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                Text(feature.subtitle)
                    .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: PSLayout.scaledFont(20)))
                .foregroundStyle(PSColors.primaryGreen)
        }
        .padding(PSSpacing.lg)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                .strokeBorder(PSColors.borderLight, lineWidth: 1)
        )
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        VStack(spacing: PSSpacing.lg) {
            if subscriptionService.isProUser {
                // Already subscribed state
                VStack(spacing: PSSpacing.md) {
                    ZStack {
                        Circle().fill(PSColors.primaryGreen.opacity(0.12))
                            .frame(width: 64, height: 64)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(PSColors.primaryGreen)
                    }
                    Text("You're a Freshli+ Member!")
                        .font(.system(size: PSLayout.scaledFont(20), weight: .black))
                        .foregroundStyle(PSColors.textPrimary)
                    Text("Thank you for supporting a sustainable future. 🌱")
                        .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(PSSpacing.xxl)
                .background(PSColors.primaryGreen.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                        .strokeBorder(PSColors.primaryGreen.opacity(0.2), lineWidth: 1)
                )
            } else {
                // Subscribe button
                Button {
                    if let product = selectedProduct {
                        Task { await subscriptionService.purchase(product) }
                    }
                } label: {
                    Group {
                        if subscriptionService.isLoading {
                            ProgressView()
                                .tint(.black)
                                .frame(height: PSLayout.scaled(58))
                                .frame(maxWidth: .infinity)
                        } else {
                            HStack(spacing: PSSpacing.md) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: PSLayout.scaledFont(18), weight: .bold))
                                Text(selectedProduct == nil ? "Select a Plan" : "Start Freshli+")
                                    .font(.system(size: PSLayout.scaledFont(17), weight: .black))
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: PSLayout.scaled(58))
                        }
                    }
                    .background(
                        selectedProduct != nil
                        ? LinearGradient(colors: [PSColors.primaryGreen, Color(hex: 0x059652)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [PSColors.backgroundSecondary, PSColors.backgroundSecondary],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(Capsule())
                    .shadow(
                        color: selectedProduct != nil ? PSColors.primaryGreen.opacity(0.45) : .clear,
                        radius: 16, x: 0, y: 6
                    )
                    .animation(FLMotion.springQuick, value: selectedProduct?.id)
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(selectedProduct == nil || subscriptionService.isLoading)

                // Restore purchases
                Button {
                    showRestoreAlert = true
                } label: {
                    Text("Restore Purchases")
                        .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                        .foregroundStyle(PSColors.primaryGreen)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, PSSpacing.sm)
            }
        }
    }

    // MARK: - Legal Disclosures
    // Apple App Review Guidelines §3.1.2 — Required Subscription Disclosures

    private var legalDisclosures: some View {
        VStack(alignment: .leading, spacing: PSSpacing.lg) {
            // Divider
            Rectangle()
                .fill(PSColors.border)
                .frame(height: 1)

            // Subscription terms
            VStack(alignment: .leading, spacing: PSSpacing.md) {
                Text("Subscription Details")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                    .foregroundStyle(PSColors.textSecondary)

                VStack(alignment: .leading, spacing: PSSpacing.sm) {
                    Text("• **Payment** will be charged to your Apple ID account at confirmation of purchase.")
                    Text("• **Auto-renewal:** Your subscription automatically renews unless cancelled at least 24 hours before the end of the current period.")
                    Text("• **Billing:** Your account will be charged for renewal within 24 hours prior to the end of the current period at the same price.")
                    Text("• **Free trial:** Any unused portion of a free trial will be forfeited when you purchase a subscription.")
                }
                .font(.system(size: PSLayout.scaledFont(12), weight: .regular))
                .foregroundStyle(PSColors.textTertiary)

                // Cancellation instructions
                HStack(alignment: .top, spacing: PSSpacing.xs) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: PSLayout.scaledFont(12)))
                        .foregroundStyle(PSColors.textTertiary)
                    Text("To cancel, go to **Settings → Apple ID → Subscriptions** and turn off auto-renewal at least 24 hours before the end of your billing period.")
                        .font(.system(size: PSLayout.scaledFont(12), weight: .regular))
                        .foregroundStyle(PSColors.textTertiary)
                }
                .padding(PSSpacing.md)
                .background(PSColors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
            }

            // ToS & Privacy links
            HStack(spacing: PSSpacing.sm) {
                Link(destination: URL(string: "https://freshliapp.com/terms")!) {
                    Text("Terms of Use")
                        .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                        .foregroundStyle(PSColors.primaryGreen)
                }

                Text("·")
                    .foregroundStyle(PSColors.textTertiary)
                    .font(.system(size: PSLayout.scaledFont(12)))

                Link(destination: URL(string: "https://freshliapp.com/privacy")!) {
                    Text("Privacy Policy")
                        .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                        .foregroundStyle(PSColors.primaryGreen)
                }

                Spacer()
            }
        }
        .padding(.horizontal, PSSpacing.xs)
    }

    // MARK: - Helpers

    private func formatMonthlyFromYearly(_ monthly: Product, yearly: Product) -> String {
        let perMonth = yearly.price / 12
        return yearly.priceFormatStyle.format(perMonth)
    }
}

// MARK: - Preview

#Preview("Freshli+ — Free") {
    @Previewable @State var subscriptionService = SubscriptionService()
    FreshliProView()
        .environment(subscriptionService)
}

#Preview("Freshli+ — Subscribed") {
    @Previewable @State var subscriptionService = SubscriptionService()
    FreshliProView()
        .environment(subscriptionService)
        .onAppear {
            subscriptionService.currentTier = .pro
            subscriptionService.subscriptionStatus = .pro
        }
}
