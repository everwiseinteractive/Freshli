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
        case .pantry: return "refrigerator.fill" // Figma: pantry/refrigerator icon
        case .recipes: return "fork.knife"        // Figma: Utensils
        case .community: return "person.2.fill"  // Figma: Users
        case .profile: return "person.fill"      // Figma: Profile
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
        // Using safeAreaInset instead of ZStack + explicit padding so the tab bar
        // properly adjusts the safe area for ALL child views (NavigationStack, ScrollView,
        // List) on every device — including the 34 pt home indicator on modern iPhones.
        // The old ZStack + PSLayout.tabBarContentPadding approach undershot by ~30 pt on
        // Face ID devices because tabBarContentPadding was width-scaled (not height-aware).
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            customTabBar
        }
        .ignoresSafeArea(.keyboard)
        // SensoryFeedback (.selection) on tab change — tactile click between tabs
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
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            // Update widget data when app goes to background — uses the scene's ModelContext,
            // not a second container (which would cause a SwiftData schema conflict crash).
            WidgetDataService.updateWidgetData(modelContext: modelContext)
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
    // The background Rectangle uses .ignoresSafeArea(edges: .bottom) so the
    // ultraThinMaterial fills all the way to the physical screen edge (under
    // the home indicator), while the tab buttons themselves sit above it.
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
        .padding(.bottom, PSSpacing.md)
        .background {
            // Fill the material all the way to the screen edge (under home indicator)
            // without affecting the layout of the tab buttons above.
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Divider().opacity(0.5)
                }
        }
    }

    private func seedDataIfNeeded() {
        let pantryService = FreshliService(modelContext: modelContext)
        pantryService.seedSampleDataIfNeeded()
    }
}
