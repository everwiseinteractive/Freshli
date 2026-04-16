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
    /// Called once after the essential tab warm-up completes.
    /// FreshliApp uses this to gate the splash screen exit.
    var onReady: (() -> Void)? = nil

    @State private var selectedTab: AppTab = {
        // Restore last-used tab from previous session for seamless state restoration
        if let saved = UserDefaults.standard.string(forKey: "lastSelectedTab"),
           let tab = AppTab(rawValue: saved) {
            return tab
        }
        return .home
    }()
    @State private var previousTab: AppTab = .home
    @State private var showAddItem = false
    @State private var showFoodScanner = false
    @State private var tabBarVisibility = TabBarVisibilityService.shared
    @State private var prefetchCoordinator = PrefetchCoordinator.shared
    @State private var dataStore = FreshliDataStore.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(CelebrationManager.self) private var celebrationManager
    @Environment(AuthManager.self) private var authManager
    @Environment(SyncService.self) private var syncService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var intentPrediction = IntentPredictionService()

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
                        FLHomePage(showAddItem: $showAddItem, showFoodScanner: $showFoodScanner, switchToTab: { switchTab(to: $0) })
                    }
                    .measureTTI(for: .home)
                }
            case .pantry:
                chromedTab {
                    NavigationStack { FLPantryPage(showAddItem: $showAddItem) }
                        .measureTTI(for: .pantry)
                }
            case .recipes:
                chromedTab {
                    NavigationStack { FLRecipesPage() }
                        .measureTTI(for: .recipes)
                }
            case .community:
                chromedTab {
                    NavigationStack { FLCommunityPage() }
                        .measureTTI(for: .community)
                }
            case .profile:
                chromedTab {
                    NavigationStack { FLProfilePage() }
                        .measureTTI(for: .profile)
                }
            }
        }
        .transition(FLMotion.tabMeltTransition(reduceMotion: reduceMotion))
        .id(selectedTab)
        .ignoresSafeArea(.keyboard)
        .sensoryFeedback(.selection, trigger: selectedTab)
        .sheet(isPresented: $showAddItem) {
            NavigationStack { AddItemView() }
                .presentationDragIndicator(.visible)
                .sheetTransition()
        }
        .sheet(isPresented: $showFoodScanner) {
            NavigationStack { FoodScannerView() }
                .presentationDragIndicator(.visible)
                .sheetTransition()
        }
        .task {
            // Configure the data store with the SwiftData model context
            dataStore.configure(with: modelContext)

            // Warm up all tab snapshots during the first render pass
            // This ensures instant data access on first tab switch
            prefetchCoordinator.warmUpAllTabs()

            // Mark cold launch complete (first tab is now interactive)
            ColdLaunchTracker.shared.markInteractive()

            seedDataIfNeeded()

            // ── Signal readiness to FreshliApp ──
            // The splash screen waits for this before dissolving, ensuring
            // every tab is warm and the home screen is fully rendered.
            onReady?()

            // Non-critical post-ready work (runs after splash dismisses)
            await celebrationManager.checkWeeklyRecap(modelContext: modelContext)
            if let userId = authManager.currentUserId {
                await syncService.performFullSync(userId: userId, modelContext: modelContext)

                // Rebuild snapshots after sync brings in remote data
                dataStore.invalidateAndRebuild()
            }
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            // Persist selected tab for state restoration on next launch
            UserDefaults.standard.set(newTab.rawValue, forKey: "lastSelectedTab")
            // Notify prefetch coordinator of tab navigation for TTI tracking
            prefetchCoordinator.onTabWillAppear(newTab)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            WidgetDataService.updateWidgetData(modelContext: modelContext)
        }
    }

    // MARK: - Tab Switching

    private func switchTab(to tab: AppTab) {
        guard tab != selectedTab else { return }
        previousTab = selectedTab

        // Speak tab slide through Motion Vocabulary for VoiceOver users
        let allTabs = AppTab.allCases
        let fromIdx = allTabs.firstIndex(of: selectedTab) ?? 0
        let toIdx = allTabs.firstIndex(of: tab) ?? 0
        MotionVocabularyService.shared.speakMotion(.tabSlide(direction: toIdx > fromIdx ? 1 : -1))

        // Every tab switch resets the bar to visible — users always land in
        // a fully-chromed state on the new tab.
        tabBarVisibility.resetImmediate()

        // Start TTI measurement BEFORE the animation begins
        let ttiToken = TTIService.shared.begin(.tabSwitch, context: tab.rawValue)

        // Haptic viscosity: dissolve rumble → crystallisation click
        if !reduceMotion {
            FreshliHapticManager.shared.meltDissolve()
        }

        withAnimation(FLMotion.tabTransition) { selectedTab = tab }

        // Complete TTI after the animation settles (next frame)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(16))
            TTIService.shared.end(ttiToken, flow: .tabSwitch)
        }
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
            // Pinned to the bottom of the 88pt container so it sits near
            // the home indicator instead of vertically centered, which
            // prevents it from overlapping card content above the safe area.
            scrollUpPrompt
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 10)
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
            .elevation(.z3)
            .shadow(color: PSColors.primaryGreen.opacity(0.08), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PressableButtonStyle())
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 16)
    }

    // MARK: - Intent Bloom Helpers

    /// Maps the top predicted intent to the corresponding main tab.
    private var predictedTab: AppTab? {
        switch intentPrediction.topIntent {
        case .rescueFood, .addItems, .managePantry: return .pantry
        case .checkRecipes:                          return .recipes
        case .shareFood:                             return .community
        case .viewImpact:                            return .home
        case .none:                                  return nil
        }
    }

    /// Whether a given tab is the intent-predicted target (and not already selected).
    private func isIntentBloom(for tab: AppTab) -> Bool {
        guard let predicted = predictedTab else { return false }
        return predicted == tab && selectedTab != tab
    }

    // MARK: - Floating Tab Bar
    //
    // Design:  [  pill: home | pantry | recipes | community  ]  [● profile]
    //
    // The pill uses iOS 26 Liquid Glass (.glassEffect) so content refracts
    // through its surface, giving the bar its "floating" feel. The active tab
    // expands inside a green-tinted glass capsule; inactive tabs display only
    // their icon at reduced opacity. When IntentPredictionService has a
    // prediction, the predicted tab shows a subtle green glow pulse.
    // The profile button is a separate glass circle.

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
            .glassEffect(.regular.interactive(), in: Capsule())
            .elevation(.z4)
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
        let bloom = isIntentBloom(for: tab)

        Button { switchTab(to: tab) } label: {
            HStack(spacing: active ? 6 : 0) {
                Image(systemName: tab.icon)
                    .font(.system(
                        size: PSLayout.scaledFont(active ? 16 : 20),
                        weight: .semibold
                    ))
                    .foregroundStyle(active ? .white : PSColors.primaryGreen.opacity(0.7))
                    // Intent bloom: breathe effect on the predicted tab's icon
                    .symbolEffect(.breathe, isActive: bloom && !reduceMotion)
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
                        .minimumScaleFactor(0.8)
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
                    // Green-tinted Liquid Glass capsule slides between tabs
                    Capsule()
                        .fill(PSColors.primaryGreen)
                        .glassEffect(
                            reduceMotion
                                ? .regular.tint(PSColors.primaryGreen)
                                : .regular.tint(PSColors.primaryGreen).interactive(),
                            in: Capsule()
                        )
                        .shadow(color: PSColors.primaryGreen.opacity(0.55), radius: 10, y: 4)
                        .matchedGeometryEffect(id: "activeTabCapsule", in: tabNamespace)
                } else if bloom && !reduceMotion {
                    // Intent bloom: subtle green glow circle behind the predicted tab
                    Circle()
                        .fill(PSColors.primaryGreen.opacity(0.15))
                        .frame(width: PSLayout.scaled(36), height: PSLayout.scaled(36))
                        .blur(radius: 6)
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
        .animation(FLMotion.freshliCurve, value: selectedTab)
    }

    // MARK: - Pill Background

    private var pillBackground: some View {
        Capsule()
            // Subtle fill ensures the pill is visible even when Liquid Glass
            // doesn't render (Simulator, older devices). On real devices the
            // .glassEffect on the parent overrides this with frosted glass.
            .fill(Color(.systemBackground).opacity(0.85))
            .overlay(
                Capsule()
                    .strokeBorder(
                        PSColors.primaryGreen.opacity(0.15),
                        lineWidth: 1
                    )
            )
    }

    // MARK: - Profile Circle

    private var profileCircle: some View {
        let active = selectedTab == .profile

        return Button { switchTab(to: .profile) } label: {
            ZStack {
                // Liquid Glass circle — green-tinted when active, neutral when inactive
                Circle()
                    .fill(active ? PSColors.primaryGreen.opacity(0.35) : Color(.systemBackground).opacity(0.85))
                    .overlay(
                        Circle()
                            .strokeBorder(
                                active
                                    ? PSColors.primaryGreen.opacity(0.45)
                                    : PSColors.primaryGreen.opacity(0.15),
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
                    .foregroundStyle(active ? .white : PSColors.primaryGreen.opacity(0.7))
            }
            .frame(width: PSLayout.scaled(56), height: PSLayout.scaled(56))
            .glassEffect(
                active
                    ? .regular.tint(PSColors.primaryGreen)
                    : .regular,
                in: Circle()
            )
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
