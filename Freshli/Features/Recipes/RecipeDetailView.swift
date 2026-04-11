import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    @Environment(CelebrationManager.self) private var celebrationManager
    @State private var appeared = false
    @State private var completedSteps: Set<Int> = []
    @State private var startedCooking = false

    // Ingredients that match the pantry (derived from matchingIngredientCount)
    private var pantryIngredients: [String] {
        Array(recipe.ingredients.prefix(recipe.matchingIngredientCount))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroImageSection
                contentSection
            }
        }
        .background(PSColors.backgroundSecondary)
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(String(localized: "Close")) { dismiss() }
                    .foregroundStyle(PSColors.primaryGreen)
                    .fontWeight(.semibold)
            }
        }
        .fullScreenCover(isPresented: $startedCooking) {
            CookingScreenView(recipe: recipe, matchingPantryItems: pantryIngredients)
        }
        .onAppear {
            withAnimation(PSMotion.springGentle.delay(0.1)) { appeared = true }
            triggerRecipeMatchIfNeeded()
        }
    }

    // MARK: - Hero Image

    private var heroImageSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Rich category-coloured food image
            FoodCardImage(
                imageSystemName: recipe.imageSystemName,
                height: PSLayout.scaled(220),
                cornerRadius: 0
            )

            // Gradient scrim
            LinearGradient(
                colors: [.clear, .black.opacity(0.72)],
                startPoint: .center,
                endPoint: .bottom
            )

            // Overlaid metadata
            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                // Tags row
                HStack(spacing: PSSpacing.sm) {
                    tagPill(recipe.matchPercentageDisplay, color: PSColors.primaryGreen)
                    tagPill(recipe.prepTimeDisplay, icon: "clock")
                    tagPill(recipe.difficulty.displayName, icon: recipe.difficulty.icon)
                    Spacer()
                    // Star rating
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: PSLayout.scaledFont(12)))
                            .foregroundStyle(.yellow)
                        Text(recipe.ratingDisplay)
                            .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                Text(recipe.title)
                    .font(.system(size: PSLayout.scaledFont(26), weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
            .padding(.bottom, PSSpacing.xl)
        }
        .scaleEffect(appeared ? 1 : 0.97)
        .opacity(appeared ? 1 : 0)
    }

    private func tagPill(_ text: String, icon: String? = nil, color: Color = .white) -> some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: PSLayout.scaledFont(11), weight: .semibold))
            }
            Text(text)
                .font(.system(size: PSLayout.scaledFont(11), weight: .bold))
        }
        .foregroundStyle(icon == nil ? color == PSColors.primaryGreen ? .white : .white.opacity(0.9) : .white.opacity(0.85))
        .padding(.horizontal, PSSpacing.md)
        .padding(.vertical, PSSpacing.xxs)
        .background(icon == nil && color == PSColors.primaryGreen ? color : .white.opacity(0.18))
        .clipShape(Capsule())
    }

    // MARK: - Content

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.xxl) {
            // Summary
            Text(recipe.summary)
                .font(PSTypography.callout)
                .foregroundStyle(PSColors.textSecondary)
                .lineSpacing(3)
                .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
                .padding(.top, PSSpacing.xl)

            // Start Cooking button (hero CTA)
            Button {
                PSHaptics.shared.mediumTap()
                startedCooking = true
            } label: {
                HStack(spacing: PSSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: PSLayout.scaled(36), height: PSLayout.scaled(36))
                        Image(systemName: "flame.fill")
                            .font(.system(size: PSLayout.scaledFont(18)))
                            .foregroundStyle(.white)
                    }
                    Text(String(localized: "Start Cooking"))
                        .font(.system(size: PSLayout.scaledFont(18), weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, PSSpacing.xl)
                .padding(.vertical, PSSpacing.lg)
                .background(
                    LinearGradient(
                        colors: [PSColors.primaryGreen, PSColors.accentTeal.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
                .shadow(color: PSColors.primaryGreen.opacity(0.4), radius: 16, y: 8)
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)

            ingredientsSection
            stepsSection
        }
        .padding(.bottom, PSSpacing.xxxl)
    }

    // MARK: - Ingredients

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            // Section header
            HStack {
                Text(String(localized: "Ingredients"))
                    .font(.system(size: PSLayout.scaledFont(20), weight: .bold, design: .rounded))
                    .foregroundStyle(PSColors.textPrimary)
                Spacer()
                Text("\(recipe.ingredients.count) items")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                    .foregroundStyle(PSColors.textTertiary)
            }
            .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)

            // Pantry match summary banner
            if recipe.matchingIngredientCount > 0 {
                HStack(spacing: PSSpacing.md) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: PSLayout.scaledFont(20)))
                        .foregroundStyle(PSColors.primaryGreen)
                    Text(String(localized: "You have \(recipe.matchingIngredientCount) of \(recipe.totalIngredientCount) ingredients in your pantry"))
                        .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                        .lineLimit(2)
                }
                .padding(PSSpacing.lg)
                .background(PSColors.primaryGreen.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                        .strokeBorder(PSColors.primaryGreen.opacity(0.15), lineWidth: 1)
                )
                .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
            }

            VStack(spacing: 0) {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                    HStack(spacing: PSSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(index < recipe.matchingIngredientCount
                                      ? PSColors.primaryGreen
                                      : PSColors.backgroundSecondary)
                                .frame(width: PSLayout.scaled(28), height: PSLayout.scaled(28))
                            Image(systemName: index < recipe.matchingIngredientCount ? "checkmark" : "circle.dotted")
                                .font(.system(size: PSLayout.scaledFont(11), weight: .bold))
                                .foregroundStyle(index < recipe.matchingIngredientCount
                                                 ? .white
                                                 : PSColors.textTertiary)
                        }

                        Text(ingredient)
                            .font(PSTypography.body)
                            .foregroundStyle(PSColors.textPrimary)

                        Spacer()

                        if index < recipe.matchingIngredientCount {
                            Text(String(localized: "In Pantry"))
                                .font(.system(size: PSLayout.scaledFont(11), weight: .bold))
                                .foregroundStyle(PSColors.primaryGreen)
                                .padding(.horizontal, PSSpacing.sm)
                                .padding(.vertical, PSSpacing.xxxs)
                                .background(PSColors.primaryGreen.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, PSSpacing.md)
                    .padding(.horizontal, PSSpacing.lg)

                    if index < recipe.ingredients.count - 1 {
                        Divider()
                            .padding(.leading, PSLayout.scaled(28 + 12))
                    }
                }
            }
            .background(PSColors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                    .strokeBorder(PSColors.border, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
            .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
        }
    }

    // MARK: - Steps

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            HStack {
                Text(String(localized: "Instructions"))
                    .font(.system(size: PSLayout.scaledFont(20), weight: .bold, design: .rounded))
                    .foregroundStyle(PSColors.textPrimary)
                Spacer()
                Text("\(recipe.steps.count) steps")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                    .foregroundStyle(PSColors.textTertiary)
            }
            .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)

            VStack(spacing: PSSpacing.sm) {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                    Button {
                        PSHaptics.shared.lightTap()
                        withAnimation(PSMotion.springBouncy) {
                            if completedSteps.contains(index) {
                                completedSteps.remove(index)
                            } else {
                                completedSteps.insert(index)
                                if completedSteps.count == recipe.steps.count {
                                    PSHaptics.shared.celebrate()
                                }
                            }
                        }
                    } label: {
                        HStack(alignment: .top, spacing: PSSpacing.lg) {
                            ZStack {
                                Circle()
                                    .fill(completedSteps.contains(index)
                                          ? PSColors.primaryGreen
                                          : PSColors.primaryGreen.opacity(0.12))
                                    .frame(width: PSLayout.scaled(32), height: PSLayout.scaled(32))

                                if completedSteps.contains(index) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                                        .foregroundStyle(.white)
                                } else {
                                    Text("\(index + 1)")
                                        .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                                        .foregroundStyle(PSColors.primaryGreen)
                                }
                            }

                            Text(step)
                                .font(PSTypography.body)
                                .foregroundStyle(completedSteps.contains(index)
                                                 ? PSColors.textTertiary
                                                 : PSColors.textPrimary)
                                .strikethrough(completedSteps.contains(index), color: PSColors.textTertiary)
                                .multilineTextAlignment(.leading)
                                .lineSpacing(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(PSSpacing.lg)
                        .background(
                            completedSteps.contains(index)
                                ? PSColors.primaryGreen.opacity(0.05)
                                : PSColors.surfaceCard
                        )
                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                                .strokeBorder(
                                    completedSteps.contains(index)
                                        ? PSColors.primaryGreen.opacity(0.2)
                                        : PSColors.border,
                                    lineWidth: 0.5
                                )
                        )
                        .shadow(color: .black.opacity(0.03), radius: 8, y: 3)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .staggeredAppearance(index: index)
                }
            }
            .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)

            // All done state
            if completedSteps.count == recipe.steps.count {
                VStack(spacing: PSSpacing.md) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: PSLayout.scaledFont(48)))
                        .foregroundStyle(PSColors.primaryGreen)
                    Text(String(localized: "All Steps Complete! 🎉"))
                        .font(.system(size: PSLayout.scaledFont(20), weight: .bold, design: .rounded))
                        .foregroundStyle(PSColors.textPrimary)
                    Text(String(localized: "Great cooking! Open the cooking screen to mark ingredients as used."))
                        .font(PSTypography.callout)
                        .foregroundStyle(PSColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(PSSpacing.xxl)
                .background(PSColors.primaryGreen.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                        .strokeBorder(PSColors.primaryGreen.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Start Cooking trigger
    private func triggerRecipeMatchIfNeeded() {
        let key = "recipe_celebrated_\(recipe.id)"
        if !UserDefaults.standard.bool(forKey: key) {
            UserDefaults.standard.set(true, forKey: key)
            celebrationManager.onRecipeMatch(recipeName: recipe.title)
        }
    }
}

// MARK: - Metadata Chip (kept for backward compatibility)

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
