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
    @State private var tabBarVisibility = TabBarVisibilityService.shared
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
                chromedTab {
                    NavigationStack {
                        HomeView(showAddItem: $showAddItem, switchToTab: { switchTab(to: $0) })
                    }
                }
            case .pantry:
                chromedTab {
                    NavigationStack { FreshliView(showAddItem: $showAddItem) }
                }
            case .recipes:
                chromedTab {
                    NavigationStack { RecipesView() }
                }
            case .community:
                chromedTab {
                    NavigationStack { CommunityView() }
                }
            case .profile:
                chromedTab {
                    NavigationStack { ProfileView() }
                }
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
        // Every tab switch resets the bar to visible — users always land in
        // a fully-chromed state on the new tab.
        tabBarVisibility.resetImmediate()
        withAnimation(FLMotion.tabTransition) { selectedTab = tab }
    }

    // MARK: - Chromed Tab Wrapper
    // Wraps a destination (usually a NavigationStack) with:
    //   1. Scroll-direction tracking that drives TabBarVisibilityService
    //   2. A bottom safeAreaInset hosting the animated tab bar area
    //
    // safeAreaInset is applied to EACH destination individually because
    // NavigationStack intercepts safe area propagation on device, so child
    // views wouldn't see the correct inset if applied higher up.

    @ViewBuilder
    private func chromedTab<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { oldValue, newValue in
                tabBarVisibility.trackScroll(oldOffset: oldValue, newOffset: newValue)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { tabBarArea }
    }

    // MARK: - Tab Bar Area (Animated Container)
    // A fixed-height container that cross-fades between the full floating
    // tab bar and a compact "scroll up for menu" prompt. Keeping the height
    // constant means content below never reflows — only the visual chrome
    // morphs — which is what gives the transition its Apple-award smoothness.

    private var tabBarArea: some View {
        let visible = tabBarVisibility.isVisible
        return ZStack {
            // Full floating tab bar — slides down & fades out when hiding.
            floatingTabBar
                .opacity(visible ? 1 : 0)
                .offset(y: visible ? 0 : 110)
                .scaleEffect(visible ? 1 : 0.96, anchor: .bottom)
                .blur(radius: visible ? 0 : 4)
                .animation(.spring(response: 0.48, dampingFraction: 0.86), value: visible)
                .allowsHitTesting(visible)

            // Compact scroll-up prompt — drops in from above as the bar exits.
            scrollUpPrompt
                .opacity(visible ? 0 : 1)
                .offset(y: visible ? 32 : 0)
                .scaleEffect(visible ? 0.92 : 1, anchor: .bottom)
                .animation(
                    .spring(response: 0.55, dampingFraction: 0.82)
                        .delay(visible ? 0 : 0.06),
                    value: visible
                )
                .allowsHitTesting(!visible)
        }
        .frame(height: PSLayout.scaled(88))
    }

    // MARK: - Scroll Up Prompt
    // A low-profile pill positioned where the iPhone home indicator lives.
    // Subtle enough to stay out of the user's way, but always one tap or
    // one upward flick away from bringing the full menu back.

    private var scrollUpPrompt: some View {
        Button {
            PSHaptics.shared.lightTap()
            tabBarVisibility.show()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.up")
                    .font(.system(size: PSLayout.scaledFont(11), weight: .bold))
                    .symbolEffect(.bounce, options: .repeat(.periodic(delay: 2.4)))
                Text(String(localized: "Scroll up for menu"))
                    .font(.system(size: PSLayout.scaledFont(12), weight: .semibold, design: .rounded))
                    .fixedSize()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .overlay(
                        Capsule()
                            .fill(Color(hex: 0x0C1A10).opacity(0.85))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.14), .white.opacity(0.03)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            }
            .shadow(color: .black.opacity(0.28), radius: 16, x: 0, y: 6)
            .shadow(color: PSColors.primaryGreen.opacity(0.08), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PressableButtonStyle())
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 16)
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
