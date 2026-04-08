import SwiftUI
import SwiftData

// Figma: Profile — bg-emerald-50, back button, settings gear
// Profile card: w-20 h-20 avatar with ring-4, "Waste Warrior" subtitle
// 2-col stats grid: Food Saved (emerald bg) + Meals Shared (white bg)
// Settings list: Dark Mode toggle, Household, Notifications, Language, Logout

struct ProfileView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager: AuthManager?

    @State private var showExpiryAlerts = false
    @State private var showAuthSheet = false
    @State private var showDeleteConfirm = false
    @State private var showSettings = false
    @State private var showHouseholdSettings = false
    @State private var showLanguageSettings = false
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var appeared = false

    private var profile: UserProfile {
        if let existing = profiles.first {
            return existing
        }
        let newProfile = UserProfile()
        modelContext.insert(newProfile)
        try? modelContext.save()
        return newProfile
    }

    private var isAuthenticated: Bool {
        authManager?.authState == .authenticated
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                profileCard
                    .staggeredAppearance(index: 0)
                statsGrid
                    .staggeredAppearance(index: 1)
                milestonesCard
                    .staggeredAppearance(index: 2)
                settingsCard
                    .staggeredAppearance(index: 3)
            }
            .adaptiveHPadding()
            .padding(.vertical, PSSpacing.lg)
        }
        .background(PSColors.emeraldSurface)
        .navigationTitle(String(localized: "Profile"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: PSLayout.scaledFont(20)))
                        .foregroundStyle(PSColors.primaryGreen)
                        .frame(width: PSLayout.iconButtonSize, height: PSLayout.iconButtonSize)
                        .background(PSColors.emeraldLight)
                        .clipShape(Circle())
                }
            }
        }
        .navigationDestination(isPresented: $showExpiryAlerts) {
            ExpiryAlertsView()
        }
        .sheet(isPresented: $showAuthSheet) {
            AuthView()
                .presentationDragIndicator(.visible)
        }
        .alert(String(localized: "Delete Account"), isPresented: $showDeleteConfirm) {
            Button(String(localized: "Cancel"), role: .cancel) {}
            Button(String(localized: "Delete"), role: .destructive) {
                Task { try? await authManager?.deleteAccount() }
            }
        } message: {
            Text(String(localized: "This will permanently delete your account and all associated data. This action cannot be undone."))
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
            .presentationDragIndicator(.visible)
            .presentationDetents([.large])
        }
        .alert(String(localized: "Household Settings"), isPresented: $showHouseholdSettings) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(String(localized: "Household sharing lets family members contribute to the same pantry. Coming in a future update!"))
        }
        .alert(String(localized: "Language"), isPresented: $showLanguageSettings) {
            Button(String(localized: "Open Settings"), role: .cancel) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "PantryShare uses your device language. To change it, update your language in iOS Settings."))
        }
    }

    // MARK: - Figma: Profile card with avatar and "Waste Warrior"

    private var profileCard: some View {
        HStack(spacing: PSSpacing.xl) {
            // Figma: w-20 h-20 rounded-full ring-4 ring-emerald-50
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: PSLayout.avatarSize(64)))
                .foregroundStyle(PSColors.primaryGreen.opacity(0.4))
                .adaptiveFrame(width: 80, height: 80)
                .background(.white)
                .clipShape(Circle())
                .overlay(
                    Circle().strokeBorder(PSColors.emeraldSurface, lineWidth: 4)
                )
                .shadow(color: .black.opacity(0.04), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: PSSpacing.xxs) {
                Text(authManager?.currentDisplayName ?? (profile.displayName.isEmpty ? String(localized: "PantryShare User") : profile.displayName))
                    .font(.system(size: PSLayout.scaledFont(24), weight: .bold))
                    .tracking(-0.3)
                    .foregroundStyle(Color(hex: 0x022C22)) // emerald-950

                HStack(spacing: PSSpacing.xs) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: PSLayout.scaledFont(14)))
                    Text(String(localized: "Waste Warrior"))
                        .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                }
                .foregroundStyle(PSColors.primaryGreen.opacity(0.6))
            }

            Spacer()
        }
        .adaptiveCardPadding()
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSLayout.profileCardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSLayout.profileCardRadius, style: .continuous)
                .strokeBorder(PSColors.emeraldSurface, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 8, y: 4)
    }

    // MARK: - Figma: 2-col stats grid

    private var statsGrid: some View {
        let stats = ImpactService(modelContext: modelContext).calculateStats()

        return HStack(spacing: 12) {
            // Figma: emerald-600 card
            VStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: PSLayout.scaledFont(24)))
                    .opacity(0.8)
                Text("\(stats.itemsSaved)")
                    .font(.system(size: PSLayout.scaledFont(30), weight: .bold))
                Text(String(localized: "Food Saved"))
                    .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(PSColors.headerGreen)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
            .shadow(color: PSColors.headerGreen.opacity(0.2), radius: 16, y: 8)

            // Figma: white card with heart
            VStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.system(size: PSLayout.scaledFont(24)))
                    .foregroundStyle(Color(hex: 0xFB7185)) // rose-400
                Text("\(stats.itemsShared)")
                    .font(.system(size: PSLayout.scaledFont(30), weight: .bold))
                    .foregroundStyle(Color(hex: 0x022C22)) // emerald-950
                Text(String(localized: "Meals Shared"))
                    .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                    .foregroundStyle(PSColors.primaryGreen.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(PSColors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                    .strokeBorder(PSColors.emeraldSurface, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 8, y: 4)
        }
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
                    Text(String(localized: "Milestones"))
                        .font(.system(size: PSLayout.scaledFont(18), weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                }
                Spacer()
                Text(String(localized: "\(unlockedCount)/\(allMilestones.count)"))
                    .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                    .foregroundStyle(PSColors.primaryGreen)
            }

            if nextMilestones.isEmpty {
                // All milestones unlocked
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
                    ForEach(Array(nextMilestones.enumerated()), id: \.element.id) { index, milestone in
                        milestoneRow(milestone: milestone, index: index)
                    }
                }
            }
        }
        .adaptiveCardPadding()
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSLayout.profileCardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSLayout.profileCardRadius, style: .continuous)
                .strokeBorder(PSColors.emeraldSurface, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 8, y: 4)
    }

    private func milestoneRow(milestone: ImpactService.Milestone, index: Int) -> some View {
        HStack(spacing: PSSpacing.lg) {
            PSProgressRing(
                progress: milestone.progress,
                lineWidth: 4,
                color: milestone.isUnlocked ? PSColors.primaryGreen : PSColors.secondaryAmber,
                size: 44
            )
            .overlay {
                Image(systemName: milestone.icon)
                    .font(.system(size: PSLayout.scaledFont(16), weight: .semibold))
                    .foregroundStyle(milestone.isUnlocked ? PSColors.primaryGreen : PSColors.secondaryAmber)
            }

            VStack(alignment: .leading, spacing: 2) {
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

    // MARK: - Figma: Settings list

    private var settingsCard: some View {
        VStack(spacing: 0) {
            // Figma: Dark Mode toggle with spring-animated thumb
            settingsToggleRow(
                icon: "moon.fill",
                title: String(localized: "Dark Mode"),
                tintColor: Color(hex: 0x6366F1), // indigo
                isOn: $isDarkMode
            )

            Divider().padding(.leading, 60)

            // Figma: Notifications toggle
            settingsToggleRow(
                icon: "bell.badge.fill",
                title: String(localized: "Notifications"),
                tintColor: PSColors.expiredRed,
                isOn: Binding(
                    get: { profile.notificationsEnabled },
                    set: { profile.notificationsEnabled = $0; try? modelContext.save() }
                )
            )

            Divider().padding(.leading, 60)

            // Figma: Household Settings
            settingsNavRow(icon: "house.fill", title: String(localized: "Household Settings")) {
                showHouseholdSettings = true
            }

            Divider().padding(.leading, 60)

            // Figma: Expiry Alerts
            settingsNavRow(icon: "clock.badge.exclamationmark", title: String(localized: "Expiry Alerts")) {
                showExpiryAlerts = true
            }

            Divider().padding(.leading, 60)

            // Figma: Language
            settingsNavRow(icon: "globe", title: String(localized: "Language")) {
                showLanguageSettings = true
            }

            Divider().padding(.leading, 60)

            // Figma: Logout / Sign In (rose text for logout, green for sign in)
            if isAuthenticated {
                Button {
                    Task { await authManager?.signOut() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16))
                        Text(String(localized: "Logout"))
                            .font(.system(size: PSLayout.scaledFont(16), weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                            .foregroundStyle(PSColors.emeraldLight)
                    }
                    .foregroundStyle(PSColors.expiredRed)
                    .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
                    .padding(.vertical, 16)
                }

                Divider().padding(.leading, 60)

                // Delete Account
                Button { showDeleteConfirm = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16))
                        Text(String(localized: "Delete Account"))
                            .font(.system(size: PSLayout.scaledFont(16), weight: .semibold))
                        Spacer()
                    }
                    .foregroundStyle(PSColors.expiredRed.opacity(0.7))
                    .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
                    .padding(.vertical, 16)
                }
            } else {
                Button { showAuthSheet = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.badge.key.fill")
                            .font(.system(size: 16))
                        Text(String(localized: "Sign In"))
                            .font(.system(size: PSLayout.scaledFont(16), weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                            .foregroundStyle(PSColors.emeraldLight)
                    }
                    .foregroundStyle(PSColors.primaryGreen)
                    .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
                    .padding(.vertical, 16)
                }
            }
        }
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSLayout.profileCardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSLayout.profileCardRadius, style: .continuous)
                .strokeBorder(PSColors.emeraldSurface, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 8, y: 4)
    }

    private func settingsNavRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button {
            PSHaptics.shared.lightTap()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: 0x064E3B)) // emerald-900
                Text(title)
                    .font(.system(size: PSLayout.scaledFont(16), weight: .semibold))
                    .foregroundStyle(Color(hex: 0x064E3B))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                    .foregroundStyle(PSColors.emeraldMuted)
            }
            .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
            .padding(.vertical, 16)
        }
    }

    private func settingsToggleRow(icon: String, title: String, tintColor: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(tintColor)
            Text(title)
                .font(.system(size: PSLayout.scaledFont(16), weight: .semibold))
                .foregroundStyle(Color(hex: 0x064E3B))
            Spacer()
            // Figma: spring-animated toggle
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(PSColors.primaryGreen)
        }
        .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
        .padding(.vertical, 12)
    }
}
