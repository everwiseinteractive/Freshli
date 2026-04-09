import SwiftUI
import SwiftData

// MARK: - Recipe Rescue Flow
// NavigationStack-based flow with fluid transitions for the Recipe Rescue experience.

struct RecipeFlowView: View {
    @Query(filter: #Predicate<FreshliItem> { !$0.isConsumed && !$0.isShared && !$0.isDonated },
           sort: [SortDescriptor(\FreshliItem.expiryDate)])
    private var pantryItems: [FreshliItem]

    @State private var engine = RecipeRescueEngine()
    @State private var appeared = false
    @Namespace private var heroNamespace

    var body: some View {
        NavigationStack(path: $engine.navigationPath) {
            recipeListContent
                .navigationDestination(for: RecipeFlowDestination.self) { destination in
                    switch destination {
                    case .detail(let snapshot):
                        RecipeRescueDetailView(
                            recipe: snapshot,
                            engine: engine,
                            namespace: heroNamespace
                        )
                        .screenTransition()

                    case .cooking(let snapshot):
                        RecipeCookingView(
                            recipe: snapshot,
                            engine: engine
                        )
                        .screenTransition()
                    }
                }
        }
        .task {
            engine.loadRecipes(pantryItems: pantryItems)
        }
        .onChange(of: pantryItems.count) { _, _ in
            engine.loadRecipes(pantryItems: pantryItems)
        }
    }

    // MARK: - Main List Content

