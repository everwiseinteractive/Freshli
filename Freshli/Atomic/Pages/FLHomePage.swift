import SwiftUI
import SwiftData
import TipKit
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - FLHomePage (Page)
// The complete Home Dashboard — assembles Atomic organisms into a
// single, unified glass surface. Preserves all backend logic from
// the original HomeView: services, SwiftData queries, intent
// prediction, Metal shaders, and accessibility support.
// ══════════════════════════════════════════════════════════════════

struct FLHomePage: View {
    @Binding var showAddItem: Bool
    var switchToTab: (AppTab) -> Void

    // MARK: - Data

    @Query(filter: #Predicate<FreshliItem> { !$0.isConsumed && !$0.isShared && !$0.isDonated },
           sort: [SortDescriptor(\FreshliItem.expiryDate)])
    private var activeItems: [FreshliItem]

    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - State

    @State private var impactStats: ImpactService.ImpactStats?
    @State private var monthlyStats: ImpactService.ImpactStats?
    @State private var showWeeklyWrap = false
    @State private var bulkPlans: [IngredientMealPlan] = []
    @State private var ethyleneConflicts: [EthyleneConflict] = []
    @State private var gapFillSuggestions: [GapFillSuggestion] = []
    @State private var collectiveImpact = CollectiveImpactService.shared
    @State private var intentPrediction = IntentPredictionService()
    @State private var headerStartDate = Date.now

    private let weeklyWrapTip = WeeklyWrapTip()
    private let logger = Logger(subsystem: "com.freshli.app", category: "FLHomePage")

    // MARK: - Derived

    private var expiringItems: [FreshliItem] {
        activeItems.filter { $0.expiryStatus == .expiringSoon }
    }

    private var expiredItems: [FreshliItem] {
        activeItems.filter { $0.expiryStatus == .expired }
    }

