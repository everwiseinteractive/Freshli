import SwiftUI

/// Shareable summary card for the Weekly Impact Wrap (9:16 Instagram Stories ratio)
struct ImpactWrapCardView: View {
    let wrapData: ImpactWrapDataService.WeeklyWrapData
    let showBranding: Bool

    var body: some View {
        ZStack {
            // Rich gradient background
            backgroundGradient

            // Subtle grain texture
            textureOverlay

            // Content
            VStack(spacing: 0) {
                // Header with week range
                headerSection
                    .padding(PSSpacing.cardPadding)

                Spacer()

                // Main stats grid
                mainStatsSection
                    .padding(.horizontal, PSSpacing.cardPadding)

                Spacer()

                // Top category highlight
                topCategorySection
                    .padding(.horizontal, PSSpacing.cardPadding)

                Spacer()

                // Footer
                if showBranding {
                    footerSection
                        .padding(PSSpacing.cardPadding)
                }
            }
        }
        .frame(width: 360, height: 640) // 9:16 aspect ratio for Instagram Stories
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
    }

    // MARK: - Background & Texture

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                PSColors.primaryGreen,
                PSColors.accentTeal
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var textureOverlay: some View {
        Canvas { context, size in
            for y in stride(from: 0, through: size.height, by: 4) {
                for x in stride(from: 0, through: size.width, by: 4) {
                    let randomOpacity = Double.random(in: 0.01...0.04)
                    let rect = CGRect(x: x, y: y, width: 2, height: 2)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(.white.opacity(randomOpacity))
                    )
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            Text("Your Week of Impact")
                .font(.system(size: 24, weight: .semibold, design: .default))
                .foregroundColor(PSColors.textOnPrimary)

            Text(wrapData.weekDisplayRange)
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundColor(PSColors.textOnPrimary.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Main Stats Section

    private var mainStatsSection: some View {
        VStack(spacing: PSSpacing.md) {
            // Hero stat: Items saved
            VStack(spacing: PSSpacing.xs) {
                Text("\(wrapData.itemsSaved)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(PSColors.textOnPrimary)
                    .lineLimit(1)

                Text("Items Rescued")
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundColor(PSColors.textOnPrimary.opacity(0.9))
            }
            .padding(PSSpacing.lg)
            .background(PSColors.textOnPrimary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))

            // Supporting stats row
            HStack(spacing: PSSpacing.md) {
                StatPill(
                    icon: "dollarsign.circle.fill",
                    value: wrapData.moneySavedDisplay,
                    label: "Saved"
                )

                StatPill(
                    icon: "cloud.fill",
                    value: wrapData.co2AvoidedDisplay,
                    label: "CO₂ (kg)"
                )

                StatPill(
                    icon: "leaf.fill",
                    value: "\(wrapData.treesEquivalent)",
                    label: "Trees"
                )
            }
        }
    }

    // MARK: - Top Category Section

    private var topCategorySection: some View {
        VStack(spacing: PSSpacing.sm) {
            Text("Your Top Category")
                .font(.system(size: 12, weight: .semibold, design: .default))
                .foregroundColor(PSColors.textOnPrimary.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: PSSpacing.lg) {
                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                    Text(wrapData.topCategorySaved.displayName)
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundColor(PSColors.textOnPrimary)

                    Text("\(wrapData.topCategoryCount) items")
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundColor(PSColors.textOnPrimary.opacity(0.8))
                }

                Spacer()

                Text(wrapData.topCategorySaved.emoji)
                    .font(.system(size: 48))
            }
            .padding(PSSpacing.md)
            .background(PSColors.textOnPrimary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
        }
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        VStack(spacing: PSSpacing.sm) {
            Divider()
                .foregroundColor(PSColors.textOnPrimary.opacity(0.2))

            HStack(spacing: PSSpacing.xs) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("Freshli")
                    .font(.system(size: 12, weight: .bold, design: .default))
            }
            .foregroundColor(PSColors.textOnPrimary)

            Text("Join me in reducing food waste")
                .font(.system(size: 11, weight: .medium, design: .default))
                .foregroundColor(PSColors.textOnPrimary.opacity(0.8))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Subcomponents

private struct StatPill: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .center, spacing: PSSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(PSColors.textOnPrimary)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(PSColors.textOnPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(label)
                .font(.system(size: 10, weight: .medium, design: .default))
                .foregroundColor(PSColors.textOnPrimary.opacity(0.8))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(PSSpacing.sm)
        .background(PSColors.textOnPrimary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous))
    }
}

// MARK: - Preview

#Preview {
    let mockData = ImpactWrapDataService.WeeklyWrapData(
        itemsSaved: 42,
        itemsDonated: 5,
        itemsShared: 8,
        totalItemsImpacted: 55,
        moneySaved: 147.5,
        moneySavedDisplay: "$148",
        co2Avoided: 137.5,
        co2AvoidedDisplay: "137.5",
        treesEquivalent: 1,
        topCategorySaved: .fruits,
        topCategoryCount: 12,
        categoryBreakdown: [
            (FoodCategory.fruits, 12),
            (FoodCategory.vegetables, 8),
            (FoodCategory.dairy, 6)
        ],
        bestDayOfWeek: "Wednesday",
        currentStreak: 5,
        streakLabel: "🔥 Keep it up!",
        weekOverWeekChange: 0.23,
        weekOverWeekLabel: "23% more than last week!",
        weekStartDate: Date().addingTimeInterval(-7 * 24 * 3600),
        weekEndDate: Date(),
        weekDisplayRange: "Mar 31 - Apr 6"
    )

    ImpactWrapCardView(wrapData: mockData, showBranding: true)
        .padding()
}
