import SwiftUI

// MARK: - Discover View
// Central hub for Freshli's advanced tools. Keeps the primary screens
// (Home, Pantry, Profile) clean by grouping secondary features into an
// organised, beautifully-paced gallery.

struct DiscoverView: View {
    @State private var showARScanner = false
    @State private var showIngredientPing = false

    var body: some View {
        ScrollView {
            VStack(spacing: PSSpacing.xxxl) {
                hero
                insightsSection
                communitySection
                rewardsSection
                experimentalSection
                footerNote
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.vertical, PSSpacing.xl)
        }
        .contentMargins(.bottom, PSLayout.scaled(150), for: .scrollContent)
        .background(PSColors.backgroundPrimary)
        .navigationTitle(String(localized: "Discover"))
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showARScanner) {
            ARPantryScannerView()
        }
        .sheet(isPresented: $showIngredientPing) {
            IngredientPingView()
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: PSSpacing.md) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: 0x8B5CF6).opacity(0.15), PSColors.accentTeal.opacity(0.1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: PSLayout.scaled(84), height: PSLayout.scaled(84))
                Image(systemName: "sparkles")
                    .font(.system(size: PSLayout.scaledFont(34)))
                    .foregroundStyle(Color(hex: 0x8B5CF6))
            }
            VStack(spacing: PSSpacing.xs) {
                Text(String(localized: "Advanced Tools"))
                    .font(.system(size: PSLayout.scaledFont(22), weight: .black, design: .rounded))
                    .foregroundStyle(PSColors.textPrimary)
                Text(String(localized: "Rescue more food, waste less money, connect with your community."))
                    .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, PSSpacing.lg)
            }
        }
        .padding(.top, PSSpacing.md)
    }

    // MARK: - Smart Insights (Grid)

    private var insightsSection: some View {
        section(
            title: String(localized: "Smart Insights"),
            subtitle: String(localized: "AI tools to shop smarter and waste less"),
            icon: "chart.bar.fill",
            color: Color(hex: 0x8B5CF6)
        ) {
            LazyVGrid(columns: twoColumnGrid, spacing: PSSpacing.md) {
                NavigationLink(destination: SmartShoppingListView()) {
                    featureTile(
                        icon: "cart.badge.questionmark",
                        title: String(localized: "Smart Shopping"),
                        subtitle: String(localized: "Predict waste, fill recipe gaps"),
                        color: Color(hex: 0x8B5CF6)
                    )
                }
                .buttonStyle(PressableButtonStyle())

                NavigationLink(destination: BarcodeAnalyticsView()) {
                    featureTile(
                        icon: "barcode.viewfinder",
                        title: String(localized: "Packaging"),
                        subtitle: String(localized: "EPR cost per product"),
                        color: Color(hex: 0xEF4444)
                    )
                }
                .buttonStyle(PressableButtonStyle())

                NavigationLink(destination: BinLogDashboardView()) {
                    featureTile(
                        icon: "trash.circle.fill",
                        title: String(localized: "Trash Analytics"),
                        subtitle: String(localized: "Post-mortem on waste"),
                        color: Color(hex: 0xF97316)
                    )
                }
                .buttonStyle(PressableButtonStyle())

                NavigationLink(destination: CouncilImpactReportView()) {
                    featureTile(
                        icon: "building.columns.fill",
                        title: String(localized: "Council Report"),
                        subtitle: String(localized: "Anonymous postcode data"),
                        color: Color(hex: 0x06B6D4)
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    // MARK: - Community (List)

    private var communitySection: some View {
        section(
            title: String(localized: "Community"),
            subtitle: String(localized: "Share surplus with neighbours"),
            icon: "person.3.fill",
            color: Color(hex: 0x3B82F6)
        ) {
            VStack(spacing: PSSpacing.sm) {
                NavigationLink(destination: LocalPodsView()) {
                    featureRow(
                        icon: "building.2.fill",
                        title: String(localized: "Local Network & Pods"),
                        subtitle: String(localized: "Verified pods for your building or street"),
                        color: Color(hex: 0x3B82F6)
                    )
                }
                .buttonStyle(PressableButtonStyle())

                NavigationLink(destination: KarmaCreditsView()) {
                    featureRow(
                        icon: "leaf.circle.fill",
                        title: String(localized: "Karma Credits"),
                        subtitle: String(localized: "Earn credits when you share food"),
                        color: Color(hex: 0x8B5CF6)
                    )
                }
                .buttonStyle(PressableButtonStyle())

                Button {
                    PSHaptics.shared.lightTap()
                    showIngredientPing = true
                } label: {
                    featureRow(
                        icon: "dot.radiowaves.left.and.right",
                        title: String(localized: "Ping Your Pod"),
                        subtitle: String(localized: "Request one ingredient from neighbours"),
                        color: Color(hex: 0xEC4899)
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    // MARK: - Rewards & Integrations

    private var rewardsSection: some View {
        section(
            title: String(localized: "Rewards & Integrations"),
            subtitle: String(localized: "Get rewarded for rescuing food"),
            icon: "gift.fill",
            color: PSColors.secondaryAmber
        ) {
            VStack(spacing: PSSpacing.sm) {
                NavigationLink(destination: PerksView()) {
                    featureRow(
                        icon: "leaf.fill",
                        title: String(localized: "Zero Waste Perks"),
                        subtitle: String(localized: "Redeem points for supermarket discounts"),
                        color: PSColors.secondaryAmber
                    )
                }
                .buttonStyle(PressableButtonStyle())

                NavigationLink(destination: RetailerLinkView()) {
                    featureRow(
                        icon: "cart.badge.plus",
                        title: String(localized: "Connect Supermarket"),
                        subtitle: String(localized: "Auto-sync Tesco, Sainsbury's, Whole Foods"),
                        color: PSColors.primaryGreen
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    // MARK: - Experimental

    private var experimentalSection: some View {
        section(
            title: String(localized: "Experimental"),
            subtitle: String(localized: "Early previews of upcoming features"),
            icon: "flask.fill",
            color: Color(hex: 0x06B6D4)
        ) {
            Button {
                PSHaptics.shared.lightTap()
                showARScanner = true
            } label: {
                featureRow(
                    icon: "viewfinder",
                    title: String(localized: "AR Pantry Scanner"),
                    subtitle: String(localized: "See freshness health bars over your pantry in AR"),
                    color: Color(hex: 0x06B6D4),
                    isBeta: true
                )
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    // MARK: - Footer

    private var footerNote: some View {
        HStack(spacing: PSSpacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: PSLayout.scaledFont(11)))
                .foregroundStyle(PSColors.textTertiary)
            Text(String(localized: "More tools coming soon."))
                .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                .foregroundStyle(PSColors.textTertiary)
            Spacer()
        }
        .padding(.horizontal, PSSpacing.md)
    }

    // MARK: - Section Builders

    private var twoColumnGrid: [GridItem] {
        [GridItem(.flexible(), spacing: PSSpacing.md),
         GridItem(.flexible(), spacing: PSSpacing.md)]
    }

    @ViewBuilder
    private func section<Content: View>(title: String, subtitle: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            HStack(spacing: PSSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(color.opacity(0.12))
                        .frame(width: PSLayout.scaled(34), height: PSLayout.scaled(34))
                    Image(systemName: icon)
                        .font(.system(size: PSLayout.scaledFont(15)))
                        .foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: PSLayout.scaledFont(16), weight: .black))
                        .foregroundStyle(PSColors.textPrimary)
                    Text(subtitle)
                        .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                }
                Spacer(minLength: 0)
            }
            content()
        }
    }

    private func featureTile(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: PSLayout.scaledFont(20)))
                .foregroundStyle(color)
                .frame(width: PSLayout.scaled(40), height: PSLayout.scaled(40))
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                    .foregroundStyle(PSColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: PSLayout.scaled(140), alignment: .topLeading)
        .padding(PSSpacing.lg)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                .strokeBorder(PSColors.borderLight, lineWidth: 1)
        )
    }

    private func featureRow(icon: String, title: String, subtitle: String, color: Color, isBeta: Bool = false) -> some View {
        HStack(spacing: PSSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: PSLayout.scaled(46), height: PSLayout.scaled(46))
                Image(systemName: icon)
                    .font(.system(size: PSLayout.scaledFont(18)))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: PSSpacing.xs) {
                    Text(title)
                        .font(.system(size: PSLayout.scaledFont(15), weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                    if isBeta {
                        Text("BETA")
                            .font(.system(size: PSLayout.scaledFont(9), weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(color)
                            .clipShape(Capsule())
                    }
                }
                Text(subtitle)
                    .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                .foregroundStyle(PSColors.textTertiary)
        }
        .padding(PSSpacing.lg)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                .strokeBorder(PSColors.borderLight, lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack { DiscoverView() }
}
