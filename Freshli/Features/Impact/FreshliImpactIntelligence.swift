import SwiftUI
import Charts
import TipKit
import os

// MARK: - Impact Intelligence View (Swift 6.3)
// Data Visualization Specialist implementation.
// Multi-layered Swift Charts with MeshGradient fill, haptic scrubbing,
// spring-loaded draw animations, and TipKit insights.

private let logger = Logger(subsystem: "com.freshli.app", category: "ImpactIntelligence")

// MARK: - Data Models

/// A single data point in the Savings Growth chart.
struct ImpactDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let moneySaved: Double     // cumulative £
    let co2Avoided: Double     // cumulative kg
}

/// View model for the Impact Intelligence screen.
@Observable @MainActor
final class ImpactIntelligenceViewModel {
    var dataPoints: [ImpactDataPoint] = []
    var isLoading = true
    var selectedPoint: ImpactDataPoint?
    var insightMessage: String?

    private let userId: UUID
    private let service = FreshliSupabaseService()

    init(userId: UUID) {
        self.userId = userId
    }

    func loadData() async {
        defer { isLoading = false }
        do {
            // Fetch consumed items from the last 90 days
            let items = try await service.fetchConsumedItems(for: userId, days: 90)
            dataPoints = Self.buildTimeline(from: items)
            insightMessage = Self.generateInsight(from: items)
        } catch {
            logger.error("Failed to load impact data: \(error)")
        }
    }

    // MARK: - Timeline Builder

    /// Aggregates consumed items into a cumulative daily timeline.
    static func buildTimeline(from items: [SupabaseFreshliItem]) -> [ImpactDataPoint] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.updatedAt ?? item.expiryDate)
        }

        var cumulativeMoney: Double = 0
        var cumulativeCO2: Double = 0
        var points: [ImpactDataPoint] = []

        let sortedDays = grouped.keys.sorted()
        for day in sortedDays {
            let dayItems = grouped[day] ?? []
            // Estimated savings per item
            for item in dayItems {
                cumulativeMoney += 2.50  // Estimated average savings per item
                cumulativeCO2 += 0.5    // Estimated average CO₂ avoided per item
            }
            points.append(ImpactDataPoint(
                date: day,
                moneySaved: cumulativeMoney,
                co2Avoided: cumulativeCO2
            ))
        }
        return points
    }

    // MARK: - Insight Generator

    /// Produces a human-friendly TipKit message from consumption patterns.
    static func generateInsight(from items: [SupabaseFreshliItem]) -> String? {
        let calendar = Calendar.current
        let thisMonth = items.filter {
            calendar.isDate($0.updatedAt ?? Date.distantPast, equalTo: Date(), toGranularity: .month)
        }
        let lastMonth = items.filter {
            guard let consumed = $0.updatedAt else { return false }
            let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: Date())!
            return calendar.isDate(consumed, equalTo: oneMonthAgo, toGranularity: .month)
        }

        guard !lastMonth.isEmpty else { return nil }
        let improvement = Double(thisMonth.count - lastMonth.count) / Double(lastMonth.count) * 100

        if improvement > 0 {
            // Find the most-consumed category this month
            let categories = Dictionary(grouping: thisMonth, by: \.category)
            let topCategory = categories.max(by: { $0.value.count < $1.value.count })?.key ?? "food"
            return "You saved \(Int(improvement))% more this month by using surplus \(topCategory)!"
        }
        return nil
    }
}

// MARK: - TipKit — Freshli Insight Tip

/// A tip that appears at the top of the Impact Intelligence view with contextual insights.
struct FreshliInsightTip: Tip {
    @Parameter
    static var insightShown: Bool = false

    var title: Text {
        Text("Freshli Insight")
    }

    var message: Text? {
        Text("Swipe across the chart to explore your daily savings breakdown.")
    }

    var image: Image? {
        Image(systemName: "chart.line.uptrend.xyaxis")
    }

    var rules: [Rule] {
        #Rule(Self.$insightShown) { $0 == false }
    }
}

// MARK: - Impact Intelligence View

struct FreshliImpactIntelligenceView: View {
    @State private var viewModel: ImpactIntelligenceViewModel
    @State private var chartAnimationProgress: CGFloat = 0
    @State private var selectedDate: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let insightTip = FreshliInsightTip()