    private var recipeListContent: some View {
        VStack(spacing: 0) {
            flowHeader
            ScrollView {
                VStack(alignment: .leading, spacing: PSSpacing.xxl) {
                    filterBar
                    if engine.isLoading {
                        PSShimmerView()
                            .frame(height: PSLayout.featuredHeight)
                            .screenPadding()
                    } else if engine.filteredSnapshots.isEmpty {
                        emptyState
                    } else {
                        rescueHero
                            .staggeredAppearance(index: 0)
                        rescueList
                    }
                }
                .padding(.vertical, PSSpacing.lg)
            }
        }
        .background(PSColors.backgroundSecondary)
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(PSMotion.springGentle.delay(0.1)) { appeared = true }
        }
    }

    // MARK: - Header

    private var flowHeader: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            Text(String(localized: "Recipe Rescue"))
                .font(.system(size: PSLayout.scaledFont(30), weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(PSColors.textPrimary)

            Text(String(localized: "Save food, cook something great"))
                .font(PSTypography.callout)
                .foregroundStyle(PSColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveHPadding()
        .padding(.top, PSSpacing.md)
        .padding(.bottom, PSSpacing.lg)
        .background(PSColors.surfaceCard)
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        .overlay(alignment: .bottom) { Divider().opacity(0.5) }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PSSpacing.md) {
                ForEach(RecipeFilterMode.allCases) { filter in
                    Button {
                        PSHaptics.shared.selection()
                        withAnimation(PSMotion.springQuick) {
                            engine.activeFilter = filter
                        }
                    } label: {
                        HStack(spacing: PSSpacing.xs) {
                            Image(systemName: filter.icon)
                                .font(.system(size: PSLayout.scaledFont(12)))
                            Text(filter.rawValue)
                                .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                                .tracking(-0.2)
                        }
                        .padding(.horizontal, PSSpacing.xl)
                        .padding(.vertical, PSLayout.scaled(10))
                        .foregroundStyle(
                            engine.activeFilter == filter ? .white : PSColors.textSecondary
                        )
                        .background(
                            engine.activeFilter == filter ? PSColors.primaryGreen : PSColors.backgroundSecondary
                        )
                        .clipShape(Capsule())
                        .shadow(
                            color: engine.activeFilter == filter ? PSColors.primaryGreen.opacity(0.25) : .clear,
                            radius: 8, y: 4
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
        }
    }

    // MARK: - Featured Rescue Hero

    private var rescueHero: some View {
        Group {
            if let recipe = engine.filteredSnapshots.first {
                Button {
                    PSHaptics.shared.lightTap()
                    engine.navigateToDetail(recipe)
                } label: {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: PSLayout.featuredRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [PSColors.primaryGreen.opacity(0.4), PSColors.accentTeal.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: PSLayout.featuredHeight)
                            .overlay(alignment: .center) {
                                Image(systemName: recipe.imageSystemName)
                                    .font(.system(size: PSLayout.scaledFont(64)))
                                    .foregroundStyle(.white.opacity(0.4))
                            }

                        LinearGradient(
                            colors: [.clear, .black.opacity(0.3), .black.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: PSLayout.featuredRadius, style: .continuous))

                        VStack(alignment: .leading, spacing: PSSpacing.sm) {
                            HStack(spacing: PSSpacing.sm) {
                                Text(recipe.matchPercentageDisplay)
                                    .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, PSSpacing.md)
                                    .padding(.vertical, PSSpacing.xxs)
                                    .background(PSColors.primaryGreen)
                                    .clipShape(Capsule())

                                HStack(spacing: PSSpacing.xxs) {
                                    Image(systemName: "clock")
                                        .font(.system(size: PSLayout.scaledFont(14)))
                                    Text(recipe.prepTimeDisplay)
                                        .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                                }
                                .foregroundStyle(.white)
                            }

                            Text(recipe.title)
                                .font(.system(size: PSLayout.scaledFont(24), weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(2)

                            Text(recipe.summary)
                                .font(.system(size: PSLayout.scaledFont(14)))
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(2)
                        }
                        .adaptiveCardPadding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(PressableButtonStyle())
                .adaptiveHPadding()
            }
        }
    }

    // MARK: - Recipe List

    private var rescueList: some View {
        VStack(alignment: .leading, spacing: PSSpacing.lg) {
            Text(String(localized: "More Rescue Recipes"))
                .font(.system(size: PSLayout.scaledFont(20), weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(PSColors.textPrimary)
                .adaptiveHPadding()

            LazyVStack(spacing: PSSpacing.lg) {
                ForEach(Array(engine.filteredSnapshots.dropFirst().enumerated()), id: \.element.id) { index, recipe in
                    Button {
                        PSHaptics.shared.lightTap()
                        engine.navigateToDetail(recipe)
                    } label: {
                        rescueListCard(recipe: recipe)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .staggeredAppearance(index: index)
                }
            }
            .adaptiveHPadding()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        PSEmptyState(
            icon: engine.activeFilter == .expiringSoon ? "exclamationmark.triangle" : "book",
            title: engine.activeFilter == .forYou
                ? String(localized: "No Recipes Yet")
                : String(localized: "No \(engine.activeFilter.rawValue) Recipes"),
            message: engine.activeFilter == .forYou
                ? String(localized: "Add items to your pantry to discover rescue recipes!")
                : String(localized: "Try a different filter or add more items to your pantry."),
            actionTitle: nil,
            action: nil
        )
        .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
        .padding(.top, 40)
    }

    // MARK: - List Card

    private func rescueListCard(recipe: FreshliRecipeSnapshot) -> some View {
        HStack(spacing: PSSpacing.lg) {
            ZStack {
                RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [PSColors.primaryGreen.opacity(0.2), PSColors.accentTeal.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: PSLayout.recipeImageSize, height: PSLayout.recipeImageSize)

                Image(systemName: recipe.imageSystemName)
                    .font(.system(size: PSLayout.scaledFont(32)))
                    .foregroundStyle(PSColors.primaryGreen.opacity(0.5))
            }

            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                Text(recipe.title)
                    .font(.system(size: PSLayout.scaledFont(16), weight: .bold))
                    .foregroundStyle(PSColors.textPrimary)
                    .lineLimit(2)

                Text(recipe.matchPercentageDisplay)
                    .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                    .foregroundStyle(PSColors.primaryGreen)

                Spacer()

                HStack {
                    HStack(spacing: PSSpacing.xxs) {
                        Image(systemName: "clock")
                            .font(.system(size: PSLayout.scaledFont(14)))
                        Text(recipe.prepTimeDisplay)
                            .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                    }
                    .foregroundStyle(PSColors.textSecondary)

                    Spacer()

                    PSBadge(
                        text: recipe.difficultyEnum.displayName,
                        color: difficultyColor(recipe.difficultyEnum),
                        style: .subtle
                    )
                }
            }
            .padding(.vertical, PSSpacing.xxs)
        }
        .padding(PSSpacing.md)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                .strokeBorder(PSColors.borderLight, lineWidth: 1)
        )
    }

    private func difficultyColor(_ difficulty: RecipeDifficulty) -> Color {
        switch difficulty {
        case .easy: return PSColors.freshGreen
        case .medium: return PSColors.warningAmber
        case .hard: return PSColors.expiredRed
        }
    }
}

// MARK: - Recipe Rescue Detail View

struct RecipeRescueDetailView: View {
    let recipe: FreshliRecipeSnapshot
    let engine: RecipeRescueEngine
    var namespace: Namespace.ID

    @Environment(\.dismiss) private var dismiss
    @Environment(CelebrationManager.self) private var celebrationManager: CelebrationManager?
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PSSpacing.xxl) {
                headerSection
                metadataSection
                ingredientsSection
                startCookingButton
            }
            .padding(.vertical, PSSpacing.lg)
        }
        .background(PSColors.backgroundPrimary)
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(String(localized: "Back")) { dismiss() }
            }
        }
        .onAppear {
            withAnimation(PSMotion.springGentle.delay(0.1)) { appeared = true }
            celebrationManager?.onRecipeMatch(recipeName: recipe.title)
        }
    }

    private var headerSection: some View {
        VStack(spacing: PSSpacing.lg) {
            Image(systemName: recipe.imageSystemName)
                .font(.system(size: PSLayout.scaledFont(48), weight: .light))
                .foregroundStyle(PSColors.primaryGreen)
                .frame(width: PSLayout.scaled(100), height: PSLayout.scaled(100))
                .background(PSColors.primaryGreen.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
                .scaleEffect(appeared ? 1 : 0.7)
                .opacity(appeared ? 1 : 0)

            Text(recipe.title)
                .font(PSTypography.title1)
                .foregroundStyle(PSColors.textPrimary)
                .multilineTextAlignment(.center)

            Text(recipe.summary)
                .font(PSTypography.callout)
                .foregroundStyle(PSColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .screenPadding()
    }

    private var metadataSection: some View {
        HStack(spacing: PSSpacing.md) {
            MetadataChip(icon: "chart.pie.fill", value: recipe.matchPercentageDisplay, label: String(localized: "Match"))
            MetadataChip(icon: "clock", value: recipe.prepTimeDisplay, label: String(localized: "Prep Time"))
            MetadataChip(icon: recipe.difficultyEnum.icon, value: recipe.difficultyEnum.displayName, label: String(localized: "Difficulty"))
        }
        .screenPadding()
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            PSSectionHeader(
                title: String(localized: "Ingredients"),
                subtitle: "\(recipe.ingredients.count) items"
            )
            .screenPadding()

            VStack(spacing: PSSpacing.sm) {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                    HStack(spacing: PSSpacing.md) {
                        Image(systemName: index < recipe.matchingCount ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: PSLayout.scaledFont(18)))
                            .foregroundStyle(index < recipe.matchingCount ? PSColors.freshGreen : PSColors.textTertiary)

                        Text(ingredient)
                            .font(PSTypography.body)
                            .foregroundStyle(PSColors.textPrimary)

                        Spacer()

                        if index < recipe.matchingCount {
                            PSBadge(text: String(localized: "In Pantry"), color: PSColors.freshGreen, style: .subtle)
                        }
                    }
                    .padding(.vertical, PSSpacing.xs)

                    if index < recipe.ingredients.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(PSSpacing.cardPadding)
            .cardStyle()
            .screenPadding()
        }
    }

    private var startCookingButton: some View {
        PSButton(
            title: String(localized: "Start Cooking"),
            icon: "flame.fill",
            style: .primary,
            size: .large
        ) {
            PSHaptics.shared.mediumTap()
            engine.navigateToCooking(recipe)
        }
        .screenPadding()
        .padding(.bottom, PSSpacing.xxxl)
    }
}
