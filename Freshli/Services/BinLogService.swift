import Foundation
import SwiftUI

// MARK: - Bin Log Service
// Post-mortem analytics: track WHY food was thrown away so the app can
// proactively warn users to stop buying items they consistently waste.

// MARK: - Models

enum BinReason: String, Codable, CaseIterable, Identifiable {
    case forgotten   = "Forgot it was there"
    case disliked    = "Didn't like the taste"
    case expired     = "Expired before I got to it"
    case spoiled     = "Went mouldy / bad"
    case overbought  = "Bought too much"
    case missedPeak  = "Missed the best window"
    case other       = "Other reason"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .forgotten:  return "questionmark.circle.fill"
        case .disliked:   return "hand.thumbsdown.fill"
        case .expired:    return "clock.badge.exclamationmark.fill"
        case .spoiled:    return "xmark.octagon.fill"
        case .overbought: return "cart.fill.badge.plus"
        case .missedPeak: return "calendar.badge.exclamationmark"
        case .other:      return "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .forgotten:  return Color(hex: 0xA78BFA)
        case .disliked:   return Color(hex: 0xF472B6)
        case .expired:    return PSColors.secondaryAmber
        case .spoiled:    return PSColors.expiredRed
        case .overbought: return Color(hex: 0x3B82F6)
        case .missedPeak: return Color(hex: 0xF97316)
        case .other:      return PSColors.textTertiary
        }
    }
}

struct BinEntry: Identifiable, Codable {
    let id: UUID
    let itemName: String
    let categoryRaw: String
    let reason: BinReason
    let date: Date
    let costEstimate: Double

    init(id: UUID = UUID(), itemName: String, categoryRaw: String, reason: BinReason, date: Date = Date(), costEstimate: Double = 3.50) {
        self.id = id
        self.itemName = itemName
        self.categoryRaw = categoryRaw
        self.reason = reason
        self.date = date
        self.costEstimate = costEstimate
    }
}

struct StopBuyingAlert: Identifiable {
    let id = UUID()
    let itemName: String
    let binCount: Int
    let totalCost: Double
    let topReason: BinReason
    let timeWindow: String
}

// MARK: - Service

@MainActor
@Observable
final class BinLogService {
    static let shared = BinLogService()
    private init() { loadEntries() }

    var entries: [BinEntry] = []
    private let storeKey = "bin_log_entries"

    // MARK: - Log

    func log(item: FreshliItem, reason: BinReason) {
        let entry = BinEntry(
            itemName: item.name,
            categoryRaw: item.category.rawValue,
            reason: reason,
            costEstimate: 3.50
        )
        entries.insert(entry, at: 0)
        saveEntries()
    }

    func log(itemName: String, categoryRaw: String, reason: BinReason, cost: Double = 3.50) {
        let entry = BinEntry(itemName: itemName, categoryRaw: categoryRaw, reason: reason, costEstimate: cost)
        entries.insert(entry, at: 0)
        saveEntries()
    }

    // MARK: - Analytics

    /// Items the user has binned 3+ times in the last 30 days.
    func stopBuyingAlerts() -> [StopBuyingAlert] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recent = entries.filter { $0.date >= cutoff }
        let grouped = Dictionary(grouping: recent) { $0.itemName.lowercased() }

        return grouped.compactMap { (_, items) -> StopBuyingAlert? in
            guard items.count >= 3 else { return nil }
            let sample = items.first!
            let topReason = mostCommonReason(in: items)
            let cost = items.reduce(0.0) { $0 + $1.costEstimate }
            return StopBuyingAlert(
                itemName: sample.itemName,
                binCount: items.count,
                totalCost: cost,
                topReason: topReason,
                timeWindow: "last 30 days"
            )
        }
        .sorted { $0.binCount > $1.binCount }
    }

    /// Breakdown of bin reasons across all entries (for dashboards).
    func reasonBreakdown() -> [(BinReason, Int)] {
        let grouped = Dictionary(grouping: entries) { $0.reason }
        return BinReason.allCases.compactMap { reason -> (BinReason, Int)? in
            let count = grouped[reason]?.count ?? 0
            guard count > 0 else { return nil }
            return (reason, count)
        }
        .sorted { $0.1 > $1.1 }
    }

    /// Total estimated money wasted in the given number of days.
    func totalWastedCost(days: Int = 30) -> Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return entries.filter { $0.date >= cutoff }.reduce(0.0) { $0 + $1.costEstimate }
    }

    private func mostCommonReason(in entries: [BinEntry]) -> BinReason {
        let grouped = Dictionary(grouping: entries) { $0.reason }
        return grouped.max(by: { $0.value.count < $1.value.count })?.key ?? .forgotten
    }

    // MARK: - Persistence

    private func saveEntries() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }

    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: storeKey),
              let decoded = try? JSONDecoder().decode([BinEntry].self, from: data) else { return }
        entries = decoded
    }
}
