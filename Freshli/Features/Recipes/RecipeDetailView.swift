import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    @Environment(CelebrationManager.self) private var celebrationManager
    @State private var appeared = false
    @State private var completedSteps: Set<Int> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PSSpacing.xxl) {
                headerSection
                metadataSection
                ingredientsSection
                stepsSection
            }
            .padding(.vertical, PSSpacing.lg)
        }
        .background(PSColors.backgroundPrimary)
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(String(localized: "Close")) { dismiss() }
            }
        }
        .onAppear {
            withAnimation(PSMotion.springGentle.delay(0.1)) { appeared = true }
            triggerRecipeMatchIfNeeded()
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
            MetadataChip(icon: recipe.difficulty.icon, value: recipe.difficulty.displayName, label: String(localized: "Difficulty"))
        }
        .screenPadding()
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            PSSectionHeader(title: String(localized: "Ingredients"), subtitle: "\(recipe.ingredients.count) items")
                .screenPadding()

            VStack(spacing: PSSpacing.sm) {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                    HStack(spacing: PSSpacing.md) {
                        Image(systemName: index < recipe.matchingIngredientCount ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: PSLayout.scaledFont(18)))
                            .foregroundStyle(index < recipe.matchingIngredientCount ? PSColors.freshGreen : PSColors.textTertiary)

                        Text(ingredient)
                            .font(PSTypography.body)
                            .foregroundStyle(PSColors.textPrimary)

                        Spacer()

                        if index < recipe.matchingIngredientCount {
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

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            PSSectionHeader(title: String(localized: "Steps"), subtitle: "\(recipe.steps.count) steps")
                .screenPadding()

            VStack(spacing: PSSpacing.md) {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                    Button {
                        PSHaptics.shared.lightTap()
                        withAnimation(PSMotion.springBouncy) {
                            if completedSteps.contains(index) {
                                completedSteps.remove(index)
                            } else {
                                completedSteps.insert(index)
                                // Celebrate all steps completed
                                if completedSteps.count == recipe.steps.count {
                                    PSHaptics.shared.celebrate()
                                }
                            }
                        }
                    } label: {
                        HStack(alignment: .top, spacing: PSSpacing.md) {
                            ZStack {
                                Circle()
                                    .fill(completedSteps.contains(index) ? PSColors.primaryGreen : PSColors.primaryGreen.opacity(0.12))

                                if completedSteps.contains(index) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
                                        .foregroundStyle(PSColors.textOnPrimary)
                                        .scaleEffect(1.2)
                                } else {
                                    Text("\(index + 1)")
                                        .font(PSTypography.caption1Medium)
                                        .foregroundStyle(PSColors.primaryGreen)
                                }
                            }
                            .frame(width: PSLayout.scaled(28), height: PSLayout.scaled(28))

                            Text(step)
                                .font(PSTypography.body)
                                .foregroundStyle(completedSteps.contains(index) ? PSColors.textTertiary : PSColors.textPrimary)
                                .strikethrough(completedSteps.contains(index))
                                .multilineTextAlignment(.leading)

                            Spacer()
                        }
                        .padding(.vertical, PSSpacing.sm)
                        .padding(.horizontal, PSSpacing.md)
                        .background(completedSteps.contains(index) ? PSColors.primaryGreen.opacity(0.05) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .staggeredAppearance(index: index)
                }
            }
            .padding(PSSpacing.cardPadding)
            .cardStyle()
            .screenPadding()
        }
        .padding(.bottom, PSSpacing.xxxl)
    }

    // MARK: - Start Cooking trigger (fires recipe match celebration on first view)
    private func triggerRecipeMatchIfNeeded() {
        let key = "recipe_celebrated_\(recipe.id)"
        if !UserDefaults.standard.bool(forKey: key) {
            UserDefaults.standard.set(true, forKey: key)
            celebrationManager.onRecipeMatch(recipeName: recipe.title)
        }
    }
}

struct MetadataChip: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: PSSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
                .foregroundStyle(PSColors.primaryGreen)
            Text(value)
                .font(PSTypography.calloutMedium)
                .foregroundStyle(PSColors.textPrimary)
            Text(label)
                .font(PSTypography.caption2)
                .foregroundStyle(PSColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PSSpacing.md)
        .background(PSColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
    }
}
