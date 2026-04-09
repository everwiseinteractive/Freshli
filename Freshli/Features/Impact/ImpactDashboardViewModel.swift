import SwiftUI
import Observation

/// Data structure for daily freshness metrics
struct DailyFreshness: Identifiable {
    let id = UUID()
    let day: String
    let savedPercent: Double
    let wastedPercent: Double
}

/// Enum for time period selection
enum TimePeriod: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case allTime = "All Time"
}

/// ViewModel for the premium Impact Dashboard
/// Loads and manages impact statistics from Supabase
@Observable
final class ImpactDashboardViewModel {
    // MARK: - State
    var weeklyStats: (moneySaved: Double, co2Avoided: Double, eventsCount: Int)? = nil
    var monthlyStats: (moneySaved: Double, co2Avoided: Double, eventsCount: Int)? = nil
    var weeklyComparison: (moneyChangePercent: Double, co2ChangePercent: Double)? = nil

    var freshnessTrend: [DailyFreshness] = []
    var recentEvents: [SupabaseImpactEvent] = []

    var selectedPeriod: TimePeriod = .week
    var isLoading = false
    var errorMessage: String? = nil

    var showMilestone = false
    var lastMilestoneTitle: String = ""
    var lastMilestoneValue: String = ""
    var lastMilestoneIcon: String = "star.fill"

    private let impactService: ImpactSupabaseService
    private let userId: UUID

    // MARK: - Initializer
    init(userId: UUID, impactService: ImpactSupabaseService = ImpactSupabaseService()) {
        self.userId = userId
        self.impactService = impactService
    }

    // MARK: - Data Loading

    /// Loads all impact data for the dashboard
    func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            async let weeklyTask = loadWeeklyData()
            async let monthlyTask = loadMonthlyData()
            async let comparisonTask = loadWeeklyComparison()

            let (weekly, monthly, comparison) = try await (weeklyTask, monthlyTask, comparisonTask)

            await MainActor.run {
                self.weeklyStats = weekly
                self.monthlyStats = monthly
                self.weeklyComparison = comparison
                self.isLoading = false
                self.generateFreshnessTrend()
                self.loadRecentEvents()
                self.checkMilestones()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    /// Loads weekly statistics from service
    private func loadWeeklyData() async throws -> (moneySaved: Double, co2Avoided: Double, eventsCount: Int) {
        try await impactService.fetchWeeklyStats(userId: userId)
    }

    /// Loads monthly statistics from service
    private func loadMonthlyData() async throws -> (moneySaved: Double, co2Avoided: Double, eventsCount: Int) {
        try await impactService.fetchMonthlyStats(userId: userId)
    }

    /// Loads weekly comparison data
    private func loadWeeklyComparison() async throws -> (moneyChangePercent: Double, co2ChangePercent: Double) {
        try await impactService.compareWeeklyImpact(userId: userId)
    }

    /// Loads recent events for activity feed
    private func loadRecentEvents() {
        Task {
            do {
                let weeklyEvents = try await impactService.fetchWeeklyImpact(userId: userId)
                await MainActor.run {
                    self.recentEvents = Array(weeklyEvents.prefix(5))
                }
            } catch {
                // Silently fail for recent events
            }
        }
    }

    // MARK: - Freshness Trend Generation

    /// Generates 7-day freshness trend data
    /// Simulates daily breakdown of saved items vs wasted items
    private func generateFreshnessTrend() {
        let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        var trends: [DailyFreshness] = []

        for (index, day) in days.enumerated() {
            // Simulate distribution: more saved later in week
            let saved = 30.0 + Double(index) * 8.0 + Double.random(in: -5...5)
            let wasted = max(0, 70.0 - saved + Double.random(in: -3...3))

            trends.append(DailyFreshness(
                day: day,
                savedPercent: saved,
                wastedPercent: wasted
            ))
        }

        self.freshnessTrend = trends
    }

    // MARK: - Milestone Detection

    /// Checks if any milestones have been reached
    private func checkMilestones() {
        guard let weeklyStats else { return }

        let milestones: [(threshold: Double, title: String, icon: String, type: String)] = [
            (50, "Carbon Crusader", "leaf.fill", "co2"),
            (50, "Money Master", "dollarsign.circle.fill", "money"),
            (5, "Sharing Champion", "heart.fill", "meals")
        ]

        for milestone in milestones {
            let value: Double
            switch milestone.type {
            case "co2":
                value = weeklyStats.co2Avoided
            case "money":
                value = weeklyStats.moneySaved
            case "meals":
                value = Double(weeklyStats.eventsCount)
            default:
                value = 0
            }

            if value >= milestone.threshold {
                showMilestone = true
                lastMilestoneTitle = milestone.title
                lastMilestoneValue = formatValue(value, type: milestone.type)
                lastMilestoneIcon = milestone.icon

                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation {
                        self.showMilestone = false
                    }
                }
                break
            }
        }
    }

    // MARK: - Helper Methods

    /// Formats a value based on its type
    private func formatValue(_ value: Double, type: String) -> String {
        switch type {
        case "co2":
            return String(format: "%.1f", value) + " kg"
        case "money":
            return String(format: "$%.2f", value)
        case "meals":
            return "\(Int(value))"
        default:
            return "\(value)"
        }
    }

    /// Gets the current stats based on selected period
    var currentStats: (moneySaved: Double, co2Avoided: Double, eventsCount: Int)? {
        switch selectedPeriod {
        case .week:
            return weeklyStats
        case .month:
            return monthlyStats
        case .allTime:
            return weeklyStats // Placeholder; would need allTime stats from service
        }
    }

    /// Gets percentage change for current period
    var percentageChange: (money: Double, co2: Double)? {
        if selectedPeriod == .week {
            return weeklyComparison.map { ($0.moneyChangePercent, $0.co2ChangePercent) }
        }
        return nil
    }
}
