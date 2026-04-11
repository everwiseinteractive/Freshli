import SwiftUI
import SwiftData

// MARK: - App Tab

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case pantry
    case recipes
    case community
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:      return String(localized: "Home")
        case .pantry:    return String(localized: "Pantry")
        case .recipes:   return String(localized: "Recipes")
        case .community: return String(localized: "Community")
        case .profile:   return String(localized: "Profile")
        }
    }

    var icon: String {
        switch self {
        case .home:      return "house.fill"
        case .pantry:    return "refrigerator.fill"
        case .recipes:   return "fork.knife"
        case .community: return "person.2.fill"
        case .profile:   return "person.fill"
        }
    }
}

// MARK: - App Tab View

struct AppTabView: View {
    @State private var selectedTab: AppTab = .home
    @State private var previousTab: AppTab = .home
    @State private var showAddItem = false
    @Environment(\.modelContext) private var modelContext
    @Environment(CelebrationManager.self) private var celebrationManager
    @Environment(AuthManager.self) private var authManager
    @Environment(SyncService.self) private var syncService

    @Namespace private var tabNamespace

    // Main tabs live inside the floating pill; Profile gets its own circle.
    private var mainTabs: [AppTab] { [.home, .pantry, .recipes, .community] }

    private var slideDirection: FLMotion.TabSlideDirection {
        let all = AppTab.allCases
        let cur = all.firstIndex(of: selectedTab) ?? 0
        let prv = all.firstIndex(of: previousTab) ?? 0
        return cur >= prv ? .forward : .backward
    }

