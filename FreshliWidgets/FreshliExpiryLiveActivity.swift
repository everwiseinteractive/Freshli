import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Scenario 1: Expiring Soon Live Activity
// Persistent Lock Screen activity with a green→amber progress bar.
// Triggers when an item has <6 hours remaining.

struct FreshliExpiryLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FreshliExpiryAttributes.self) { context in
            // Lock Screen / Banner
            expiryLockScreen(context: context)
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: Expanded
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Text(FreshliLA.emoji(for: context.attributes.category))
                            .font(.system(size: 28))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.attributes.itemName)
                                .font(FreshliLA.rounded(15, weight: .bold))
                            Text(context.attributes.quantity)
                                .font(FreshliLA.rounded(12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        if context.state.status == "rescued" {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(FreshliLA.freshGreen)
                        } else {
                            Text(formatMinutes(context.state.minutesRemaining))
                                .font(FreshliLA.rounded(18, weight: .black))
                                .foregroundStyle(FreshliLA.expiryProgressColor(context.state.progress))
                            Text("remaining")
                                .font(FreshliLA.rounded(11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        if context.state.status == "rescued" {
                            rescuedBanner()
                        } else {
                            // Progress bar: green → amber
                            FreshliLAProgressBar(
                                progress: context.state.progress,
                                color: FreshliLA.expiryProgressColor(context.state.progress)
                            )

                            HStack(spacing: 12) {
                                FreshliLAPill(icon: "fork.knife", label: "Cook", color: FreshliLA.freshGreen)
                                FreshliLAPill(icon: "arrow.up.heart", label: "Share", color: FreshliLA.infoBlue)
                                FreshliLAPill(icon: "heart.fill", label: "Donate", color: FreshliLA.warningAmber)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                // Compact: emoji + name
                HStack(spacing: 4) {
                    Text(FreshliLA.emoji(for: context.attributes.category))
                        .font(.system(size: 14))
                    Text(context.attributes.itemName)
                        .font(FreshliLA.rounded(13, weight: .bold))
                        .lineLimit(1)
                }
            } compactTrailing: {
                // Compact: time remaining with color
                Text(formatMinutes(context.state.minutesRemaining))
                    .font(FreshliLA.rounded(13, weight: .black))
                    .foregroundStyle(FreshliLA.expiryProgressColor(context.state.progress))
            } minimal: {
                // Minimal: just the progress ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: CGFloat(context.state.progress))
                        .stroke(
                            FreshliLA.expiryProgressColor(context.state.progress),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    Text(FreshliLA.emoji(for: context.attributes.category))
                        .font(.system(size: 10))
                }
            }
            .widgetURL(URL(string: "freshli://expiring"))
            .keylineTint(FreshliLA.freshGreen)
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func expiryLockScreen(context: ActivityViewContext<FreshliExpiryAttributes>) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Item info
                HStack(spacing: 10) {
                    Text(FreshliLA.emoji(for: context.attributes.category))
                        .font(.system(size: 34))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.itemName)
                            .font(FreshliLA.rounded(17, weight: .bold))
                        Text(context.attributes.quantity)
                            .font(FreshliLA.rounded(13))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Time display
                VStack(alignment: .trailing, spacing: 2) {
                    if context.state.status == "rescued" {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(FreshliLA.freshGreen)
                        Text("Rescued!")
                            .font(FreshliLA.rounded(13, weight: .bold))
                            .foregroundStyle(FreshliLA.freshGreen)
                    } else {
                        Text(formatMinutes(context.state.minutesRemaining))
                            .font(FreshliLA.rounded(24, weight: .black))
                            .foregroundStyle(FreshliLA.expiryProgressColor(context.state.progress))
                        Text("until expiry")
                            .font(FreshliLA.rounded(11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if context.state.status != "rescued" {
                // Progress bar: green→amber gradient
                FreshliLAProgressBar(
                    progress: context.state.progress,
                    color: FreshliLA.expiryProgressColor(context.state.progress)
                )
            }
        }
        .padding(16)
        .containerBackground(for: .widget) {
            ZStack {
                // Glassmorphism base
                Color.black.opacity(0.5)
                LinearGradient(
                    colors: [
                        FreshliLA.expiryProgressColor(context.state.progress).opacity(0.12),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                // Glass border
                RoundedRectangle(cornerRadius: 20)
                    .stroke(FreshliLA.glassBorder, lineWidth: 0.5)
            }
        }
    }

    // MARK: - Helpers

    private func rescuedBanner() -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(FreshliLA.freshGreen)
            Text("Food rescued! Nice work reducing waste.")
                .font(FreshliLA.rounded(13, weight: .medium))
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes <= 0 { return "Now!" }
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 { return "\(hours)h" }
        return "\(hours)h \(mins)m"
    }
}

// MARK: - Previews

extension FreshliExpiryAttributes {
    fileprivate static var preview: FreshliExpiryAttributes {
        FreshliExpiryAttributes(itemName: "Organic Milk", category: "dairy", quantity: "1 carton")
    }
}

extension FreshliExpiryAttributes.ContentState {
    fileprivate static var expiringSoon: FreshliExpiryAttributes.ContentState {
        .init(progress: 0.35, minutesRemaining: 127, expiryDate: Date().addingTimeInterval(7620), status: "expiring")
    }

    fileprivate static var critical: FreshliExpiryAttributes.ContentState {
        .init(progress: 0.08, minutesRemaining: 28, expiryDate: Date().addingTimeInterval(1680), status: "expiring")
    }

    fileprivate static var rescued: FreshliExpiryAttributes.ContentState {
        .init(progress: 0, minutesRemaining: 0, expiryDate: .now, status: "rescued")
    }
}

#Preview("Expiry - Lock Screen", as: .content, using: FreshliExpiryAttributes.preview) {
    FreshliExpiryLiveActivity()
} contentStates: {
    FreshliExpiryAttributes.ContentState.expiringSoon
    FreshliExpiryAttributes.ContentState.critical
    FreshliExpiryAttributes.ContentState.rescued
}
