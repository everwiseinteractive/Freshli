import SwiftUI

/// Displays Hero Badges ("10-Meal Donor" etc.) using SF Symbols with
/// variable color animations that react to reputation score.
struct HeroBadgeView: View {
    let badge: HeroBadge
    let reputationScore: Double
    var size: HeroBadgeSize = .medium

    @State private var animatePulse = false

    var body: some View {
        VStack(spacing: size.labelSpacing) {
            badgeIcon
            if size.showLabel {
                badgeLabel
            }
        }
        .onAppear {
            animatePulse = true
        }
    }

    // MARK: - Icon

    @ViewBuilder
    private var badgeIcon: some View {
        ZStack {
            // Glow ring
            Circle()
                .fill(
                    RadialGradient(
                        colors: [badgePrimaryColor.opacity(0.25), .clear],
                        center: .center,
                        startRadius: size.iconSize * 0.3,
                        endRadius: size.iconSize * 0.8
                    )
                )
                .frame(width: size.containerSize, height: size.containerSize)
                .scaleEffect(animatePulse ? 1.05 : 0.95)
                .animation(
                    .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                    value: animatePulse
                )

            // Background circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [badgePrimaryColor, badgeSecondaryColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size.iconSize, height: size.iconSize)
                .shadow(color: badgePrimaryColor.opacity(0.3), radius: 8, y: 3)

            // Symbol with variable color
            Image(systemName: badge.sfSymbol)
                .font(.system(size: size.symbolSize, weight: .semibold))
                .foregroundStyle(.white)
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.variableColor.iterative, options: .repeating, value: animatePulse)
        }
    }

    // MARK: - Label

    @ViewBuilder
    private var badgeLabel: some View {
        VStack(spacing: 2) {
            Text(badge.displayName)
                .font(size == .large ? PSTypography.calloutMedium : PSTypography.caption1Medium)
                .foregroundStyle(PSColors.textPrimary)
                .lineLimit(1)

            if size == .large {
                Text(badge.subtitle)
                    .font(PSTypography.caption1)
                    .foregroundStyle(PSColors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Colors

    private var badgePrimaryColor: Color {
        Color(hex: UInt(badge.color.primary, radix: 16) ?? 0x22C55E)
    }

    private var badgeSecondaryColor: Color {
        Color(hex: UInt(badge.color.secondary, radix: 16) ?? 0x4ADE80)
    }
}

// MARK: - Badge Size

enum HeroBadgeSize {
    case small, medium, large

    var containerSize: CGFloat {
        switch self {
        case .small: 44
        case .medium: 64
        case .large: 88
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .small: 32
        case .medium: 48
        case .large: 64
        }
    }

    var symbolSize: CGFloat {
        switch self {
        case .small: 14
        case .medium: 22
        case .large: 30
        }
    }

    var labelSpacing: CGFloat {
        switch self {
        case .small: 4
        case .medium: 6
        case .large: 8
        }
    }

    var showLabel: Bool {
        self != .small
    }
}

// MARK: - Badge Row (Horizontal scrollable collection)

struct HeroBadgeRow: View {
    let badges: [HeroBadge]
    let reputationScore: Double
    var size: HeroBadgeSize = .medium

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PSSpacing.lg) {
                ForEach(badges) { badge in
                    HeroBadgeView(
                        badge: badge,
                        reputationScore: reputationScore,
                        size: size
                    )
                }
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.vertical, PSSpacing.sm)
        }
    }
}

// MARK: - Badge Grid (for profile / showcase)

struct HeroBadgeGrid: View {
    let earnedBadges: [HeroBadge]
    let reputationScore: Double

