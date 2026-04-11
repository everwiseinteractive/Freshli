import SwiftUI
import SwiftData

// MARK: - Perks View
// Zero Waste Points balance, reward catalog, and employer wellness milestones.

struct PerksView: View {
    @Query private var allItems: [FreshliItem]
    @Environment(\.modelContext) private var modelContext
    @Environment(PSToastManager.self) private var toastManager

    @State private var selectedCategory: RewardCategory? = nil
    @State private var showRedeemAlert = false
    @State private var selectedReward: WasteReward?
    @State private var showRedemptionConfetti = false
    @State private var lastRedeemedReward: WasteReward?

    private var stats: ImpactService.ImpactStats {
        ImpactService(modelContext: modelContext).calculateStats()
    }
    private var points: Int { PerksService.shared.points(for: stats.itemsSaved) }
    private var unlockedPerks: [EmployerPerk] { PerksService.shared.unlockedPerks(itemsSaved: stats.itemsSaved, co2Avoided: stats.co2Avoided) }
    private var nextPerk: EmployerPerk? { PerksService.shared.nextPerk(itemsSaved: stats.itemsSaved, co2Avoided: stats.co2Avoided) }
    private var filteredRewards: [WasteReward] {
        guard let cat = selectedCategory else { return PerksService.shared.rewards }
        return PerksService.shared.rewards.filter { $0.category == cat }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: PSSpacing.xxl) {
                pointsHeroCard
                employerSection
                rewardCatalogSection
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.vertical, PSSpacing.lg)
        }
        .background(PSColors.backgroundPrimary)
        .navigationTitle("Zero Waste Perks")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Redeem Reward", isPresented: $showRedeemAlert, presenting: selectedReward) { reward in
            Button("Redeem \(reward.pointsCost) pts") {
                redeem(reward)
            }
            Button("Cancel", role: .cancel) { }
        } message: { reward in
            Text("Redeem \(reward.discountValue) from \(reward.retailer) for \(reward.pointsCost) Zero Waste Points?")
        }
    }

    // MARK: - Redemption

    private func redeem(_ reward: WasteReward) {
        guard points >= reward.pointsCost else {
            toastManager.show(.warning(String(localized: "Not enough points yet — keep rescuing!")))
            return
        }
        PSHaptics.shared.success()
        lastRedeemedReward = reward
        toastManager.show(.success(String(localized: "\(reward.discountValue) from \(reward.retailer) redeemed! Check your email for the code.")))
    }

    // MARK: - Points Hero

    private var pointsHeroCard: some View {
        VStack(spacing: PSSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                    Text("Your Points Balance")
                        .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    HStack(alignment: .firstTextBaseline, spacing: PSSpacing.xs) {
                        Text(PerksService.shared.pointsDisplay(for: stats.itemsSaved))
                            .font(.system(size: PSLayout.scaledFont(48), weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("pts")
                            .font(.system(size: PSLayout.scaledFont(20), weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.bottom, PSSpacing.xs)
                    }
                    Text("\(stats.itemsSaved) items rescued · \(stats.co2Display) CO₂ avoided")
                        .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                ZStack {
                    Circle().fill(.white.opacity(0.12)).frame(width: PSLayout.scaled(64), height: PSLayout.scaled(64))
                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: PSLayout.scaledFont(36)))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            // Earn rate note
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: PSLayout.scaledFont(14)))
                    .foregroundStyle(.white.opacity(0.8))
                Text("Earn 10 pts for every item you rescue from waste")
                    .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
            }
            .padding(PSSpacing.md)
            .background(.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
        }
        .padding(PSSpacing.xl)
        .background(LinearGradient(
            colors: [PSColors.primaryGreen, PSColors.accentTeal.opacity(0.9)],
            startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .shadow(color: PSColors.primaryGreen.opacity(0.35), radius: 20, y: 8)
    }

    // MARK: - Employer Wellness Section

    private var employerSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: PSLayout.scaledFont(13)))
                    .foregroundStyle(Color(hex: 0xA855F7))
                Text("Employer Wellness")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                    .foregroundStyle(PSColors.textSecondary)
                    .textCase(.uppercase).tracking(0.5)
                Spacer()
                Text("\(unlockedPerks.count)/\(PerksService.shared.employerPerks.count) unlocked")
                    .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
                    .foregroundStyle(Color(hex: 0xA855F7))
                    .padding(.horizontal, PSSpacing.sm)
                    .padding(.vertical, PSSpacing.xxs)
                    .background(Color(hex: 0xA855F7).opacity(0.1))
                    .clipShape(Capsule())
            }

            ForEach(PerksService.shared.employerPerks) { perk in
                let isUnlocked = unlockedPerks.contains(where: { $0.id == perk.id })
                employerPerkRow(perk, isUnlocked: isUnlocked)
            }

            if let next = nextPerk {
                nextPerkProgress(next)
            }
        }
    }

    private func employerPerkRow(_ perk: EmployerPerk, isUnlocked: Bool) -> some View {
        HStack(spacing: PSSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isUnlocked ? perk.color.opacity(0.15) : PSColors.borderLight.opacity(0.5))
                    .frame(width: PSLayout.scaled(44), height: PSLayout.scaled(44))
                Image(systemName: isUnlocked ? perk.icon : "lock.fill")
                    .font(.system(size: PSLayout.scaledFont(18)))
                    .foregroundStyle(isUnlocked ? perk.color : PSColors.textTertiary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(perk.title)
                    .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                    .foregroundStyle(isUnlocked ? PSColors.textPrimary : PSColors.textTertiary)
                Text(perk.description)
                    .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            if isUnlocked {
                Text(perk.perkValue)
                    .font(.system(size: PSLayout.scaledFont(11), weight: .bold))
                    .foregroundStyle(perk.color)
                    .padding(.horizontal, PSSpacing.sm)
                    .padding(.vertical, PSSpacing.xxs)
                    .background(perk.color.opacity(0.12))
                    .clipShape(Capsule())
            } else {
                Text("\(perk.itemsThreshold) items")
                    .font(.system(size: PSLayout.scaledFont(11), weight: .semibold))
                    .foregroundStyle(PSColors.textTertiary)
            }
        }
        .padding(PSSpacing.md)
        .background(isUnlocked ? PSColors.surfaceCard : PSColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
            .strokeBorder(isUnlocked ? perk.color.opacity(0.2) : PSColors.borderLight, lineWidth: 1))
        .opacity(isUnlocked ? 1 : 0.6)
    }

    private func nextPerkProgress(_ perk: EmployerPerk) -> some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            HStack {
                Text("Progress to \(perk.title)")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                    .foregroundStyle(PSColors.textSecondary)
                Spacer()
                Text("\(stats.itemsSaved)/\(perk.itemsThreshold) items")
                    .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
                    .foregroundStyle(perk.color)
            }
            GeometryReader { geo in
                let progress = min(1.0, Double(stats.itemsSaved) / Double(perk.itemsThreshold))
                ZStack(alignment: .leading) {
                    Capsule().fill(PSColors.borderLight).frame(height: PSLayout.scaled(8))
                    Capsule()
                        .fill(LinearGradient(colors: [perk.color, perk.color.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progress, height: PSLayout.scaled(8))
                }
            }
            .frame(height: PSLayout.scaled(8))
        }
        .padding(PSSpacing.md)
        .background(perk.color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
    }

    // MARK: - Reward Catalog

    private var rewardCatalogSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: "gift.fill")
                    .font(.system(size: PSLayout.scaledFont(13)))
                    .foregroundStyle(PSColors.secondaryAmber)
                Text("Reward Catalog")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                    .foregroundStyle(PSColors.textSecondary)
                    .textCase(.uppercase).tracking(0.5)
            }

            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PSSpacing.sm) {
                    categoryChip(nil, label: "All")
                    ForEach(RewardCategory.allCases) { cat in
                        categoryChip(cat, label: cat.rawValue)
                    }
                }
                .padding(.horizontal, 1)
            }

            ForEach(filteredRewards) { reward in
                rewardCard(reward)
            }
        }
    }

    private func categoryChip(_ cat: RewardCategory?, label: String) -> some View {
        let isSelected = selectedCategory == cat
        return Button {
            PSHaptics.shared.lightTap()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { selectedCategory = cat }
        } label: {
            Text(label)
                .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                .foregroundStyle(isSelected ? .white : PSColors.textSecondary)
                .padding(.horizontal, PSSpacing.md)
                .padding(.vertical, PSSpacing.xs)
                .background(isSelected ? PSColors.secondaryAmber : PSColors.surfaceCard)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? Color.clear : PSColors.borderLight, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func rewardCard(_ reward: WasteReward) -> some View {
        let canAfford = points >= reward.pointsCost
        return HStack(spacing: PSSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(reward.retailerColor.opacity(0.12))
                    .frame(width: PSLayout.scaled(50), height: PSLayout.scaled(50))
                Text(reward.retailerLogo)
                    .font(.system(size: PSLayout.scaledFont(22), weight: .black))
                    .foregroundStyle(reward.retailerColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(reward.title)
                    .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                    .foregroundStyle(PSColors.textPrimary)
                Text(reward.description)
                    .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .lineLimit(2)
                Text(reward.retailer)
                    .font(.system(size: PSLayout.scaledFont(11), weight: .semibold))
                    .foregroundStyle(reward.retailerColor)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: PSSpacing.xs) {
                Text(reward.discountValue)
                    .font(.system(size: PSLayout.scaledFont(15), weight: .black, design: .rounded))
                    .foregroundStyle(canAfford ? PSColors.primaryGreen : PSColors.textTertiary)
                Button {
                    PSHaptics.shared.mediumTap()
                    selectedReward = reward
                    showRedeemAlert = true
                } label: {
                    Text("\(reward.pointsCost) pts")
                        .font(.system(size: PSLayout.scaledFont(11), weight: .bold))
                        .foregroundStyle(canAfford ? .white : PSColors.textTertiary)
                        .padding(.horizontal, PSSpacing.sm)
                        .padding(.vertical, PSSpacing.xxs)
                        .background(canAfford ? PSColors.primaryGreen : PSColors.borderLight)
                        .clipShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(!canAfford)
            }
        }
        .padding(PSSpacing.md)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
            .strokeBorder(PSColors.borderLight, lineWidth: 1))
        .opacity(canAfford ? 1 : 0.7)
    }
}

#Preview {
    NavigationStack { PerksView() }
        .modelContainer(for: FreshliItem.self, inMemory: true)
}
