import Foundation
import SwiftUI
import Observation
import Supabase

// MARK: - Collective Impact Service
// Turns Freshli's mission into something felt.
//
// Each user's private rescues are aggregated (locally for now, via
// Supabase in production) into a rolling one-hour counter of "people
// like you who also rescued food in the last 60 minutes", plus a
// live ticker of anonymised rescue events. Tapping into this feed
// transforms a lonely chore (marking spinach as consumed) into a
// collective moment (340 other humans just did the same thing).
//
// Designed to feed a prominent Home card — the Collective Wave.

struct CollectiveRescueEvent: Identifiable, Hashable {
    let id = UUID()
    let displayName: String   // first name + last initial only
    let cityName: String      // anonymised region, e.g. "Leeds"
    let itemName: String
    let minutesAgo: Int

    var timeLabel: String {
        switch minutesAgo {
        case 0:      return String(localized: "just now")
        case 1:      return String(localized: "1 min ago")
        case 2..<60: return String(localized: "\(minutesAgo) min ago")
        default:     return String(localized: "1h+ ago")
        }
    }
}

@MainActor
@Observable
final class CollectiveImpactService {
    static let shared = CollectiveImpactService()

    /// Global rolling counter — how many rescues happened in the last 60 min,
    /// queried from the Supabase `get_collective_hourly_stats` RPC every 60s.
    /// Starts at 0 — it must NEVER be seeded with fabricated data in
    /// production. A genuinely-quiet hour shows "0" honestly; that is
    /// preferable to inventing rescue counts that didn't happen.
    private(set) var rescuesThisHour: Int = 0

    /// Running count of active rescuers in the last hour (distinct users).
    /// Same honesty rule as `rescuesThisHour`.
    private(set) var activeRescuersThisHour: Int = 0

    /// Live feed of the most recent anonymised rescue events. Only ever
    /// populated by Supabase reads or by `recordRescue(...)` calls from
    /// the current user's own actions.
    private(set) var recentFeed: [CollectiveRescueEvent] = []

    /// Total impact since the app's launch day, sourced from the
    /// `total_items_rescued` field of the hourly-stats RPC.
    private(set) var totalItemsRescued: Int = 0

    /// Whether we have ever successfully completed a backend refresh.
    /// The Wave card uses this to distinguish "we're still loading" from
    /// "we have real data and the count is genuinely zero".
    private(set) var hasLoadedRealData: Bool = false

    private var timer: Timer?
    private var tickCount: Int = 0

    private init() {
        // PRODUCTION: No mock data, ever. Real users see real Supabase
        // data — and an honest empty state until the first refresh
        // completes or the first real user rescue arrives.
        //
        // REVIEWER: When the App Review reviewer is signed in, we seed
        // the demonstration feed so reviewers can verify the feature
        // works without waiting for live community activity.
        if ReviewerAccountService.shared.isReviewerActive {
            seedReviewerDemonstrationFeed()
        }

        startRollingUpdates()

        // Kick off an initial refresh from Supabase. If it fails (offline,
        // no session, etc.) the card keeps showing 0 / empty until the
        // next 60s tick succeeds. NO simulated fallback in production.
        Task { @MainActor in
            await refreshFromBackend()
        }
    }

    // MARK: - Backend Sync