    /// All non-fresh items (for notification badge counts)
    private var urgentItems: [FreshliItem] {
        activeItems.filter { $0.expiryStatus != .fresh }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return String(localized: "Good Morning") }
        if hour < 17 { return String(localized: "Good Afternoon") }
        return String(localized: "Good Evening")
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroHeader
                    .visualEffect { content, proxy in
                        let minY = proxy.frame(in: .scrollView).minY
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
                dashboardContent
            }
        }
        .contentMargins(.bottom, PSLayout.scaled(150), for: .scrollContent)
        .background(PSColors.backgroundSecondary)
        .ignoresSafeArea(edges: .top)
        .navigationDestination(isPresented: $showWeeklyWrap) {
            WeeklyWrapView()
        }
        .task { await loadData() }
        .onChange(of: activeItems.count) { _, _ in refreshData() }
    }

    // MARK: - Data Loading

    private func loadData() async {
        let service = ImpactService(modelContext: modelContext)
        impactStats = service.calculateStats()
        monthlyStats = service.calculateMonthlyStats()
        bulkPlans = MealPlanService.shared.generateBulkPlan(for: activeItems)
        ethyleneConflicts = PreservationGuideService.shared.conflicts(in: activeItems)
        gapFillSuggestions = SmartShoppingService.shared.fillGapSuggestions(
            pantryItems: activeItems,
            recipes: RecipeService.shared.recipes
        )

        runIntentPrediction()
        intentPrediction.loadStoredEvents()

        if #available(iOS 26.0, *) {
            let snapshot = activeItems.prefix(10).map { item in
                "\(item.name): expires \(item.expiryDate.formatted(.dateTime.month().day())), \(item.expiryStatus.rawValue)"
            }.joined(separator: "\n")
            await intentPrediction.analysePatterns(pantrySnapshot: snapshot)
        }
    }

    private func refreshData() {
        let service = ImpactService(modelContext: modelContext)
        impactStats = service.calculateStats()
        monthlyStats = service.calculateMonthlyStats()
        bulkPlans = MealPlanService.shared.generateBulkPlan(for: activeItems)
        ethyleneConflicts = PreservationGuideService.shared.conflicts(in: activeItems)
        gapFillSuggestions = SmartShoppingService.shared.fillGapSuggestions(
            pantryItems: activeItems,
            recipes: RecipeService.shared.recipes
        )
        runIntentPrediction()
    }

    private func runIntentPrediction() {
        let expiringCount = activeItems.filter { $0.expiryStatus != .fresh }.count
        let expiredCount = activeItems.filter { $0.expiryStatus == .expired }.count
        let recentlyAdded = activeItems.filter {
            $0.dateAdded > Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        }.count
        let stats = impactStats

        intentPrediction.predict(
            expiringCount: expiringCount,
            expiredCount: expiredCount,
            totalItems: activeItems.count,
            recentlyAdded: recentlyAdded,
            recentlyConsumed: stats?.itemsSaved ?? 0,
            recentlyShared: stats?.itemsShared ?? 0,
            streakDays: stats?.mealsCreated ?? 0
        )

        PrefetchCoordinator.shared.onPredictionUpdated(
            topIntent: intentPrediction.topIntent,
            predictions: intentPrediction.predictions
        )
    }

    // ══════════════════════════════════════════════════════════════
    // MARK: - Hero Header
    // Metal GPU-powered animated header with Freshli shaders.
    // ══════════════════════════════════════════════════════════════

    private var heroHeader: some View {
        ZStack(alignment: .top) {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
                let time = Float(timeline.date.timeIntervalSince(headerStartDate))

                UnevenRoundedRectangle(bottomLeadingRadius: PSSpacing.radiusHero, bottomTrailingRadius: PSSpacing.radiusHero)
                    .fill(
                        LinearGradient(
                            colors: [PSColors.headerGreen, PSColors.primaryGreenDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: PSLayout.headerHeight)
                    .modifier(HeroShaderModifier(time: time))
                    .drawingGroup()
            }

            // Soft decorative circles
            Circle()
                .fill(.white.opacity(0.04))
                .frame(width: PSLayout.scaled(240))
                .blur(radius: 40)
                .offset(x: PSLayout.scaled(100), y: PSLayout.scaled(-40))

            Circle()
                .fill(.white.opacity(0.03))
                .frame(width: PSLayout.scaled(180))
                .blur(radius: 30)
                .offset(x: PSLayout.scaled(-80), y: PSLayout.scaled(60))

            VStack(spacing: 0) {
                headerBar
                searchBar
                streakSection
            }
        }
    }

    // MARK: - Header Bar (Avatar + Greeting + Actions)

    private var headerBar: some View {
        HStack(alignment: .center) {
            NavigationLink(destination: FLProfilePage()) {
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
                FLText(greeting, .footnote, color: .custom(.white.opacity(0.65)))
                Text(authManager.currentDisplayName ?? String(localized: "Freshli User"))
                    .font(.system(size: PSLayout.scaledFont(22), weight: .bold))
                    .tracking(-0.3)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
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
                        if !urgentItems.isEmpty {
                            Circle()
                                .fill(PSColors.expiredRed)
                                .frame(width: PSLayout.scaled(8), height: PSLayout.scaled(8))
                                .overlay(Circle().strokeBorder(PSColors.headerGreen, lineWidth: 1.5))
                                .offset(x: -1, y: 2)
                        }
                    }
                }
                .accessibilityLabel(
                    urgentItems.isEmpty
                        ? String(localized: "Notifications")
                        : String(localized: "Notifications, \(urgentItems.count) items need attention")
                )
                .accessibilityHint(String(localized: "Opens your expiry alerts"))
            }
        }
        .padding(.top, PSLayout.headerTopPadding)
        .adaptiveHPadding()
        .padding(.bottom, PSSpacing.lg)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
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
        .background(.clear)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
        .adaptiveHPadding()
        .onTapGesture {
            PSHaptics.shared.selection()
            switchToTab(.pantry)
        }
    }

    // MARK: - Streak Section (in header)

    private var streakSection: some View {
        let streak = UserDefaults.standard.integer(forKey: "celebration_currentStreak")
        let hasStreak = streak > 0

        return HStack(spacing: PSSpacing.md) {
            Image(systemName: "flame.fill")
                .font(.system(size: PSLayout.scaledFont(20), weight: .bold))
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
                .fixedSize()
                .compositingGroup()
                .metalStreakFlame(streakDays: streak)

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
        .padding(.vertical, PSSpacing.lg)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
        .adaptiveHPadding()
        .padding(.bottom, PSSpacing.lg)
    }

    // ══════════════════════════════════════════════════════════════
    // MARK: - Dashboard Content
    // Lean layout: 4-6 high-signal cards. Secondary features live
    // in Discover. Alerts consolidated into one rotating card.
    // ══════════════════════════════════════════════════════════════

    private var dashboardContent: some View {
        VStack(spacing: PSSpacing.xl) {
            // Expiry alerts — uses Atomic organism
            FLExpiryAlertCard(
                expiringCount: expiringItems.count,
                expiredCount: expiredItems.count
            )
            .padding(.top, max(PSLayout.headerOverlap, PSLayout.scaled(-20)))
            .dashboardEntrance(index: 0)

            // Live wave — Atomic organism
            FLWaveCard()
                .dashboardEntrance(index: 1)

            // Quick actions grid — Atomic organism
            FLQuickActions(
                onScanFridge: { showAddItem = true },
                onAddItem: { showAddItem = true },
                onViewRecipes: { switchToTab(.recipes) },
                onSwitchTab: switchToTab
            )
            .dashboardEntrance(index: 2)

            // AI predictive surface
            PredictiveSurfaceCard(
                predictionService: intentPrediction,
                switchToTab: switchToTab
            )
            .dashboardEntrance(index: 3)

            // Smart alert (ethylene / gap-fill)
            smartAlertCard
                .dashboardEntrance(index: 4)

            // Cash not trashed — monthly savings
            cashNotTrashedCard
                .dashboardEntrance(index: 5)

            // Community fridges — Atomic organism
            FLCommunityFridgesCard()
                .dashboardEntrance(index: 6)

            // Pro upgrade nudge
            ProUpgradeNudge()
                .dashboardEntrance(index: 7)

            // Recipe suggestion
            recipeSuggestionCard
                .dashboardEntrance(index: 8)

            // Bulk meal plan
            if !bulkPlans.isEmpty {
                bulkPlanCard
                    .dashboardEntrance(index: 9)
            }

            // Community swap CTA
            communitySwapCard
                .dashboardEntrance(index: 10)
        }
        .adaptiveHPadding()
        .padding(.bottom, PSSpacing.xxxl)
    }

    // ══════════════════════════════════════════════════════════════
    // MARK: - Smart Alert Card (Ethylene / Gap-Fill)
    // ══════════════════════════════════════════════════════════════

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
                navigable: false
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
                    navigable: true
                )
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private func smartAlertContainer(
        category: String,
        title: String,
        message: String,
        icon: String,
        color: Color,
        extraCount: Int,
        navigable: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: PSSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: PSLayout.scaledFont(20)))
                .foregroundStyle(color)
                .frame(width: PSLayout.scaled(42), height: PSLayout.scaled(42))

            VStack(alignment: .leading, spacing: 2) {
                FLText(category, .sectionLabel, color: .custom(color))
                FLText(title, .headline, color: .primary)
                FLText(message, .caption, color: .secondary)
                    .lineSpacing(2)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                if extraCount > 0 {
                    FLText(
                        String(localized: "+\(extraCount) more alert\(extraCount == 1 ? "" : "s")"),
                        .callout,
                        color: .custom(color)
                    )
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            if navigable {
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

    // ══════════════════════════════════════════════════════════════
    // MARK: - Cash Not Trashed Card
    // ══════════════════════════════════════════════════════════════

    private var cashNotTrashedCard: some View {
        let stats = monthlyStats ?? ImpactService.ImpactStats()
        let monthName = Calendar.current.monthSymbols[Calendar.current.component(.month, from: Date()) - 1]
        let streak = RescueStreakService.shared.currentStreak

        return NavigationLink(destination: ImpactDashboardView()) {
            VStack(alignment: .leading, spacing: PSSpacing.lg) {
                HStack(spacing: PSSpacing.sm) {
                    Image(systemName: "banknote.fill")
                        .font(.system(size: PSLayout.scaledFont(22)))
                        .foregroundStyle(PSColors.secondaryAmber)

                    VStack(alignment: .leading, spacing: 1) {
                        FLText("Cash Not Trashed", .headline, color: .primary)
                        FLText(String(localized: "\(monthName) savings"), .caption, color: .secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                        .foregroundStyle(PSColors.textTertiary)
                }

                HStack(alignment: .firstTextBaseline, spacing: PSSpacing.xs) {
                    Text(stats.moneySavedDisplay)
                        .font(.system(size: PSLayout.scaledFont(42), weight: .black, design: .rounded))
                        .foregroundStyle(PSColors.secondaryAmber)
                    FLText(String(localized: "saved this month"), .callout, color: .secondary)
                        .padding(.bottom, PSSpacing.xs)
                }

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
            .freshliCard(cornerRadius: PSSpacing.radiusXxl)
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

    // ══════════════════════════════════════════════════════════════
    // MARK: - Recipe Suggestion Card
    // ══════════════════════════════════════════════════════════════

    private var recipeSuggestionCard: some View {
        let suggestions = RecipeService.shared.urgencyPrioritisedRecipes(items: activeItems)
        let recipe = suggestions.first
        let urgentItem = recipe.flatMap { RecipeService.shared.mostUrgentIngredient(for: $0, items: activeItems) }
        let isRescueMode = urgentItem.map { $0.expiryStatus != .fresh } ?? false

        return VStack(alignment: .leading, spacing: PSSpacing.lg) {
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: isRescueMode ? "bolt.fill" : "sparkles")
                    .font(.system(size: PSLayout.scaledFont(18)))
                    .foregroundStyle(isRescueMode ? PSColors.secondaryAmber : .purple)

                VStack(alignment: .leading, spacing: 1) {
                    FLText(
                        isRescueMode ? "Cook This First" : "Suggested for You",
                        .headline,
                        color: .primary
                    )
                    if isRescueMode, let urgentItem {
                        FLText(
                            "\(urgentItem.name) expires \(urgentItem.expiryStatus == .expiringToday ? "today" : "soon") — rescue it!",
                            .footnote,
                            color: .amber
                        )
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
                                Text("\u{2022}  \(recipe.prepTimeDisplay)")
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
        .elevation(.z2)
    }

    // ══════════════════════════════════════════════════════════════
    // MARK: - Bulk Plan Card
    // ══════════════════════════════════════════════════════════════

    private var bulkPlanCard: some View {
        VStack(alignment: .leading, spacing: PSSpacing.lg) {
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: PSLayout.scaledFont(18)))
                    .foregroundStyle(PSColors.accentTeal)

                VStack(alignment: .leading, spacing: 1) {
                    FLText("Zero-Waste Meal Plan", .headline, color: .primary)
                    FLText(String(localized: "Use every bit — nothing wasted"), .footnote, color: .secondary)
                }
                Spacer()
            }

            ForEach(bulkPlans) { plan in
                VStack(alignment: .leading, spacing: PSSpacing.sm) {
                    HStack(spacing: PSSpacing.sm) {
                        Text(plan.ingredient.name)
                            .font(.system(size: PSLayout.scaledFont(14), weight: .black))
                            .foregroundStyle(PSColors.accentTeal)
                        Text("\u{00B7}")
                            .foregroundStyle(PSColors.textTertiary)
                        Text(plan.totalPortionLabel)
                            .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                            .foregroundStyle(PSColors.textSecondary)
                        Spacer()
                        Text("\(plan.coveragePercent)% used")
                            .font(.system(size: PSLayout.scaledFont(10), weight: .bold))
                            .foregroundStyle(PSColors.accentTeal)
                            .padding(.horizontal, PSSpacing.sm)
                            .padding(.vertical, 3)
                            .background(PSColors.accentTeal.opacity(0.12))
                            .clipShape(Capsule())
                    }

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
        .elevation(.z2)
    }

    // ══════════════════════════════════════════════════════════════
    // MARK: - Community Swap Card
    // ══════════════════════════════════════════════════════════════

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

                    FLText("Community Swap", .displaySmall, color: .custom(Color(hex: 0x064E3B)))
                    FLText(
                        String(localized: "Share surplus food with neighbors nearby."),
                        .callout,
                        color: .custom(PSColors.primaryGreen.opacity(0.8))
                    )
                    .lineLimit(2)
                }

                Spacer()

                // Arrow circle — no background box
                Circle()
                    .fill(PSColors.primaryGreen)
                    .frame(width: PSLayout.scaled(44), height: PSLayout.scaled(44))
                    .shadow(color: PSColors.primaryGreen.opacity(0.35), radius: 12, y: 4)
                    .overlay(
                        Image(systemName: "arrow.right")
                            .font(.system(size: PSLayout.scaledFont(18), weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
            .adaptiveCardPadding()
            .freshliCard(cornerRadius: PSSpacing.radiusXxl)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// ══════════════════════════════════════════════════════════════════
// MARK: - HeroShaderModifier (Safe Shader Application)
// Conditionally applies the Metal 4 shader stack to the hero header.
// If the Metal default library is missing the required shaders (e.g.
// .metal files not in Compile Sources), falls back to a static
// .ultraThinMaterial overlay instead of SwiftUI's yellow prohibition
// screen.
// ══════════════════════════════════════════════════════════════════

private struct HeroShaderModifier: ViewModifier {
    let time: Float

    func body(content: Content) -> some View {
        if ShaderWarmUpService.shadersAvailable {
            content
                .visualEffect { view, proxy in
                    view
                        .colorEffect(
                            ShaderLibrary.heroGradient(
                                .float2(proxy.safeShaderSize),
                                .float(time)
                            )
                        )
                        .colorEffect(
                            ShaderLibrary.freshliAura(
                                .float2(proxy.safeShaderSize),
                                .float(time)
                            )
                        )
                        .colorEffect(
                            ShaderLibrary.subtleNoise(
                                .float2(proxy.safeShaderSize),
                                .float(time),
                                .float(0.3)
                            )
                        )
                        .colorEffect(
                            ShaderLibrary.liquidGlass(
                                .float4(0, 0, proxy.safeShaderSize.width, proxy.safeShaderSize.height),
                                .float(0.03),
                                .float(time * 0.5)
                            )
                        )
                }
        } else {
            // Graceful fallback: static glass material
            content
                .overlay(.ultraThinMaterial.opacity(0.3))
        }
    }
}
