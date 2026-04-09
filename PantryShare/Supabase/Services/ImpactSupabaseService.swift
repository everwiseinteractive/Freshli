import Foundation
import Supabase
import os

// MARK: - Impact Supabase Service
// Handles impact event tracking and statistics aggregation for Freshli impact metrics.

@Observable
final class ImpactSupabaseService: Sendable {
    private let client = AppSupabase.client
    private let logger = Logger(subsystem: "com.freshli.app", category: "ImpactSupabaseService")

    // MARK: - Record Operations

    /// Records an impact event for a user
    /// - Parameters:
    ///   - userId: User ID recording the event
    ///   - eventType: Type of event (e.g., "item_consumed", "item_shared", "item_donated")
    ///   - itemName: Name of the item involved (optional)
    ///   - moneySaved: Estimated money saved in dollars
    ///   - co2Avoided: Estimated CO2 avoided in kilograms
    ///   - metadata: Additional metadata as dictionary (optional)
    /// - Returns: The created SupabaseImpactEvent
    /// - Throws: DatabaseError if the insert fails
    func recordEvent(
        userId: UUID,
        eventType: String,
        itemName: String? = nil,
        moneySaved: Double = 0.0,
        co2Avoided: Double = 0.0,
        metadata: [String: AnyCodable]? = nil
    ) async throws -> SupabaseImpactEvent {
        debugLog("ImpactSupabaseService: Recording \(eventType) event for user \(userId)")

        let event = SupabaseImpactEvent(
            id: UUID(),
            userId: userId,
            eventType: eventType,
            itemName: itemName,
            quantity: nil,
            estimatedMoneySaved: moneySaved,
            estimatedCo2Avoided: co2Avoided,
            metadata: metadata,
            createdAt: Date()
        )

        let response: SupabaseImpactEvent = try await client
            .from("impact_events")
            .insert(event)
            .select()
            .single()
            .execute()
            .value

        debugLog("ImpactSupabaseService: Successfully recorded event \(response.id)")
        return response
    }

    // MARK: - Fetch Operations

    /// Fetches impact events for the current week
    /// - Parameter userId: User ID to fetch events for
    /// - Returns: Array of SupabaseImpactEvent from the past 7 days
    /// - Throws: DatabaseError if the fetch fails
    func fetchWeeklyImpact(userId: UUID) async throws -> [SupabaseImpactEvent] {
        debugLog("ImpactSupabaseService: Fetching weekly impact for user \(userId)")

        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: weekAgo)

        let events: [SupabaseImpactEvent] = try await client
            .from("impact_events")
            .select()
            .eq("user_id", value: userId)
            .gte("created_at", value: dateString)
            .order("created_at", ascending: false)
            .execute()
            .value

