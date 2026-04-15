import SwiftUI

// MARK: - Neighbor Badge View

struct NeighborBadgeView: View {
    let badge: NeighborBadge
    let isEarned: Bool

    @State private var showDetails = false

    var body: some View {
        Button(action: { showDetails.toggle() }) {
            VStack(spacing: PSSpacing.sm) {
                // Badge Icon
                ZStack {
                    Circle()
                        .fill(isEarned ? badge.color.opacity(0.15) : PSColors.borderLight)
                        .frame(width: 60, height: 60)

                    if isEarned {
                        Circle()
                            .strokeBorder(badge.color, lineWidth: 2)
                            .frame(width: 60, height: 60)

                        Image(systemName: badge.icon)
                            .font(.system(size: PSLayout.scaledFont(28)))
                            .foregroundStyle(badge.color)
                    } else {
                        Image(systemName: badge.icon)
                            .font(.system(size: PSLayout.scaledFont(28)))
                            .foregroundStyle(PSColors.textTertiary)

                        Image(systemName: "lock.fill")
                            .font(.system(size: PSLayout.scaledFont(14)))
                            .foregroundStyle(PSColors.textTertiary)
                            .offset(x: 20, y: 20)
                    }
                }

                // Badge Name
                Text(badge.displayName)
                    .font(PSTypography.caption1)
                    .foregroundStyle(isEarned ? PSColors.textPrimary : PSColors.textTertiary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                // Earned/Locked Indicator
                if isEarned {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: PSLayout.scaledFont(12)))
                        .foregroundStyle(badge.color)
                } else {
                    Text(String(localized: "Locked"))
                        .font(PSTypography.caption2)
                        .foregroundStyle(PSColors.textTertiary)
                }
            }
            .padding(.vertical, PSSpacing.sm)
            .padding(.horizontal, PSSpacing.xs)
        }
        .sheet(isPresented: $showDetails) {
            BadgeDetailsSheet(badge: badge, isEarned: isEarned)
                .presentationDragIndicator(.visible)
                .sheetTransition()
        }
    }
}

// MARK: - Badge Details Sheet

private struct BadgeDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let badge: NeighborBadge
    let isEarned: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .center, spacing: PSSpacing.xxl) {
                    // Large Badge Icon
                    ZStack {
                        Circle()
                            .fill(isEarned ? badge.color.opacity(0.15) : PSColors.borderLight)
                            .frame(width: 120, height: 120)

                        if isEarned {
                            Circle()
                                .strokeBorder(badge.color, lineWidth: 3)
                                .frame(width: 120, height: 120)

                            Image(systemName: badge.icon)
                                .font(.system(size: PSLayout.scaledFont(56)))
                                .foregroundStyle(badge.color)
                        } else {
                            Image(systemName: badge.icon)
                                .font(.system(size: PSLayout.scaledFont(56)))
                                .foregroundStyle(PSColors.textTertiary)

                            Image(systemName: "lock.fill")
                                .font(.system(size: PSLayout.scaledFont(24)))
                                .foregroundStyle(PSColors.textTertiary)
                                .offset(x: 38, y: 38)
                        }
                    }
                    .padding(.top, PSSpacing.xxl)

                    // Badge Name and Status
                    VStack(alignment: .center, spacing: PSSpacing.md) {
                        Text(badge.displayName)
                            .font(PSTypography.title2)
                            .foregroundStyle(PSColors.textPrimary)

                        HStack(spacing: PSSpacing.sm) {
                            if isEarned {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: PSLayout.scaledFont(16)))
                                    .foregroundStyle(badge.color)

                                Text(String(localized: "Earned"))
                                    .font(PSTypography.subheadline)
                                    .foregroundStyle(badge.color)
                            } else {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: PSLayout.scaledFont(16)))
                                    .foregroundStyle(PSColors.textTertiary)

                                Text(String(localized: "Locked"))
                                    .font(PSTypography.subheadline)
                                    .foregroundStyle(PSColors.textTertiary)
                            }
                        }
                    }

                    // Description
                    VStack(alignment: .leading, spacing: PSSpacing.md) {
                        Text(String(localized: "About"))
                            .font(PSTypography.headline)
                            .foregroundStyle(PSColors.textPrimary)

                        Text(badge.description)
                            .font(PSTypography.body)
                            .foregroundStyle(PSColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Requirements
                    VStack(alignment: .leading, spacing: PSSpacing.md) {
                        Text(String(localized: "Requirements"))
                            .font(PSTypography.headline)
                            .foregroundStyle(PSColors.textPrimary)

                        requirementsView
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.vertical, PSSpacing.xxl)
            }
            .background(PSColors.backgroundPrimary)
            .navigationTitle(badge.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: PSLayout.scaledFont(24)))
                            .foregroundStyle(PSColors.textTertiary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var requirementsView: some View {
        switch badge {
        case .firstShare:
            RequirementRow(
                icon: "hand.thumbsup.fill",
                title: String(localized: "Complete 1 handoff"),
                isMet: isEarned
            )

        case .reliable:
            RequirementRow(
                icon: "checkmark.circle.fill",
                title: String(localized: "Complete 5 successful handoffs"),
                isMet: isEarned
            )

        case .superSharer:
            RequirementRow(
                icon: "gift.fill",
                title: String(localized: "Complete 15 successful handoffs"),
                isMet: isEarned
            )

        case .punctual:
            RequirementRow(
                icon: "clock.fill",
                title: String(localized: "Maintain 90% on-time pickup rate"),
                isMet: isEarned
            )

        case .qualityStar:
            RequirementRow(
                icon: "sparkles",
                title: String(localized: "Achieve 4.5+ average quality rating"),
                isMet: isEarned
            )

        case .communityHero:
            RequirementRow(
                icon: "crown.fill",
                title: String(localized: "Complete 25+ community handoffs"),
                isMet: isEarned
            )
        }
    }
}

// MARK: - Requirement Row

private struct RequirementRow: View {
    let icon: String
    let title: String
    let isMet: Bool

    var body: some View {
        HStack(spacing: PSSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: PSLayout.scaledFont(18)))
                .foregroundStyle(isMet ? PSColors.primaryGreen : PSColors.textTertiary)
                .frame(width: PSSpacing.xl)

            Text(title)
                .font(PSTypography.body)
                .foregroundStyle(isMet ? PSColors.textPrimary : PSColors.textTertiary)

            Spacer()

            if isMet {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: PSLayout.scaledFont(18)))
                    .foregroundStyle(PSColors.primaryGreen)
            }
        }
        .padding(.vertical, PSSpacing.sm)
        .padding(.horizontal, PSSpacing.md)
        .background(isMet ? PSColors.primaryGreen.opacity(0.08) : PSColors.surfaceCard)
        .cornerRadius(PSSpacing.radiusMd)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: PSSpacing.lg) {
        HStack(spacing: PSSpacing.md) {
            NeighborBadgeView(badge: .firstShare, isEarned: true)
            NeighborBadgeView(badge: .reliable, isEarned: true)
            NeighborBadgeView(badge: .superSharer, isEarned: false)
        }

        Spacer()
    }
    .padding()
}
