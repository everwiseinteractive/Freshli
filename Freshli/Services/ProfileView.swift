import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    
    @Query private var profiles: [UserProfile]
    
    private var profile: UserProfile? {
        profiles.first
    }
    
    @State private var impactStats: ImpactService.ImpactStats?
    
    var body: some View {
        ScrollView {
            VStack(spacing: PSSpacing.xl) {
                // Profile Header
                VStack(spacing: PSSpacing.md) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(PSColors.primaryGreen)
                    
                    Text(profile?.displayName ?? "Freshli User")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                    
                    if let email = authManager.currentUserEmail {
                        Text(email)
                            .font(.system(size: 14))
                            .foregroundStyle(PSColors.textSecondary)
                    }
                }
                .padding(.top, PSSpacing.xl)
                
                // Impact Stats
                if let stats = impactStats {
                    VStack(alignment: .leading, spacing: PSSpacing.lg) {
                        Text("Your Impact")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(PSColors.textPrimary)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: PSSpacing.lg) {
                            StatCard(
                                icon: "leaf.fill",
                                value: "\(stats.itemsSaved)",
                                label: "Items Saved",
                                color: PSColors.freshGreen
                            )
                            
                            StatCard(
                                icon: "heart.fill",
                                value: "\(stats.itemsShared)",
                                label: "Items Shared",
                                color: PSColors.primaryGreen
                            )
                            
                            StatCard(
                                icon: "gift.fill",
                                value: "\(stats.itemsDonated)",
                                label: "Donated",
                                color: Color.purple
                            )
                            
                            StatCard(
                                icon: "dollarsign.circle.fill",
                                value: "$\(Int(stats.moneySaved))",
                                label: "Money Saved",
                                color: Color(hex: 0xFFB703)
                            )
                        }
                    }
                    .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
                }
                
                // Settings
                VStack(alignment: .leading, spacing: PSSpacing.sm) {
                    Text("Settings")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                    
                    SettingsRow(icon: "bell.fill", title: "Notifications", value: "On")
                    SettingsRow(icon: "globe", title: "Language", value: "English")
                    SettingsRow(icon: "clock.fill", title: "Expiry Reminder", value: "3 days")
                    
                    if authManager.authState == .authenticated {
                        Button {
                            Task {
                                await authManager.signOut()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundStyle(PSColors.expiredRed)
                                Text("Sign Out")
                                    .foregroundStyle(PSColors.expiredRed)
                                Spacer()
                            }
                            .padding(.vertical, PSSpacing.md)
                            .padding(.horizontal, PSSpacing.lg)
                            .background(PSColors.surfaceCard)
                            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg))
                        }
                    }
                }
                .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
                
                // App Info
                VStack(spacing: PSSpacing.xs) {
                    Text("Freshli")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PSColors.textTertiary)
                    Text("Version 1.0.0")
                        .font(.system(size: 12))
                        .foregroundStyle(PSColors.textTertiary)
                }
                .padding(.top, PSSpacing.xl)
            }
            .padding(.bottom, PSLayout.tabBarContentPadding)
        }
        .background(PSColors.backgroundSecondary)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            impactStats = ImpactService(modelContext: modelContext).calculateStats()
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: PSSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(color)
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(PSColors.textPrimary)
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PSColors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PSSpacing.lg)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

// MARK: - Settings Row

private struct SettingsRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(PSColors.primaryGreen)
            Text(title)
                .foregroundStyle(PSColors.textPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(PSColors.textSecondary)
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(PSColors.textTertiary)
        }
        .padding(.vertical, PSSpacing.md)
        .padding(.horizontal, PSSpacing.lg)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg))
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .modelContainer(for: UserProfile.self, inMemory: true)
    }
}