    var body: some View {
        Group {
            switch selectedTab {
            case .home:
                NavigationStack {
                    HomeView(showAddItem: $showAddItem, switchToTab: { switchTab(to: $0) })
                }
                // safeAreaInset is applied to EACH NavigationStack individually.
                // Applying it to the outer Group is insufficient — NavigationStack
                // intercepts safe area propagation on real devices, so child views
                // (ScrollViews, ZStack FABs) would not see the correct inset.
                .safeAreaInset(edge: .bottom, spacing: 0) { floatingTabBar }

            case .pantry:
                NavigationStack { FreshliView(showAddItem: $showAddItem) }
                    .safeAreaInset(edge: .bottom, spacing: 0) { floatingTabBar }

            case .recipes:
                NavigationStack { RecipesView() }
                    .safeAreaInset(edge: .bottom, spacing: 0) { floatingTabBar }

            case .community:
                NavigationStack { CommunityView() }
                    .safeAreaInset(edge: .bottom, spacing: 0) { floatingTabBar }

            case .profile:
                NavigationStack { ProfileView() }
                    .safeAreaInset(edge: .bottom, spacing: 0) { floatingTabBar }
            }
        }
        .transition(FLMotion.tabSlideTransition(direction: slideDirection))
        .id(selectedTab)
        .ignoresSafeArea(.keyboard)
        .sensoryFeedback(.selection, trigger: selectedTab)
        .sheet(isPresented: $showAddItem) {
            NavigationStack { AddItemView() }
                .presentationDragIndicator(.visible)
        }
        .task {
            seedDataIfNeeded()
            await celebrationManager.checkWeeklyRecap(modelContext: modelContext)
            if let userId = authManager.currentUserId {
                await syncService.performFullSync(userId: userId, modelContext: modelContext)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            WidgetDataService.updateWidgetData(modelContext: modelContext)
        }
    }

    // MARK: - Tab Switching

    private func switchTab(to tab: AppTab) {
        guard tab != selectedTab else { return }
        previousTab = selectedTab
        withAnimation(FLMotion.tabTransition) { selectedTab = tab }
    }

    // MARK: - Floating Tab Bar
    //
    // Design:  [  pill: home | pantry | recipes | community  ]  [● profile]
    //
    // The pill uses a dark frosted-glass capsule so content bleeds through at
    // its edges, giving the bar its "floating" feel.  The active tab expands
    // to show an icon + label inside a green gradient capsule; inactive tabs
    // display only their icon at reduced opacity.  The profile button is a
    // separate circle that pulses green when active.

    private var floatingTabBar: some View {
        HStack(alignment: .center, spacing: 10) {

            // ── Main pill ──────────────────────────────────────────────────
            HStack(spacing: 0) {
                ForEach(mainTabs, id: \.self) { tab in
                    pillTabItem(for: tab)
                }
            }
            .padding(5)
            .background { pillBackground }
            .shadow(color: .black.opacity(0.32), radius: 22, x: 0, y: 10)
            .shadow(color: PSColors.primaryGreen.opacity(0.10), radius: 6, x: 0, y: 2)

            // ── Profile circle ─────────────────────────────────────────────
            profileCircle
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)     // floats above the home indicator
        .frame(maxWidth: .infinity)
        // Transparent: content is visible through the bar edges
        .background(.clear)
    }

    // MARK: - Pill Tab Item

    @ViewBuilder
    private func pillTabItem(for tab: AppTab) -> some View {
        let active = selectedTab == tab

        Button { switchTab(to: tab) } label: {
            HStack(spacing: active ? 6 : 0) {
                Image(systemName: tab.icon)
                    .font(.system(
                        size: PSLayout.scaledFont(active ? 16 : 20),
                        weight: .semibold
                    ))
                    .foregroundStyle(active ? .white : .white.opacity(0.38))
                    // Fixed-width frame keeps inactive icons centred without layout jumping
                    .frame(width: active ? nil : PSLayout.scaled(44))

                if active {
                    Text(tab.title)
                        .font(.system(
                            size: PSLayout.scaledFont(14),
                            weight: .bold,
                            design: .rounded
                        ))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize()
                        // Slide + fade the label in/out as tabs switch
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.82, anchor: .leading)),
                            removal:   .opacity.combined(with: .scale(scale: 0.82, anchor: .trailing))
                        ))
                }
            }
            .frame(height: PSLayout.scaled(46))
            .padding(.horizontal, active ? PSSpacing.md : 0)
            .background {
                if active {
                    // Green gradient capsule slides between tabs via matchedGeometryEffect
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [PSColors.primaryGreen, Color(hex: 0x16A34A)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: PSColors.primaryGreen.opacity(0.55), radius: 10, y: 4)
                        .matchedGeometryEffect(id: "activeTabCapsule", in: tabNamespace)
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
        .animation(FLMotion.freshliCurve, value: selectedTab)
    }

    // MARK: - Pill Background

    private var pillBackground: some View {
        Capsule()
            // Dark frosted glass: ultraThinMaterial tinted dark-forest green
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .overlay(
                Capsule()
                    .fill(Color(hex: 0x0C1A10).opacity(0.90))
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        // Subtle top-to-bottom gradient border gives depth
                        LinearGradient(
                            colors: [.white.opacity(0.16), .white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }

    // MARK: - Profile Circle

    private var profileCircle: some View {
        let active = selectedTab == .profile

        return Button { switchTab(to: .profile) } label: {
            ZStack {
                // Background: green gradient when active, dark when inactive
                Circle()
                    .fill(
                        active
                        ? LinearGradient(
                            colors: [PSColors.primaryGreen, Color(hex: 0x059652)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          )
                        : LinearGradient(
                            colors: [Color(hex: 0x1A2D1E), Color(hex: 0x111C14)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          )
                    )
                    // Border: green glow when active, whisper-white when inactive
                    .overlay(
                        Circle()
                            .strokeBorder(
                                active
                                    ? PSColors.primaryGreen.opacity(0.45)
                                    : .white.opacity(0.09),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(
                        color: active
                            ? PSColors.primaryGreen.opacity(0.55)
                            : .black.opacity(0.28),
                        radius: active ? 14 : 8,
                        y: 4
                    )

                Image(systemName: "person.fill")
                    .font(.system(size: PSLayout.scaledFont(20), weight: .semibold))
                    .foregroundStyle(.white.opacity(active ? 1.0 : 0.58))
            }
            .frame(width: PSLayout.scaled(56), height: PSLayout.scaled(56))
            // Subtle scale-up gives a satisfying "press" feel when active
            .scaleEffect(active ? 1.07 : 1.0)
        }
        .buttonStyle(PressableButtonStyle())
        .animation(FLMotion.freshliCurve, value: selectedTab)
    }

    // MARK: - Seed Data

    private func seedDataIfNeeded() {
        let pantryService = FreshliService(modelContext: modelContext)
        pantryService.seedSampleDataIfNeeded()
    }
}