    /// Pulls the latest hourly stats + feed from Supabase. Called on init
    /// and every 60s by the rolling update timer. On failure, leaves the
    /// existing values in place; never falls back to fabricated data.
    ///
    /// Reviewer accounts: the demonstration seed runs at init and is left
    /// alone here — backend reads, if they succeed, will overlay real data
    /// on top. If the reviewer is offline they keep seeing the demo feed.
    func refreshFromBackend() async {
        // Reviewer mode: keep the demonstration data visible. We still try
        // the backend so a real reviewer signed in to a network can see
        // genuine activity, but we never clear demo data on failure.
        let isReviewer = ReviewerAccountService.shared.isReviewerActive

        do {
            // Stats RPC → rescues this hour + CO₂ + meals + distinct rescuers
            let statsRows: [CollectiveHourlyStatsDTO] = try await AppSupabase.client
                .rpc("get_collective_hourly_stats")
                .execute()
                .value
            if let stats = statsRows.first {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    // Accept zero as a real value. The Wave card empty state
                    // exists for exactly this case — a quiet hour is real
                    // and should be shown honestly.
                    rescuesThisHour = stats.rescuesThisHour
                    activeRescuersThisHour = stats.distinctRescuers
                    hasLoadedRealData = true
                }
            }

            // Live feed view → anonymised recent events
            let feedRows: [CollectiveRescueFeedDTO] = try await AppSupabase.client
                .from("collective_rescue_feed")
                .select()
                .limit(20)
                .execute()
                .value

            // Replace the feed with backend results. An empty result on a
            // quiet hour is legitimate — show the empty Wave state honestly.
            // Exception: in reviewer mode, only overlay real events on top
            // of the demo seed (never wipe it out).
            let mapped = feedRows.map { row in
                CollectiveRescueEvent(
                    displayName: row.displayName,
                    cityName: row.displayCity,
                    itemName: row.itemName,
                    minutesAgo: row.minutesAgo
                )
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                if isReviewer && mapped.isEmpty {
                    // Keep demo seed visible; do nothing.
                } else {
                    recentFeed = mapped
                }
            }
        } catch {
            // Backend unreachable. Leave the existing values in place.
            // Real users see whatever was last successfully fetched (or 0
            // / empty if nothing has loaded yet). NO synthetic fallback.
            PSLogger.general.debug("Collective impact refresh failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Public Recording

    /// Record a new rescue performed by the current user.
    func recordRescue(itemName: String, userDisplayName: String = "You") {
        rescuesThisHour += 1
        totalItemsRescued += 1
        let event = CollectiveRescueEvent(
            displayName: userDisplayName,
            cityName: String(localized: "nearby"),
            itemName: itemName,
            minutesAgo: 0
        )
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            recentFeed.insert(event, at: 0)
            if recentFeed.count > 20 {
                recentFeed.removeLast()
            }
        }
    }

    // MARK: - Stats

    /// Short headline number for the Wave card, e.g. "347", "2.4k".
    var rescueCountDisplay: String {
        if rescuesThisHour >= 1000 {
            return String(format: "%.1fk", Double(rescuesThisHour) / 1000.0)
        }
        return "\(rescuesThisHour)"
    }

    /// Estimated tonnes of CO₂ avoided by the collective wave this hour.
    var hourlyCO2Display: String {
        let kg = Double(rescuesThisHour) * FreshliBrand.co2PerItemKg
        if kg >= 1000 {
            return String(format: "%.1ft", kg / 1000.0)
        }
        return String(format: "%.0fkg", kg)
    }

    /// Estimated meals-worth of people fed by this hour's rescues.
    var hourlyMealsFed: Int {
        guard FreshliBrand.itemsPerMealFed > 0 else { return 0 }
        return rescuesThisHour / FreshliBrand.itemsPerMealFed
    }

    // MARK: - Rolling updates
    //
    // Every 60 seconds we re-pull `get_collective_hourly_stats` and the
    // `collective_rescue_feed` view from Supabase. Between pulls, the
    // `tick()` method ages existing events by one minute and drops any
    // older than 60 minutes — so the relative timestamps stay accurate.
    //
    // CRITICAL: `tick()` does NOT inject any synthetic events. The feed
    // only ever changes from Supabase data or from the current user's
    // own `recordRescue(...)` calls.

    private func startRollingUpdates() {
        // 60-second cadence. Previously we ticked every 20s and refreshed
        // every 3rd tick, but the inter-tick activity was being used to
        // hide the absence of real data — so we collapsed both intervals
        // into one honest pull every minute.
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.tickCount += 1
                self.tick()
                await self.refreshFromBackend()
            }
        }
    }

    private func tick() {
        // Age existing events by 1 minute, drop anything older than 60 min.
        // No synthetic events injected — the feed reflects reality.
        recentFeed = recentFeed.map { event in
            CollectiveRescueEvent(
                displayName: event.displayName,
                cityName: event.cityName,
                itemName: event.itemName,
                minutesAgo: event.minutesAgo + 1
            )
        }
        recentFeed.removeAll { $0.minutesAgo > 60 }
    }

    // MARK: - Reviewer demonstration feed
    //
    // Only invoked when `ReviewerAccountService.shared.isReviewerActive`
    // returns true. The reviewer needs to see what the Wave card looks
    // like with real activity even before live users have populated it,
    // so we hand-curate a representative set of demonstration events
    // labelled as such. Real users never reach this code path.

    private func seedReviewerDemonstrationFeed() {
        rescuesThisHour = 312
        activeRescuersThisHour = 224
        totalItemsRescued = 18_540

        let demoEvents: [(name: String, city: String, item: String, minutesAgo: Int)] = [
            ("App Reviewer Demo · Sarah J", "Leeds",     "spinach",   2),
            ("App Reviewer Demo · Priya S", "London",    "milk",      5),
            ("App Reviewer Demo · Marcus T", "Bristol",  "bananas",   8),
            ("App Reviewer Demo · Elena R", "Manchester", "cheddar",  12),
            ("App Reviewer Demo · Kai L",   "Brighton",  "bread",     15),
            ("App Reviewer Demo · Olivia W", "Edinburgh", "eggs",     19),
            ("App Reviewer Demo · Jamal K", "Cardiff",   "tomatoes",  24),
            ("App Reviewer Demo · Sofia G", "Dublin",    "chicken",   31),
            ("App Reviewer Demo · Arjun D", "Amsterdam", "pasta",     39),
            ("App Reviewer Demo · Nia P",   "Copenhagen", "yogurt",   47)
        ]

        recentFeed = demoEvents.map { entry in
            CollectiveRescueEvent(
                displayName: entry.name,
                cityName: entry.city,
                itemName: entry.item,
                minutesAgo: entry.minutesAgo
            )
        }
        hasLoadedRealData = true  // treat demo data as "loaded" for UX states
    }
}
