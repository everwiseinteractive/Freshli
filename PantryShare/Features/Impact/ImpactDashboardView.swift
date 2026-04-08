import SwiftUI
import SwiftData

struct ImpactDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<PantryItem> { !$0.isConsumed && !$0.isShared && !$0.isDonated })
    private var activeItems: [PantryItem]

    @Query private var allItems: [PantryItem]
    @Query private var profiles: [UserProfile]

    @State private var stats: ImpactService.ImpactStats?
    @State private var milestones: [ImpactService.Milestone] = []
    @State private var appeared = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        ScrollView {
            VStack(spacing: PSSpacing.xxl) {
                // MARK: - Hero Header
                heroSection

                // MARK: - Primary Stats Grid
                if let stats {
                    primaryStatsGrid(stats)
                }

                // MARK: - Global Context Card
                globalImpactCard

                // MARK: - Milestones Progress
                if !milestones.isEmpty {
                    milestonesSection
                }

                // MARK: - Food Waste Facts
                educationSection

                // MARK: - Call to Action
                ctaSection
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.bottom, PSSpacing.xxxl)
        }
        .background(PSColors.backgroundPrimary)
        .navigationTitle(String(localized: "Your Impact"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let service = ImpactService(modelContext: modelContext)
            stats = service.calculateStats()
            milestones = service.milestones(for: service.calculateStats())
            withAnimation(PSMotion.springDefault) {
                appeared = true
            }
        }
    }

    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: PSSpacing.lg) {
            // Large eco icon
            ZStack {
                Circle()
                    .fill(PSColors.primaryGreen.opacity(0.12))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(PSColors.primaryGreen.opacity(0.08))
                    .frame(width: 160, height: 160)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(PSColors.primaryGreen)
            }
            .scaleEffect(appeared ? 1 : 0.5)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: PSSpacing.xs) {
                Text(String(localized: "You're Making a Difference"))
                    .font(PSTypography.title2)
                    .foregroundStyle(PSColors.textPrimary)

                Text(String(localized: "Every item you save helps reduce the 1.3 billion tonnes of food wasted globally each year."))
                    .font(PSTypography.body)
                    .foregroundStyle(PSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, PSSpacing.xl)
        .staggeredAppearance(index: 0)
    }

    // MARK: - Primary Stats
    private func primaryStatsGrid(_ stats: ImpactService.ImpactStats) -> some View {
        VStack(spacing: PSSpacing.md) {
            HStack(spacing: PSSpacing.md) {
                // Food Saved
                StatCard(
                    icon: "leaf.fill",
                    value: "\(stats.itemsSaved)",
                    label: String(localized: "Items Saved"),
                    color: PSColors.primaryGreen,
                    index: 1
                )

                // Money Saved
                StatCard(
                    icon: "dollarsign.circle.fill",
                    value: stats.moneySavedDisplay,
                    label: String(localized: "Money Saved"),
                    color: PSColors.secondaryAmber,
                    index: 2
                )
            }

            HStack(spacing: PSSpacing.md) {
                // CO2 Avoided
                StatCard(
                    icon: "cloud.fill",
                    value: stats.co2Display,
                    label: String(localized: "CO₂ Avoided"),
                    color: PSColors.accentTeal,
                    index: 3
                )

                // Meals Shared
                StatCard(
                    icon: "heart.fill",
                    value: "\(stats.itemsShared + stats.itemsDonated)",
                    label: String(localized: "Meals Shared"),
                    color: Color(hex: 0xEC4899),
                    index: 4
                )
            }
        }
        .staggeredAppearance(index: 1)
    }

    // MARK: - Global Impact Context
    private var globalImpactCard: some View {
        VStack(spacing: PSSpacing.lg) {
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(PSColors.infoBlue)

                Text(String(localized: "Global Food Waste Crisis"))
                    .font(PSTypography.headline)
                    .foregroundStyle(PSColors.textPrimary)

                Spacer()
            }

            VStack(spacing: PSSpacing.md) {
                GlobalFactRow(
                    stat: "1/3",
                    description: String(localized: "of all food produced is lost or wasted worldwide"),
                    source: "FAO"
                )

                Divider().foregroundStyle(PSColors.divider)

                GlobalFactRow(
                    stat: "8-10%",
                    description: String(localized: "of global greenhouse gas emissions come from food waste"),
                    source: "UNEP"
                )

                Divider().foregroundStyle(PSColors.divider)

                GlobalFactRow(
                    stat: "783M",
                    description: String(localized: "people face hunger while food is being wasted"),
                    source: "UN"
                )
            }

            if let stats {
                Divider().foregroundStyle(PSColors.divider)

                HStack(alignment: .top, spacing: PSSpacing.md) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(PSColors.primaryGreen)
                        .font(.system(size: 14, weight: .semibold))

                    Text(String(localized: "Your \(stats.co2Display) CO₂ saved equals \(equivalentTrees(stats.co2Avoided)) trees absorbing carbon for a year."))
                        .font(PSTypography.callout)
                        .foregroundStyle(PSColors.textSecondary)
                }
            }
        }
        .padding(PSSpacing.cardPadding)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .staggeredAppearance(index: 2)
    }

    // MARK: - Milestones
    private var milestonesSection: some View {
        VStack(spacing: PSSpacing.lg) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(PSColors.secondaryAmber)
                Text(String(localized: "Milestones"))
                    .font(PSTypography.headline)
                    .foregroundStyle(PSColors.textPrimary)
                Spacer()

                let unlocked = milestones.filter { $0.isUnlocked }.count
                Text("\(unlocked)/\(milestones.count)")
                    .font(PSTypography.caption1Medium)
                    .foregroundStyle(PSColors.textSecondary)
            }

            VStack(spacing: PSSpacing.sm) {
                ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                    MilestoneRow(milestone: milestone)
                        .staggeredAppearance(index: index + 3)
                }
            }
        }
        .padding(PSSpacing.cardPadding)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    // MARK: - Education
    private var educationSection: some View {
        VStack(spacing: PSSpacing.lg) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(PSColors.secondaryAmber)
                Text(String(localized: "Did You Know?"))
                    .font(PSTypography.headline)
                Spacer()
            }

            VStack(spacing: PSSpacing.md) {
                EducationTip(
                    icon: "cart.fill",
                    title: String(localized: "Plan Before You Shop"),
                    description: String(localized: "Check your pantry before shopping. Meal planning can reduce household food waste by up to 30%.")
                )

                EducationTip(
                    icon: "thermometer.snowflake",
                    title: String(localized: "Freeze Before It Expires"),
                    description: String(localized: "Most foods can be frozen before their expiry date, extending their life by weeks or months.")
                )

                EducationTip(
                    icon: "arrow.3.trianglepath",
                    title: String(localized: "First In, First Out"),
                    description: String(localized: "Place newer items behind older ones. Use the FIFO method to naturally rotate your stock.")
                )

                EducationTip(
                    icon: "person.2.fill",
                    title: String(localized: "Share the Surplus"),
                    description: String(localized: "If you can't use it, share it. Community food sharing reduces waste and feeds neighbors in need.")
                )
            }
        }
        .padding(PSSpacing.cardPadding)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .staggeredAppearance(index: 5)
    }

    // MARK: - CTA
    private var ctaSection: some View {
        VStack(spacing: PSSpacing.md) {
            Text(String(localized: "Keep going! Every item counts."))
                .font(PSTypography.bodyMedium)
                .foregroundStyle(PSColors.textSecondary)
                .multilineTextAlignment(.center)

            PSButton(
                title: String(localized: "Check Your Pantry"),
                icon: "refrigerator.fill",
                style: .primary,
                size: .large,
                isFullWidth: true
            ) {
                dismiss()
            }
        }
        .padding(.vertical, PSSpacing.lg)
        .staggeredAppearance(index: 6)
    }

    // MARK: - Helpers
    private func equivalentTrees(_ co2Kg: Double) -> String {
        // Average tree absorbs ~22kg CO2/year
        let trees = max(1, Int(co2Kg / 22.0))
        return "\(trees)"
    }
}

