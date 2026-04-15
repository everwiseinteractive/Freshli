import SwiftUI
import SwiftData

// MARK: - Smart Shopping List View
// Predictive waste prevention + "Fill the Gap" recipe unlock suggestions.

struct SmartShoppingListView: View {
    @Query private var allItems: [FreshliItem]
    @Environment(\.modelContext) private var modelContext

    @State private var wastePredictions: [WastePrediction] = []
    @State private var gapSuggestions: [GapFillSuggestion] = []
    @State private var selectedCategory: RecommendTab = .waste
    @State private var showCopied = false
    @Namespace private var tabNamespace

    enum RecommendTab: String, CaseIterable {
        case waste = "Smarter Buys"
        case gap   = "Fill the Gap"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: PSSpacing.xxl) {
                heroHeader
                tabPicker
                if selectedCategory == .waste {
                    wastePredictionsSection
                } else {
                    gapFillSection
                }
                footerNote
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.vertical, PSSpacing.lg)
        }
        .background(PSColors.backgroundPrimary)
        .navigationTitle("Smart Shopping")
        .navigationBarTitleDisplayMode(.inline)
        .task { computeRecommendations() }
        .onChange(of: allItems.count) { _, _ in computeRecommendations() }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        VStack(spacing: PSSpacing.md) {
            Image(systemName: "cart.badge.questionmark")
                .font(.system(size: PSLayout.scaledFont(40)))
                .foregroundStyle(PSColors.primaryGreen)
            VStack(spacing: PSSpacing.xs) {
                Text("Buy Smarter, Waste Less")
                    .font(.system(size: PSLayout.scaledFont(20), weight: .black, design: .rounded))
                    .foregroundStyle(PSColors.textPrimary)
                Text("AI-powered suggestions based on your waste patterns and what you already have.")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(RecommendTab.allCases, id: \.self) { tab in
                Button {
                    PSHaptics.shared.lightTap()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedCategory = tab
                    }
                } label: {
                    VStack(spacing: PSSpacing.xxs) {
                        Text(tab.rawValue)
                            .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                            .foregroundStyle(selectedCategory == tab ? PSColors.primaryGreen : PSColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, PSSpacing.md)
                        Rectangle()
                            .fill(selectedCategory == tab ? PSColors.primaryGreen : Color.clear)
                            .frame(height: 2)
                            .matchedGeometryEffect(id: "underline", in: tabNamespace, isSource: selectedCategory == tab)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
    }

    // MARK: - Smarter Buys (Waste Predictions)

    @ViewBuilder
    private var wastePredictionsSection: some View {
        if wastePredictions.isEmpty {
            emptyState(
                icon: "checkmark.seal.fill",
                color: PSColors.primaryGreen,
                title: "No waste patterns detected",
                subtitle: "Keep using Freshli! Once we see patterns in your purchases we'll suggest smarter quantities."
            )
        } else {
            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                sectionHeader("Based on Your History", icon: "chart.bar.fill", color: PSColors.secondaryAmber)
                ForEach(wastePredictions) { prediction in
                    wastePredictionCard(prediction)
                }
            }
        }
    }

    private func wastePredictionCard(_ p: WastePrediction) -> some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            // Top row
            HStack(spacing: PSSpacing.md) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: PSLayout.scaledFont(24)))
                    .foregroundStyle(PSColors.secondaryAmber)
                    .frame(width: PSLayout.scaled(44), height: PSLayout.scaled(44))
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.itemName)
                        .font(.system(size: PSLayout.scaledFont(15), weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                    Text("Buy \(formatQty(p.suggestedQuantity, unit: p.suggestedUnit))")
                        .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                        .foregroundStyle(PSColors.primaryGreen)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("~$\(String(format: "%.0f", p.estimatedSavings))")
                        .font(.system(size: PSLayout.scaledFont(18), weight: .black, design: .rounded))
                        .foregroundStyle(PSColors.secondaryAmber)
                    Text("potential saving")
                        .font(.system(size: PSLayout.scaledFont(10), weight: .medium))
                        .foregroundStyle(PSColors.textTertiary)
                }
            }
            // Waste bar
            VStack(alignment: .leading, spacing: PSSpacing.xs) {
                HStack {
                    Text("Waste rate")
                        .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                    Spacer()
                    Text("\(Int(p.wasteRate * 100))% (\(p.wastedCount)/\(p.totalCount) items)")
                        .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
                        .foregroundStyle(PSColors.expiredRed)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(PSColors.borderLight).frame(height: PSLayout.scaled(6))
                        Capsule()
                            .fill(LinearGradient(colors: [PSColors.secondaryAmber, PSColors.expiredRed],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * p.wasteRate, height: PSLayout.scaled(6))
                    }
                }
                .frame(height: PSLayout.scaled(6))
            }
            // Reason chip
            Text(p.reason)
                .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                .foregroundStyle(PSColors.textSecondary)
                .lineSpacing(2)
        }
        .padding(PSSpacing.lg)
        .background(PSColors.secondaryAmber.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
            .strokeBorder(PSColors.secondaryAmber.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Fill the Gap

    @ViewBuilder
    private var gapFillSection: some View {
        if gapSuggestions.isEmpty {
            emptyState(
                icon: "puzzlepiece.fill",
                color: Color(hex: 0x8B5CF6),
                title: "Your pantry covers everything!",
                subtitle: "You already have the ingredients for every recipe we know. Add more items to discover gap suggestions."
            )
        } else {
            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                sectionHeader("One Purchase, Multiple Meals", icon: "puzzlepiece.fill", color: Color(hex: 0x8B5CF6))
                ForEach(gapSuggestions) { suggestion in
                    gapFillCard(suggestion)
                }
            }
        }
    }

    private func gapFillCard(_ s: GapFillSuggestion) -> some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            HStack(spacing: PSSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: 0x8B5CF6).opacity(0.12))
                        .frame(width: PSLayout.scaled(48), height: PSLayout.scaled(48))
                    Text(s.category.emoji)
                        .font(.system(size: PSLayout.scaledFont(24)))
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: PSSpacing.xs) {
                        Text("Buy")
                            .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                            .foregroundStyle(PSColors.textSecondary)
                        Text(s.itemToBuy)
                            .font(.system(size: PSLayout.scaledFont(16), weight: .black))
                            .foregroundStyle(Color(hex: 0x8B5CF6))
                    }
                    Text("Unlocks \(s.unlocksRecipes.count) recipes from your pantry")
                        .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                }
                Spacer()
                Text("+\(s.unlocksRecipes.count)")
                    .font(.system(size: PSLayout.scaledFont(22), weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: 0x8B5CF6))
            }
            // Recipe pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PSSpacing.xs) {
                    ForEach(s.unlocksRecipes.prefix(4)) { recipe in
                        HStack(spacing: PSSpacing.xxs) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: PSLayout.scaledFont(10)))
                            Text(recipe.title)
                                .font(.system(size: PSLayout.scaledFont(11), weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(Color(hex: 0x8B5CF6))
                        .padding(.horizontal, PSSpacing.sm)
                        .padding(.vertical, PSSpacing.xxs)
                        .background(Color(hex: 0x8B5CF6).opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 1)
            }
        }
        .padding(PSSpacing.lg)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
            .strokeBorder(Color(hex: 0x8B5CF6).opacity(0.15), lineWidth: 1))
    }

    // MARK: - Helpers

    private func emptyState(icon: String, color: Color, title: String, subtitle: String) -> some View {
        VStack(spacing: PSSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: PSLayout.scaledFont(40)))
                .foregroundStyle(color.opacity(0.6))
            Text(title)
                .font(.system(size: PSLayout.scaledFont(16), weight: .bold))
                .foregroundStyle(PSColors.textPrimary)
            Text(subtitle)
                .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                .foregroundStyle(PSColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding(PSSpacing.xxl)
        .frame(maxWidth: .infinity)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
    }

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: PSSpacing.sm) {
            Image(systemName: icon).font(.system(size: PSLayout.scaledFont(13))).foregroundStyle(color)
            Text(title)
                .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                .foregroundStyle(PSColors.textSecondary)
                .textCase(.uppercase).tracking(0.5)
        }
    }

    private var footerNote: some View {
        HStack(spacing: PSSpacing.sm) {
            Image(systemName: "sparkles").font(.system(size: PSLayout.scaledFont(14))).foregroundStyle(PSColors.textTertiary)
            Text("Recommendations improve as you track more items in your pantry.")
                .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                .foregroundStyle(PSColors.textTertiary)
                .lineSpacing(2)
        }
        .multilineTextAlignment(.leading)
        .padding(.horizontal, PSSpacing.xl)
    }

    private func formatQty(_ qty: Double, unit: String) -> String {
        qty == qty.rounded() ? "\(Int(qty)) \(unit)" : String(format: "%.1f \(unit)", qty)
    }

    private func computeRecommendations() {
        wastePredictions = SmartShoppingService.shared.predictWastefulItems(from: allItems)
        gapSuggestions = SmartShoppingService.shared.fillGapSuggestions(
            pantryItems: allItems.filter { $0.isActive },
            recipes: RecipeService.shared.recipes
        )
    }
}

#Preview {
    NavigationStack { SmartShoppingListView() }
}
