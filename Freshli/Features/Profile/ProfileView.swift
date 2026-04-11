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
    @State private var householdSize: Int = 1
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
                    milestonesCard.staggeredAppearance(index: 2)
                    settingsCard.staggeredAppearance(index: 3)
                    proCard.staggeredAppearance(index: 4)
                }
                .adaptiveHPadding()
                .padding(.bottom, PSSpacing.xxxl)
            }
        }
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

                HStack(spacing: PSSpacing.xs) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: PSLayout.scaledFont(12)))
                    Text(String(localized: "Waste Warrior"))
                        .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                }
                .foregroundStyle(PSColors.primaryGreen)
                .padding(.horizontal, PSSpacing.sm)
                .padding(.vertical, PSSpacing.xxs)
                .background(PSColors.primaryGreen.opacity(0.1))
                .clipShape(Capsule())

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
        NavigationLink(destination: FreshliProView()) {
            HStack(spacing: PSSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(PSColors.secondaryAmber.opacity(0.15))
                        .frame(width: PSLayout.scaled(52), height: PSLayout.scaled(52))
                    Image(systemName: "crown.fill")
                        .font(.system(size: PSLayout.scaledFont(22)))
                        .foregroundStyle(PSColors.secondaryAmber)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Upgrade to Freshli+"))
                        .font(.system(size: PSLayout.scaledFont(16), weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                    Text(String(localized: "Unlock premium features and insights"))
                        .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                    .foregroundStyle(PSColors.textTertiary)
            }
            .adaptiveCardPadding()
            .background(
                LinearGradient(
                    colors: [PSColors.secondaryAmber.opacity(0.08), PSColors.secondaryAmber.opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: PSLayout.profileCardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PSLayout.profileCardRadius, style: .continuous)
                    .strokeBorder(PSColors.secondaryAmber.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: PSColors.secondaryAmber.opacity(0.1), radius: 12, y: 6)
        }
        .buttonStyle(PressableButtonStyle())
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
