import SwiftUI
import SwiftData

struct RecipesView: View {
    @Query(filter: #Predicate<FreshliItem> { !$0.isConsumed && !$0.isShared && !$0.isDonated },
           sort: [SortDescriptor(\FreshliItem.expiryDate)])
    private var pantryItems: [FreshliItem]

    @State private var activeFilter = "For You"
    @State private var selectedRecipe: Recipe?
    @State private var matchedRecipes: [Recipe] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let filters = ["For You", "Quick & Easy", "Breakfast", "Vegan", "Desserts"]

    /// All recipes to display: pantry-matched when available, otherwise the full built-in library.
    /// This ensures the screen is always filled with great content.
    private var displayRecipes: [Recipe] {
        if matchedRecipes.isEmpty {
            return RecipeService.shared.recipes
        }
        return matchedRecipes
    }

    private var recipes: [Recipe] { filterRecipes(displayRecipes) }
    private var isPantryMatched: Bool { !matchedRecipes.isEmpty }

    // Items expiring soon — used to show Rescue Chef banner
    private var urgentCount: Int {
        pantryItems.filter { $0.expiryStatus == .expiringSoon || $0.expiryStatus == .expiringToday || $0.expiryStatus == .expired }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            recipesHeader

            ScrollView {
                VStack(alignment: .leading, spacing: PSSpacing.xl) {
                    // Rescue Chef urgent banner
                    if urgentCount > 0 {
                        rescueChefBanner
                            .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
                            .padding(.top, PSSpacing.md)
                            .staggeredAppearance(index: 0)
                    }

                    // Leftover Heroes — always visible in "For You" filter
                    if activeFilter == "For You" {
                        leftoverHeroesSection
                            .staggeredAppearance(index: urgentCount > 0 ? 1 : 0)
                    }

                    if recipes.isEmpty && activeFilter != "For You" {
                        PSEmptyState(
                            icon: activeFilter == "Vegan" ? "leaf" : activeFilter == "Breakfast" ? "sunrise.fill" : activeFilter == "Desserts" ? "birthday.cake" : "timer",
                            title: String(localized: "\(activeFilter) Recipes"),
                            message: String(localized: "No \(activeFilter.lowercased()) recipes found. Try a different filter!"),
                            actionTitle: nil, action: nil
                        )
                        .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
                        .padding(.top, 40)
                    } else if !recipes.isEmpty {
                        if activeFilter == "For You" {
                            featuredRecipe.staggeredAppearance(index: urgentCount > 0 ? 2 : 1)
                        }
                        recipeList
                    }
                }
                .padding(.top, PSSpacing.md)
            }
            // Make sure the last card always sits above the floating tab bar.
            .contentMargins(.bottom, PSLayout.scaled(150), for: .scrollContent)
        }
        .background(PSColors.backgroundSecondary)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedRecipe) { recipe in
            NavigationStack { RecipeDetailView(recipe: recipe) }
                .presentationDragIndicator(.visible)
        }
        .task { matchedRecipes = RecipeService.shared.recipesForFreshli(items: pantryItems) }
        .onChange(of: pantryItems.count) { _, _ in matchedRecipes = RecipeService.shared.recipesForFreshli(items: pantryItems) }
    }

    // MARK: - Header

    private var recipesHeader: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            HStack(alignment: .center, spacing: PSSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Recipes"))
                        .font(.system(size: PSLayout.scaledFont(28), weight: .bold))
                        .tracking(-0.3)
                        .foregroundStyle(PSColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(isPantryMatched
                        ? String(localized: "\(matchedRecipes.count) recipes matched to your pantry")
                        : String(localized: "\(RecipeService.shared.recipes.count) recipes to explore"))
                        .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                        .foregroundStyle(PSColors.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                NavigationLink(destination: RescueChefView()) {
                    HStack(spacing: PSSpacing.xxs) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: PSLayout.scaledFont(12)))
                        Text(String(localized: "Rescue"))
                            .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
                    }
                    .foregroundStyle(PSColors.expiredRed)
                    .padding(.horizontal, PSSpacing.sm)
                    .padding(.vertical, PSSpacing.xs)
                    .background(PSColors.expiredRed.opacity(0.1))
                    .clipShape(Capsule())
                }
                .layoutPriority(2)
                .fixedSize()
            }
            .adaptiveHPadding()

            filterChips
        }
        .padding(.top, PSSpacing.md)
        .padding(.bottom, PSSpacing.md)
        .frame(maxWidth: .infinity)
        .background(PSColors.surfaceCard)
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        .overlay(alignment: .bottom) { Divider().opacity(0.5) }
    }

    // MARK: - Leftover Heroes Section

    private var leftoverHeroesSection: some View {
        let heroes = RecipeService.shared.leftoverHeroes
        return VStack(alignment: .leading, spacing: PSSpacing.md) {
            // Section header
            HStack(alignment: .center, spacing: PSSpacing.sm) {
                HStack(spacing: PSSpacing.xs) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
                        .foregroundStyle(Color(hex: 0xF59E0B))
                    Text("LEFTOVER HEROES")
                        .font(.system(size: PSLayout.scaledFont(10), weight: .black))
                        .tracking(0.6)
                        .foregroundStyle(Color(hex: 0xF59E0B))
                }
                .padding(.horizontal, PSSpacing.sm)
                .padding(.vertical, PSSpacing.xxs)
                .background(Color(hex: 0xF59E0B).opacity(0.12))
                .clipShape(Capsule())
                .fixedSize()
                .layoutPriority(1)

                Text("Turn leftovers into magic")
                    .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                    .foregroundStyle(PSColors.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)

            // Horizontal scroll of hero recipe cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PSSpacing.md) {
                    ForEach(heroes) { recipe in
                        Button { selectedRecipe = recipe } label: {
                            leftoverHeroCard(recipe)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
            }
        }
    }

    private func leftoverHeroCard(_ recipe: Recipe) -> some View {
        let cardWidth = PSLayout.scaled(200)
        let cardHeight = PSLayout.scaled(170)
        return ZStack(alignment: .bottomLeading) {
            // Base — real food photo sized to the card exactly.
            FoodCardImage(
                title: recipe.title,
                imageSystemName: recipe.imageSystemName,
                height: cardHeight,
                cornerRadius: PSSpacing.radiusXl
            )
            .frame(width: cardWidth, height: cardHeight)

            // Dark scrim for legibility.
            LinearGradient(
                colors: [.clear, .black.opacity(0.72)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))

            // Text overlay — constrained to the card's inner width so the
            // first letter can never be clipped by the ZStack edge.
            VStack(alignment: .leading, spacing: PSSpacing.xs) {
                HStack(spacing: PSSpacing.xxs) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("HERO")
                        .font(.system(size: 9, weight: .black))
                        .tracking(0.5)
                }
                .foregroundStyle(Color(hex: 0x1A1A1A))
                .padding(.horizontal, PSSpacing.sm)
                .padding(.vertical, 3)
                .background(
                    LinearGradient(
                        colors: [Color(hex: 0xFBBF24), Color(hex: 0xF59E0B)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .fixedSize()

                Text(recipe.title)
                    .font(.system(size: PSLayout.scaledFont(14), weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: PSSpacing.xs) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(recipe.prepTimeDisplay)
                        .font(.system(size: PSLayout.scaledFont(11), weight: .semibold))

                    if !recipe.substitutions.isEmpty {
                        Text("·")
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10))
                        Text("\(recipe.substitutions.count) swaps")
                            .font(.system(size: PSLayout.scaledFont(11), weight: .semibold))
                    }
                }
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            }
            .padding(PSSpacing.md)
            .frame(width: cardWidth, alignment: .leading)
        }
        .frame(width: cardWidth, height: cardHeight, alignment: .bottomLeading)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                .strokeBorder(Color(hex: 0xF59E0B).opacity(0.4), lineWidth: 1.5)
        )
        .shadow(color: Color(hex: 0xF59E0B).opacity(0.15), radius: 12, y: 5)
    }

    // MARK: - Rescue Chef Banner

    private var rescueChefBanner: some View {
        NavigationLink(destination: RescueChefView()) {
            HStack(spacing: PSSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(PSColors.expiredRed.opacity(0.15))
                        .frame(width: PSLayout.scaled(52), height: PSLayout.scaled(52))
                    Image(systemName: "flame.fill")
                        .font(.system(size: PSLayout.scaledFont(24)))
                        .foregroundStyle(PSColors.expiredRed)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Rescue Chef"))
                        .font(.system(size: PSLayout.scaledFont(16), weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                    Text(String(localized: "\(urgentCount) item\(urgentCount == 1 ? "" : "s") need cooking now — get recipe ideas!"))
                        .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                    .foregroundStyle(PSColors.expiredRed.opacity(0.5))
            }
            .padding(PSSpacing.lg)
            .background(PSColors.expiredRed.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                    .strokeBorder(PSColors.expiredRed.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Filter Chips

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
                            .shadow(color: activeFilter == filter ? .black.opacity(0.12) : .clear, radius: 8, y: 4)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
        }
    }

    // MARK: - Featured Recipe

    private var featuredRecipe: some View {
        Group {
            if let recipe = recipes.first {
                Button { selectedRecipe = recipe } label: {
                    ZStack(alignment: .bottom) {
                        // Real food photograph — matched to recipe title
                        FoodCardImage(
                            title: recipe.title,
                            imageSystemName: recipe.imageSystemName,
                            height: PSLayout.featuredHeight,
                            cornerRadius: PSLayout.featuredRadius
                        )

                        // Dark gradient scrim so white text is readable
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.20), .black.opacity(0.82)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: PSLayout.featuredRadius, style: .continuous))

                        // Content
                        VStack(alignment: .leading, spacing: PSSpacing.sm) {
                            HStack(spacing: PSSpacing.sm) {
                                Text(recipe.matchPercentageDisplay)
                                    .font(.system(size: PSLayout.scaledFont(11), weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, PSSpacing.md)
                                    .padding(.vertical, PSSpacing.xxs)
                                    .background(PSColors.primaryGreen)
                                    .clipShape(Capsule())

                                HStack(spacing: PSSpacing.xxs) {
                                    Image(systemName: "clock")
                                        .font(.system(size: PSLayout.scaledFont(13)))
                                    Text(recipe.prepTimeDisplay)
                                        .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                                }
                                .foregroundStyle(.white.opacity(0.85))

                                Spacer()

                                HStack(spacing: PSSpacing.xxs) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: PSLayout.scaledFont(13)))
                                        .foregroundStyle(.yellow)
                                    Text(recipe.ratingDisplay)
                                        .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }

                            Text(recipe.title)
                                .font(.system(size: PSLayout.scaledFont(22), weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .minimumScaleFactor(0.85)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: PSSpacing.sm) {
                                Text(recipe.difficulty.displayName)
                                    .font(.system(size: PSLayout.scaledFont(11)))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .padding(.horizontal, PSSpacing.sm)
                                    .padding(.vertical, PSSpacing.xxxs)
                                    .background(.white.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.xs))
                                Text("Healthy")
                                    .font(.system(size: PSLayout.scaledFont(11)))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .padding(.horizontal, PSSpacing.sm)
                                    .padding(.vertical, PSSpacing.xxxs)
                                    .background(.white.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.xs))
                            }
                        }
                        .padding(PSSpacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Heart button
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "heart")
                                    .font(.system(size: PSLayout.scaledFont(18)))
                                    .foregroundStyle(.white)
                                    .frame(width: PSLayout.iconButtonSize, height: PSLayout.iconButtonSize)
                                    .background(.white.opacity(0.15))
                                    .clipShape(Circle())
                            }
                            Spacer()
                        }
                        .padding(PSSpacing.lg)
                    }
                }
                .buttonStyle(PressableButtonStyle())
                .adaptiveHPadding()
                .shadow(color: PSColors.primaryGreen.opacity(0.2), radius: 20, y: 10)
            }
        }
    }

    // MARK: - Recipe List

    private var recipeList: some View {
        VStack(alignment: .leading, spacing: PSSpacing.lg) {
            Text(String(localized: "Recommended for You"))
                .font(.system(size: PSLayout.scaledFont(20), weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(PSColors.textPrimary)
                .adaptiveHPadding()

            LazyVStack(spacing: PSSpacing.md) {
                ForEach(Array(recipes.dropFirst().enumerated()), id: \.element.id) { index, recipe in
                    Button { selectedRecipe = recipe } label: {
                        recipeListCard(recipe: recipe)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .staggeredAppearance(index: index)
                }
            }
            .adaptiveHPadding()
        }
    }

    // MARK: - Filter Logic

    private func filterRecipes(_ recipes: [Recipe]) -> [Recipe] {
        switch activeFilter {
        case "Quick & Easy": return recipes.filter { $0.prepTimeMinutes <= 20 }
        case "Vegan": return recipes.filter { recipe in
            !recipe.ingredients.contains { i in
                let l = i.lowercased()
                return l.contains("meat") || l.contains("dairy") || l.contains("seafood") ||
                       l.contains("egg") || l.contains("milk") || l.contains("butter") ||
                       l.contains("cheese") || l.contains("honey") || l.contains("fish")
            }
        }
        case "Breakfast": return recipes.filter { recipe in
            let l = recipe.title.lowercased()
            return l.contains("breakfast") || l.contains("oat") || l.contains("egg") ||
                   l.contains("pancake") || l.contains("toast") || l.contains("hash") || l.contains("scrambl")
        }
        case "Desserts": return recipes.filter { recipe in
            let l = recipe.title.lowercased()
            return l.contains("dessert") || l.contains("cake") || l.contains("cookie") ||
                   l.contains("brownie") || l.contains("pie") || l.contains("pudding") ||
                   l.contains("mousse") || l.contains("tart") || l.contains("cheesecake")
        }
        default: return recipes
        }
    }

    // MARK: - Recipe List Card

    private func recipeListCard(recipe: Recipe) -> some View {
        let imageSize = PSLayout.recipeImageSize
        return HStack(spacing: PSSpacing.lg) {
            // Real food photograph — matched to recipe title.
            // Explicit outer frame + layoutPriority(0) ensures the image
            // can never push its width into the title column.
            ZStack(alignment: .topLeading) {
                FoodCardImage(
                    title: recipe.title,
                    imageSystemName: recipe.imageSystemName,
                    height: imageSize,
                    cornerRadius: PSSpacing.radiusLg
                )
                .frame(width: imageSize, height: imageSize)

                // Match percentage badge
                Text(recipe.matchPercentageDisplay)
                    .font(.system(size: PSLayout.scaledFont(10), weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(PSColors.primaryGreen)
                    .clipShape(Capsule())
                    .padding(PSSpacing.xs)
            }
            .frame(width: imageSize, height: imageSize)
            .layoutPriority(0)

            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                Text(recipe.title)
                    .font(.system(size: PSLayout.scaledFont(16), weight: .bold))
                    .foregroundStyle(PSColors.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Difficulty + time chips
                HStack(spacing: PSSpacing.xs) {
                    Label(recipe.prepTimeDisplay, systemImage: "clock")
                        .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)

                    Text("•")
                        .foregroundStyle(PSColors.textTertiary)

                    Text(recipe.difficulty.displayName)
                        .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                }

                Spacer()

                HStack {
                    HStack(spacing: PSSpacing.xxs) {
                        Image(systemName: "star.fill")
                            .font(.system(size: PSLayout.scaledFont(13)))
                            .foregroundStyle(.yellow)
                        Text(recipe.ratingDisplay)
                            .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                            .foregroundStyle(PSColors.textPrimary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                        .foregroundStyle(PSColors.textTertiary)
                }
            }
            .padding(.vertical, PSSpacing.xs)
            .layoutPriority(1)
        }
        .padding(PSSpacing.md)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                .strokeBorder(PSColors.borderLight, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
    }
}