// MARK: - Subcomponents

private struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    let index: Int

    var body: some View {
        VStack(spacing: PSSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(color)

            Text(value)
                .font(PSTypography.statMedium)
                .foregroundStyle(PSColors.textPrimary)
                .contentTransition(.numericText())

            Text(label)
                .font(PSTypography.caption1)
                .foregroundStyle(PSColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PSSpacing.xl)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg))
    }
}

private struct GlobalFactRow: View {
    let stat: String
    let description: String
    let source: String

    var body: some View {
        HStack(alignment: .top, spacing: PSSpacing.md) {
            Text(stat)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(PSColors.primaryGreen)
                .frame(width: 80, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(description)
                    .font(PSTypography.callout)
                    .foregroundStyle(PSColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("— \(source)")
                    .font(PSTypography.caption2)
                    .foregroundStyle(PSColors.textTertiary)
            }
        }
    }
}

private struct MilestoneRow: View {
    let milestone: ImpactService.Milestone

    var body: some View {
        HStack(spacing: PSSpacing.md) {
            PSProgressRing(
                progress: milestone.progress,
                lineWidth: 4,
                color: milestone.isUnlocked ? PSColors.primaryGreen : PSColors.textTertiary,
                size: 44
            )
            .overlay {
                Image(systemName: milestone.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(milestone.isUnlocked ? PSColors.primaryGreen : PSColors.textTertiary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(milestone.title)
                    .font(PSTypography.bodyMedium)
                    .foregroundStyle(milestone.isUnlocked ? PSColors.textPrimary : PSColors.textSecondary)

                Text(milestone.description)
                    .font(PSTypography.caption1)
                    .foregroundStyle(PSColors.textTertiary)
            }

            Spacer()

            if milestone.isUnlocked {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(PSColors.primaryGreen)
            } else {
                Text("\(Int(milestone.progress * 100))%")
                    .font(PSTypography.caption1Medium)
                    .foregroundStyle(PSColors.textTertiary)
            }
        }
        .padding(.vertical, PSSpacing.xs)
    }
}

private struct EducationTip: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: PSSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(PSColors.primaryGreen)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(PSTypography.calloutMedium)
                    .foregroundStyle(PSColors.textPrimary)

                Text(description)
                    .font(PSTypography.callout)
                    .foregroundStyle(PSColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ImpactDashboardView()
            .modelContainer(for: [PantryItem.self, SharedListing.self, UserProfile.self], inMemory: true)
    }
}
