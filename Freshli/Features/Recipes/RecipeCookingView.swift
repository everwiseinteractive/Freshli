import SwiftUI
import SwiftData
import Combine
import Supabase

// MARK: - Recipe Cooking View
// Step-by-step cooking flow. Marking "Done Cooking" triggers background impact updates via FreshliImpactActor.

struct RecipeCookingView: View {
    let recipe: FreshliRecipeSnapshot
    let engine: RecipeRescueEngine

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CelebrationManager.self) private var celebrationManager

    @Query(filter: #Predicate<FreshliItem> { !$0.isConsumed && !$0.isShared && !$0.isDonated },
           sort: [SortDescriptor(\FreshliItem.expiryDate)])
    private var pantryItems: [FreshliItem]

    @State private var appeared = false
    @State private var showCompletionSheet = false
    @State private var showHarvestCelebration = false
    @State private var markedItemCount = 0
    @State private var celebrateStepTrigger = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            cookingHeader
            ScrollView {
                VStack(alignment: .leading, spacing: PSSpacing.xxl) {
                    progressSection
                    stepsSection
                    if engine.allStepsCompleted {
                        completionSection
                            .transition(.flCelebrationPop)
                            .celebrationPop(trigger: $celebrateStepTrigger)
                    }
                }
                .padding(.vertical, PSSpacing.lg)
            }
        }
        .background(PSColors.backgroundPrimary)
        .navigationTitle(String(localized: "Cooking"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(String(localized: "Back")) {
                    engine.stopCooking()
                    dismiss()
                }
            }
        }
        .onAppear {
            let anim: Animation = reduceMotion ? .easeOut(duration: 0.2) : PSMotion.springGentle.delay(0.1)
            withAnimation(anim) { appeared = true }
            engine.startCooking(recipe: recipe)
        }
        .harvestCelebration(isActive: $showHarvestCelebration, intensity: .celebration)
        .sheet(isPresented: $showCompletionSheet) {
            RecipeDoneSheet(
                recipe: recipe,
                itemsUsed: markedItemCount,
                onDismiss: {
                    showCompletionSheet = false
                    engine.popToRoot()
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Cooking Header

    private var cookingHeader: some View {
        VStack(spacing: PSSpacing.md) {
            HStack(spacing: PSSpacing.md) {
                Image(systemName: recipe.imageSystemName)
                    .font(.system(size: PSLayout.scaledFont(24)))
                    .foregroundStyle(PSColors.primaryGreen)
                    .frame(width: PSLayout.scaled(44), height: PSLayout.scaled(44))
                    .background(PSColors.primaryGreen.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))

                VStack(alignment: .leading, spacing: PSSpacing.xxxs) {
                    Text(recipe.title)
                        .font(PSTypography.headline)
                        .foregroundStyle(PSColors.textPrimary)
                        .lineLimit(1)

                    Text(String(localized: "\(engine.completedSteps.count) of \(recipe.steps.count) steps"))
                        .font(PSTypography.caption1)
                        .foregroundStyle(PSColors.textSecondary)
                }

                Spacer()

                if let elapsed = engine.cookingStartTime {
                    CookingTimer(startTime: elapsed)
                }
            }
        }
        .adaptiveHPadding()
        .padding(.vertical, PSSpacing.md)
        .background(PSColors.surfaceCard)
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(spacing: PSSpacing.sm) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous)
                        .fill(PSColors.primaryGreen.opacity(0.12))
                        .frame(height: PSLayout.scaled(8))

                    RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous)
                        .fill(PSColors.primaryGreen)
                        .frame(width: geo.size.width * engine.cookingProgress, height: PSLayout.scaled(8))
                        .flAnimation(PSMotion.springBouncy, value: engine.cookingProgress)
                }
            }
            .frame(height: PSLayout.scaled(8))

            if let nextStep = engine.nextStepText, !engine.allStepsCompleted {
                HStack(spacing: PSSpacing.xs) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: PSLayout.scaledFont(14)))
                        .foregroundStyle(PSColors.primaryGreen)
                    Text(String(localized: "Next: \(nextStep)"))
                        .font(PSTypography.caption1Medium)
                        .foregroundStyle(PSColors.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .screenPadding()
    }

    // MARK: - Steps

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            PSSectionHeader(title: String(localized: "Steps"), subtitle: "\(recipe.steps.count) steps")
                .screenPadding()

            VStack(spacing: PSSpacing.md) {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                    Button {
                        PSHaptics.shared.lightTap()
                        withAnimation(FLMotion.adaptive(PSMotion.springBouncy, reduceMotion: reduceMotion)) {
                            engine.toggleStep(index)
                        }
                        if engine.allStepsCompleted {
                            celebrateStepTrigger = true
                        }
                    } label: {
                        stepRow(index: index, step: step)
                    }
                    .buttonStyle(.plain)
                    .staggeredAppearance(index: index)
                }
            }
            .padding(PSSpacing.cardPadding)
            .cardStyle()
            .screenPadding()
        }
    }

    private func stepRow(index: Int, step: String) -> some View {
        let isCompleted = engine.completedSteps.contains(index)
        let isCurrent = index == engine.currentStepIndex && !engine.allStepsCompleted

        return HStack(alignment: .top, spacing: PSSpacing.md) {
            ZStack {
                Circle()
                    .fill(isCompleted ? PSColors.primaryGreen : isCurrent ? PSColors.primaryGreen.opacity(0.2) : PSColors.primaryGreen.opacity(0.08))

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
                        .foregroundStyle(PSColors.textOnPrimary)
                        .scaleEffect(1.2)
                } else {
                    Text("\(index + 1)")
                        .font(PSTypography.caption1Medium)
                        .foregroundStyle(isCurrent ? PSColors.primaryGreen : PSColors.textTertiary)
                }
            }
            .frame(width: PSLayout.scaled(28), height: PSLayout.scaled(28))

            VStack(alignment: .leading, spacing: PSSpacing.xxxs) {
                Text(step)
                    .font(PSTypography.body)
                    .foregroundStyle(isCompleted ? PSColors.textTertiary : PSColors.textPrimary)
                    .strikethrough(isCompleted)
                    .multilineTextAlignment(.leading)

                if isCurrent {
                    Text(String(localized: "Tap to complete"))
                        .font(PSTypography.caption2)
                        .foregroundStyle(PSColors.primaryGreen)
                }
            }

            Spacer()

            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: PSLayout.scaledFont(18)))
                    .foregroundStyle(PSColors.freshGreen)
            }
        }
        .padding(.vertical, PSSpacing.sm)
        .padding(.horizontal, PSSpacing.md)
        .background(
            isCompleted ? PSColors.primaryGreen.opacity(0.05) :
            isCurrent ? PSColors.primaryGreen.opacity(0.03) : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
        .overlay(
            isCurrent ?
            RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous)
                .strokeBorder(PSColors.primaryGreen.opacity(0.2), lineWidth: 1) : nil
        )
    }

    // MARK: - Completion Section

    private var completionSection: some View {
        VStack(spacing: PSSpacing.lg) {
            VStack(spacing: PSSpacing.sm) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: PSLayout.scaledFont(48)))
                    .foregroundStyle(PSColors.primaryGreen)

                Text(String(localized: "All Steps Complete!"))
                    .font(PSTypography.title2)
                    .foregroundStyle(PSColors.textPrimary)

                Text(String(localized: "Mark ingredients as used to track your food rescue impact."))
                    .font(PSTypography.callout)
                    .foregroundStyle(PSColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            PSButton(
                title: String(localized: "Done Cooking — Mark Used"),
                icon: "leaf.fill",
                style: .primary,
                size: .large
            ) {
                markUsedAndCelebrate()
            }

            PSButton(
                title: String(localized: "Skip Marking"),
                style: .tertiary,
                size: .small
            ) {
                engine.popToRoot()
            }
        }
        .screenPadding()
        .padding(.bottom, PSSpacing.xxxl)
    }

    // MARK: - Mark Used Action

    private func markUsedAndCelebrate() {
        PSHaptics.shared.mediumTap()

        // Get current user ID from Supabase auth
        let userId = AppSupabase.client.auth.currentSession?.user.id

        let marked = engine.markIngredientsUsed(
            recipe: recipe,
            pantryItems: pantryItems,
            modelContext: modelContext,
            userId: userId
        )

        markedItemCount = marked.count

        if marked.count > 0 {
            showHarvestCelebration = true
            RescueStreakService.shared.recordActivity()
            celebrationManager.fireFoodSaved(modelContext: modelContext)

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1500))
                showCompletionSheet = true
            }
        } else {
            showCompletionSheet = true
        }
    }
}

