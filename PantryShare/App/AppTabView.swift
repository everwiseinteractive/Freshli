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

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return String(localized: "Home")
        case .pantry: return String(localized: "Pantry")
        case .recipes: return String(localized: "Recipes")
        case .community: return String(localized: "Community")
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .pantry: return "leaf.fill"       // Figma: Apple icon
        case .recipes: return "fork.knife"      // Figma: Utensils
        case .community: return "person.2.fill" // Figma: Users
        }
    }
}

struct AppTabView: View {
    @State private var selectedTab: AppTab = .home
    @State private var showAddItem = false
    @Environment(\.modelContext) private var modelContext
    @Environment(CelebrationManager.self) private var celebrationManager: CelebrationManager?
    @Environment(AuthManager.self) private var authManager: AuthManager?
    @Environment(SyncService.self) private var syncService: SyncService?

    @Namespace private var tabNamespace

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            Group {
                switch selectedTab {
                case .home:
                    NavigationStack {
                        HomeView(showAddItem: $showAddItem, switchToTab: { selectedTab = $0 })
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
                }
            }
            .padding(.bottom, PSLayout.tabBarContentPadding)

            // Figma: custom tab bar — bg-white/80 backdrop-blur-xl border-t
            customTabBar
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showAddItem) {
            NavigationStack {
                AddItemView()
            }
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            seedDataIfNeeded()
            // Check for weekly recap celebration
            celebrationManager?.checkWeeklyRecap(modelContext: modelContext)
        }
        .task {
            // Perform initial sync if authenticated
            if let userId = authManager?.currentUserId {
                await syncService?.performFullSync(userId: userId, modelContext: modelContext)
            }
        }
    }

    // Figma: iOS-style bottom navigation
    private var customTabBar: some View {
        HStack {
            ForEach(AppTab.allCases) { tab in
                Button {
                    if selectedTab != tab {
                        PSHaptics.shared.selection()
                    }
                    withAnimation(PSMotion.springBouncy) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: PSSpacing.xxs) {
                        Image(systemName: tab.icon)
                            .font(.system(size: PSLayout.scaledFont(24), weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundStyle(selectedTab == tab ? PSColors.primaryGreen : PSColors.textTertiary)

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
        .padding(.bottom, PSLayout.scaled(32))
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Divider().opacity(0.5)
                }
        )
    }

    private func seedDataIfNeeded() {
        let pantryService = FreshliService(modelContext: modelContext)
        pantryService.seedSampleDataIfNeeded()
    }
}
