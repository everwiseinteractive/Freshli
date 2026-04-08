import SwiftUI

struct RecipeCard: View {
    let recipe: Recipe
    var onTap: (() -> Void)?

    var body: some View {
        Button { onTap?() } label: {
            VStack(alignment: .leading, spacing: PSSpacing.md) {
                HStack(spacing: PSSpacing.md) {
                    Image(systemName: recipe.imageSystemName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(PSColors.primaryGreen)
                        .frame(width: 52, height: 52)
                        .background(PSColors.primaryGreen.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))

                    VStack(alignment: .leading, spacing: PSSpacing.xxxs) {
                        Text(recipe.title)
                            .font(PSTypography.bodyMedium)
                            .foregroundStyle(PSColors.textPrimary)
                            .lineLimit(1)

                        Text(recipe.summary)
                            .font(PSTypography.caption1)
                            .foregroundStyle(PSColors.textSecondary)
                            .lineLimit(2)
                    }

                    Spacer()
                }

                HStack(spacing: PSSpacing.lg) {
                    matchBadge

                    Label(recipe.prepTimeDisplay, systemImage: "clock")
                        .font(PSTypography.caption1Medium)
                        .foregroundStyle(PSColors.textSecondary)

                    Label(recipe.difficulty.displayName, systemImage: recipe.difficulty.icon)
                        .font(PSTypography.caption1Medium)
                        .foregroundStyle(PSColors.textSecondary)

                    Spacer()
                }
            }
            .padding(PSSpacing.cardPadding)
            .cardStyle()
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(recipe.title), \(recipe.matchPercentageDisplay) match, \(recipe.prepTimeDisplay)")
    }

    private var matchBadge: some View {
        HStack(spacing: PSSpacing.xxxs) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 10))
            Text("\(recipe.matchingIngredientCount)/\(recipe.totalIngredientCount)")
                .font(PSTypography.caption2Medium)
        }
        .padding(.horizontal, PSSpacing.sm)
        .padding(.vertical, PSSpacing.xxxs)
        .foregroundStyle(matchColor)
        .background(matchColor.opacity(0.12))
        .clipShape(Capsule())
    }

    private var matchColor: Color {
        if recipe.matchPercentage >= 0.75 { return PSColors.freshGreen }
        if recipe.matchPercentage >= 0.5 { return PSColors.warningAmber }
        return PSColors.textSecondary
    }
}

struct RecipeCardCompact: View {
    let recipe: Recipe
    var onTap: (() -> Void)?

    var body: some View {
        Button { onTap?() } label: {
            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                Image(systemName: recipe.imageSystemName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(PSColors.primaryGreen)
                    .frame(width: 40, height: 40)
                    .background(PSColors.primaryGreen.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(recipe.title)
                    .font(PSTypography.calloutMedium)
                    .foregroundStyle(PSColors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: PSSpacing.xs) {
                    Text(recipe.prepTimeDisplay)
                        .font(PSTypography.caption2)
                        .foregroundStyle(PSColors.textSecondary)
                    Text("·")
                        .foregroundStyle(PSColors.textTertiary)
                    Text(recipe.matchPercentageDisplay)
                        .font(PSTypography.caption2Medium)
                        .foregroundStyle(PSColors.primaryGreen)
                }
            }
            .padding(PSSpacing.md)
            .frame(width: 155)
            .cardStyle()
        }
        .buttonStyle(PressableButtonStyle())
    }
}
