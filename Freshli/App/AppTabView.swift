import SwiftUI
import SwiftData

// Figma: 4 tabs — Home, Pantry (Apple icon), Recipes (Utensils), Community (Users)
// backdrop-blur-xl, active tab has bg-green-100 rounded-2xl with layoutId
// icon size 24, text-[10px], active text-green-600, inactive text-neutral-400

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case pantry
    case recipes
    case community
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return String(localized: "Home")
        case .pantry: return String(localized: "Pantry")
        case .recipes: return String(localized: "Recipes")
        case .community: return String(localized: "Community")
        case .profile: return String(localized: "Profile")
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .pantry: return "leaf.fill"       // Figma: Apple icon
        case .recipes: return "fork.knife"      // Figma: Utensils
        case .community: return "person.2.fill" // Figma: Users
        case .profile: return "person.fill"     // Figma: Profile
        }
    }
}

struct AppTabView: View {
    @State private var selectedTab: AppTab = .home
    @State private var previousTab: AppTab = .home
    @State private var showAddItem = false
    @Environment(\.modelContext) private var modelContext
    @Environment(CelebrationManager.self) private var celebrationManager
    @Environment(AuthManager.self) private var authManager
    @Environment(SyncService.self) private var syncService

    @Namespace private var tabNamespace

    /// Determines the slide direction based on tab order for organic transition
    private var slideDirection: FLMotion.TabSlideDirection {
        let allTabs = AppTab.allCases
        let currentIndex = allTabs.firstIndex(of: selectedTab) ?? 0
        let previousIndex = allTabs.firstIndex(of: previousTab) ?? 0
        return currentIndex >= previousIndex ? .forward : .backward
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content with custom Slide & Scale transition for organic tab switching
            Group {
                switch selectedTab {
                case .home:
                    NavigationStack {
                        HomeView(showAddItem: $showAddItem, switchToTab: { switchTab(to: $0) })
                    }
                case .pantry:
                    NavigationStack {
                        FreshliView(showAddItem: $showAddItem)
                    }
                case .recipes:
                    NavigationStack {
                        RecipesView()
                    }
                case .community:
                    NavigationStack {
                        CommunityView()
                    }
                case .profile:
                    NavigationStack {
                        ProfileView()
                    }
                }
            }
            .transition(FLMotion.tabSlideTransition(direction: slideDirection))
            .id(selectedTab)
            .padding(.bottom, PSLayout.tabBarContentPadding)

            // Figma: custom tab bar — bg-white/80 backdrop-blur-xl border-t
            customTabBar
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .ignoresSafeArea(.keyboard)
        // SensoryFeedback (.selection) on tab change — tactile click between Pantry & Community
        .sensoryFeedback(.selection, trigger: selectedTab)
        .sheet(isPresented: $showAddItem) {
            NavigationStack {
                AddItemView()
            }
            .presentationDragIndicator(.visible)
        }
        .task {
            seedDataIfNeeded()
            // Check for weekly recap celebration
            await celebrationManager.checkWeeklyRecap(modelContext: modelContext)
            
            // Perform initial sync if authenticated
            if let userId = authManager.currentUserId {
                await syncService.performFullSync(userId: userId, modelContext: modelContext)
            }
        }
    }

    /// Switches tab with direction tracking for organic slide + scale transition
    private func switchTab(to tab: AppTab) {
        guard tab != selectedTab else { return }
        previousTab = selectedTab
        withAnimation(FLMotion.tabTransition) {
            selectedTab = tab
        }
    }

    // Figma: iOS-style bottom navigation
    // Uses explicit bottom safe area inset so the material fills to the screen edge.
    private var customTabBar: some View {
        HStack {
            ForEach(AppTab.allCases) { tab in
                Button {
                    switchTab(to: tab)
                } label: {
                    VStack(spacing: PSSpacing.xxs) {
                        Image(systemName: tab.icon)
                            .font(.system(size: PSLayout.scaledFont(24), weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundStyle(selectedTab == tab ? PSColors.primaryGreen : PSColors.textTertiary)
                            // Subtle scale pulse on active icon
                            .scaleEffect(selectedTab == tab ? 1.08 : 1.0)
                            .animation(FLMotion.freshliCurve, value: selectedTab)

                        Text(tab.title)
                            .font(.system(size: PSLayout.scaledFont(10), weight: .medium))
                            .foregroundStyle(selectedTab == tab ? PSColors.primaryGreen : PSColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, PSSpacing.sm)
                    // Figma: bg-green-100 dark:bg-green-900/30 rounded-2xl layoutId="activeTab"
                    .background {
                        if selectedTab == tab {
                            RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                                .fill(PSColors.green100)
                                .matchedGeometryEffect(id: "activeTab", in: tabNamespace)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, PSSpacing.lg)
        .padding(.top, PSSpacing.sm)
        .padding(.bottom, bottomSafeAreaInset + PSSpacing.md)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider().opacity(0.5)
        }
    }

    /// Bottom safe area inset for the current window.
    @MainActor
    private var bottomSafeAreaInset: CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return 34 // Default safe area for devices with notch
        }
        return window.safeAreaInsets.bottom
    }

    private func seedDataIfNeeded() {
        let pantryService = FreshliService(modelContext: modelContext)
        pantryService.seedSampleDataIfNeeded()
    }
}