// MARK: - Cooking Timer

struct CookingTimer: View {
    let startTime: Date
    @State private var elapsed: TimeInterval = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: PSSpacing.xxs) {
            Image(systemName: "timer")
                .font(.system(size: PSLayout.scaledFont(12)))
            Text(formattedElapsed)
                .font(.system(size: PSLayout.scaledFont(14), weight: .medium).monospacedDigit())
        }
        .foregroundStyle(PSColors.primaryGreen)
        .padding(.horizontal, PSSpacing.md)
        .padding(.vertical, PSSpacing.xs)
        .background(PSColors.primaryGreen.opacity(0.08))
        .clipShape(Capsule())
        .onReceive(timer) { _ in
            elapsed = Date().timeIntervalSince(startTime)
        }
    }

    private var formattedElapsed: String {
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Recipe Done Sheet

struct RecipeDoneSheet: View {
    let recipe: FreshliRecipeSnapshot
    let itemsUsed: Int
    let onDismiss: () -> Void

    private var co2Saved: String {
        String(format: "%.1f", Double(itemsUsed) * 0.8)
    }

    private var moneySaved: String {
        String(format: "$%.2f", Double(itemsUsed) * 3.50)
    }

    var body: some View {
        VStack(spacing: PSSpacing.xxl) {
            VStack(spacing: PSSpacing.md) {
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: PSLayout.scaledFont(56)))
                    .foregroundStyle(PSColors.primaryGreen)

                Text(String(localized: "Food Rescued!"))
                    .font(PSTypography.title1)
                    .foregroundStyle(PSColors.textPrimary)

                Text(String(localized: "You used \(itemsUsed) pantry items in \(recipe.title)"))
                    .font(PSTypography.callout)
                    .foregroundStyle(PSColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if itemsUsed > 0 {
                HStack(spacing: PSSpacing.lg) {
                    ImpactStatBubble(
                        icon: "cloud.fill",
                        value: "\(co2Saved) kg",
                        label: String(localized: "CO₂ Avoided")
                    )
                    ImpactStatBubble(
                        icon: "dollarsign.circle.fill",
                        value: moneySaved,
                        label: String(localized: "Money Saved")
                    )
                }
            }

            PSButton(
                title: String(localized: "Back to Recipes"),
                icon: "book.fill",
                style: .primary,
                size: .large
            ) {
                onDismiss()
            }
        }
        .padding(PSSpacing.xxl)
    }
}

struct ImpactStatBubble: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: PSSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: PSLayout.scaledFont(24)))
                .foregroundStyle(PSColors.primaryGreen)

            Text(value)
                .font(PSTypography.headline)
                .foregroundStyle(PSColors.textPrimary)

            Text(label)
                .font(PSTypography.caption2)
                .foregroundStyle(PSColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PSSpacing.lg)
        .background(PSColors.primaryGreen.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
    }
}
