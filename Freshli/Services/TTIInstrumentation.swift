import SwiftUI
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - TTI Instrumentation
// Measures Time-to-Interactive for critical user flows.
// Captures the end-to-end latency from user action to first
// meaningful paint, including data fetch + layout + render.
//
// Measurement points:
//   1. Cold launch → splash dismissed → first tab rendered
//   2. Tab switch → tap → first meaningful paint
//   3. Item action → consume/share → UI updated
//
// All measurements are local-only — surfaced in the Metal
// Performance HUD and logged via os.Logger for Instruments.
// ══════════════════════════════════════════════════════════════════

// MARK: - TTI Event

/// A timestamped measurement of a user flow's Time-to-Interactive.
struct TTIEvent: Identifiable, Sendable {
    let id = UUID()
    let flow: TTIFlow
    let durationMs: Double
    let timestamp: Date
    let withinBudget: Bool

    var budgetMs: Double { flow.budgetMs }
    var overBudgetMs: Double { max(0, durationMs - budgetMs) }
}

/// Measured user flows with their TTI budgets.
enum TTIFlow: String, CaseIterable, Sendable {
    case coldLaunch = "Cold Launch"
    case tabSwitch = "Tab Switch"
    case itemAction = "Item Action"
    case sheetPresent = "Sheet Present"
    case pullToRefresh = "Pull to Refresh"

    /// Maximum acceptable TTI in milliseconds.
    var budgetMs: Double {
        switch self {
        case .coldLaunch:    return 3000  // 3s total cold start
        case .tabSwitch:     return 300   // 300ms — the primary target
        case .itemAction:    return 200   // 200ms for consume/share feedback
        case .sheetPresent:  return 400   // 400ms for sheet + data load
        case .pullToRefresh: return 1000  // 1s for network round-trip
        }
    }
}

// MARK: - TTI Service

@Observable @MainActor
final class TTIService {
    static let shared = TTIService()

    /// Rolling window of recent TTI measurements (last 50).
    private(set) var recentEvents: [TTIEvent] = []

    /// Active measurement timers (flow → start time).
    private var activeTimers: [String: CFAbsoluteTime] = [:]

    /// Aggregate stats per flow.
    private(set) var flowStats: [TTIFlow: TTIFlowStats] = [:]

    private let logger = Logger(subsystem: "com.freshli", category: "TTI")
    private let maxEvents = 50

    private init() {}

    // MARK: - Measurement API

    /// Starts a TTI timer for a specific flow.
    /// Returns a token that must be passed to `end()`.
    @discardableResult
    func begin(_ flow: TTIFlow, context: String = "") -> String {
        let token = "\(flow.rawValue)_\(context)_\(UUID().uuidString.prefix(8))"
        activeTimers[token] = CFAbsoluteTimeGetCurrent()
        return token
    }

    /// Ends a TTI measurement and records the result.
    func end(_ token: String, flow: TTIFlow) {
        guard let startTime = activeTimers.removeValue(forKey: token) else {
            logger.warning("TTI end called for unknown token: \(token)")
            return
        }

        let durationMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
        let withinBudget = durationMs <= flow.budgetMs

        let event = TTIEvent(
            flow: flow,
            durationMs: durationMs,
            timestamp: Date(),
            withinBudget: withinBudget
        )

        recentEvents.append(event)
        if recentEvents.count > maxEvents {
            recentEvents.removeFirst()
        }

        // Update aggregate stats
        updateStats(flow: flow, durationMs: durationMs)

        // Log with signpost for Instruments
        if withinBudget {
            logger.info("TTI [\(flow.rawValue)]: \(durationMs, format: .fixed(precision: 1))ms (budget: \(flow.budgetMs)ms)")
        } else {
            logger.warning("TTI [\(flow.rawValue)]: \(durationMs, format: .fixed(precision: 1))ms OVER BUDGET (\(flow.budgetMs)ms)")
        }
    }

    /// Convenience: measure a synchronous block.
    func measure<T>(_ flow: TTIFlow, context: String = "", block: () -> T) -> T {
        let token = begin(flow, context: context)
        let result = block()
        end(token, flow: flow)
        return result
    }

    /// Convenience: measure an async block.
    func measure<T>(_ flow: TTIFlow, context: String = "", block: () async -> T) async -> T {
        let token = begin(flow, context: context)
        let result = await block()
        end(token, flow: flow)
        return result
    }

    // MARK: - Stats

    private func updateStats(flow: TTIFlow, durationMs: Double) {
        var stats = flowStats[flow] ?? TTIFlowStats(flow: flow)
        stats.record(durationMs)
        flowStats[flow] = stats
    }

    /// Whether all measured flows are within their TTI budgets (p95).
    var allFlowsWithinBudget: Bool {
        flowStats.values.allSatisfy { $0.p95Ms <= $0.flow.budgetMs }
    }

    // MARK: - HUD Display

    /// Summary for the performance HUD overlay.
    var hudSummary: String {
        guard !recentEvents.isEmpty else { return "No TTI data" }
        let avg = recentEvents.map(\.durationMs).reduce(0, +) / Double(recentEvents.count)
        let overBudget = recentEvents.filter { !$0.withinBudget }.count
        return String(format: "TTI avg: %.0fms | %d/%d within budget",
                      avg, recentEvents.count - overBudget, recentEvents.count)
    }
}

// MARK: - Flow Stats

struct TTIFlowStats: Sendable {
    let flow: TTIFlow
    private(set) var measurements: [Double] = []
    private(set) var count: Int = 0

    var averageMs: Double {
        guard count > 0 else { return 0 }
        return measurements.reduce(0, +) / Double(count)
    }

    var p95Ms: Double {
        guard count > 0 else { return 0 }
        let sorted = measurements.sorted()
        let index = Int(Double(count) * 0.95)
        return sorted[min(index, count - 1)]
    }

    var maxMs: Double {
        measurements.max() ?? 0
    }

    var withinBudgetRate: Double {
        guard count > 0 else { return 1.0 }
        let within = measurements.filter { $0 <= flow.budgetMs }.count
        return Double(within) / Double(count)
    }

    mutating func record(_ durationMs: Double) {
        measurements.append(durationMs)
        count += 1
        // Keep last 100 measurements
        if measurements.count > 100 {
            measurements.removeFirst()
        }
    }
}

// MARK: - Cold Launch TTI Tracker

/// Tracks the full cold launch TTI from process start to first tab render.
/// Started in FreshliApp.init, ended when the first tab's content appears.
@Observable @MainActor
final class ColdLaunchTracker {
    static let shared = ColdLaunchTracker()

    private(set) var hasCompleted = false
    private(set) var coldLaunchMs: Double?
    private var startTime: CFAbsoluteTime

    private init() {
        // Capture process start time as closely as possible
        startTime = CFAbsoluteTimeGetCurrent()
    }

    /// Called when the splash screen is dismissed and first tab renders.
    func markInteractive() {
        guard !hasCompleted else { return }
        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
        coldLaunchMs = duration
        hasCompleted = true

        let token = TTIService.shared.begin(.coldLaunch, context: "cold")
        TTIService.shared.end(token, flow: .coldLaunch)

        Logger(subsystem: "com.freshli", category: "TTI")
            .info("Cold launch TTI: \(duration, format: .fixed(precision: 0))ms")
    }
}
