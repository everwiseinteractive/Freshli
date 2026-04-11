import SwiftUI
import SwiftData
import TipKit
import os

struct HomeView: View {
    @Binding var showAddItem: Bool
    var switchToTab: (AppTab) -> Void

    @Query(filter: #Predicate<FreshliItem> { !$0.isConsumed && !$0.isShared && !$0.isDonated },
           sort: [SortDescriptor(\FreshliItem.expiryDate)])
    private var activeItems: [FreshliItem]

    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var impactStats: ImpactService.ImpactStats?
    @State private var monthlyStats: ImpactService.ImpactStats?
    @State private var showWeeklyWrap = false
    @State private var selectedImpactStat: String?
    @State private var bulkPlans: [IngredientMealPlan] = []
    @State private var ethyleneConflicts: [EthyleneConflict] = []
    @State private var gapFillSuggestions: [GapFillSuggestion] = []
    @State private var collectiveImpact = CollectiveImpactService.shared
    @State private var showCommunityFridges = false

    private let weeklyWrapTip = WeeklyWrapTip()

    private let logger = Logger(subsystem: "com.freshli.app", category: "HomeView")

    private var expiringItems: [FreshliItem] {
        activeItems.filter { $0.expiryStatus != .fresh }.prefix(5).map { $0 }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return String(localized: "Good Morning") }
        if hour < 17 { return String(localized: "Good Afternoon") }
        return String(localized: "Good Evening")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                curvedHeader
                    // Scroll-linked parallax: when the user pulls down past
                    // the top (overscroll), the header stretches from its
                    // bottom anchor, giving the hero a tactile, premium feel
                    // — the signature iOS "rubber-band" hero stretch. When
                    // scrolling up, the header scales subtly towards its
                    // center and gains a hint of blur so it feels like it's
                    // receding into the distance beneath the content cards.
                    .visualEffect { content, proxy in
                        let minY = proxy.frame(in: .scrollView).minY
                        // `minY > 0` means overscroll pull-down; `minY < 0`
                        // means the user has scrolled the hero offscreen.
                        let overscroll = max(minY, 0)
                        let scrolledAway = max(-minY, 0)
                        return content
                            .scaleEffect(
                                x: 1 + (overscroll / 1_000),
                                y: 1 + (overscroll / 400),
                                anchor: .bottom
                            )
                            .offset(y: -scrolledAway * 0.25)
                            .blur(radius: min(scrolledAway / 40, 6))
                    }
                contentSections
            }
        }
        // Reserve space for the floating tab bar so the last card never
        // sits under it. Mirrors the pattern used in RecipesView.
        .contentMargins(.bottom, PSLayout.scaled(150), for: .scrollContent)
        .background(PSColors.backgroundSecondary)
        .ignoresSafeArea(edges: .top)
        .navigationDestination(isPresented: $showWeeklyWrap) {
            WeeklyWrapView()
        }
        .task {
            let service = ImpactService(modelContext: modelContext)
            impactStats = service.calculateStats()
            monthlyStats = service.calculateMonthlyStats()
            bulkPlans = MealPlanService.shared.generateBulkPlan(for: activeItems)
            ethyleneConflicts = PreservationGuideService.shared.conflicts(in: activeItems)
            gapFillSuggestions = SmartShoppingService.shared.fillGapSuggestions(
                pantryItems: activeItems,
                recipes: RecipeService.shared.recipes
            )
        }
        .onChange(of: activeItems.count) { _, _ in
            let service = ImpactService(modelContext: modelContext)
            impactStats = service.calculateStats()
            monthlyStats = service.calculateMonthlyStats()
            bulkPlans = MealPlanService.shared.generateBulkPlan(for: activeItems)
            ethyleneConflicts = PreservationGuideService.shared.conflicts(in: activeItems)
            gapFillSuggestions = SmartShoppingService.shared.fillGapSuggestions(
                pantryItems: activeItems,
                recipes: RecipeService.shared.recipes
            )
        }
    }

    // MARK: - Curved Header

    private var curvedHeader: some View {
        ZStack(alignment: .top) {
            // Base gradient — richer than flat green
            UnevenRoundedRectangle(bottomLeadingRadius: PSSpacing.radiusHero, bottomTrailingRadius: PSSpacing.radiusHero)
                .fill(
                    LinearGradient(
                        colors: [PSColors.headerGreen, PSColors.primaryGreenDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: PSLayout.headerHeight)

            // Decorative circles
            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: PSLayout.scaled(240))
                .blur(radius: 40)
                .offset(x: PSLayout.scaled(100), y: PSLayout.scaled(-40))

            Circle()
                .fill(.white.opacity(0.04))
                .frame(width: PSLayout.scaled(180))
                .blur(radius: 30)
                .offset(x: PSLayout.scaled(-80), y: PSLayout.scaled(60))

            VStack(spacing: 0) {
                // Avatar + greeting + actions row
                HStack(alignment: .center) {
                    NavigationLink(destination: ProfileView()) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.15))
                                .frame(width: PSLayout.scaled(52), height: PSLayout.scaled(52))
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: PSLayout.scaledFont(42)))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .accessibilityLabel(String(localized: "Your profile"))
                    .accessibilityHint(String(localized: "Opens your profile, stats, and settings"))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(greeting)
                            .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                            .foregroundStyle(.white.opacity(0.65))
                        Text(authManager.currentDisplayName ?? String(localized: "Freshli User"))
                            .font(.system(size: PSLayout.scaledFont(22), weight: .bold))
                            .tracking(-0.3)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    .padding(.leading, PSSpacing.sm)

                    Spacer()

                    HStack(spacing: PSSpacing.sm) {
                        Button {
                            PSHaptics.shared.lightTap()
                            showWeeklyWrap = true
                        } label: {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: PSLayout.scaledFont(18)))
                                .foregroundStyle(.white)
                                .frame(width: PSLayout.iconButtonSize, height: PSLayout.iconButtonSize)
                                .background(.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(String(localized: "Weekly Wrap"))
                        .accessibilityHint(String(localized: "Shows your impact story for this week"))
                        .popoverTip(weeklyWrapTip)

                        NavigationLink(destination: ExpiryAlertsView()) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: PSLayout.scaledFont(18)))
                                    .foregroundStyle(.white)
                                    .frame(width: PSLayout.iconButtonSize, height: PSLayout.iconButtonSize)
                                    .background(.white.opacity(0.15))
                                    .clipShape(Circle())
                                if !expiringItems.isEmpty {
                                    Circle()
                                        .fill(PSColors.expiredRed)
                                        .frame(width: PSLayout.scaled(8), height: PSLayout.scaled(8))
                                        .overlay(Circle().strokeBorder(PSColors.headerGreen, lineWidth: 1.5))
                                        .offset(x: -1, y: 2)
                                }
                            }
                        }
                        .accessibilityLabel(
                            expiringItems.isEmpty
                                ? String(localized: "Notifications")
                                : String(localized: "Notifications, \(expiringItems.count) items need attention")
                        )
                        .accessibilityHint(String(localized: "Opens your expiry alerts"))
                    }
                }
                .padding(.top, PSLayout.headerTopPadding)
                .adaptiveHPadding()
                .padding(.bottom, PSSpacing.lg)

                // Search bar
                HStack(spacing: PSSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: PSLayout.scaledFont(18)))
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.leading, PSSpacing.lg)
                    Text(String(localized: "Search recipes, ingredients..."))
                        .font(.system(size: PSLayout.scaledFont(15), weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: PSLayout.scaledFont(16)))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.trailing, PSSpacing.lg)
                }
                .frame(height: PSLayout.searchBarHeight)
                // Liquid Glass (iOS 26) — search bar refracts the hero
                // gradient through it, so the field feels embedded in the
                // header surface instead of painted on top.
                .background(.white.opacity(0.06))
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                )
                .adaptiveHPadding()
                .onTapGesture {
                    PSHaptics.shared.selection()
                    switchToTab(.pantry)
                }

                // Streak strip — Duolingo-style daily check-in indicator
                streakStrip
                    .adaptiveHPadding()
                    .padding(.bottom, PSSpacing.lg)
            }
        }
    }

    // MARK: - Streak Strip
    //
    // Apple-Design-Award-level treatment: an earned moment, not a bolted-
    // on banner. When the user has an active streak, the flame gets a
    // luminous glow, the day dots fill with warm orange, and the copy
    // celebrates. When there's no streak, the whole strip reads as a
    // gentle invitation, not a nag.

    private var streakStrip: some View {
        let streak = UserDefaults.standard.integer(forKey: "celebration_currentStreak")
        let hasStreak = streak > 0

        return HStack(spacing: PSSpacing.md) {
            // Luminous flame with multi-layer glow when earned
            ZStack {
                if hasStreak {
                    Circle()
                        .fill(Color.orange.opacity(0.35))
                        .frame(width: PSLayout.scaled(44), height: PSLayout.scaled(44))
                        .blur(radius: 8)
                }
                Circle()
                    .fill(hasStreak ? Color.orange.opacity(0.22) : .white.opacity(0.14))
                    .frame(width: PSLayout.scaled(36), height: PSLayout.scaled(36))
                Image(systemName: "flame.fill")
                    .font(.system(size: PSLayout.scaledFont(17), weight: .bold))
                    .foregroundStyle(
                        hasStreak
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [Color(hex: 0xFBBF24), Color(hex: 0xF97316)],
                                    startPoint: .top, endPoint: .bottom
                                )
                              )
                            : AnyShapeStyle(Color.white.opacity(0.5))
                    )
                    .symbolEffect(.pulse, options: .repeat(.periodic(delay: 3.0)), isActive: hasStreak)
            }
            .fixedSize()

            VStack(alignment: .leading, spacing: 2) {
                Text(hasStreak
                     ? String(localized: "\(streak)-day rescue streak")
                     : String(localized: "Begin your rescue journey"))
                    .font(.system(size: PSLayout.scaledFont(14), weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(hasStreak
                     ? String(localized: "You're making this planet better, one rescue at a time")
                     : String(localized: "One item saved today starts a habit that lasts"))
                    .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 7-day ring of accent dots — fills from left as streak grows
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { day in
                    Circle()
                        .fill(
                            day < streak
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        colors: [Color(hex: 0xFBBF24), Color(hex: 0xF97316)],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                  )
                                : AnyShapeStyle(Color.white.opacity(0.22))
                        )
                        .frame(width: 7, height: 7)
                        .shadow(color: day < streak ? Color.orange.opacity(0.55) : .clear, radius: 3)
                }
            }
            .fixedSize()
        }
        .padding(.horizontal, PSSpacing.lg)
        .padding(.vertical, PSSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                .fill(.white.opacity(hasStreak ? 0.12 : 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                )
        }
    }

    // MARK: - Content

    private var contentSections: some View {
        // A deliberately lean layout — world-class apps surface 4-6 high-signal
        // cards, not 9. Secondary features live in the Discover hub reachable
        // from the profile tab. Alerts are consolidated into one rotating card.
        VStack(spacing: PSSpacing.xl) {
            expiringSoonCard
                .padding(.top, max(PSLayout.headerOverlap, PSLayout.scaled(-20)))
                .dashboardEntrance(index: 0)

            // The mission, made visible. Shows the live global rescue wave
            // and transforms a lonely chore into a collective moment.
            collectiveWaveCard
                .dashboardEntrance(index: 1)

            smartAlertCard
                .dashboardEntrance(index: 2)

            cashNotTrashedCard
                .dashboardEntrance(index: 3)

            // Real community fridges nearby — the physical end-point of surplus.
            communityFridgesCard
                .dashboardEntrance(index: 4)

            // Self-hides for Pro subscribers and after dismissal.
            ProUpgradeNudge()
                .dashboardEntrance(index: 5)

            recipeSuggestionCard
                .dashboardEntrance(index: 6)

            if !bulkPlans.isEmpty {
                bulkPlanCard
                    .dashboardEntrance(index: 7)
            }

            communitySwapCard
                .dashboardEntrance(index: 8)
        }
        .adaptiveHPadding()
        .padding(.bottom, PSSpacing.xxxl)
    }

    // MARK: - Collective Wave Card
    //
    // The emotional heart of the app. Shows that every private rescue is
    // a drop in a global river. Updates live via CollectiveImpactService.

    private var collectiveWaveCard: some View {
        NavigationLink(destination: CollectiveWaveView()) {
            VStack(alignment: .leading, spacing: PSSpacing.lg) {
                // Header
                HStack(spacing: PSSpacing.sm) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.18))
                            .frame(width: PSLayout.scaled(34), height: PSLayout.scaled(34))
                        Image(systemName: "globe.europe.africa.fill")
                            .font(.system(size: PSLayout.scaledFont(16)))
                            .foregroundStyle(.white)
                            .symbolEffect(.pulse, options: .repeat(.periodic(delay: 3.5)))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: PSSpacing.xs) {
                            Circle()
                                .fill(.white)
                                .frame(width: 6, height: 6)
                                .opacity(0.9)
                            Text(String(localized: "LIVE WAVE"))
                                .font(.system(size: PSLayout.scaledFont(10), weight: .black))
                                .foregroundStyle(.white.opacity(0.85))
                                .tracking(1.2)
                        }
                        Text(String(localized: "Right now, worldwide"))
                            .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                }

                // Big number
                HStack(alignment: .firstTextBaseline, spacing: PSSpacing.sm) {
                    Text(collectiveImpact.rescueCountDisplay)
                        .font(.system(size: PSLayout.scaledFont(48), weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text(String(localized: "people rescued food in the last hour"))
                        .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Mini stats row
                HStack(spacing: PSSpacing.lg) {
                    waveStatTile(
                        icon: "cloud.fill",
                        value: collectiveImpact.hourlyCO2Display,
                        label: String(localized: "CO₂ avoided")
                    )
                    Rectangle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 1, height: PSLayout.scaled(36))
                    waveStatTile(
                        icon: "fork.knife",
                        value: "\(collectiveImpact.hourlyMealsFed)",
                        label: String(localized: "meals fed")
                    )
                }

                // Latest rescue pulse
                if let latest = collectiveImpact.recentFeed.first {
                    HStack(spacing: PSSpacing.xs) {
                        Image(systemName: "sparkles")
                            .font(.system(size: PSLayout.scaledFont(10)))
                            .foregroundStyle(.white.opacity(0.85))
                        Text(String(localized: "\(latest.displayName) in \(latest.cityName) just rescued \(latest.itemName) · \(latest.timeLabel)"))
                            .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, PSSpacing.md)
                    .padding(.vertical, PSSpacing.sm)
                    .background(.white.opacity(0.1))
                    .clipShape(Capsule())
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 4)),
                        removal: .opacity
                    ))
                    .id(latest.id)
                }
            }
            .adaptiveCardPadding()
            .background(
                LinearGradient(
                    colors: [FreshliBrand.missionAccentLight, FreshliBrand.missionAccent, FreshliBrand.planetBlue.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
            .shadow(color: FreshliBrand.missionAccent.opacity(0.32), radius: 22, y: 10)
            .shadow(color: FreshliBrand.planetBlue.opacity(0.15), radius: 8, y: 3)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func waveStatTile(icon: String, value: String, label: String) -> some View {
        HStack(spacing: PSSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: PSLayout.scaledFont(15), weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text(label)
                    .font(.system(size: PSLayout.scaledFont(10), weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Community Fridges Card
    //
    // The physical end-point of the mission. Real fridges in real
    // neighbourhoods that anyone can drop surplus into, 24/7.

    private var communityFridgesCard: some View {
        NavigationLink(destination: LocalPodsView().onAppear {
            AnalyticsService.shared.track(.fridgeViewed, properties: .props([
                "fridge_count": CommunityPodsService.shared.communityFridges.count,
                "from": "home_card"
            ]))
        }) {
            HStack(spacing: PSSpacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                        .fill(FreshliBrand.planetBlue.opacity(0.12))
                        .frame(width: PSLayout.scaled(56), height: PSLayout.scaled(56))
                    Image(systemName: "refrigerator.fill")
                        .font(.system(size: PSLayout.scaledFont(24)))
                        .foregroundStyle(FreshliBrand.planetBlue)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: PSSpacing.xs) {
                        Text(String(localized: "COMMUNITY FRIDGES"))
                            .font(.system(size: PSLayout.scaledFont(10), weight: .black))
                            .foregroundStyle(FreshliBrand.planetBlue)
                            .tracking(0.8)
                        Circle()
                            .fill(PSColors.primaryGreen)
                            .frame(width: 6, height: 6)
                    }
                    Text(String(localized: "Drop surplus, no questions asked"))
                        .font(.system(size: PSLayout.scaledFont(15), weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                    Text(String(localized: "\(CommunityPodsService.shared.communityFridges.count) real fridges nearby · Open 24/7"))
                        .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                    .foregroundStyle(PSColors.textTertiary)
            }
            .adaptiveCardPadding()
            .background(PSColors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                    .strokeBorder(FreshliBrand.planetBlue.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: FreshliBrand.planetBlue.opacity(0.08), radius: 12, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Smart Alert Card (Unified)
    // Prioritised rotating alert: ethylene conflicts > fill-the-gap suggestions.
    // Only shows when there's something actionable — otherwise silently collapses.

    @ViewBuilder
    private var smartAlertCard: some View {
        if let conflict = ethyleneConflicts.first {
            smartAlertContainer(
                category: String(localized: "ETHYLENE ALERT"),
                title: String(localized: "Storage Conflict"),
                message: conflict.advice,
                icon: "exclamationmark.triangle.fill",
                color: PSColors.secondaryAmber,
                extraCount: ethyleneConflicts.count - 1,
                destination: nil
            )
        } else if let suggestion = gapFillSuggestions.first {
            NavigationLink(destination: SmartShoppingListView()) {
                smartAlertContainer(
                    category: String(localized: "FILL THE GAP"),
                    title: String(localized: "Buy \(suggestion.itemToBuy)"),
                    message: String(localized: "Unlocks \(suggestion.unlocksRecipes.count) recipes from your current pantry"),
                    icon: "cart.badge.plus",
                    color: Color(hex: 0x8B5CF6),
                    extraCount: max(0, gapFillSuggestions.count - 1),
                    destination: "SmartShopping"
                )
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private func smartAlertContainer(category: String, title: String, message: String, icon: String, color: Color, extraCount: Int, destination: String?) -> some View {
        HStack(alignment: .top, spacing: PSSpacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: PSLayout.scaled(42), height: PSLayout.scaled(42))
                Image(systemName: icon)
                    .font(.system(size: PSLayout.scaledFont(16)))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(category)
                    .font(.system(size: PSLayout.scaledFont(10), weight: .black))
                    .foregroundStyle(color)
                    .tracking(0.8)
                Text(title)
                    .font(.system(size: PSLayout.scaledFont(15), weight: .bold))
                    .foregroundStyle(PSColors.textPrimary)
                Text(message)
                    .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .lineSpacing(2)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                if extraCount > 0 {
                    Text(String(localized: "+\(extraCount) more alert\(extraCount == 1 ? "" : "s")"))
                        .font(.system(size: PSLayout.scaledFont(11), weight: .semibold))
                        .foregroundStyle(color)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            if destination != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                    .foregroundStyle(PSColors.textTertiary)
                    .padding(.top, PSSpacing.xxs)
            }
        }
        .adaptiveCardPadding()
        .background(color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Expiring Soon Card

    private var expiringSoonCard: some View {
        VStack(alignment: .leading, spacing: PSSpacing.lg) {
            HStack {
                HStack(spacing: PSSpacing.sm) {
                    ZStack {
                        Circle()
                            .fill(PSColors.secondaryAmber.opacity(0.15))
                            .frame(width: PSLayout.scaled(34), height: PSLayout.scaled(34))
                        Image(systemName: "clock.fill")
                            .font(.system(size: PSLayout.scaledFont(16)))
                            .foregroundStyle(PSColors.secondaryAmber)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(String(localized: "Expiring Soon"))
                            .font(.system(size: PSLayout.scaledFont(17), weight: .bold))
                            .foregroundStyle(PSColors.textPrimary)
                        if !expiringItems.isEmpty {
                            Text(String(localized: "\(expiringItems.count) item\(expiringItems.count == 1 ? "" : "s") need attention"))
                                .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                                .foregroundStyle(PSColors.secondaryAmber)
                        }
                    }
                }
                Spacer()
                Button {
                    PSHaptics.shared.lightTap()
                    switchToTab(.pantry)
                } label: {
                    Text(String(localized: "View All"))
                        .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                        .foregroundStyle(PSColors.primaryGreen)
                        .padding(.horizontal, PSSpacing.md)
                        .padding(.vertical, PSSpacing.xs)
                        .background(PSColors.primaryGreen.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            if expiringItems.isEmpty {
                HStack(spacing: PSSpacing.md) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: PSLayout.scaledFont(24)))
                        .foregroundStyle(PSColors.primaryGreen)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "All good!"))
                            .font(.system(size: PSLayout.scaledFont(15), weight: .bold))
                            .foregroundStyle(PSColors.textPrimary)
                        Text(String(localized: "All your items are fresh."))
                            .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                            .foregroundStyle(PSColors.textSecondary)
                    }
                    Spacer()
                }
                .padding(PSSpacing.lg)
                .background(PSColors.primaryGreen.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PSSpacing.md) {
                        ForEach(Array(expiringItems.enumerated()), id: \.element.id) { index, item in
                            ExpiringItemPill(item: item)
                                .staggeredAppearance(index: index)
                        }
                    }
                    .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
                }
                .scrollClipDisabled()
            }
        }
        .adaptiveCardPadding()
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                .strokeBorder(
                    expiringItems.isEmpty
                        ? PSColors.primaryGreen.opacity(0.12)
                        : PSColors.secondaryAmber.opacity(0.2),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 16, y: 6)
    }

    // MARK: - Recipe Suggestion Card (Shelf-Life Prioritised)

    private var recipeSuggestionCard: some View {
        // Use urgency-sorted recipes — items expiring soonest surface first
        let suggestions = RecipeService.shared.urgencyPrioritisedRecipes(items: activeItems)
        let recipe = suggestions.first
        let urgentItem = recipe.flatMap { RecipeService.shared.mostUrgentIngredient(for: $0, items: activeItems) }
        let isRescueMode = urgentItem.map { $0.expiryStatus != .fresh } ?? false

        return VStack(alignment: .leading, spacing: PSSpacing.lg) {
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: isRescueMode ? "bolt.fill" : "sparkles")
                    .font(.system(size: PSLayout.scaledFont(18)))
                    .foregroundStyle(isRescueMode ? PSColors.secondaryAmber : .purple)
                    .padding(PSSpacing.xs)
                    .background((isRescueMode ? PSColors.secondaryAmber : Color.purple).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(isRescueMode ? String(localized: "Cook This First") : String(localized: "Suggested for You"))
                        .font(.system(size: PSLayout.scaledFont(17), weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                    if isRescueMode, let urgentItem {
                        Text("\(urgentItem.name) expires \(urgentItem.expiryStatus == .expiringToday ? "today" : "soon") — rescue it!")
                            .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                            .foregroundStyle(PSColors.secondaryAmber)
                    }
                }
                Spacer()
                Button { switchToTab(.recipes) } label: {
                    Text(String(localized: "More"))
                        .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                        .foregroundStyle(isRescueMode ? PSColors.secondaryAmber : .purple)
                        .padding(.horizontal, PSSpacing.md)
                        .padding(.vertical, PSSpacing.xs)
                        .background((isRescueMode ? PSColors.secondaryAmber : Color.purple).opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            if let recipe {
                Button {
                    PSHaptics.shared.lightTap()
                    switchToTab(.recipes)
                } label: {
                    ZStack(alignment: .bottomLeading) {
                        FoodCardImage(
                            title: recipe.title,
                            imageSystemName: recipe.imageSystemName,
                            height: PSLayout.cardImageHeight,
                            cornerRadius: PSSpacing.radiusXl
                        )
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.72)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))

                        VStack(alignment: .leading, spacing: PSSpacing.xs) {
                            HStack(spacing: PSSpacing.xs) {
                                // Urgency badge
                                if isRescueMode {
                                    HStack(spacing: 3) {
                                        Image(systemName: "bolt.fill")
                                            .font(.system(size: PSLayout.scaledFont(9)))
                                        Text(String(localized: "Rescue First!"))
                                            .font(.system(size: PSLayout.scaledFont(11), weight: .black))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, PSSpacing.sm)
                                    .padding(.vertical, PSSpacing.xxxs)
                                    .background(PSColors.secondaryAmber)
                                    .clipShape(Capsule())
                                } else {
                                    Text(String(localized: "Uses your pantry"))
                                        .font(.system(size: PSLayout.scaledFont(11), weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.9))
                                        .padding(.horizontal, PSSpacing.sm)
                                        .padding(.vertical, PSSpacing.xxxs)
                                        .background(PSColors.primaryGreen)
                                        .clipShape(Capsule())
                                }
                                Text("•  \(recipe.prepTimeDisplay)")
                                    .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            Text(recipe.title)
                                .font(.system(size: PSLayout.scaledFont(20), weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        .padding(PSSpacing.lg)
                    }
                }
                .buttonStyle(PressableButtonStyle())
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
                .shadow(
                    color: (isRescueMode ? PSColors.secondaryAmber : PSColors.primaryGreen).opacity(0.2),
                    radius: 12, y: 6
                )
            } else {
                PSEmptyState(
                    icon: "book",
                    title: String(localized: "No Recipes Yet"),
                    message: String(localized: "Add items to your pantry to discover recipes!"),
                    actionTitle: nil, action: nil
                )
            }
        }
        .adaptiveCardPadding()
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                .strokeBorder(
                    (isRescueMode ? PSColors.secondaryAmber : Color.purple).opacity(0.12),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
    }

    // MARK: - Waste-Free Bulk Plan Card

    private var bulkPlanCard: some View {
        VStack(alignment: .leading, spacing: PSSpacing.lg) {
            // Header
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: PSLayout.scaledFont(18)))
                    .foregroundStyle(PSColors.accentTeal)
                    .padding(PSSpacing.xs)
                    .background(PSColors.accentTeal.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(String(localized: "Zero-Waste Meal Plan"))
                        .font(.system(size: PSLayout.scaledFont(17), weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                    Text(String(localized: "Use every bit — nothing wasted"))
                        .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                }
                Spacer()
            }

            ForEach(bulkPlans) { plan in
                VStack(alignment: .leading, spacing: PSSpacing.sm) {
                    // Ingredient header row
                    HStack(spacing: PSSpacing.sm) {
                        Text(plan.ingredient.name)
                            .font(.system(size: PSLayout.scaledFont(14), weight: .black))
                            .foregroundStyle(PSColors.accentTeal)
                        Text("·")
                            .foregroundStyle(PSColors.textTertiary)
                        Text(plan.totalPortionLabel)
                            .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                            .foregroundStyle(PSColors.textSecondary)
                        Spacer()
                        // Coverage pill
                        Text("\(plan.coveragePercent)% used")
                            .font(.system(size: PSLayout.scaledFont(10), weight: .bold))
                            .foregroundStyle(PSColors.accentTeal)
                            .padding(.horizontal, PSSpacing.sm)
                            .padding(.vertical, 3)
                            .background(PSColors.accentTeal.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    // Meal slots
                    HStack(spacing: PSSpacing.sm) {
                        ForEach(plan.slots) { slot in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(slot.dayLabel)
                                    .font(.system(size: PSLayout.scaledFont(10), weight: .bold))
                                    .foregroundStyle(PSColors.textTertiary)
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                                Text(slot.recipe.title)
                                    .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                                    .foregroundStyle(PSColors.textPrimary)
                                    .lineLimit(2)
                                Text(slot.portionLabel)
                                    .font(.system(size: PSLayout.scaledFont(10), weight: .medium))
                                    .foregroundStyle(PSColors.accentTeal)
                            }
                            .padding(PSSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(PSColors.accentTeal.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous)
                                    .strokeBorder(PSColors.accentTeal.opacity(0.15), lineWidth: 1)
                            )
                        }
                    }
                }

                if plan.id != bulkPlans.last?.id {
                    Divider().opacity(0.5)
                }
            }
        }
        .adaptiveCardPadding()
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                .strokeBorder(PSColors.accentTeal.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
    }

    // MARK: - Cash Not Trashed Card

    private var cashNotTrashedCard: some View {
        let stats = monthlyStats ?? ImpactService.ImpactStats()
        let monthName = Calendar.current.monthSymbols[Calendar.current.component(.month, from: Date()) - 1]
        let streak = RescueStreakService.shared.currentStreak

        return NavigationLink(destination: ImpactDashboardView()) {
            VStack(alignment: .leading, spacing: PSSpacing.lg) {
                // Header
                HStack(spacing: PSSpacing.sm) {
                    ZStack {
                        Circle()
                            .fill(PSColors.secondaryAmber.opacity(0.15))
                            .frame(width: PSLayout.scaled(36), height: PSLayout.scaled(36))
                        Image(systemName: "banknote.fill")
                            .font(.system(size: PSLayout.scaledFont(17)))
                            .foregroundStyle(PSColors.secondaryAmber)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(String(localized: "Cash Not Trashed"))
                            .font(.system(size: PSLayout.scaledFont(17), weight: .bold))
                            .foregroundStyle(PSColors.textPrimary)
                        Text(String(localized: "\(monthName) savings"))
                            .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                            .foregroundStyle(PSColors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                        .foregroundStyle(PSColors.textTertiary)
                }

                // Big savings figure
                HStack(alignment: .firstTextBaseline, spacing: PSSpacing.xs) {
                    Text(stats.moneySavedDisplay)
                        .font(.system(size: PSLayout.scaledFont(42), weight: .black, design: .rounded))
                        .foregroundStyle(PSColors.secondaryAmber)
                    Text(String(localized: "saved this month"))
                        .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                        .foregroundStyle(PSColors.textSecondary)
                        .padding(.bottom, PSSpacing.xs)
                }

                // Stats row
                HStack(spacing: 0) {
                    cashStatTile(icon: "leaf.fill", value: "\(stats.itemsSaved)", label: String(localized: "Items Rescued"), color: PSColors.primaryGreen)
                    Rectangle().fill(PSColors.borderLight).frame(width: 1, height: PSLayout.scaled(36))
                    cashStatTile(icon: "wind", value: stats.co2Display, label: String(localized: "CO₂ Avoided"), color: PSColors.accentTeal)
                    if streak > 0 {
                        Rectangle().fill(PSColors.borderLight).frame(width: 1, height: PSLayout.scaled(36))
                        cashStatTile(icon: "flame.fill", value: "\(streak)d", label: String(localized: "Streak"), color: Color(hex: 0xF97316))
                    }
                }
                .padding(.top, PSSpacing.xs)
            }
            .adaptiveCardPadding()
            .background(PSColors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                    .strokeBorder(PSColors.secondaryAmber.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: PSColors.secondaryAmber.opacity(0.1), radius: 16, y: 6)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func cashStatTile(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: PSSpacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: PSLayout.scaledFont(14)))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: PSLayout.scaledFont(18), weight: .black, design: .rounded))
                .foregroundStyle(PSColors.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                .foregroundStyle(PSColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Community Swap Card

    private var communitySwapCard: some View {
        Button {
            PSHaptics.shared.lightTap()
            switchToTab(.community)
        } label: {
            HStack(spacing: PSSpacing.xl) {
                VStack(alignment: .leading, spacing: PSSpacing.sm) {
                    HStack(spacing: PSSpacing.xs) {
                        Image(systemName: "leaf.arrow.triangle.circlepath")
                            .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                            .foregroundStyle(PSColors.primaryGreen)
                        Text(String(localized: "Community Active"))
                            .font(.system(size: PSLayout.scaledFont(11), weight: .bold))
                            .foregroundStyle(PSColors.primaryGreen)
                    }
                    .padding(.horizontal, PSSpacing.md)
                    .padding(.vertical, PSSpacing.xxs)
                    .background(PSColors.primaryGreen.opacity(0.12))
                    .clipShape(Capsule())

                    Text(String(localized: "Community Swap"))
                        .font(.system(size: PSLayout.scaledFont(18), weight: .bold))
                        .foregroundStyle(Color(hex: 0x064E3B))

                    Text(String(localized: "Share surplus food with neighbors nearby."))
                        .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                        .foregroundStyle(PSColors.primaryGreen.opacity(0.8))
                        .lineLimit(2)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(PSColors.primaryGreen.opacity(0.12))
                        .frame(width: PSLayout.scaled(56), height: PSLayout.scaled(56))
                    Circle()
                        .fill(PSColors.primaryGreen)
                        .frame(width: PSLayout.scaled(44), height: PSLayout.scaled(44))
                        .shadow(color: PSColors.primaryGreen.opacity(0.35), radius: 12, y: 4)
                    Image(systemName: "arrow.right")
                        .font(.system(size: PSLayout.scaledFont(18), weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .adaptiveCardPadding()
            .background(PSColors.emeraldSurface)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                    .strokeBorder(PSColors.primaryGreen.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: PSColors.primaryGreen.opacity(0.1), radius: 16, y: 6)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Expiring Item Pill

private struct ExpiringItemPill: View {
    let item: FreshliItem

    private var urgencyColor: Color {
        switch item.expiryStatus {
        case .expired:       return PSColors.expiredRed
        case .expiringToday: return PSColors.expiredRed
        case .expiringSoon:  return PSColors.secondaryAmber
        case .fresh:         return PSColors.primaryGreen
        }
    }

    var body: some View {
        NavigationLink(destination: FreshliDetailView(item: item)) {
            VStack(spacing: PSSpacing.sm) {
                ZStack(alignment: .topTrailing) {
                    FoodItemImage(
                        name: item.name,
                        category: item.category,
                        size: PSLayout.emojiCircleSize
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(urgencyColor.opacity(0.25), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)

                    Circle()
                        .fill(urgencyColor)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                }

                VStack(spacing: 2) {
                    Text(item.name)
                        .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                        .foregroundStyle(PSColors.textPrimary)
                        .lineLimit(1)
                        .frame(width: PSLayout.scaled(100))

                    Text(item.expiryDate.expiryDisplayText)
                        .font(.system(size: PSLayout.scaledFont(11), weight: .bold))
                        .foregroundStyle(urgencyColor)
                }
            }
            .padding(PSSpacing.md)
            .frame(width: PSLayout.pillWidth)
            .background(urgencyColor.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                    .strokeBorder(urgencyColor.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

#Preview {
    HomeView(showAddItem: .constant(false), switchToTab: { _ in })
}