    init(userId: UUID) {
        self._viewModel = State(initialValue: ImpactIntelligenceViewModel(userId: userId))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: PSSpacing.xl) {
                // MARK: TipKit Insight
                tipSection

                // MARK: Dynamic Insight Banner
                if let insight = viewModel.insightMessage {
                    insightBanner(insight)
                }

                // MARK: Savings Growth Chart
                savingsChartSection

                // MARK: Selected Point Detail
                if let selected = viewModel.selectedPoint {
                    selectedPointCard(selected)
                }
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.vertical, PSSpacing.screenVertical)
        }
        .navigationTitle("Impact Intelligence")
        .task {
            await viewModel.loadData()
            // Spring-loaded chart draw animation
            withAnimation(.spring(response: 1.2, dampingFraction: 0.7)) {
                chartAnimationProgress = 1.0
            }
        }
    }

    // MARK: - Tip Section

    @ViewBuilder
    private var tipSection: some View {
        TipView(insightTip)
            .tipBackground(FreshliColor.freshliGreenSurface)
    }

    // MARK: - Insight Banner

    private func insightBanner(_ message: String) -> some View {
        HStack(spacing: PSSpacing.sm) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(FreshliColor.impactGold)
                .symbolEffect(.pulse, options: .repeating)
            Text(message)
                .font(.freshliBodyMedium)
                .foregroundStyle(PSColors.textPrimary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .freshliCard()
    }

    // MARK: - Savings Growth Chart

    @ViewBuilder
    private var savingsChartSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            Text("Savings Growth")
                .font(.freshliDisplayMedium)

            if viewModel.isLoading {
                ProgressView()
                    .frame(height: 260)
                    .frame(maxWidth: .infinity)
            } else {
                savingsChart
                    .frame(height: 260)
            }
        }
        .padding()
        .freshliCard()
    }

    private var savingsChart: some View {
        Chart {
            // MARK: AreaMark — Money Saved (primary layer)
            ForEach(viewModel.dataPoints) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Money Saved", point.moneySaved * chartAnimationProgress)
                )
                .foregroundStyle(moneySavedGradient)
                .interpolationMethod(.catmullRom)

                // Line overlay for crisp edge
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Money Saved", point.moneySaved * chartAnimationProgress)
                )
                .foregroundStyle(FreshliColor.freshliGreen)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.catmullRom)
            }

            // MARK: AreaMark — CO₂ Avoided (secondary layer)
            ForEach(viewModel.dataPoints) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("CO₂ Avoided", point.co2Avoided * chartAnimationProgress)
                )
                .foregroundStyle(co2Gradient)
                .interpolationMethod(.catmullRom)
                .opacity(0.5)
            }

            // MARK: RuleMark — Scrub indicator
            if let selectedDate {
                RuleMark(x: .value("Selected", selectedDate))
                    .foregroundStyle(Color.primary.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .center) {
                        if let point = viewModel.dataPoints.min(by: {
                            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
                        }) {
                            VStack(spacing: 2) {
                                Text("£\(point.moneySaved, specifier: "%.0f")")
                                    .font(.freshliCaption)
                                    .foregroundStyle(FreshliColor.freshliGreen)
                                Text("\(point.co2Avoided, specifier: "%.1f") kg CO₂")
                                    .font(.freshliFootnote)
                                    .foregroundStyle(PSColors.accentTeal)
                            }
                            .padding(6)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [4]))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("£\(v, specifier: "%.0f")")
                            .font(.freshliFootnote)
                    }
                }
            }
        }
        .onChange(of: selectedDate) { _, newDate in
            guard newDate != nil else { return }
            // Haptic feedback on scrub
            PSHaptics.shared.lightTap()
            // Update selected point for detail card
            if let date = newDate {
                viewModel.selectedPoint = viewModel.dataPoints.min(by: {
                    abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                })
            }
        }
    }

    // MARK: - Gradient Fills

    /// MeshGradient-inspired linear fill for Money Saved area.
    private var moneySavedGradient: LinearGradient {
        LinearGradient(
            colors: [
                FreshliColor.freshliGreen.opacity(0.5),
                FreshliColor.freshliGreen.opacity(0.15),
                FreshliColor.freshliGreen.opacity(0.02)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Teal gradient for CO₂ Avoided area.
    private var co2Gradient: LinearGradient {
        LinearGradient(
            colors: [
                PSColors.accentTeal.opacity(0.4),
                PSColors.accentTeal.opacity(0.08)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Selected Point Detail Card

    private func selectedPointCard(_ point: ImpactDataPoint) -> some View {
        HStack(spacing: PSSpacing.lg) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Money Saved")
                    .font(.freshliCaption)
                    .foregroundStyle(.secondary)
                Text("£\(point.moneySaved, specifier: "%.2f")")
                    .font(.freshliDisplaySmall)
                    .foregroundStyle(FreshliColor.freshliGreen)
            }

            Divider().frame(height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text("CO₂ Avoided")
                    .font(.freshliCaption)
                    .foregroundStyle(.secondary)
                Text("\(point.co2Avoided, specifier: "%.1f") kg")
                    .font(.freshliDisplaySmall)
                    .foregroundStyle(PSColors.accentTeal)
            }

            Spacer()

            Text(point.date, style: .date)
                .font(.freshliFootnote)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .freshliCard()
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: point.id)
    }
}

// MARK: - Preview

#Preview("Impact Intelligence") {
    NavigationStack {
        FreshliImpactIntelligenceView(userId: UUID())
    }
}
