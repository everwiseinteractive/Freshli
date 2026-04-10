import SwiftUI
import SwiftData

struct RecipesView: View {
    @Query(filter: #Predicate<FreshliItem> { !$0.isConsumed && !$0.isShared && !$0.isDonated })
    private var activeItems: [FreshliItem]
    
    @State private var searchText = ""
    @State private var selectedRecipe: RecipeService.Recipe?
    
    private var matchedRecipes: [RecipeService.Recipe] {
        RecipeService.shared.recipesForFreshli(items: activeItems)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: PSSpacing.xl) {
                // Header
                VStack(alignment: .leading, spacing: PSSpacing.sm) {
                    Text("Recipes")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                    
                    Text("\(matchedRecipes.count) recipes match your pantry")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
                .padding(.top, PSSpacing.xl)
                
                // Recipe Cards
                if matchedRecipes.isEmpty {
                    PSEmptyState(
                        icon: "book.closed",
                        title: "No Recipes Yet",
                        message: "Add items to your pantry to discover delicious recipes!",
                        actionTitle: nil,
                        action: nil
                    )
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: PSSpacing.lg) {
                        ForEach(matchedRecipes) { recipe in
                            RecipeCard(recipe: recipe)
                                .onTapGesture {
                                    selectedRecipe = recipe
                                }
                        }
                    }
                    .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
                }
            }
            .padding(.bottom, PSLayout.tabBarContentPadding)
        }
        .background(PSColors.backgroundSecondary)
        .navigationTitle("Recipes")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedRecipe) { recipe in
            RecipeDetailView(recipe: recipe)
        }
    }
}

// MARK: - Recipe Card

private struct RecipeCard: View {
    let recipe: RecipeService.Recipe
    
    var body: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            // Recipe Image Placeholder
            RoundedRectangle(cornerRadius: PSSpacing.radiusLg)
                .fill(PSColors.primaryGreen.opacity(0.1))
                .frame(height: 160)
                .overlay(
                    Image(systemName: "fork.knife")
                        .font(.system(size: 48))
                        .foregroundStyle(PSColors.primaryGreen.opacity(0.3))
                )
            
            VStack(alignment: .leading, spacing: PSSpacing.xs) {
                HStack {
                    Text(recipe.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                    
                    Spacer()
                    
                    Text(recipe.matchBadgeText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, PSSpacing.sm)
                        .padding(.vertical, PSSpacing.xxs)
                        .background(PSColors.primaryGreen)
                        .clipShape(Capsule())
                }
                
                Text(recipe.description)
                    .font(.system(size: 14))
                    .foregroundStyle(PSColors.textSecondary)
                    .lineLimit(2)
                
                HStack(spacing: PSSpacing.lg) {
                    Label(recipe.cookTime, systemImage: "clock")
                    Label("\(recipe.servings) servings", systemImage: "person.2")
                    Label(recipe.difficulty, systemImage: "chart.bar")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PSColors.textTertiary)
            }
            .padding(.horizontal, PSSpacing.md)
            .padding(.bottom, PSSpacing.md)
        }
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

// MARK: - Recipe Detail View

private struct RecipeDetailView: View {
    let recipe: RecipeService.Recipe
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PSSpacing.xl) {
                    // Image
                    RoundedRectangle(cornerRadius: PSSpacing.radiusLg)
                        .fill(PSColors.primaryGreen.opacity(0.1))
                        .frame(height: 200)
                        .overlay(
                            Image(systemName: "fork.knife")
                                .font(.system(size: 64))
                                .foregroundStyle(PSColors.primaryGreen.opacity(0.3))
                        )
                    
                    VStack(alignment: .leading, spacing: PSSpacing.md) {
                        Text("Ingredients")
                            .font(.system(size: 20, weight: .bold))
                        
                        ForEach(recipe.ingredients, id: \.self) { ingredient in
                            HStack {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundStyle(PSColors.primaryGreen)
                                Text(ingredient)
                                    .font(.system(size: 16))
                                Spacer()
                                
                                if recipe.matchedIngredients.contains(ingredient) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(PSColors.freshGreen)
                                }
                            }
                        }
                        
                        Text("Instructions")
                            .font(.system(size: 20, weight: .bold))
                            .padding(.top, PSSpacing.lg)
                        
                        ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, instruction in
                            HStack(alignment: .top, spacing: PSSpacing.sm) {
                                Text("\(index + 1).")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(PSColors.primaryGreen)
                                Text(instruction)
                                    .font(.system(size: 16))
                            }
                        }
                    }
                    .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
                }
                .padding(.bottom, PSSpacing.hero)
            }
            .navigationTitle(recipe.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        RecipesView()
            .modelContainer(for: FreshliItem.self, inMemory: true)
    }
}
