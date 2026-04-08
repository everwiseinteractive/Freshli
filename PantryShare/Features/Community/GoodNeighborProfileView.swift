import SwiftUI

// MARK: - Good Neighbor Profile View

struct GoodNeighborProfileView: View {
    @Environment(GoodNeighborService.self) private var goodNeighborService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PSSpacing.xxl) {
                // Score Card
                scoreCard

                // Badges Section
                badgesSection

                // Stats Section
                statsSection

                // Next Badge Progress
                nextBadgeSection
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.vertical, PSSpacing.xxl)
        }
        .background(PSColors.backgroundPrimary)
        .navigationTitle(String(localized: "Good Neighbor Score"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Score Card

    private var scoreCard: some View {
        PSCard {
            VStack(alignment: .center, spacing: PSSpacing.md) {
                Text(String(localized: "Your Good Neighbor Score"))
                    .font(PSTypography.headline)
                    .foregroundStyle(PSColors.textSecondary)

                HStack(alignment: .center, spacing: PSSpacing.sm) {
                    Image(systemName: "star.fill")
                        .font(.system(size: PSLayout.scaledFont(32)))
                        .foregroundStyle(PSColors.warningAmber)

                    VStack(alignment: .leading, spacing: PSSpacing.xs) {
                        Text(String(format: "%.1f", goodNeighborService.calculateScore()))
                            .font(PSTypography.statLarge)
                            .foregroundStyle(PSColors.textPrimary)

                        Text("out of 5 stars")
                            .font(PSTypography.caption1)
                            .foregroundStyle(PSColors.textSecondary)
                    }

                    Spacer()
                }

                // Score visualization
                Canvas { context, size in
                    let score = goodNeighborService.calculateScore()
                    let fillColor = scoreColor(for: score)

                    var path = Path(roundedRect: CGRect(x: 0, y: 0, width: 300, height: 8), cornerRadius: 4)
                    context.fill(path, with: .color(PSColors.borderLight))

                    let fillWidth = (score / 5.0) * 300
                    var fillPath = Path(roundedRect: CGRect(x: 0, y: 0, width: fillWidth, height: 8), cornerRadius: 4)
                    context.fill(fillPath, with: .color(fillColor))
                }
                .frame(height: 8)
            }
            .padding(.vertical, PSSpacing.md)
        }
    }

    // MARK: - Badges Section

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            Text(String(localized: "Badges"))
                .font(PSTypography.headline)
                .foregroundStyle(PSColors.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PSSpacing.md) {
                    ForEach(goodNeighborService.allBadges(), id: \.badge.id) { item in
                        NeighborBadgeView(badge: item.badge, isEarned: item.isEarned)
                            .frame(width: 100)
                    }
                }
                .padding(.horizontal, -PSSpacing.screenHorizontal)
                .padding(.horizontal, PSSpacing.screenHorizontal)
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            Text(String(localized: "Your Stats"))
                .font(PSTypography.headline)
                .foregroundStyle(PSColors.textPrimary)

            VStack(spacing: PSSpacing.md) {
                StatRow(
                    label: String(localized: "Total Handoffs"),
                    value: String(goodNeighborService.profile.totalHandoffs),
                    icon: "hands.raised.fill",
                    color: PSColors.infoBlue
                )

                StatRow(
                    label: String(localized: "Success Rate"),
                    value: String(format: "%.0f%%", goodNeighborService.profile.successRate * 100),
                    icon: "checkmark.circle.fill",
                    color: PSColors.primaryGreen
                )

                StatRow(
                    label: String(localized: "On-Time Rate"),
                    value: String(format: "%.0f%%", goodNeighborService.profile.onTimeRate * 100),
                    icon: "clock.fill",
                    color: PSColors.warningAmber
                )

                StatRow(
                    label: String(localized: "Avg. Quality Rating"),
                    value: String(format: "%.1f/5.0", goodNeighborService.profile.averageQualityRating),
                    icon: "sparkles",
                    color: PSColors.accentTeal
                )
            }
        }
    }

    // MARK: - Next Badge Section

    private var nextBadgeSection: some View {
        Group {
            if let nextBadge = goodNeighborService.nextBadge() {
                VStack(alignment: .leading, spacing: PSSpacing.md) {
                    Text(String(localized: "Work Towards"))
                        .font(PSTypography.headline)
                        .foregroundStyle(PSColors.textPrimary)

                    PSCard {
                        VStack(alignment: .leading, spacing: PSSpacing.md) {
                            HStack(spacing: PSSpacing.md) {
                                Image(systemName: nextBadge.icon)
                                    .font(.system(size: PSLayout.scaledFont(24)))
                                    .foregroundStyle(nextBadge.color)

                                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                                    Text(nextBadge.displayName)
                                        .font(PSTypography.headline)
                                        .foregroundStyle(PSColors.textPrimary)

                                    Text(nextBadge.description)
                                        .font(PSTypography.caption1)
                                        .foregroundStyle(PSColors.textSecondary)
                                }

                                Spacer()
                            }

                            // Progress bar
                            VStack(alignment: .leading, spacing: PSSpacing.xs) {
                                let progress = goodNeighborService.progressToNextBadge()
                                Canvas { context, size in
                                    var path = Path(roundedRect: CGRect(x: 0, y: 0, width: 240, height: 6), cornerRadius: 3)
                                    context.fill(path, with: .color(PSColors.borderLight))

                                    let fillWidth = progress * 240
                                    var fillPath = Path(roundedRect: CGRect(x: 0, y: 0, width: fillWidth, height: 6), cornerRadius: 3)
                                    context.fill(fillPath, with: .color(nextBadge.color))
                                }
                                .frame(height: 6)

                                Text(String(format: "%.0f%% complete", progress * 100))
                                    .font(PSTypography.caption1)
                                    .foregroundStyle(PSColors.textSecondary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func scoreColor(for score: Double) -> Color {
        switch score {
        case 4.5...5.0:
            return PSColors.primaryGreen
        case 3.5..<4.5:
            return PSColors.freshGreen
        case 2.5..<3.5:
            return PSColors.warningAmber
        default:
            return PSColors.expiredRed
        }
    }
}

// MARK: - Stat Row Component

private struct StatRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: PSSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: PSLayout.scaledFont(20)))
                .foregroundStyle(color)
                .frame(width: PSSpacing.xl)

            VStack(alignment: .leading, spacing: PSSpacing.xs) {
                Text(label)
                    .font(PSTypography.caption1)
                    .foregroundStyle(PSColors.textSecondary)

                Text(value)
                    .font(PSTypography.headline)
                    .foregroundStyle(PSColors.textPrimary)
            }

            Spacer()
        }
        .padding(.vertical, PSSpacing.sm)
        .padding(.horizontal, PSSpacing.md)
        .background(PSColors.surfaceCard)
        .cornerRadius(PSSpacing.radiusMd)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GoodNeighborProfileView()
            .environment(GoodNeighborService())
    }
}
