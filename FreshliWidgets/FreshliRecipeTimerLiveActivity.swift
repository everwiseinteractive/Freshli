import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Freshli Recipe Timer Live Activity
// Apple Design Award-level cooking Live Activity.
// Displays the current step, live countdown, and step progress in
// the Dynamic Island and on the Lock Screen.

struct FreshliRecipeTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FreshliRecipeTimerAttributes.self) { context in
            // Lock Screen / StandBy / Notification Banner
            RecipeTimerLockScreenView(context: context)
                .activitySystemActionForegroundColor(.white)
                .activityBackgroundTint(Color(red: 0.04, green: 0.12, blue: 0.07))

        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: - Expanded Island
                DynamicIslandExpandedRegion(.leading) {
                    expandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    expandedTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottom(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    // Empty — content in leading/trailing/bottom
                }
            } compactLeading: {
                compactLeadingView(context: context)
            } compactTrailing: {
                compactTrailingView(context: context)
            } minimal: {
                minimalView(context: context)
            }
            .widgetURL(URL(string: "freshli://cooking"))
            .keylineTint(FreshliLA.freshGreen)
        }
    }

    // MARK: - Expanded Leading

    @ViewBuilder
    private func expandedLeading(context: ActivityViewContext<FreshliRecipeTimerAttributes>) -> some View {
        HStack(spacing: 6) {
            // Recipe emoji in a green circle
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [FreshliLA.freshGreen, FreshliLA.accentTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                Text(context.attributes.recipeEmoji)
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(context.attributes.recipeName)
                    .font(FreshliLA.rounded(13, weight: .bold))
                    .lineLimit(1)
                    .foregroundStyle(.white)

                // Step dot indicators
                HStack(spacing: 3) {
                    ForEach(1...context.state.totalSteps, id: \.self) { step in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(stepPillColor(step: step, current: context.state.currentStep, status: context.state.status))
                            .frame(width: step == context.state.currentStep ? 14 : 6, height: 4)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: context.state.currentStep)
                    }
                }
            }
        }
        .padding(.leading, 4)
    }

    // MARK: - Expanded Trailing

    @ViewBuilder
    private func expandedTrailing(context: ActivityViewContext<FreshliRecipeTimerAttributes>) -> some View {
        if context.state.status == "done" {
            VStack(spacing: 2) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(FreshliLA.freshGreen)
                Text("Done!")
                    .font(FreshliLA.rounded(10, weight: .bold))
                    .foregroundStyle(FreshliLA.freshGreen)
            }
        } else {
            // Circular progress ring + countdown
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 3.5)
                    .frame(width: 44, height: 44)

                // Progress ring (amber → red as time runs out)
                Circle()
                    .trim(from: 0, to: timerProgressFraction(state: context.state))
                    .stroke(
                        timerRingColor(state: context.state),
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                    )
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))

                // Countdown text
                Text(timerInterval: Date.now...context.state.timerEnd, countsDown: true)
                    .font(FreshliLA.rounded(11, weight: .black))
                    .foregroundStyle(timerRingColor(state: context.state))
                    .monospacedDigit()
                    .frame(width: 36)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
            }
        }
    }

    // MARK: - Expanded Bottom

    @ViewBuilder
    private func expandedBottom(context: ActivityViewContext<FreshliRecipeTimerAttributes>) -> some View {
        if context.state.status == "done" {
            HStack(spacing: 8) {
                Image(systemName: "party.popper.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(FreshliLA.warningAmber)
                Text("Enjoy your meal! Tap to mark ingredients used.")
                    .font(FreshliLA.rounded(12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
            .padding(.horizontal, 4)
            .padding(.top, 6)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                // Current step instruction
                HStack(spacing: 6) {
                    Image(systemName: stepIcon(context.state.stepDescription))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(timerRingColor(state: context.state))
                        .frame(width: 20)

                    Text(context.state.stepDescription)
                        .font(FreshliLA.rounded(12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Animated progress bar
                FreshliLAProgressBar(
                    progress: timerProgressFraction(state: context.state),
                    color: timerRingColor(state: context.state)
                )
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
        }
    }

    // MARK: - Compact Leading

    @ViewBuilder
    private func compactLeadingView(context: ActivityViewContext<FreshliRecipeTimerAttributes>) -> some View {
        HStack(spacing: 4) {
            Text(context.attributes.recipeEmoji)
                .font(.system(size: 14))
            if context.state.status != "done" {
                Text("Step \(context.state.currentStep)/\(context.state.totalSteps)")
                    .font(FreshliLA.rounded(12, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Compact Trailing

    @ViewBuilder
    private func compactTrailingView(context: ActivityViewContext<FreshliRecipeTimerAttributes>) -> some View {
        if context.state.status == "done" {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(FreshliLA.freshGreen)
        } else {
            Text(timerInterval: Date.now...context.state.timerEnd, countsDown: true)
                .font(FreshliLA.rounded(13, weight: .black))
                .foregroundStyle(timerRingColor(state: context.state))
                .monospacedDigit()
                .frame(width: 46, alignment: .trailing)
        }
    }

    // MARK: - Minimal

    @ViewBuilder
    private func minimalView(context: ActivityViewContext<FreshliRecipeTimerAttributes>) -> some View {
        if context.state.status == "done" {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(FreshliLA.freshGreen)
        } else {
            Text(timerInterval: Date.now...context.state.timerEnd, countsDown: true)
                .font(FreshliLA.rounded(10, weight: .bold))
                .foregroundStyle(timerRingColor(state: context.state))
                .monospacedDigit()
        }
    }

    // MARK: - Color Helpers

    private func stepPillColor(step: Int, current: Int, status: String) -> Color {
        if status == "done" || step < current { return FreshliLA.freshGreen }
        if step == current { return Color.white }
        return Color.white.opacity(0.18)
    }

    private func timerProgressFraction(state: FreshliRecipeTimerAttributes.ContentState) -> Double {
        guard state.stepDurationSeconds > 0 else { return 0 }
        let remaining = max(0, state.timerEnd.timeIntervalSinceNow)
        let total = TimeInterval(state.stepDurationSeconds)
        return max(0, min(1, remaining / total))
    }

    private func timerRingColor(state: FreshliRecipeTimerAttributes.ContentState) -> Color {
        let fraction = timerProgressFraction(state: state)
        if fraction > 0.5 { return FreshliLA.freshGreen }
        if fraction > 0.25 { return FreshliLA.warningAmber }
        return FreshliLA.expiredRed
    }

    private func stepIcon(_ description: String) -> String {
        let l = description.lowercased()
        if l.contains("boil") || l.contains("simmer") { return "flame.fill" }
        if l.contains("chop") || l.contains("dice") || l.contains("cut") || l.contains("slice") { return "scissors" }
        if l.contains("mix") || l.contains("stir") || l.contains("whisk") { return "arrow.triangle.2.circlepath" }
        if l.contains("bake") || l.contains("oven") { return "oven.fill" }
        if l.contains("rest") || l.contains("cool") || l.contains("wait") { return "clock.fill" }
        if l.contains("fry") || l.contains("sauté") || l.contains("sear") { return "frying.pan.fill" }
        if l.contains("serve") || l.contains("plate") || l.contains("dish") { return "fork.knife" }
        if l.contains("season") || l.contains("salt") || l.contains("pepper") { return "sparkles" }
        return "flame.fill"
    }
}

// MARK: - Lock Screen View (extracted for clarity)

private struct RecipeTimerLockScreenView: View {
    let context: ActivityViewContext<FreshliRecipeTimerAttributes>

    private var timerProgress: Double {
        guard context.state.stepDurationSeconds > 0 else { return 0 }
        let remaining = max(0, context.state.timerEnd.timeIntervalSinceNow)
        return max(0, min(1, remaining / TimeInterval(context.state.stepDurationSeconds)))
    }

    private var ringColor: Color {
        if timerProgress > 0.50 { return FreshliLA.freshGreen }
        if timerProgress > 0.25 { return FreshliLA.warningAmber }
        return FreshliLA.expiredRed
    }

    private var isDone: Bool { context.state.status == "done" }

    var body: some View {
        VStack(spacing: 14) {
            // Top row: recipe identity + timer ring
            HStack(alignment: .center, spacing: 14) {
                // Left: emoji + name + step counter
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [FreshliLA.freshGreen.opacity(0.8), FreshliLA.accentTeal.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 42, height: 42)
                        Text(context.attributes.recipeEmoji)
                            .font(.system(size: 22))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.recipeName)
                            .font(FreshliLA.rounded(16, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        if isDone {
                            Label("All steps complete", systemImage: "checkmark.circle.fill")
                                .font(FreshliLA.rounded(12, weight: .medium))
                                .foregroundStyle(FreshliLA.freshGreen)
                        } else {
                            Text("Step \(context.state.currentStep) of \(context.state.totalSteps)")
                                .font(FreshliLA.rounded(12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                    }
                }

                Spacer()

                // Right: circular timer
                if isDone {
                    VStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(FreshliLA.freshGreen)
                        Text("Done!")
                            .font(FreshliLA.rounded(11, weight: .bold))
                            .foregroundStyle(FreshliLA.freshGreen)
                    }
                } else {
                    ZStack {
                        // Track
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 5)
                            .frame(width: 56, height: 56)
                        // Progress arc
                        Circle()
                            .trim(from: 0, to: timerProgress)
                            .stroke(
                                ringColor,
                                style: StrokeStyle(lineWidth: 5, lineCap: .round)
                            )
                            .frame(width: 56, height: 56)
                            .rotationEffect(.degrees(-90))
                        // Countdown
                        Text(timerInterval: Date.now...context.state.timerEnd, countsDown: true)
                            .font(FreshliLA.rounded(13, weight: .black))
                            .foregroundStyle(ringColor)
                            .monospacedDigit()
                            .frame(width: 44)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.5)
                    }
                }
            }

            if isDone {
                // Completion banner
                HStack(spacing: 8) {
                    Image(systemName: "party.popper.fill")
                        .foregroundStyle(FreshliLA.warningAmber)
                    Text("Enjoy your meal! Open Freshli to log your cook.")
                        .font(FreshliLA.rounded(13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                // Step description + step progress bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: stepIcon(context.state.stepDescription))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ringColor)
                            .frame(width: 22)

                        Text(context.state.stepDescription)
                            .font(FreshliLA.rounded(13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(2)
                    }

                    // Step capsule progress track
                    HStack(spacing: 4) {
                        ForEach(1...context.state.totalSteps, id: \.self) { step in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(stepBarColor(step: step))
                                .frame(maxWidth: .infinity)
                                .frame(height: 5)
                        }
                    }
                }
            }
        }
        .padding(16)
        .containerBackground(for: .widget) {
            ZStack {
                // Rich dark forest gradient
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.03, green: 0.10, blue: 0.06), location: 0),
                        .init(color: Color(red: 0.06, green: 0.18, blue: 0.10), location: 0.6),
                        .init(color: Color(red: 0.04, green: 0.14, blue: 0.11), location: 1.0),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Subtle green atmospheric glow top-right
                Circle()
                    .fill(FreshliLA.freshGreen.opacity(0.08))
                    .frame(width: 140)
                    .blur(radius: 30)
                    .offset(x: 80, y: -40)

                // Glass border
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(FreshliLA.glassBorder, lineWidth: 0.5)
            }
        }
    }

    // MARK: - Helpers

    private func stepBarColor(step: Int) -> Color {
        if step < context.state.currentStep { return FreshliLA.freshGreen }
        if step == context.state.currentStep { return Color.white.opacity(0.85) }
        return Color.white.opacity(0.12)
    }

    private func stepIcon(_ description: String) -> String {
        let l = description.lowercased()
        if l.contains("boil") || l.contains("simmer") { return "flame.fill" }
        if l.contains("chop") || l.contains("dice") || l.contains("cut") || l.contains("slice") { return "scissors" }
        if l.contains("mix") || l.contains("stir") || l.contains("whisk") { return "arrow.triangle.2.circlepath" }
        if l.contains("bake") || l.contains("oven") { return "oven.fill" }
        if l.contains("rest") || l.contains("cool") || l.contains("wait") { return "clock.fill" }
        if l.contains("fry") || l.contains("sauté") || l.contains("sear") { return "frying.pan.fill" }
        if l.contains("serve") || l.contains("plate") || l.contains("dish") { return "fork.knife" }
        return "flame.fill"
    }
}

// MARK: - Previews

extension FreshliRecipeTimerAttributes {
    fileprivate static var preview: FreshliRecipeTimerAttributes {
        FreshliRecipeTimerAttributes(recipeName: "Chicken Stir-Fry", recipeEmoji: "🥘")
    }
}

extension FreshliRecipeTimerAttributes.ContentState {
    fileprivate static var step2: FreshliRecipeTimerAttributes.ContentState {
        .init(currentStep: 2, totalSteps: 5,
              stepDescription: "Sauté vegetables in a hot wok for 4 minutes until tender",
              timerEnd: Date().addingTimeInterval(240),
              stepDurationSeconds: 240, status: "cooking")
    }
    fileprivate static var finalStep: FreshliRecipeTimerAttributes.ContentState {
        .init(currentStep: 5, totalSteps: 5,
              stepDescription: "Let it rest for 2 minutes before serving",
              timerEnd: Date().addingTimeInterval(120),
              stepDurationSeconds: 120, status: "cooking")
    }
    fileprivate static var complete: FreshliRecipeTimerAttributes.ContentState {
        .init(currentStep: 5, totalSteps: 5,
              stepDescription: "All done!", timerEnd: .now,
              stepDurationSeconds: 0, status: "done")
    }
}

#Preview("Lock Screen – Cooking", as: .content, using: FreshliRecipeTimerAttributes.preview) {
    FreshliRecipeTimerLiveActivity()
} contentStates: {
    FreshliRecipeTimerAttributes.ContentState.step2
    FreshliRecipeTimerAttributes.ContentState.finalStep
    FreshliRecipeTimerAttributes.ContentState.complete
}
