import Foundation
import SwiftUI
import Observation

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

    /// Global rolling counter — how many rescues happened in the last 60 min.
    private(set) var rescuesThisHour: Int = 0

    /// Running count of active rescuers in the last hour (distinct users).
    private(set) var activeRescuersThisHour: Int = 0

    /// Live feed of the most recent anonymised rescue events.
    private(set) var recentFeed: [CollectiveRescueEvent] = []

    /// Total impact since the app's launch day (in-memory for now).
    private(set) var totalItemsRescued: Int = 0

    private var timer: Timer?

    private init() {
        seedSimulatedFeed()
        startRollingUpdates()
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
        rescuesThisHour / FreshliBrand.itemsPerMealFed
    }

    // MARK: - Simulation (until Supabase is wired up)

    /// Seed the feed with realistic anonymised events on startup so the
    /// first-time user sees a bustling community instead of an empty feed.
    private func seedSimulatedFeed() {
        // A realistic base number so the counter doesn't start at 0.
        rescuesThisHour = Int.random(in: 280...420)
        activeRescuersThisHour = Int(Double(rescuesThisHour) * 0.72)
        totalItemsRescued = Int.random(in: 14_000...28_000)

        let items = ["spinach", "milk", "bananas", "cheddar", "bread", "eggs",
                     "tomatoes", "chicken", "pasta", "yogurt", "apples",
                     "lettuce", "carrots", "salmon", "berries", "peppers"]
        let names = ["Sarah J", "Priya S", "Marcus T", "Elena R", "Kai L",
                     "Olivia W", "Jamal K", "Sofia G", "Arjun D", "Nia P",
                     "Takeshi M", "Zoe B", "Luca F", "Aminata K", "Finn H"]
        let cities = ["Leeds", "London", "Bristol", "Manchester", "Brighton",
                      "Edinburgh", "Cardiff", "Dublin", "Amsterdam", "Copenhagen",
                      "Porto", "Lisbon", "Berlin", "Lyon", "Barcelona"]

        var feed: [CollectiveRescueEvent] = []
        for i in 0..<10 {
            feed.append(CollectiveRescueEvent(
                displayName: names.randomElement() ?? "A neighbour",
                cityName: cities.randomElement() ?? "nearby",
                itemName: items.randomElement() ?? "food",
                minutesAgo: i * 2 + Int.random(in: 0...2)
            ))
        }
        recentFeed = feed
    }

    /// Every 20 seconds, simulate a new rescue happening somewhere in the
    /// network to keep the ticker feeling alive.
    private func startRollingUpdates() {
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    private func tick() {
        // Age existing events by 1 minute
        recentFeed = recentFeed.map { event in
            CollectiveRescueEvent(
                displayName: event.displayName,
                cityName: event.cityName,
                itemName: event.itemName,
                minutesAgo: event.minutesAgo + 1
            )
        }

        // Drop events older than 60 minutes
        recentFeed.removeAll { $0.minutesAgo > 60 }

        // Inject a new simulated rescue roughly every tick
        let items = ["spinach", "milk", "bananas", "cheddar", "bread", "eggs",
                     "tomatoes", "chicken", "pasta", "yogurt", "lentils"]
        let names = ["Oscar L", "Amara N", "Wren K", "Tariq S", "Isla B",
                     "Nikhil R", "Yuki T", "Eliora M", "Kofi A", "Maeve D"]
        let cities = ["Leeds", "London", "Bristol", "Manchester", "Brighton",
                      "Edinburgh", "Dublin", "Amsterdam", "Berlin", "Barcelona"]

        let newEvent = CollectiveRescueEvent(
            displayName: names.randomElement() ?? "A neighbour",
            cityName: cities.randomElement() ?? "nearby",
            itemName: items.randomElement() ?? "food",
            minutesAgo: 0
        )
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
            recentFeed.insert(newEvent, at: 0)
            if recentFeed.count > 20 {
                recentFeed.removeLast()
            }
            rescuesThisHour += 1
            totalItemsRescued += 1
        }
    }
}