        debugLog("ImpactSupabaseService: Fetched \(events.count) weekly impact events")
        return events
    }

    /// Fetches impact events for the current month
    /// - Parameter userId: User ID to fetch events for
    /// - Returns: Array of SupabaseImpactEvent from the past 30 days
    /// - Throws: DatabaseError if the fetch fails
    func fetchMonthlyImpact(userId: UUID) async throws -> [SupabaseImpactEvent] {
        debugLog("ImpactSupabaseService: Fetching monthly impact for user \(userId)")

        let monthAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: monthAgo)

        let events: [SupabaseImpactEvent] = try await client
            .from("impact_events")
            .select()
            .eq("user_id", value: userId)
            .gte("created_at", value: dateString)
            .order("created_at", ascending: false)
            .execute()
            .value

        debugLog("ImpactSupabaseService: Fetched \(events.count) monthly impact events")
        return events
    }

    /// Fetches all impact events for a user (lifetime)
    /// - Parameter userId: User ID to fetch events for
    /// - Returns: Array of all SupabaseImpactEvent
    /// - Throws: DatabaseError if the fetch fails
    func fetchLifetimeImpact(userId: UUID) async throws -> [SupabaseImpactEvent] {
        debugLog("ImpactSupabaseService: Fetching lifetime impact for user \(userId)")

        let events: [SupabaseImpactEvent] = try await client
            .from("impact_events")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value

        debugLog("ImpactSupabaseService: Fetched \(events.count) lifetime impact events")
        return events
    }

    /// Fetches impact events by type
    /// - Parameters:
    ///   - userId: User ID to fetch events for
    ///   - eventType: Type of event to filter by
    /// - Returns: Array of SupabaseImpactEvent matching the type
    /// - Throws: DatabaseError if the fetch fails
    func fetchEvents(userId: UUID, ofType eventType: String) async throws -> [SupabaseImpactEvent] {
        debugLog("ImpactSupabaseService: Fetching \(eventType) events for user \(userId)")

        let events: [SupabaseImpactEvent] = try await client
            .from("impact_events")
            .select()
            .eq("user_id", value: userId)
            .eq("event_type", value: eventType)
            .order("created_at", ascending: false)
            .execute()
            .value

        return events
    }

    // MARK: - Statistics Operations

    /// Calculates lifetime impact statistics for a user
    /// - Parameter userId: User ID to calculate stats for
    /// - Returns: Tuple with totalMoneySaved, totalCo2Avoided, totalEventsCount
    /// - Throws: DatabaseError if the fetch fails
    func fetchLifetimeStats(userId: UUID) async throws -> (
        moneySaved: Double,
        co2Avoided: Double,
        eventsCount: Int
    ) {
        debugLog("ImpactSupabaseService: Calculating lifetime stats for user \(userId)")

        let events = try await fetchLifetimeImpact(userId: userId)

        let totalMoneySaved = events.reduce(0) { $0 + ($1.estimatedMoneySaved ?? 0) }
        let totalCo2Avoided = events.reduce(0) { $0 + ($1.estimatedCo2Avoided ?? 0) }

        debugLog("ImpactSupabaseService: Lifetime stats - Money: $\(totalMoneySaved), CO2: \(totalCo2Avoided)kg")
        return (totalMoneySaved, totalCo2Avoided, events.count)
    }

    /// Calculates weekly impact statistics
    /// - Parameter userId: User ID to calculate stats for
    /// - Returns: Tuple with totalMoneySaved, totalCo2Avoided, totalEventsCount
    /// - Throws: DatabaseError if the fetch fails
    func fetchWeeklyStats(userId: UUID) async throws -> (
        moneySaved: Double,
        co2Avoided: Double,
        eventsCount: Int
    ) {
        debugLog("ImpactSupabaseService: Calculating weekly stats for user \(userId)")

        let events = try await fetchWeeklyImpact(userId: userId)

        let totalMoneySaved = events.reduce(0) { $0 + ($1.estimatedMoneySaved ?? 0) }
        let totalCo2Avoided = events.reduce(0) { $0 + ($1.estimatedCo2Avoided ?? 0) }

        return (totalMoneySaved, totalCo2Avoided, events.count)
    }

    /// Calculates monthly impact statistics
    /// - Parameter userId: User ID to calculate stats for
    /// - Returns: Tuple with totalMoneySaved, totalCo2Avoided, totalEventsCount
    /// - Throws: DatabaseError if the fetch fails
    func fetchMonthlyStats(userId: UUID) async throws -> (
        moneySaved: Double,
        co2Avoided: Double,
        eventsCount: Int
    ) {
        debugLog("ImpactSupabaseService: Calculating monthly stats for user \(userId)")

        let events = try await fetchMonthlyImpact(userId: userId)

        let totalMoneySaved = events.reduce(0) { $0 + ($1.estimatedMoneySaved ?? 0) }
        let totalCo2Avoided = events.reduce(0) { $0 + ($1.estimatedCo2Avoided ?? 0) }

        return (totalMoneySaved, totalCo2Avoided, events.count)
    }

    /// Counts impact events by type for aggregated statistics
    /// - Parameter userId: User ID to count events for
    /// - Returns: Dictionary mapping event types to their count
    /// - Throws: DatabaseError if the fetch fails
    func countEventsByType(userId: UUID) async throws -> [String: Int] {
        debugLog("ImpactSupabaseService: Counting events by type for user \(userId)")

        let events = try await fetchLifetimeImpact(userId: userId)

        var counts: [String: Int] = [:]
        for event in events {
            counts[event.eventType, default: 0] += 1
        }

        return counts
    }

    /// Calculates average impact per event
    /// - Parameters:
    ///   - userId: User ID to calculate for
    ///   - timeFrame: Time period to analyze ("week", "month", "lifetime")
    /// - Returns: Tuple with averageMoneySaved and averageCo2Avoided per event
    /// - Throws: DatabaseError if the fetch fails
    func calculateAverageImpact(
        userId: UUID,
        timeFrame: String
    ) async throws -> (averageMoneySaved: Double, averageCo2Avoided: Double) {
        debugLog("ImpactSupabaseService: Calculating average impact for user \(userId) - \(timeFrame)")

        let (totalMoney, totalCo2, count): (Double, Double, Int) = switch timeFrame {
        case "week":
            try await fetchWeeklyStats(userId: userId)
        case "month":
            try await fetchMonthlyStats(userId: userId)
        case "lifetime":
            try await fetchLifetimeStats(userId: userId)
        default:
            try await fetchLifetimeStats(userId: userId)
        }

        guard count > 0 else {
            return (0, 0)
        }

        let averageMoney = totalMoney / Double(count)
        let averageCo2 = totalCo2 / Double(count)

        return (averageMoney, averageCo2)
    }

    // MARK: - Comparison Operations

    /// Compares current week's impact to last week's
    /// - Parameter userId: User ID to compare for
    /// - Returns: Tuple with percentage change for money and CO2
    /// - Throws: DatabaseError if the fetch fails
    func compareWeeklyImpact(userId: UUID) async throws -> (
        moneyChangePercent: Double,
        co2ChangePercent: Double
    ) {
        debugLog("ImpactSupabaseService: Comparing weekly impact for user \(userId)")

        let currentWeek = try await fetchWeeklyStats(userId: userId)

        // Fetch previous week
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let formatter = ISO8601DateFormatter()

        let events: [SupabaseImpactEvent] = try await client
            .from("impact_events")
            .select()
            .eq("user_id", value: userId)
            .gte("created_at", value: formatter.string(from: twoWeeksAgo))
            .lt("created_at", value: formatter.string(from: weekAgo))
            .execute()
            .value

        let prevMoney = events.reduce(0) { $0 + ($1.estimatedMoneySaved ?? 0) }
        let prevCo2 = events.reduce(0) { $0 + ($1.estimatedCo2Avoided ?? 0) }

        let moneyChange = prevMoney > 0 ? ((currentWeek.moneySaved - prevMoney) / prevMoney) * 100 : 0
        let co2Change = prevCo2 > 0 ? ((currentWeek.co2Avoided - prevCo2) / prevCo2) * 100 : 0

        return (moneyChange, co2Change)
    }

    // MARK: - Helper Enums

    enum DatabaseError: LocalizedError {
        case fetchFailed(String)
        case insertFailed(String)
        case invalidData
        case userNotFound

        var errorDescription: String? {
            switch self {
            case .fetchFailed(let message):
                return "Failed to fetch impact events: \(message)"
            case .insertFailed(let message):
                return "Failed to record impact event: \(message)"
            case .invalidData:
                return "Invalid impact event data"
            case .userNotFound:
                return "User not found"
            }
        }
    }
}
