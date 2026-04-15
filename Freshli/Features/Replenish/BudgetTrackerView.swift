import SwiftUI

// MARK: - Budget Tracker Card
// Real-time "Estimated Cost" vs "Last Price Paid" comparison
// as items are added to the Freshli Replenish smart list.

struct BudgetTrackerView: View {
    let summary: ReplenishBudgetSummary

    @State private var appeared = false

    var body: some View {
        PSGlassCard {
            VStack(spacing: PSSpacing.lg) {
                // Header
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PSColors.primaryGreen)

                    Text("Budget Tracker")
                        .font(PSTypography.headline)
                        .foregroundStyle(PSColors.textPrimary)

                    Spacer()

                    Text("\(summary.itemCount) items")
                        .font(PSTypography.caption1)
                        .foregroundStyle(PSColors.textTertiary)
                }

                // Cost Comparison
                HStack(spacing: PSSpacing.xl) {
                    CostColumn(
                        label: "Estimated Cost",
                        amount: summary.estimatedTotal,
                        color: PSColors.primaryGreen,
                        icon: "tag.fill"
                    )

                    // Divider
                    Rectangle()
                        .fill(PSColors.border.opacity(0.5))
                        .frame(width: 1, height: 48)

                    CostColumn(
                        label: "Last Paid",
                        amount: summary.lastPaidTotal,
                        color: PSColors.textSecondary,
                        icon: "clock.fill"
                    )
                }

                // Savings Indicator
                if summary.lastPaidTotal > 0 {
                    HStack(spacing: PSSpacing.sm) {
                        Image(systemName: summary.savings >= 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(summary.savings >= 0 ? PSColors.primaryGreen : PSColors.expiredRed)

                        Text(savingsText)
                            .font(PSTypography.caption1Medium)
                            .foregroundStyle(summary.savings >= 0 ? PSColors.primaryGreen : PSColors.expiredRed)

                        Spacer()

                        // Progress ring
                        BudgetProgressRing(
                            purchased: summary.purchasedCount,
                            total: summary.itemCount
                        )
                    }
                    .padding(.top, PSSpacing.xs)
                }
            }
            .padding(PSSpacing.cardPadding)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(PSMotion.springDefault.delay(0.1)) {
                appeared = true
            }
        }
    }

    private var savingsText: String {
        let absSavings = Swift.abs(summary.savings)
        let pct = Swift.abs(summary.savingsPercentage)
        if summary.savings >= 0 {
            return String(format: "Save $%.2f (%.0f%% less)", absSavings, pct)
        } else {
            return String(format: "$%.2f more (%.0f%% increase)", absSavings, pct)
        }
    }
}

// MARK: - Cost Column

private struct CostColumn: View {
    let label: String
    let amount: Double
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: PSSpacing.xs) {
            HStack(spacing: PSSpacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color.opacity(0.7))

                Text(label)
                    .font(PSTypography.caption2)
                    .foregroundStyle(PSColors.textTertiary)
            }

            Text(String(format: "$%.2f", amount))
                .font(PSTypography.statMedium)
                .monospacedDigit()
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .compositingGroup()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Budget Progress Ring

private struct BudgetProgressRing: View {
    let purchased: Int
    let total: Int

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(purchased) / Double(total)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(PSColors.border.opacity(0.3), lineWidth: 3)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(PSColors.primaryGreen, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(PSMotion.springDefault, value: progress)

            Text("\(purchased)/\(total)")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(PSColors.textSecondary)
        }
        .frame(width: 32, height: 32)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        BudgetTrackerView(summary: ReplenishBudgetSummary(
            estimatedTotal: 34.47,
            lastPaidTotal: 42.93,
            itemCount: 8,
            purchasedCount: 3
        ))

        BudgetTrackerView(summary: ReplenishBudgetSummary(
            estimatedTotal: 12.99,
            lastPaidTotal: 0,
            itemCount: 2,
            purchasedCount: 0
        ))
    }
    .padding()
    .background(PSColors.backgroundPrimary)
}