    private let columns = [
        GridItem(.adaptive(minimum: 80, maximum: 100), spacing: PSSpacing.lg)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: PSSpacing.lg) {
            // Section header
            HStack {
                Label {
                    Text("Hero Badges")
                        .font(PSTypography.headline)
                } icon: {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(PSColors.warningAmber)
                }
                .foregroundStyle(PSColors.textPrimary)

                Spacer()

                Text("\(earnedBadges.count)/\(HeroBadge.allCases.count)")
                    .font(PSTypography.caption1Medium)
                    .foregroundStyle(PSColors.textTertiary)
            }

            // Grid
            LazyVGrid(columns: columns, spacing: PSSpacing.xl) {
                ForEach(HeroBadge.allCases) { badge in
                    let isEarned = earnedBadges.contains(badge)

                    VStack(spacing: PSSpacing.xs) {
                        if isEarned {
                            HeroBadgeView(
                                badge: badge,
                                reputationScore: reputationScore,
                                size: .medium
                            )
                        } else {
                            lockedBadge(badge)
                        }
                    }
                }
            }
        }
        .padding(PSSpacing.cardPadding)
        .glassCardStyle()
    }

    @ViewBuilder
    private func lockedBadge(_ badge: HeroBadge) -> some View {
        VStack(spacing: PSSpacing.xs) {
            ZStack {
                Circle()
                    .fill(PSColors.backgroundTertiary)
                    .frame(width: 48, height: 48)

                Image(systemName: badge.sfSymbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(PSColors.textTertiary.opacity(0.4))
            }

            Text(badge.displayName)
                .font(PSTypography.caption1Medium)
                .foregroundStyle(PSColors.textTertiary)
                .lineLimit(1)
        }
        .opacity(0.5)
    }
}

// MARK: - Reputation Score Indicator

struct ReputationScoreView: View {
    let reputation: UserReputation

    @State private var animatedProgress: Double = 0

    var body: some View {
        PSGlassCard {
            VStack(spacing: PSSpacing.lg) {
                // Score header
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: PSSpacing.xxs) {
                        Text("Reputation Score")
                            .font(PSTypography.footnoteMedium)
                            .foregroundStyle(PSColors.textSecondary)

                        Text(String(format: "%.0f", reputation.reputationScore))
                            .font(PSTypography.statLarge)
                            .foregroundStyle(PSColors.textPrimary)
                    }

                    Spacer()

                    // Tier badge
                    Text(reputation.tier.displayName)
                        .font(PSTypography.caption1Medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, PSSpacing.sm)
                        .padding(.vertical, PSSpacing.xxs + 1)
                        .background(
                            Color(hex: UInt(reputation.tier.color, radix: 16) ?? 0x22C55E)
                        )
                        .clipShape(Capsule())
                }

                // Progress bar
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(PSColors.backgroundTertiary)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [PSColors.primaryGreen, PSColors.primaryGreenDark],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: proxy.size.width * animatedProgress, height: 8)
                    }
                }
                .frame(height: 8)

                // Stats row
                HStack(spacing: PSSpacing.lg) {
                    statItem(value: "\(reputation.totalShares)", label: String(localized: "Shares"))
                    statItem(value: "\(reputation.totalDonations)", label: String(localized: "Donations"))
                    statItem(
                        value: reputation.totalReviews > 0
                            ? String(format: "%.1f", reputation.averageRating)
                            : "--",
                        label: String(localized: "Rating")
                    )
                    statItem(value: "\(reputation.earnedBadges.count)", label: String(localized: "Badges"))
                }
            }
        }
        .onAppear {
            withAnimation(PSMotion.easeSlow.delay(0.2)) {
                animatedProgress = reputation.reputationScore / 100.0
            }
        }
    }

    @ViewBuilder
    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(PSTypography.statSmall)
                .foregroundStyle(PSColors.textPrimary)

            Text(label)
                .font(PSTypography.caption2)
                .foregroundStyle(PSColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Badges") {
    ScrollView {
        VStack(spacing: 24) {
            HeroBadgeRow(
                badges: [.firstShare, .tenMealDonor, .zeroWasteHero],
                reputationScore: 65
            )

            HeroBadgeGrid(
                earnedBadges: [.firstShare, .tenMealDonor, .trustedMember],
                reputationScore: 45
            )
            .padding(.horizontal)

            ReputationScoreView(reputation: UserReputation(
                userId: UUID(),
                totalShares: 12,
                totalDonations: 8,
                averageRating: 4.6,
                totalReviews: 14,
                isVerified: true,
                earnedBadges: [.firstShare, .tenMealDonor, .trustedMember]
            ))
            .padding(.horizontal)
        }
    }
}
