import SwiftUI
import SwiftData

// Figma: Recipes — sticky header, filter chips (active: bg-neutral-900 text-white)
// Featured recipe: rounded-[2rem] h-80 with gradient overlay, match badge, rating
// Recipe list cards: rounded-[1.25rem] with w-28 h-28 image, match%, time, rating

struct RecipesView: View {
    @Query(filter: #Predicate<FreshliItem> { !$0.isConsumed && !$0.isShared && !$0.isDonated },
           sort: [SortDescriptor(\FreshliItem.expiryDate)])
    private var pantryItems: [FreshliItem]

    @State private var activeFilter = "For You"
    @State private var selectedRecipe: Recipe?
    @State private var appeared = false
    @State private var matchedRecipes: [Recipe] = []
    @State private var showRescueChef = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let filters = ["For You", "Quick & Easy", "Breakfast", "Vegan", "Desserts"]

    private var recipes: [Recipe] {
        filterRecipes(matchedRecipes)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Figma: px-6 pt-12 pb-4 bg-white sticky top-0 z-30 shadow-sm border-b
            recipesHeader

            ScrollView {
                VStack(alignment: .leading, spacing: PSSpacing.xxl) {
                    if recipes.isEmpty && activeFilter != "For You" {
                        // Figma: empty state for filtered results
                        PSEmptyState(
                            icon: activeFilter == "Vegan" ? "leaf" : activeFilter == "Breakfast" ? "sunrise.fill" : activeFilter == "Desserts" ? "birthday.cake" : "timer",
                            title: String(localized: "\(activeFilter) Recipes"),
                            message: String(localized: "No \(activeFilter.lowercased()) recipes match your current pantry. Try different items!"),
                            actionTitle: nil,
                            action: nil
                        )
                        .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
                        .padding(.top, 40)
                    } else if !recipes.isEmpty {
                        if activeFilter == "For You" {
                            featuredRecipe
                                .staggeredAppearance(index: 0)
                        }
                        recipeList
                    } else {
                        PSEmptyState(
                            icon: "book",
                            title: String(localized: "No Recipes Yet"),
                            message: String(localized: "Add items to your pantry to discover recipes you can make!"),
                            actionTitle: nil,
                            action: nil
                        )
                        .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
                        .padding(.top, 40)
                    }
                }
                .padding(.vertical, PSSpacing.lg)
            }
        }
        .background(PSColors.backgroundSecondary)
        .navigationBarHidden(true)
        .sheet(item: $selectedRecipe) { recipe in
            NavigationStack {
                RecipeDetailView(recipe: recipe)
            }
            .presentationDragIndicator(.visible)
        }
        .navigationDestination(isPresented: $showRescueChef) {
            RescueChefView()
        }
        .task {
            matchedRecipes = RecipeService.shared.recipesForFreshli(items: pantryItems)
        }
        .onChange(of: pantryItems.count) { _, _ in
            matchedRecipes = RecipeService.shared.recipesForFreshli(items: pantryItems)
        }
    }

    // MARK: - Figma: Sticky Recipes header with title + filter chips

    private var recipesHeader: some View {
        VStack(alignment: .leading, spacing: PSSpacing.lg) {
            // Figma: text-3xl font-bold text-neutral-900 tracking-tight
            HStack {
                Text(String(localized: "Recipes"))
                    .font(.system(size: PSLayout.scaledFont(30), weight: .bold))
                    .tracking(-0.3)
                    .foregroundStyle(PSColors.textPrimary)
                Spacer()
                NavigationLink(destination: RescueChefView()) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: PSLayout.scaledFont(18)))
                        .foregroundStyle(PSColors.expiredRed)
                        .frame(width: PSLayout.scaled(36), height: PSLayout.scaled(36))
                        .background(PSColors.expiredRed.opacity(0.1))
                        .clipShape(Circle())
                }
                .accessibilityLabel(String(localized: "Rescue Chef"))
                .accessibilityHint(String(localized: "See recipes for items that need rescuing"))
            }
            .adaptiveHPadding()

            // Filter chips extend full width with their own horizontal padding
            filterChips
        }
        .padding(.top, PSSpacing.md)
        .padding(.bottom, PSSpacing.lg)
        .background(PSColors.surfaceCard)
        // Figma: shadow-sm border-b border-neutral-100
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        .overlay(alignment: .bottom) { Divider().opacity(0.5) }
    }

    // MARK: - Figma: Filter chips (active: bg-neutral-900 text-white shadow-md)

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PSSpacing.md) {
                ForEach(filters, id: \.self) { filter in
                    Button {
                        PSHaptics.shared.selection()
                        withAnimation(FLMotion.adaptive(PSMotion.springQuick, reduceMotion: reduceMotion)) { activeFilter = filter }
                    } label: {
                        Text(filter)
                            .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                            .tracking(-0.2)
                            .padding(.horizontal, PSSpacing.xl)
                            .padding(.vertical, PSLayout.scaled(10))
                            .foregroundStyle(activeFilter == filter ? .white : PSColors.textSecondary)
                            .background(activeFilter == filter ? PSColors.textPrimary : PSColors.backgroundSecondary)
                            .clipShape(Capsule())
                            .shadow(color: activeFilter == filter ? .black.opacity(0.1) : .clear, radius: 8, y: 4)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
        }
    }

    // MARK: - Figma: Featured Recipe (rounded-[2rem] with gradient overlay)

    private var featuredRecipe: some View {
        Group {
            if let recipe = recipes.first {
                Button { selectedRecipe = recipe } label: {
                    ZStack(alignment: .bottom) {
                        // Figma: h-80 image with gradient
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

                        // Figma: gradient overlay
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.3), .black.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: PSLayout.featuredRadius, style: .continuous))

                        // Figma: content overlay at bottom
                        VStack(alignment: .leading, spacing: PSSpacing.sm) {
                            HStack(spacing: PSSpacing.sm) {
                                // Figma: match badge
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

                            HStack(spacing: PSSpacing.lg) {
                                HStack(spacing: PSSpacing.xxs) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: PSLayout.scaledFont(16)))
                                        .foregroundStyle(.yellow)
                                    Text(recipe.ratingDisplay)
                                        .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                                        .foregroundStyle(.white)
                                }

                                ForEach(["Healthy", "Quick"], id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: PSLayout.scaledFont(12)))
                                        .foregroundStyle(.white.opacity(0.8))
                                        .padding(.horizontal, PSSpacing.sm)
                                        .padding(.vertical, PSSpacing.xxxs)
                                        .background(.white.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.xs))
                                }
                            }
                        }
                        .adaptiveCardPadding()
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Figma: heart button top-right
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "heart")
                                    .font(.system(size: PSLayout.scaledFont(20)))
                                    .foregroundStyle(.white)
                                    .frame(width: PSLayout.iconButtonSize, height: PSLayout.iconButtonSize)
                                    .background(.white.opacity(0.2))
                                    .clipShape(Circle())
                            }
                            Spacer()
                        }
                        .padding(PSSpacing.lg)
                    }
                }
                .buttonStyle(PressableButtonStyle())
                .adaptiveHPadding()
            }
        }
    }

    // MARK: - Figma: Recipe List

    private var recipeList: some View {
        VStack(alignment: .leading, spacing: PSSpacing.lg) {
            Text(String(localized: "Recommended for You"))
                .font(.system(size: PSLayout.scaledFont(20), weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(PSColors.textPrimary)
                .adaptiveHPadding()

            LazyVStack(spacing: PSSpacing.lg) {
                ForEach(Array(recipes.dropFirst().enumerated()), id: \.element.id) { index, recipe in
                    Button { selectedRecipe = recipe } label: {
                        recipeListCard(recipe: recipe)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .staggeredAppearance(index: index)
                }
            }
            .adaptiveHPadding()
            .listChangeAnimation("\(activeFilter)-\(recipes.count)")
        }
    }

    // MARK: - Filter Logic

    private func filterRecipes(_ recipes: [Recipe]) -> [Recipe] {
        switch activeFilter {
        case "Quick & Easy":
            return recipes.filter { $0.prepTimeMinutes <= 20 }
        case "Vegan":
            return recipes.filter { recipe in
                !recipe.ingredients.contains { ingredient in
                    let lower = ingredient.lowercased()
                    return lower.contains("meat") || lower.contains("dairy") || lower.contains("seafood") ||
                           lower.contains("egg") || lower.contains("milk") || lower.contains("butter") ||
                           lower.contains("cheese") || lower.contains("honey") || lower.contains("fish")
                }
            }
        case "Breakfast":
            return recipes.filter { recipe in
                let lower = recipe.title.lowercased()
                return lower.contains("breakfast") || lower.contains("oat") || lower.contains("egg") ||
                       lower.contains("pancake") || lower.contains("toast") || lower.contains("hash") ||
                       lower.contains("scrambl")
            }
        case "Desserts":
            return recipes.filter { recipe in
                let lower = recipe.title.lowercased()
                return lower.contains("dessert") || lower.contains("cake") || lower.contains("cookie") ||
                       lower.contains("brownie") || lower.contains("pie") || lower.contains("pudding") ||
                       lower.contains("mousse") || lower.contains("tart") || lower.contains("cheesecake")
            }
        default: // "For You"
            return recipes
        }
    }

    // Figma: recipe list card — rounded-[1.25rem] p-3 with w-28 h-28 image
    private func recipeListCard(recipe: Recipe) -> some View {
        HStack(spacing: PSSpacing.lg) {
            // Figma: w-28 h-28 rounded-[1rem] = 112x112 16px radius
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

                // Figma: heart overlay top-right
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "heart")
                            .font(.system(size: PSLayout.scaledFont(14)))
                            .foregroundStyle(.white)
                            .padding(PSSpacing.xs)
                            .background(.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(PSSpacing.sm)
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

                    HStack(spacing: PSSpacing.xxs) {
                        Image(systemName: "star.fill")
                            .font(.system(size: PSLayout.scaledFont(14)))
                            .foregroundStyle(.yellow)
                        Text(recipe.ratingDisplay)
                            .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                            .foregroundStyle(PSColors.textPrimary)
                    }
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
}
