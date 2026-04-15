import SwiftUI

// ══════════════════════════════════════════════════════════════════
// MARK: - FLCommunityFridgesCard (Organism)
// The community fridges card on the home dashboard. Shows nearby
// real-world fridges. Icon has NO background box.
// ══════════════════════════════════════════════════════════════════

struct FLCommunityFridgesCard: View {
    private let fridgeCount = CommunityPodsService.shared.communityFridges.count

    var body: some View {
        FLNavigableCard(
            destination: LocalPodsView().onAppear {
                AnalyticsService.shared.track(.fridgeViewed, properties: .props([
                    "fridge_count": fridgeCount,
                    "from": "home_card"
                ]))
            }
        ) {
            HStack(spacing: PSSpacing.lg) {
                // Refrigerator icon — NO background box
                Image(systemName: "refrigerator.fill")
                    .font(.system(size: PSLayout.scaledFont(28)))
                    .foregroundStyle(FreshliBrand.planetBlue)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: PSSpacing.xs) {
                        FLText("COMMUNITY FRIDGES", .sectionLabel, color: .custom(FreshliBrand.planetBlue))
                        Circle()
                            .fill(PSColors.primaryGreen)
                            .frame(width: 6, height: 6)
                    }
                    FLText(
                        String(localized: "Drop surplus, no questions asked"),
                        .callout,
                        color: .primary
                    )
                    FLText(
                        String(localized: "\(fridgeCount) real fridges nearby · Open 24/7"),
                        .caption,
                        color: .secondary
                    )
                    .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                    .foregroundStyle(PSColors.textTertiary)
            }
        }
    }
}
