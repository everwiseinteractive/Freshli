import AppIntents
import Foundation
import Supabase

// MARK: - Freshli App Shortcuts Provider
// Registers all Freshli intents with Siri, Shortcuts app, and Spotlight.

struct FreshliShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogConsumedIntent(),
            phrases: [
                "Log food as consumed in \(.applicationName)",
                "Mark item as used in \(.applicationName)",
                "I finished something in \(.applicationName)"
            ],
            shortTitle: "Log Consumed",
            systemImageName: "checkmark.circle"
        )

        AppShortcut(
            intent: WhatsExpiringIntent(),
            phrases: [
                "What's expiring in \(.applicationName)",
                "Show expiring items in \(.applicationName)",
                "Check my \(.applicationName) expiring food"
            ],
            shortTitle: "What's Expiring",
            systemImageName: "clock.badge.exclamationmark"
        )

        AppShortcut(
            intent: ShareSurplusIntent(),
            phrases: [
                "Share food on \(.applicationName)",
                "List surplus in \(.applicationName) community",
                "Give away food with \(.applicationName)"
            ],
            shortTitle: "Share Surplus",
            systemImageName: "hand.raised.fill"
        )

        AppShortcut(
            intent: WhatsForDinnerIntent(),
            phrases: [
                "What's for dinner in \(.applicationName)",
                "Suggest a meal from \(.applicationName)",
                "Recipe ideas from \(.applicationName)"
            ],
            shortTitle: "What's for Dinner?",
            systemImageName: "fork.knife"
        )

        AppShortcut(
            intent: RescueMyPantryIntent(),
            phrases: [
                "Rescue my pantry with \(.applicationName)",
                "Ask \(.applicationName) for rescue recipes",
                "Save my food with \(.applicationName)",
                "What can I cook with \(.applicationName)"
            ],
            shortTitle: "Rescue My Pantry",
            systemImageName: "sparkles"
        )
    }
}

// MARK: - Helpers

/// Resolves the current authenticated Supabase user ID without launching the app.
private func currentUserId() async throws -> UUID {
    let session = try await AppSupabase.client.auth.session
    return session.user.id
}

// MARK: - Log Consumed Intent
// "Hey Siri, I finished the Milk with Freshli" → background Supabase update.

struct LogConsumedIntent: AppIntent {
    static var title: LocalizedStringResource { "Log Item as Consumed" }
    static var description: IntentDescription { "Mark a pantry item as consumed in Freshli." }
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Item Name")
    var itemName: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let userId = try await currentUserId()
        let service = FreshliSupabaseService()

        // Fetch active (not consumed) items for this user
        let allItems: [SupabaseFreshliItem] = try await AppSupabase.client
            .from("pantry_items")
            .select()
            .eq("user_id", value: userId)
            .eq("is_consumed", value: false)
            .execute()
            .value

        // Case-insensitive match on item name
        let searchName = itemName.lowercased()
        guard let match = allItems.first(where: { $0.name.lowercased() == searchName })
                ?? allItems.first(where: { $0.name.lowercased().contains(searchName) }) else {
            return .result(dialog: "Couldn't find \(itemName) in your pantry.")
        }

        try await service.markAsConsumed(id: match.id, userId: userId)
        return .result(dialog: "Done! Marked \(match.name) as consumed. Nice work reducing waste!")
    }
}

// MARK: - What's Expiring Intent
// Siri reads out top 3 items expiring today.

struct WhatsExpiringIntent: AppIntent {
    static var title: LocalizedStringResource { "What's Expiring" }
    static var description: IntentDescription { "Check which pantry items are expiring soon." }
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let userId = try await currentUserId()
        let service = FreshliSupabaseService()

        // Fetch items expiring within the next 1 day (today)
        let expiring = try await service.fetchExpiringItems(for: userId, within: 1)

        if expiring.isEmpty {
            return .result(dialog: "You have nothing expiring today. Your pantry is looking great!")
        }

        let top3 = expiring.prefix(3)
        let formatter = DateFormatter()
        formatter.dateStyle = .short

        let lines = top3.map { item -> String in
            let dateStr = formatter.string(from: item.expiryDate)
            return "\(item.name) (expires \(dateStr))"
        }
        let summary = lines.joined(separator: ", ")
        let remaining = expiring.count - top3.count

        var dialog = "Expiring soon: \(summary)."
        if remaining > 0 {
            dialog += " Plus \(remaining) more."
        }

        return .result(dialog: "\(dialog)")
    }
}

// MARK: - Share Surplus Intent
// "Hey Siri, share these Eggs on Freshli" → creates draft listing.

