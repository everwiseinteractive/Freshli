import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
    @Environment(NetworkMonitor.self) private var networkMonitor

    @State private var showExpiryAlerts = false
    @State private var showAuthSheet = false
    @State private var showDeleteConfirm = false
    @State private var showSettings = false
    @State private var showHouseholdSettings = false
    @State private var showLanguageSettings = false
    @State private var showDiscover = false
    @State private var householdSize: Int = 1
    @Environment(SubscriptionService.self) private var subscriptionService
    @AppStorage("isDarkMode") private var isDarkMode = false

    private var profile: UserProfile {
        if let existing = profiles.first { return existing }
        let newProfile = UserProfile()
        modelContext.insert(newProfile)
        try? modelContext.save()
        return newProfile
    }

    private var isAuthenticated: Bool { authManager.authState == .authenticated }
    private var displayName: String {
        authManager.currentDisplayName ?? (profile.displayName.isEmpty ? String(localized: "Freshli User") : profile.displayName)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero banner — blends into the content below
                heroBanner
                    .padding(.bottom, PSLayout.scaled(-40))

                VStack(spacing: PSSpacing.xl) {
                    profileCard.staggeredAppearance(index: 0)
                    statsGrid.staggeredAppearance(index: 1)
                    heroTierCard.staggeredAppearance(index: 2)
                    discoverHeroCard.staggeredAppearance(index: 3)
                    milestonesCard.staggeredAppearance(index: 4)
                    settingsCard.staggeredAppearance(index: 5)
                    proCard.staggeredAppearance(index: 6)
                }
                .adaptiveHPadding()
            }
        }
        .contentMargins(.bottom, PSLayout.scaled(150), for: .scrollContent)
        .background(PSColors.backgroundSecondary)
        .ignoresSafeArea(edges: .top)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: PSLayout.scaledFont(18)))
                        .foregroundStyle(.white)
                        .frame(width: PSLayout.iconButtonSize, height: PSLayout.iconButtonSize)
                        .background(.white.opacity(0.2))
                        .clipShape(Circle())
                }
            }
        }
        .navigationDestination(isPresented: $showExpiryAlerts) { ExpiryAlertsView() }
        .navigationDestination(isPresented: $showDiscover) { DiscoverView() }
        .sheet(isPresented: $showAuthSheet) {
            AuthView().presentationDragIndicator(.visible)
        }
        .alert(String(localized: "Delete Account"), isPresented: $showDeleteConfirm) {
            Button(String(localized: "Cancel"), role: .cancel) {}
            Button(String(localized: "Delete"), role: .destructive) {
                Task { try? await authManager.deleteAccount() }
            }
        } message: {
            Text(String(localized: "This will permanently delete your account and all associated data. This action cannot be undone."))
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
                .presentationDragIndicator(.visible)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showHouseholdSettings) {
            householdSheet
        }
        .alert(String(localized: "Language"), isPresented: $showLanguageSettings) {
            Button(String(localized: "Open Settings"), role: .cancel) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "Freshli uses your device language. To change it, update your language in iOS Settings."))
        }
    }

    // MARK: - Hero Banner

    private var heroBanner: some View {
        ZStack(alignment: .bottom) {
            // Gradient fill
            LinearGradient(
                colors: [PSColors.primaryGreen, PSColors.accentTeal.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: .top)
            .frame(height: PSLayout.scaled(180))

            // Decorative circles
            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: PSLayout.scaled(200))
                .blur(radius: 30)
                .offset(x: PSLayout.scaled(80), y: PSLayout.scaled(-40))

            Circle()
                .fill(.white.opacity(0.05))
                .frame(width: PSLayout.scaled(120))
                .blur(radius: 20)
                .offset(x: PSLayout.scaled(-60), y: PSLayout.scaled(20))

            // Offline banner
            if networkMonitor.isConnected == false {
                HStack(spacing: PSSpacing.sm) {
                    Image(systemName: "wifi.slash").font(.system(size: 12, weight: .semibold))
                    Text(String(localized: "Offline"))
                        .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, PSSpacing.md)
                .padding(.vertical, PSSpacing.sm)
                .background(.black.opacity(0.2))
                .clipShape(Capsule())
                .padding(.bottom, PSLayout.scaled(48))
            }
        }
        .frame(height: PSLayout.scaled(180))
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        HStack(spacing: PSSpacing.xl) {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: PSLayout.scaled(84), height: PSLayout.scaled(84))
                    .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [PSColors.primaryGreen, PSColors.accentTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: PSLayout.scaled(84), height: PSLayout.scaled(84))
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: PSLayout.scaledFont(60)))
                    .foregroundStyle(PSColors.primaryGreen.opacity(0.5))
            }

            VStack(alignment: .leading, spacing: PSSpacing.xs) {
                Text(displayName)
                    .font(.system(size: PSLayout.scaledFont(22), weight: .bold))
                    .tracking(-0.3)
                    .foregroundStyle(PSColors.textPrimary)

                let tier = HeroTier.tier(for: ImpactService(modelContext: modelContext).calculateStats().itemsSaved)
                HStack(spacing: PSSpacing.xs) {
                    Text(tier.emoji)
                        .font(.system(size: PSLayout.scaledFont(11)))
                    Text(tier.title)
                        .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                }
                .foregroundStyle(tier.color)
                .padding(.horizontal, PSSpacing.sm)
                .padding(.vertical, PSSpacing.xxs)
                .background(tier.color.opacity(0.12))
                .clipShape(Capsule())

                let streak = RescueStreakService.shared.currentStreak
                if streak > 0 {
                    HStack(spacing: PSSpacing.xs) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: PSLayout.scaledFont(11)))
                            .foregroundStyle(Color(hex: 0xF97316))
                        Text(String(localized: "\(streak)-day rescue streak"))
                            .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                            .foregroundStyle(PSColors.textSecondary)
                    }
                }

                if isAuthenticated {
                    Text(authManager.currentUserEmail ?? "")
                        .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                        .foregroundStyle(PSColors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .adaptiveCardPadding()
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSLayout.profileCardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 20, y: 8)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        let stats = ImpactService(modelContext: modelContext).calculateStats()

        return VStack(spacing: PSSpacing.md) {
            HStack(spacing: PSSpacing.md) {
                statCard(
                    icon: "leaf.fill",
                    value: "\(stats.itemsSaved)",
                    label: String(localized: "Food Saved"),
                    isAccent: true
                )
                statCard(
                    icon: "heart.fill",
                    value: "\(stats.itemsShared)",
                    label: String(localized: "Meals Shared"),
                    isAccent: false,
                    iconColor: Color(hex: 0xFB7185)
                )
            }
            HStack(spacing: PSSpacing.md) {
                statCard(
                    icon: "wind",
                    value: stats.co2Display,
                    label: String(localized: "CO₂ Avoided"),
                    isAccent: false,
                    iconColor: PSColors.accentTeal
                )
                statCard(
                    icon: "dollarsign.circle.fill",
                    value: stats.moneySavedDisplay,
                    label: String(localized: "Money Saved"),
                    isAccent: false,
                    iconColor: PSColors.secondaryAmber
                )
            }

            NavigationLink(destination: ImpactDashboardView()) {
                HStack(spacing: PSSpacing.xs) {
                    Text(String(localized: "View Full Impact Report"))
                        .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                        .foregroundStyle(PSColors.primaryGreen)
                    Image(systemName: "arrow.right")
                        .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                        .foregroundStyle(PSColors.primaryGreen)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, PSSpacing.md)
                .background(PSColors.primaryGreen.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
            }
        }
    }

    private func statCard(icon: String, value: String, label: String, isAccent: Bool, iconColor: Color = .white) -> some View {
        VStack(spacing: PSSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: PSLayout.scaledFont(22)))
                .foregroundStyle(isAccent ? .white.opacity(0.9) : iconColor)
            Text(value)
                .font(.system(size: PSLayout.scaledFont(28), weight: .black))
                .foregroundStyle(isAccent ? .white : PSColors.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                .foregroundStyle(isAccent ? .white.opacity(0.75) : PSColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PSSpacing.xl)
        .background(
            isAccent
                ? AnyShapeStyle(LinearGradient(colors: [PSColors.headerGreen, PSColors.primaryGreenDark], startPoint: .topLeading, endPoint: .bottomTrailing))
                : AnyShapeStyle(PSColors.surfaceCard)
        )
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                .strokeBorder(isAccent ? Color.clear : PSColors.borderLight, lineWidth: 1)
        )
        .shadow(
            color: isAccent ? PSColors.headerGreen.opacity(0.25) : .black.opacity(0.04),
            radius: isAccent ? 16 : 8,
            y: isAccent ? 8 : 4
        )
    }

    // MARK: - Hero Tier Card

    private var heroTierCard: some View {
        let stats = ImpactService(modelContext: modelContext).calculateStats()
        let tier = HeroTier.tier(for: stats.itemsSaved)
        let progress = HeroTier.progressToNextTier(for: stats.itemsSaved)
        let streak = RescueStreakService.shared.currentStreak

        return VStack(alignment: .leading, spacing: PSSpacing.lg) {
            // Header row
            HStack(spacing: PSSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tier.color.opacity(0.15))
                        .frame(width: PSLayout.scaled(36), height: PSLayout.scaled(36))
                    Text(tier.emoji)
                        .font(.system(size: PSLayout.scaledFont(18)))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(String(localized: "Hero Tier"))
                        .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                        .foregroundStyle(PSColors.textSecondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Text(tier.title)
                        .font(.system(size: PSLayout.scaledFont(18), weight: .black))
                        .foregroundStyle(tier.color)
                }
                Spacer()
                // Streak badge
                if streak > 0 {
                    HStack(spacing: PSSpacing.xxs) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: PSLayout.scaledFont(11)))
                        Text("\(streak)d")
                            .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
                    }
                    .foregroundStyle(Color(hex: 0xF97316))
                    .padding(.horizontal, PSSpacing.sm)
                    .padding(.vertical, PSSpacing.xxs)
                    .background(Color(hex: 0xF97316).opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            // Description
            Text(tier.description)
                .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                .foregroundStyle(PSColors.textSecondary)
                .lineSpacing(2)

            // Progress to next tier
            if let next = tier.nextTier {
                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                    HStack {
                        Text(String(localized: "Progress to \(next.emoji) \(next.title)"))
                            .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                            .foregroundStyle(PSColors.textSecondary)
                        Spacer()
                        Text(String(localized: "\(stats.itemsSaved)/\(next.minItems) items"))
                            .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
                            .foregroundStyle(tier.color)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(PSColors.borderLight)
                                .frame(height: PSLayout.scaled(8))
                            Capsule()
                                .fill(LinearGradient(colors: tier.gradientColors, startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * progress, height: PSLayout.scaled(8))
                        }
                    }
                    .frame(height: PSLayout.scaled(8))
                }
            } else {
                HStack(spacing: PSSpacing.sm) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: PSLayout.scaledFont(14)))
                        .foregroundStyle(tier.color)
                    Text(String(localized: "You've reached the highest tier — Legend! 👑"))
                        .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                        .foregroundStyle(tier.color)
                }
            }
        }
        .adaptiveCardPadding()
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSLayout.profileCardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSLayout.profileCardRadius, style: .continuous)
                .strokeBorder(tier.color.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: tier.color.opacity(0.08), radius: 16, y: 6)
    }

    // MARK: - Discover Hero Card

    private var discoverHeroCard: some View {
        Button {
            PSHaptics.shared.lightTap()
            showDiscover = true
        } label: {
            HStack(spacing: PSSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.18))
                        .frame(width: PSLayout.scaled(56), height: PSLayout.scaled(56))
                    Image(systemName: "sparkles")
                        .font(.system(size: PSLayout.scaledFont(26)))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "DISCOVER"))
                        .font(.system(size: PSLayout.scaledFont(10), weight: .black))
                        .foregroundStyle(.white.opacity(0.75))
                        .tracking(1.5)
                    Text(String(localized: "Advanced Tools"))
                        .font(.system(size: PSLayout.scaledFont(19), weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(String(localized: "Smart shopping, pods, analytics & more"))
                        .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: PSLayout.scaledFont(15), weight: .bold))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(PSSpacing.xl)
            .background(
                LinearGradient(
                    colors: [Color(hex: 0x8B5CF6), Color(hex: 0xEC4899).opacity(0.88)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: PSLayout.profileCardRadius, style: .continuous))
            .shadow(color: Color(hex: 0x8B5CF6).opacity(0.3), radius: 18, y: 8)
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Milestones Card

    private var milestonesCard: some View {
        let impactService = ImpactService(modelContext: modelContext)
        let stats = impactService.calculateStats()
        let allMilestones = impactService.milestones(for: stats)
        let nextMilestones = allMilestones.filter { !$0.isUnlocked }.prefix(3)
        let unlockedCount = allMilestones.filter(\.isUnlocked).count

        return VStack(alignment: .leading, spacing: PSSpacing.lg) {
            HStack {
                HStack(spacing: PSSpacing.sm) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: PSLayout.scaledFont(18)))
                        .foregroundStyle(PSColors.secondaryAmber)
                        .padding(PSSpacing.xs)
                        .background(PSColors.secondaryAmber.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Text(String(localized: "Milestones"))
                        .font(.system(size: PSLayout.scaledFont(17), weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                }
                Spacer()
                Text(String(localized: "\(unlockedCount)/\(allMilestones.count) unlocked"))
                    .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                    .foregroundStyle(PSColors.primaryGreen)
                    .padding(.horizontal, PSSpacing.sm)
                    .padding(.vertical, PSSpacing.xxs)
                    .background(PSColors.primaryGreen.opacity(0.1))
                    .clipShape(Capsule())
            }

            if nextMilestones.isEmpty {
                HStack(spacing: PSSpacing.md) {
                    Image(systemName: "star.fill")
                        .font(.system(size: PSLayout.scaledFont(20)))
                        .foregroundStyle(PSColors.secondaryAmber)
                    Text(String(localized: "All milestones unlocked! You're a true Waste Warrior."))
                        .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                }
                .padding(PSSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PSColors.secondaryAmber.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
            } else {
                VStack(spacing: PSSpacing.md) {
                    ForEach(Array(nextMilestones.enumerated()), id: \.element.id) { _, milestone in
                        milestoneRow(milestone: milestone)
                    }
                }
            }
        }
        .adaptiveCardPadding()
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSLayout.profileCardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSLayout.profileCardRadius, style: .continuous)
                .strokeBorder(PSColors.borderLight, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 12, y: 6)
    }

    private func milestoneRow(milestone: ImpactService.Milestone) -> some View {
        HStack(spacing: PSSpacing.lg) {
            PSProgressRing(
                progress: milestone.progress,
                lineWidth: 4,
                color: milestone.isUnlocked ? PSColors.primaryGreen : PSColors.secondaryAmber,
                size: PSLayout.scaled(44)
            )
            .overlay {
                Image(systemName: milestone.icon)
                    .font(.system(size: PSLayout.scaledFont(15), weight: .semibold))
                    .foregroundStyle(milestone.isUnlocked ? PSColors.primaryGreen : PSColors.secondaryAmber)
            }

            VStack(alignment: .leading, spacing: PSSpacing.xxxs) {
                Text(milestone.title)
                    .font(.system(size: PSLayout.scaledFont(15), weight: .bold))
                    .foregroundStyle(PSColors.textPrimary)
                Text(milestone.description)
                    .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(String(format: "%.0f%%", milestone.progress * 100))
                .font(.system(size: PSLayout.scaledFont(14), weight: .bold, design: .rounded))
                .foregroundStyle(milestone.progress >= 1.0 ? PSColors.primaryGreen : PSColors.textTertiary)
        }
        .padding(.vertical, PSSpacing.xs)
    }

    // MARK: - Settings Card

    private var settingsCard: some View {
        VStack(spacing: 0) {
            settingsToggleRow(icon: "moon.fill", title: String(localized: "Dark Mode"), iconBg: Color(hex: 0x6366F1), isOn: $isDarkMode)
            settingsDivider()
            settingsToggleRow(
                icon: "bell.badge.fill",
                title: String(localized: "Notifications"),
                iconBg: PSColors.expiredRed,
                isOn: Binding(
                    get: { profile.notificationsEnabled },
                    set: { profile.notificationsEnabled = $0; try? modelContext.save() }
                )
            )
            settingsDivider()
            settingsNavRow(icon: "house.fill", iconBg: PSColors.accentTeal, title: String(localized: "Household Settings")) { showHouseholdSettings = true }
            settingsDivider()
            settingsNavRow(icon: "clock.badge.exclamationmark", iconBg: PSColors.secondaryAmber, title: String(localized: "Expiry Alerts")) { showExpiryAlerts = true }
            settingsDivider()
            settingsNavRow(icon: "globe", iconBg: PSColors.infoBlue, title: String(localized: "Language")) { showLanguageSettings = true }
            settingsDivider()

            if isAuthenticated {
                settingsActionRow(icon: "rectangle.portrait.and.arrow.right", iconBg: PSColors.expiredRed.opacity(0.8), title: String(localized: "Sign Out"), foreground: PSColors.expiredRed) {
                    Task { await authManager.signOut() }
                }
                settingsDivider()
                settingsActionRow(icon: "trash.fill", iconBg: PSColors.expiredRed.opacity(0.5), title: String(localized: "Delete Account"), foreground: PSColors.expiredRed.opacity(0.7)) {
                    showDeleteConfirm = true
                }
            } else {
                settingsActionRow(icon: "person.badge.key.fill", iconBg: PSColors.primaryGreen, title: String(localized: "Sign In"), foreground: PSColors.primaryGreen) {
                    showAuthSheet = true
                }
            }
        }
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSLayout.profileCardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSLayout.profileCardRadius, style: .continuous)
                .strokeBorder(PSColors.borderLight, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 12, y: 6)
    }

    private func settingsDivider() -> some View {
        Divider().padding(.leading, PSLayout.adaptiveHorizontalPadding + 28 + PSSpacing.md)
    }

    private func settingsToggleRow(icon: String, title: String, iconBg: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: PSSpacing.md) {
            iconContainer(icon: icon, bg: iconBg)
            Text(title)
                .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
                .foregroundStyle(PSColors.textPrimary)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(PSColors.primaryGreen)
        }
        .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
        .padding(.vertical, PSSpacing.md)
    }

    private func settingsNavRow(icon: String, iconBg: Color, title: String, action: @escaping () -> Void) -> some View {
        Button {
            PSHaptics.shared.lightTap()
            action()
        } label: {
            HStack(spacing: PSSpacing.md) {
                iconContainer(icon: icon, bg: iconBg)
                Text(title)
                    .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
                    .foregroundStyle(PSColors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                    .foregroundStyle(PSColors.textTertiary)
            }
            .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
            .padding(.vertical, PSSpacing.md)
        }
    }

    private func settingsActionRow(icon: String, iconBg: Color, title: String, foreground: Color, action: @escaping () -> Void) -> some View {
        Button {
            PSHaptics.shared.lightTap()
            action()
        } label: {
            HStack(spacing: PSSpacing.md) {
                iconContainer(icon: icon, bg: iconBg)
                Text(title)
                    .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
                    .foregroundStyle(foreground)
                Spacer()
            }
            .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
            .padding(.vertical, PSSpacing.md)
        }
    }

    private func iconContainer(icon: String, bg: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    // MARK: - Pro Card

    private var proCard: some View {
        Group {
            if subscriptionService.isProUser {
                proMemberCard
            } else {
                proUpgradeCard
            }
        }
    }

    // Already subscribed — show appreciation & manage link
    private var proMemberCard: some View {
        HStack(spacing: PSSpacing.lg) {
            ZStack {
                Circle()
                    .fill(PSColors.primaryGreen.opacity(0.12))
                    .frame(width: PSLayout.scaled(50), height: PSLayout.scaled(50))
                Image(systemName: "crown.fill")
                    .font(.system(size: PSLayout.scaledFont(22)))
                    .foregroundStyle(PSColors.primaryGreen)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Freshli+ Member"))
                    .font(.system(size: PSLayout.scaledFont(16), weight: .bold))
                    .foregroundStyle(PSColors.textPrimary)
                Text(String(localized: "Thank you for supporting zero waste 🌱"))
                    .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
            }
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: PSLayout.scaledFont(22)))
                .foregroundStyle(PSColors.primaryGreen)
        }
        .adaptiveCardPadding()
        .background(PSColors.primaryGreen.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: PSLayout.profileCardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSLayout.profileCardRadius, style: .continuous)
                .strokeBorder(PSColors.primaryGreen.opacity(0.2), lineWidth: 1)
        )
    }

    // Free user — show compelling feature-preview upgrade card
    private var proUpgradeCard: some View {
        NavigationLink(destination: FreshliProView()) {
            VStack(alignment: .leading, spacing: PSSpacing.lg) {
                // Top row: badge + chevron
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: PSSpacing.xxs) {
                        HStack(spacing: PSSpacing.xs) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: PSLayout.scaledFont(11), weight: .black))
                            Text("FRESHLI+")
                                .font(.system(size: PSLayout.scaledFont(11), weight: .black))
                                .tracking(0.8)
                        }
                        .foregroundStyle(PSColors.secondaryAmber)

                        Text(String(localized: "Unlock your full potential"))
                            .font(.system(size: PSLayout.scaledFont(18), weight: .black))
                            .tracking(-0.3)
                            .foregroundStyle(PSColors.textPrimary)

                        Text(String(localized: "14-day free trial — no commitment"))
                            .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                            .foregroundStyle(PSColors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                        .foregroundStyle(PSColors.textTertiary)
                        .padding(PSSpacing.xs)
                }

                // Feature tiles — 3 concrete benefits
                HStack(spacing: PSSpacing.sm) {
                    proFeatureTile(icon: "sparkles",            color: Color(hex: 0x8B5CF6), title: "AI Chef",    detail: "Recipes from\nexpiring food")
                    proFeatureTile(icon: "chart.bar.fill",      color: PSColors.secondaryAmber, title: "Analytics", detail: "Savings &\nwaste trends")
                    proFeatureTile(icon: "person.2.fill",       color: Color(hex: 0x3B82F6), title: "Family",     detail: "Share with\nup to 6")
                }

                // CTA pill
                HStack {
                    Spacer()
                    Text(String(localized: "Start Free Trial  →"))
                        .font(.system(size: PSLayout.scaledFont(14), weight: .black))
                        .foregroundStyle(.black)
                        .padding(.horizontal, PSSpacing.xxl)
                        .padding(.vertical, PSSpacing.md)
                        .background(
                            LinearGradient(
                                colors: [PSColors.primaryGreen, Color(hex: 0x059652)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: PSColors.primaryGreen.opacity(0.35), radius: 10, y: 4)
                    Spacer()
                }
            }
            .adaptiveCardPadding()
            .background(
                LinearGradient(
                    colors: [PSColors.secondaryAmber.opacity(0.07), PSColors.secondaryAmber.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: PSLayout.profileCardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PSLayout.profileCardRadius, style: .continuous)
                    .strokeBorder(PSColors.secondaryAmber.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: PSColors.secondaryAmber.opacity(0.12), radius: 16, y: 6)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func proFeatureTile(icon: String, color: Color, title: String, detail: String) -> some View {
        VStack(spacing: PSSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: PSLayout.scaled(40), height: PSLayout.scaled(40))
                Image(systemName: icon)
                    .font(.system(size: PSLayout.scaledFont(18), weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(title)
                .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                .foregroundStyle(PSColors.textPrimary)
            Text(detail)
                .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                .foregroundStyle(PSColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PSSpacing.md)
        .padding(.horizontal, PSSpacing.xs)
        .background(PSColors.surfaceCard.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
    }

    // MARK: - Household Sheet

    private var householdSheet: some View {
        VStack(spacing: PSSpacing.lg) {
            VStack(spacing: PSSpacing.sm) {
                Text(String(localized: "Household Size"))
                    .font(PSTypography.title3)
                    .foregroundStyle(PSColors.textPrimary)
                Text(String(localized: "How many people share this pantry?"))
                    .font(PSTypography.caption1)
                    .foregroundStyle(PSColors.textSecondary)
            }
            Picker(String(localized: "Household Members"), selection: $householdSize) {
                ForEach(1...10, id: \.self) { num in
                    Text("\(num) \(num == 1 ? String(localized: "person") : String(localized: "people"))").tag(num)
                }
            }
            .pickerStyle(.wheel)
            PSButton(title: String(localized: "Save"), icon: "checkmark.circle") {
                showHouseholdSettings = false
                try? modelContext.save()
            }
            Spacer()
        }
        .padding(PSSpacing.lg)
        .presentationDragIndicator(.visible)
    }
}
