import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Scenario 3: Recipe Timer Live Activity
// Shows the current recipe step and countdown timer in the Dynamic Island.
// Active while the user is cooking a Freshli recipe.

struct FreshliRecipeTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FreshliRecipeTimerAttributes.self) { context in
            // Lock Screen / Banner
            recipeTimerLockScreen(context: context)
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: Expanded
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Text(context.attributes.recipeEmoji)
                                .font(.system(size: 22))
                            Text(context.attributes.recipeName)
                                .font(FreshliLA.rounded(14, weight: .bold))
                                .lineLimit(1)
                        }

                        // Step progress
                        HStack(spacing: 3) {
                            ForEach(1...context.state.totalSteps, id: \.self) { step in
                                Circle()
                                    .fill(stepDotColor(step: step, current: context.state.currentStep))
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        if context.state.status == "done" {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(FreshliLA.freshGreen)
                        } else {
                            // Live countdown using system timer
                            Text(timerInterval: Date.now...context.state.timerEnd, countsDown: true)
                                .font(FreshliLA.rounded(20, weight: .black))
                                .foregroundStyle(FreshliLA.warningAmber)
                                .monospacedDigit()
                                .frame(width: 70, alignment: .trailing)

                            Text("Step \(context.state.currentStep)/\(context.state.totalSteps)")
                                .font(FreshliLA.rounded(11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.status == "done" {
                        recipeDoneBanner()
                    } else {
                        VStack(spacing: 8) {
                            // Current step description
                            HStack(spacing: 8) {
                                Image(systemName: stepIcon(context.state.stepDescription))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(FreshliLA.warningAmber)
                                    .frame(width: 20)

                                Text(context.state.stepDescription)
                                    .font(FreshliLA.rounded(13, weight: .medium))
                                    .lineLimit(2)
                            }

                            // Timer progress bar
                            FreshliLAProgressBar(
                                progress: timerProgress(state: context.state),
                                color: FreshliLA.warningAmber
                            )
                        }
                        .padding(.top, 4)
                    }
                }
            } compactLeading: {
                // Compact: recipe emoji + step
                HStack(spacing: 4) {
                    Text(context.attributes.recipeEmoji)
                        .font(.system(size: 14))
                    Text("Step \(context.state.currentStep)")
                        .font(FreshliLA.rounded(13, weight: .bold))
                }
            } compactTrailing: {
                // Compact: countdown timer
                if context.state.status == "done" {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(FreshliLA.freshGreen)
                } else {
                    Text(timerInterval: Date.now...context.state.timerEnd, countsDown: true)
                        .font(FreshliLA.rounded(13, weight: .black))
                        .foregroundStyle(FreshliLA.warningAmber)
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }
            } minimal: {
                // Minimal: timer countdown
                if context.state.status == "done" {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(FreshliLA.freshGreen)
                } else {
                    Text(timerInterval: Date.now...context.state.timerEnd, countsDown: true)
                        .font(FreshliLA.rounded(11, weight: .bold))
                        .foregroundStyle(FreshliLA.warningAmber)
                        .monospacedDigit()
                }
            }
            .widgetURL(URL(string: "freshli://recipe-timer"))
            .keylineTint(FreshliLA.warningAmber)
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func recipeTimerLockScreen(context: ActivityViewContext<FreshliRecipeTimerAttributes>) -> some View {
        VStack(spacing: 12) {
            // Header: recipe name + timer
            HStack {
                HStack(spacing: 8) {
                    Text(context.attributes.recipeEmoji)
                        .font(.system(size: 30))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.recipeName)
                            .font(FreshliLA.rounded(17, weight: .bold))
                        Text("Step \(context.state.currentStep) of \(context.state.totalSteps)")
                            .font(FreshliLA.rounded(13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if context.state.status == "done" {
                    VStack(spacing: 2) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(FreshliLA.freshGreen)
                        Text("Done!")
                            .font(FreshliLA.rounded(12, weight: .bold))
                            .foregroundStyle(FreshliLA.freshGreen)
                    }
                } else {
                    // Live countdown
                    Text(timerInterval: Date.now...context.state.timerEnd, countsDown: true)
                        .font(FreshliLA.rounded(28, weight: .black))
                        .foregroundStyle(FreshliLA.warningAmber)
                        .monospacedDigit()
                }
            }

            if context.state.status != "done" {
                // Step description + progress
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: stepIcon(context.state.stepDescription))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(FreshliLA.warningAmber)
                            .frame(width: 22)

                        Text(context.state.stepDescription)
                            .font(FreshliLA.rounded(14, weight: .medium))
                            .lineLimit(2)

                        Spacer()
                    }

                    // Step progress dots
                    HStack(spacing: 4) {
                        ForEach(1...context.state.totalSteps, id: \.self) { step in
                            Capsule()
                                .fill(stepBarColor(step: step, current: context.state.currentStep))
                                .frame(height: 4)
                        }
                    }
                }
            }
        }
        .padding(16)
        .containerBackground(for: .widget) {
            ZStack {
                Color.black.opacity(0.5)
                LinearGradient(
                    colors: [
                        FreshliLA.warningAmber.opacity(0.1),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RoundedRectangle(cornerRadius: 20)
                    .stroke(FreshliLA.glassBorder, lineWidth: 0.5)
            }
        }
    }

    // MARK: - Done Banner

    private func recipeDoneBanner() -> some View {
        HStack(spacing: 6) {
            Image(systemName: "party.popper.fill")
                .foregroundStyle(FreshliLA.warningAmber)
            Text("Recipe complete! Time to enjoy your meal.")
                .font(FreshliLA.rounded(13, weight: .medium))
        }
    }

    // MARK: - Helpers

    private func stepDotColor(step: Int, current: Int) -> Color {
        if step < current {
            return FreshliLA.freshGreen
        } else if step == current {
            return FreshliLA.warningAmber
        } else {
            return Color.white.opacity(0.2)
        }
    }

    private func stepBarColor(step: Int, current: Int) -> Color {
        if step < current {
            return FreshliLA.freshGreen
        } else if step == current {
            return FreshliLA.warningAmber
        } else {
            return Color.white.opacity(0.15)
        }
    }

    private func timerProgress(state: FreshliRecipeTimerAttributes.ContentState) -> Double {
        guard state.stepDurationSeconds > 0 else { return 0 }
        let remaining = state.timerEnd.timeIntervalSinceNow
        let total = TimeInterval(state.stepDurationSeconds)
        return max(0, min(1, remaining / total))
    }

    private func stepIcon(_ description: String) -> String {
        let lowered = description.lowercased()
        if lowered.contains("boil") || lowered.contains("simmer") { return "flame.fill" }
        if lowered.contains("chop") || lowered.contains("dice") || lowered.contains("cut") { return "scissors" }
        if lowered.contains("mix") || lowered.contains("stir") || lowered.contains("whisk") { return "arrow.triangle.2.circlepath" }
        if lowered.contains("bake") || lowered.contains("oven") { return "oven.fill" }
        if lowered.contains("rest") || lowered.contains("cool") || lowered.contains("wait") { return "clock.fill" }
        if lowered.contains("fry") || lowered.contains("sauté") || lowered.contains("sear") { return "frying.pan.fill" }
        if lowered.contains("serve") || lowered.contains("plate") { return "fork.knife" }
        return "flame.fill"
    }
}

// MARK: - Previews

extension FreshliRecipeTimerAttributes {
    fileprivate static var preview: FreshliRecipeTimerAttributes {
        FreshliRecipeTimerAttributes(recipeName: "Veggie Stir Fry", recipeEmoji: "🥘")
    }
}

extension FreshliRecipeTimerAttributes.ContentState {
    fileprivate static var cooking: FreshliRecipeTimerAttributes.ContentState {
        .init(
            currentStep: 2,
            totalSteps: 5,
            stepDescription: "Sauté vegetables for 4 minutes",
            timerEnd: Date().addingTimeInterval(240),
            stepDurationSeconds: 240,
            status: "cooking"
        )
    }

    fileprivate static var lastStep: FreshliRecipeTimerAttributes.ContentState {
        .init(
            currentStep: 5,
            totalSteps: 5,
            stepDescription: "Let it rest for 2 minutes before serving",
            timerEnd: Date().addingTimeInterval(120),
            stepDurationSeconds: 120,
            status: "cooking"
        )
    }

    fileprivate static var done: FreshliRecipeTimerAttributes.ContentState {
        .init(
            currentStep: 5,
            totalSteps: 5,
            stepDescription: "Done!",
            timerEnd: .now,
            stepDurationSeconds: 0,
            status: "done"
        )
    }
}

#Preview("Recipe Timer - Lock Screen", as: .content, using: FreshliRecipeTimerAttributes.preview) {
    FreshliRecipeTimerLiveActivity()
} contentStates: {
    FreshliRecipeTimerAttributes.ContentState.cooking
    FreshliRecipeTimerAttributes.ContentState.lastStep
    FreshliRecipeTimerAttributes.ContentState.done
}