struct ShareSurplusIntent: AppIntent {
    static var title: LocalizedStringResource { "Share Surplus Food" }
    static var description: IntentDescription { "Share surplus food with the Freshli community." }
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Item Name")
    var itemName: String

    @Parameter(title: "Description", default: "Available for pickup")
    var itemDescription: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let userId = try await currentUserId()
        let listingService = ListingSupabaseService()
        let pantryService = FreshliSupabaseService()

        // Try to find the item in the user's pantry for metadata
        let allItems: [SupabaseFreshliItem] = try await AppSupabase.client
            .from("pantry_items")
            .select()
            .eq("user_id", value: userId)
            .eq("is_consumed", value: false)
            .eq("is_shared", value: false)
            .execute()
            .value

        let searchName = itemName.lowercased()
        let pantryMatch = allItems.first(where: { $0.name.lowercased() == searchName })
            ?? allItems.first(where: { $0.name.lowercased().contains(searchName) })

        let listing = SupabaseListing(
            id: UUID(),
            userId: userId,
            itemName: pantryMatch?.name ?? itemName,
            itemDescription: itemDescription,
            quantity: pantryMatch.map { "\(Int($0.quantity)) \($0.unit)" },
            listingType: "share",
            status: "active",
            datePosted: Date(),
            expiryDate: pantryMatch?.expiryDate,
            foodCategory: pantryMatch?.category
        )

        let created = try await listingService.createListing(listing)

        // If we matched a pantry item, mark it as shared
        if let match = pantryMatch {
            try await pantryService.markAsShared(id: match.id, userId: userId)
        }

        return .result(dialog: "Shared \(created.itemName) with the Freshli community! Others nearby can now claim it.")
    }
}

// MARK: - Rescue My Pantry Intent
//
// "Hey Siri, rescue my pantry" — invokes the FoundationModels Rescue
// Chef entirely on-device, with zero network round-trip. Pulls the
// user's at-risk items from Supabase, hands them to AIRescueService
// as PantrySnapshots, and reads back the first (best-ranked) recipe
// as a Siri dialog. Falls back gracefully if Apple Intelligence is
// unavailable on this device.
//
// This is the flagship iOS 26 feature's voice surface — the same
// on-device LLM that powers the in-app "Ask Freshli" button, now
// available from Siri, the Shortcuts app, Spotlight, and Control
// Center custom shortcuts.

struct RescueMyPantryIntent: AppIntent {
    static var title: LocalizedStringResource { "Rescue My Pantry" }
    static var description: IntentDescription {
        IntentDescription(
            "Ask Freshli's on-device Rescue Chef to suggest recipes for the items in your pantry that are about to expire.",
            categoryName: "Freshli Recipes"
        )
    }
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let userId = try await currentUserId()
        let service = FreshliSupabaseService()

        // Grab everything expiring in the next 48 hours — matches the
        // same window the in-app Rescue Chef uses.
        let expiring = try await service.fetchExpiringItems(for: userId, within: 2)

        guard !expiring.isEmpty else {
            return .result(dialog: "Your pantry is in great shape — nothing's about to expire. Freshli will let you know when anything needs rescuing.")
        }

        // Map Supabase DTOs → PantrySnapshot value types so the AI
        // service can work without a SwiftData context (App Intents
        // run in a headless extension process).
        let snapshots = expiring.map { dto in
            PantrySnapshot(
                name: dto.name,
                quantity: dto.quantity,
                unit: dto.unit,
                expiryDate: dto.expiryDate
            )
        }

        do {
            let response = try await AIRescueService.shared.generateMissions(fromSnapshots: snapshots)
            guard let top = response.missions.first else {
                return .result(dialog: "Rescue Chef couldn't think of anything this time. Try again in a moment.")
            }

            // Format the top recipe as a spoken Siri dialog. Read the
            // title, the first two steps, and the items used so Siri
            // gives a useful answer in under ~15 seconds of speech.
            // The user can tap through to the app for the full recipe.
            let itemsUsed = top.usedItems.prefix(3).joined(separator: ", ")
            let firstSteps = top.steps.prefix(2).joined(separator: " Then ")
            let dialog = """
            Rescue Chef suggests \(top.title). \
            It uses \(itemsUsed). \
            \(firstSteps) \
            Open Freshli for the full recipe.
            """
            return .result(dialog: "\(dialog)")
        } catch AIRescueError.apiUnavailable {
            return .result(dialog: "Apple Intelligence isn't available on this device yet. Open Freshli to see recipe ideas from our rule-based Rescue Chef.")
        } catch {
            return .result(dialog: "Rescue Chef ran into a problem cooking up ideas. Please try again in a moment.")
        }
    }
}
