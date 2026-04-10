import SwiftUI
import SwiftData
import os

// Figma: Home — bg-green-600 rounded-b-[40px] header with avatar, greeting, bell
// Search bar inside header with bg-white/20 backdrop-blur
// Expiring Soon card with horizontal items, Recipe Suggestion card, Community Swap card

struct HomeView: View {
    @Binding var showAddItem: Bool
    var switchToTab: (AppTab) -> Void

    @Query(filter: #Predicate<FreshliItem> { !$0.isConsumed && !$0.isShared && !$0.isDonated },
           sort: [SortDescriptor(\FreshliItem.expiryDate)])
    private var activeItems: [FreshliItem]

    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager: AuthManager?

    @State private var selectedImpactStat: String?
    @State private var impactStats: ImpactService.ImpactStats?
    @State private var showWeeklyWrap = false

    private let logger = Logger(subsystem: "com.freshli.app", category: "HomeView")

    private var expiringItems: [FreshliItem] {
        activeItems.filter { $0.expiryStatus != .fresh }.prefix(5).map { $0 }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return String(localized: "Good Morning,") }
        if hour < 17 { return String(localized: "Good Afternoon,") }
        return String(localized: "Good Evening,")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                curvedHeader
                contentSections
            }
        }
        .background(PSColors.backgroundSecondary)
        .ignoresSafeArea(edges: .top)
        .navigationDestination(isPresented: $showWeeklyWrap) {
            WeeklyWrapView()
        }
        .task {
            logger.info("HomeView appeared — \(activeItems.count) active items")
            impactStats = ImpactService(modelContext: modelContext).calculateStats()
        }
        .onChange(of: activeItems.count) { _, _ in
            impactStats = ImpactService(modelContext: modelContext).calculateStats()
        }
    }

    // MARK: - Figma: Green curved header

    private var curvedHeader: some View {
        ZStack(alignment: .top) {
            // Figma: bg-green-600 rounded-b-[40px]
            UnevenRoundedRectangle(bottomLeadingRadius: PSSpacing.radiusHero, bottomTrailingRadius: PSSpacing.radiusHero)
                .fill(PSColors.headerGreen)
                .frame(height: PSLayout.headerHeight)

            // Figma: decorative blur blob
            Circle()
                .fill(PSColors.headerGreenLight.opacity(0.5))
                .adaptiveFrame(width: 256, height: 256)
                .blur(radius: PSLayout.scaled(80))
                .offset(x: PSLayout.scaled(100), y: PSLayout.scaled(-60))

            VStack(spacing: 0) {
                // Figma: avatar + greeting + bell row
                HStack(alignment: .center) {
                    // Figma: w-12 h-12 rounded-full border-2 border-white avatar
                    NavigationLink(destination: ProfileView()) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: PSLayout.scaledFont(44)))
                            .foregroundStyle(.white.opacity(0.8))
                            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(greeting)
                            .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                        Text(authManager?.currentDisplayName ?? String(localized: "Freshli User"))
                            .font(.system(size: PSLayout.scaledFont(24), weight: .bold))
                            .tracking(-0.3)
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    HStack(spacing: PSSpacing.sm) {
                        // Weekly wrap button
                        Button {
                            PSHaptics.shared.lightTap()
                            showWeeklyWrap = true
                        } label: {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: PSLayout.scaledFont(20)))
                                .foregroundStyle(.white)
                                .frame(width: PSLayout.iconButtonSize, height: PSLayout.iconButtonSize)
                                .background(.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(String(localized: "View Weekly Wrap"))
                        .accessibilityHint(String(localized: "See your weekly impact summary"))

                        // Figma: notification bell with badge — navigates to ExpiryAlertsView
                        NavigationLink(destination: ExpiryAlertsView()) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: PSLayout.scaledFont(20)))
                                    .foregroundStyle(.white)
                                    .frame(width: PSLayout.iconButtonSize, height: PSLayout.iconButtonSize)
                                    .background(.white.opacity(0.2))
                                    .clipShape(Circle())

                                // Figma: w-2 h-2 bg-red-500 border border-green-600
                                if !expiringItems.isEmpty {
                                    Circle()
                                        .fill(PSColors.expiredRed)
                                        .frame(width: PSLayout.scaled(8), height: PSLayout.scaled(8))
                                        .overlay(Circle().strokeBorder(PSColors.headerGreen, lineWidth: 1))
                                        .offset(x: -2, y: 2)
                                }
                            }
                        }
                        .accessibilityLabel(String(localized: "View Expiry Alerts"))
                        .accessibilityHint(String(localized: "Notifications: \(expiringItems.count) items expiring soon"))
                    }
                }
                .padding(.top, PSLayout.headerTopPadding)
                .adaptiveHPadding()
                .padding(.bottom, PSLayout.cardPadding)

                // Figma: search bar with bg-white/20 backdrop-blur rounded-2xl
                HStack(spacing: PSSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: PSLayout.scaledFont(20)))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.leading, PSSpacing.lg)

                    Text(String(localized: "Search recipes, ingredients..."))
                        .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))

                    Spacer()
                }
                .frame(height: PSLayout.searchBarHeight)
                // Figma: bg-white/20 backdrop-blur-md rounded-2xl border border-white/10
                .background(.ultraThinMaterial.opacity(0.3))
                .background(.white.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
                .adaptiveHPadding()
                .scaleEffect(0.97, anchor: .center)
                .opacity(0.9)
                .onTapGesture {
                    PSHaptics.shared.selection()
                    switchToTab(.pantry)
                }
            }
        }
    }

    // MARK: - Content Sections

    private var contentSections: some View {
        VStack(spacing: PSSpacing.xxl) {
            // Figma: cards overlap header by -mt-10
            // Clamp overlap to prevent clipping on SE
            expiringSoonCard
                .padding(.top, max(PSLayout.headerOverlap, PSLayout.scaled(-20)))
                .dashboardEntrance(index: 0)

            impactSummaryCard
                .dashboardEntrance(index: 1)

            recipeSuggestionCard
                .dashboardEntrance(index: 2)

            communitySwapCard
                .dashboardEntrance(index: 3)
        }
        .adaptiveHPadding()
        .padding(.bottom, PSSpacing.xxxl)
    }

    // MARK: - Figma: Expiring Soon Card

    private var expiringSoonCard: some View {
        VStack(alignment: .leading, spacing: PSSpacing.lg) {
            HStack {
                HStack(spacing: PSSpacing.sm) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: PSLayout.scaledFont(20)))
                        .foregroundStyle(PSColors.secondaryAmber)
                    Text(String(localized: "Expiring Soon"))
                        .font(.system(size: PSLayout.scaledFont(18), weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                        .psAccessibleHeader(String(localized: "Expiring Soon"))
                }
                Spacer()
                Button {
                    PSHaptics.shared.lightTap()
                    switchToTab(.pantry)
                } label: {
                    Text(String(localized: "View All"))
                        .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                        .foregroundStyle(PSColors.primaryGreen)
                }
            }

            if expiringItems.isEmpty {
                Text(String(localized: "All items are fresh!"))
                    .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, PSSpacing.lg)
            } else {
                // Figma: horizontal scroll w-36 items with emoji icons
                // Safe area handling for scroll edge
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PSSpacing.lg) {
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
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: PSColors.primaryGreen.opacity(0.08), radius: 12, y: 4)
    }

    // MARK: - Impact Summary Card

    private var impactSummaryCard: some View {
        NavigationLink(destination: ImpactDashboardView()) {
            VStack(alignment: .leading, spacing: PSSpacing.lg) {
                HStack(spacing: PSSpacing.sm) {
                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: PSLayout.scaledFont(20)))
                        .foregroundStyle(PSColors.primaryGreen)
                    Text(String(localized: "Your Impact"))
                        .font(.system(size: PSLayout.scaledFont(18), weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                        .psAccessibleHeader(String(localized: "Your Impact"))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                        .foregroundStyle(PSColors.primaryGreen.opacity(0.5))
                }

                if let stats = impactStats {
                // Adaptive layout: stack on SE, horizontal otherwise
                if PSLayout.isCompact {
                    VStack(spacing: PSSpacing.lg) {
                        impactStatTile(
                            icon: "leaf.fill",
                            value: "\(stats.itemsSaved)",
                            label: String(localized: "Saved")
                        )

                        impactStatTile(
                            icon: "wind",
                            value: stats.co2Display,
                            label: String(localized: "CO\u{2082} Avoided")
                        )

                        impactStatTile(
                            icon: "dollarsign.circle",
                            value: stats.moneySavedDisplay,
                            label: String(localized: "Money Saved")
                        )
                    }
                } else {
                    HStack(spacing: 0) {
                        impactStatTile(
                            icon: "leaf.fill",
                            value: "\(stats.itemsSaved)",
                            label: String(localized: "Saved")
                        )

                        impactStatTile(
                            icon: "wind",
                            value: stats.co2Display,
                            label: String(localized: "CO\u{2082} Avoided")
                        )

                        impactStatTile(
                            icon: "dollarsign.circle",
                            value: stats.moneySavedDisplay,
                            label: String(localized: "Money Saved")
                        )
                    }
                }
            } else {
                // Placeholder/shimmer while loading
                if PSLayout.isCompact {
                    VStack(spacing: PSSpacing.lg) {
                        PSShimmerView()
                        PSShimmerView()
                        PSShimmerView()
                    }
                } else {
                    HStack(spacing: 0) {
                        PSShimmerView()
                        PSShimmerView()
                        PSShimmerView()
                    }
                }
            }
            }
            .adaptiveCardPadding()
            .background(PSColors.emeraldSurface)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                    .strokeBorder(PSColors.primaryGreen.opacity(0.15), lineWidth: 1)
            )
        }
    }

    private func impactStatTile(icon: String, value: String, label: String) -> some View {
        Button {
            PSHaptics.shared.lightTap()
            withAnimation(PSMotion.springBouncy) {
                selectedImpactStat = label
            }
        } label: {
            VStack(spacing: PSSpacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: PSLayout.scaledFont(20)))
                    .foregroundStyle(PSColors.primaryGreen)
                    .scaleEffect(selectedImpactStat == label ? 1.15 : 1.0)
                Text(value)
                    .font(.system(size: PSLayout.scaledFont(22), weight: .bold))
                    .foregroundStyle(PSColors.textPrimary)
                Text(label)
                    .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, PSSpacing.sm)
            .background(selectedImpactStat == label ? PSColors.primaryGreen.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
            .scaleEffect(selectedImpactStat == label ? 0.96 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    // MARK: - Figma: Recipe Suggestion Card

    private var recipeSuggestionCard: some View {
        VStack(alignment: .leading, spacing: PSSpacing.lg) {
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: PSLayout.scaledFont(20)))
                    .foregroundStyle(.purple)
                Text(String(localized: "Suggested for You"))
                    .font(.system(size: PSLayout.scaledFont(18), weight: .bold))
                    .foregroundStyle(PSColors.textPrimary)
                    .psAccessibleHeader(String(localized: "Suggested for You"))
            }

            let suggestions = RecipeService.shared.recipesForFreshli(items: activeItems)
            if !suggestions.isEmpty {
                if let recipe = suggestions.first {
                // Figma: bg-white rounded-3xl overflow-hidden shadow-sm border border-neutral-100
                Button {
                    PSHaptics.shared.lightTap()
                    switchToTab(.recipes)
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        // Figma: h-48 image with gradient overlay
                        ZStack(alignment: .bottomLeading) {
                            LinearGradient(
                                colors: [PSColors.primaryGreen.opacity(0.3), PSColors.accentTeal.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .frame(height: PSLayout.cardImageHeight)
                            .overlay(alignment: .center) {
                                Image(systemName: recipe.imageSystemName)
                                    .font(.system(size: PSLayout.scaledFont(48)))
                                    .foregroundStyle(.white.opacity(0.6))
                            }

                            // Figma: bg-gradient-to-t from-black/60 to-transparent
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )

                            VStack(alignment: .leading, spacing: 4) {
                                // Figma: px-3 py-1 bg-white/20 backdrop-blur-md rounded-full
                                Text(String(localized: "Uses your expiring items"))
                                    .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .padding(.horizontal, PSSpacing.md)
                                    .padding(.vertical, PSSpacing.xxs)
                                    .background(.white.opacity(0.2))
                                    .clipShape(Capsule())

                                Text(recipe.title)
                                    .font(.system(size: PSLayout.scaledFont(20), weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)

                                Text("\(recipe.prepTimeDisplay) • \(recipe.difficulty.displayName)")
                                    .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .padding(PSSpacing.lg)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                            .strokeBorder(LinearGradient(
                                gradient: Gradient(colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ), lineWidth: 1)
                    )
                    .shadow(color: PSColors.primaryGreen.opacity(0.06), radius: 4, y: 2)
                }
                .buttonStyle(PressableButtonStyle())
                }
            } else {
                PSEmptyState(
                    icon: "book",
                    title: String(localized: "No Recipes Yet"),
                    message: String(localized: "Add items to your pantry to discover recipes you can make!"),
                    actionTitle: nil,
                    action: nil
                )
            }
        }
    }

    // MARK: - Figma: Community Swap Card

    private var communitySwapCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: PSSpacing.xxs) {
                Text(String(localized: "Community Swap"))
                    .font(.system(size: PSLayout.scaledFont(16), weight: .bold))
                    .foregroundStyle(Color(hex: 0x064E3B))
                Text(String(localized: "Share surplus food with neighbors. Every item counts."))
                    .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                    .foregroundStyle(PSColors.primaryGreen)
                    .lineLimit(2)
                    .frame(maxWidth: PSLayout.scaled(200), alignment: .leading)
            }

            Spacer()

            Button {
                PSHaptics.shared.lightTap()
                switchToTab(.community)
            } label: {
                Image(systemName: "arrow.right")
                    .font(.system(size: PSLayout.scaledFont(20), weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: PSLayout.communityAvatarSize, height: PSLayout.communityAvatarSize)
                    .background(PSColors.primaryGreen)
                    .clipShape(Circle())
                    .shadow(color: PSColors.primaryGreen.opacity(0.25), radius: 12, y: 4)
            }
            .buttonStyle(PressableButtonStyle())
        }
        .adaptiveCardPadding()
        .background(PSColors.emeraldSurface)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                .strokeBorder(PSColors.primaryGreen.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Figma: Expiring item pill (w-36, rounded-2xl, emoji icon)

private struct ExpiringItemPill: View {
    let item: FreshliItem

    var body: some View {
        NavigationLink(destination: FreshliDetailView(item: item)) {
            VStack(spacing: PSSpacing.md) {
            // Figma: w-14 h-14 rounded-full emoji container
            Text(item.category.emoji)
                .font(.system(size: PSLayout.scaledFont(28)))
                .frame(width: PSLayout.emojiCircleSize, height: PSLayout.emojiCircleSize)
                .background(PSColors.categoryColor(for: item.category).opacity(0.15))
                .clipShape(Circle())

            VStack(spacing: 2) {
                Text(item.name)
                    .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                    .foregroundStyle(PSColors.textPrimary)
                    .lineLimit(1)
                    .frame(width: PSLayout.scaled(112))

                Text(item.expiryDate.expiryDisplayText)
                    .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
                    .foregroundStyle(PSColors.expiredRed)
            }
        }
        .padding(PSSpacing.lg)
        .frame(width: PSLayout.pillWidth)
        .background(PSColors.categoryColor(for: item.category).opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                .strokeBorder(PSColors.categoryColor(for: item.category).opacity(0.15), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.name)
        .accessibilityValue(item.expiryDate.expiryDisplayText)
        .accessibilityHint(item.expiryStatus == .expired ? String(localized: "Expired") : item.expiryStatus.displayName)
        }
    }
}

#Preview("HomeView - iPhone SE") {
    HomeView(showAddItem: .constant(false), switchToTab: { _ in })
        .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
}

#Preview("HomeView - iPhone 16 Pro Max") {
    HomeView(showAddItem: .constant(false), switchToTab: { _ in })
        .previewDevice(PreviewDevice(rawValue: "iPhone 16 Pro Max"))
}
