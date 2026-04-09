import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Scenario 2: Community Claim Live Activity
// Shows distance to pickup and claim code in Dynamic Island.
// Active while user is en route to collect a shared item.

struct FreshliClaimLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FreshliClaimAttributes.self) { context in
            // Lock Screen / Banner
            claimLockScreen(context: context)
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: Expanded
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Text(FreshliLA.emoji(for: context.attributes.category))
                                .font(.system(size: 22))
                            Text(context.attributes.itemName)
                                .font(FreshliLA.rounded(15, weight: .bold))
                                .lineLimit(1)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(FreshliLA.accentTeal)
                            Text(context.attributes.pickupLocation)
                                .font(FreshliLA.rounded(11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(FreshliLA.formatDistance(context.state.distanceMeters))
                            .font(FreshliLA.rounded(18, weight: .black))
                            .foregroundStyle(distanceColor(context.state.status))
                        Text(etaText(context.state))
                            .font(FreshliLA.rounded(11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.status == "collected" {
                        collectedBanner()
                    } else {
                        claimCodeCard(code: context.attributes.claimCode, status: context.state.status)
                    }
                }
            } compactLeading: {
                // Compact: distance indicator
                HStack(spacing: 4) {
                    Image(systemName: statusIcon(context.state.status))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(distanceColor(context.state.status))
                    Text(FreshliLA.formatDistance(context.state.distanceMeters))
                        .font(FreshliLA.rounded(13, weight: .bold))
                        .lineLimit(1)
                }
            } compactTrailing: {
                // Compact: claim code
                Text(context.attributes.claimCode)
                    .font(FreshliLA.rounded(13, weight: .black))
                    .foregroundStyle(FreshliLA.accentTeal)
            } minimal: {
                Image(systemName: statusIcon(context.state.status))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(distanceColor(context.state.status))
            }
            .widgetURL(URL(string: "freshli://claim"))
            .keylineTint(FreshliLA.accentTeal)
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func claimLockScreen(context: ActivityViewContext<FreshliClaimAttributes>) -> some View {
        VStack(spacing: 12) {
            // Top row: item + distance
            HStack {
                HStack(spacing: 8) {
                    Text(FreshliLA.emoji(for: context.attributes.category))
                        .font(.system(size: 30))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Picking up from \(context.attributes.sharerName)")
                            .font(FreshliLA.rounded(13, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(context.attributes.itemName)
                            .font(FreshliLA.rounded(17, weight: .bold))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(FreshliLA.formatDistance(context.state.distanceMeters))
                        .font(FreshliLA.rounded(22, weight: .black))
                        .foregroundStyle(distanceColor(context.state.status))
                    Text(etaText(context.state))
                        .font(FreshliLA.rounded(11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            // Claim code card
            if context.state.status != "collected" {
                claimCodeCard(code: context.attributes.claimCode, status: context.state.status)
            } else {
                collectedBanner()
            }
        }
        .padding(16)
        .containerBackground(for: .widget) {
            ZStack {
                Color.black.opacity(0.5)
                LinearGradient(
                    colors: [
                        FreshliLA.accentTeal.opacity(0.1),
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

    // MARK: - Claim Code Card

    private func claimCodeCard(code: String, status: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("CLAIM CODE")
                    .font(FreshliLA.rounded(10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
                Text(code)
                    .font(FreshliLA.rounded(28, weight: .black))
                    .foregroundStyle(FreshliLA.accentTeal)
            }

            Spacer()

            if status == "arriving" || status == "arrived" {
                VStack(spacing: 2) {
                    Image(systemName: status == "arrived" ? "mappin.circle.fill" : "figure.walk")
                        .font(.system(size: 20))
                        .foregroundStyle(FreshliLA.accentTeal)
                    Text(status == "arrived" ? "You're here!" : "Almost there")
                        .font(FreshliLA.rounded(10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(FreshliLA.accentTeal.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(FreshliLA.accentTeal.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Collected Banner

    private func collectedBanner() -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(FreshliLA.freshGreen)
            Text("Item collected! Enjoy your food.")
                .font(FreshliLA.rounded(13, weight: .medium))
        }
    }

    // MARK: - Helpers

    private func distanceColor(_ status: String) -> Color {
        switch status {
        case "arrived": return FreshliLA.freshGreen
        case "arriving": return FreshliLA.accentTeal
        default: return FreshliLA.infoBlue
        }
    }

    private func statusIcon(_ status: String) -> String {
        switch status {
        case "arrived": return "mappin.circle.fill"
        case "arriving": return "figure.walk"
        case "collected": return "checkmark.circle.fill"
        default: return "location.fill"
        }
    }

    private func etaText(_ state: FreshliClaimAttributes.ContentState) -> String {
        switch state.status {
        case "arrived": return "You're here!"
        case "arriving": return "Almost there"
        case "collected": return "Collected"
        default: return "\(state.etaMinutes) min away"
        }
    }
}

// MARK: - Previews

extension FreshliClaimAttributes {
    fileprivate static var preview: FreshliClaimAttributes {
        FreshliClaimAttributes(
            itemName: "Sourdough Bread",
            category: "bakery",
            claimCode: "F7X2",
            pickupLocation: "42 Oak Street",
            sharerName: "Maria"
        )
    }
}

extension FreshliClaimAttributes.ContentState {
    fileprivate static var enRoute: FreshliClaimAttributes.ContentState {
        .init(distanceMeters: 850, etaMinutes: 4, status: "en_route")
    }

    fileprivate static var arriving: FreshliClaimAttributes.ContentState {
        .init(distanceMeters: 120, etaMinutes: 1, status: "arriving")
    }

    fileprivate static var arrived: FreshliClaimAttributes.ContentState {
        .init(distanceMeters: 15, etaMinutes: 0, status: "arrived")
    }

    fileprivate static var collected: FreshliClaimAttributes.ContentState {
        .init(distanceMeters: 0, etaMinutes: 0, status: "collected")
    }
}

#Preview("Claim - Lock Screen", as: .content, using: FreshliClaimAttributes.preview) {
    FreshliClaimLiveActivity()
} contentStates: {
    FreshliClaimAttributes.ContentState.enRoute
    FreshliClaimAttributes.ContentState.arriving
    FreshliClaimAttributes.ContentState.arrived
    FreshliClaimAttributes.ContentState.collected
}
