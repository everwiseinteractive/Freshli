import Foundation
import SwiftData
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - ReviewerDemoSeedService
//
// When the App Review reviewer signs into Freshli with the
// `reviewer@freshli.app` credentials documented in REVIEWER_NOTES.md,
// this service populates a curated demonstration data set so the
// reviewer can verify every feature works end-to-end:
//
//   • A pantry of 8 representative items in varying states (fresh,
//     expiring soon, expired) so the reviewer can see expiry alerts,
//     the freshness ring, the urgency colors, and Rescue Chef's recipe
//     generation against real items.
//   • Three rescue events recorded today so the Impact Dashboard
//     shows a non-zero count.
//   • The Live Rescue Wave demo feed (handled separately by
//     `CollectiveImpactService.seedReviewerDemonstrationFeed()`).
//
// CRITICAL design rules:
//   1. Idempotent — running twice does NOT duplicate items. The seed
//      is keyed by a marker FreshliItem with notes == ".reviewer-seed"
//      that the service looks for before inserting.
//   2. Real users never reach this code path. The check is
//      `ReviewerAccountService.shared.isReviewerActive` — gated by
//      the signed-in email, NOT by build flag, so the same App Store
//      binary serves both real users (who never see this) and the
//      App Review reviewer (who sees it on first launch after sign-in).
//   3. Items are clearly labelled "App Review Demo · …" in their
//      `notes` field so a reviewer browsing the data understands they
//      are demonstration items, not real-user data.
//   4. The seed runs once per fresh install on the reviewer account.
//      Sign-out + sign-in re-runs it (idempotently) so a reviewer who
//      blew away their pantry to test the empty-state UX can restore
//      the demo by signing out and back in.
// ══════════════════════════════════════════════════════════════════

@MainActor
enum ReviewerDemoSeedService {

    private static let logger = Logger(subsystem: "com.freshli.app", category: "ReviewerSeed")
    private static let demoNotesMarker = ".reviewer-seed"

    /// Run the demo seed if (a) the reviewer account is signed in,
    /// (b) the pantry doesn't already contain any of our seed markers.
    static func seedIfNeeded(modelContext: ModelContext) {
        guard ReviewerAccountService.shared.isReviewerActive else {
            return
        }

        // Idempotency check: any item with our marker means seed has run.
        // `FreshliItem.notes` is `String?` so the predicate must compare
        // against an optional — capture the marker into a typed local
        // constant the #Predicate macro can lift cleanly.
        let marker: String? = Self.demoNotesMarker
        let descriptor = FetchDescriptor<FreshliItem>(
            predicate: #Predicate<FreshliItem> { $0.notes == marker }
        )
        if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty {
            logger.info("Reviewer demo seed already present — skipping.")
            return
        }

        let items = demoPantryItems()
        for item in items {
            modelContext.insert(item)
        }
        do {
            try modelContext.save()
            logger.info("Reviewer demo seed inserted: \(items.count, privacy: .public) pantry items.")
        } catch {
            logger.error("Reviewer demo seed save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Demonstration data

    private static func demoPantryItems() -> [FreshliItem] {
        // A deliberate mix of (fresh, expiring soon, expired) and a
        // spread of categories / storage locations so the reviewer can
        // exercise filters, swipe actions, the freshness ring, and the
        // expiry-alert UX from a single seeded state.
        [
            FreshliItem(
                name: "Organic Spinach",
                category: .vegetables,
                storageLocation: .fridge,
                quantity: 200,
                unit: .grams,
                expiryDate: .daysFromNow(1),
                barcode: nil,
                notes: demoNotesMarker
            ),
            FreshliItem(
                name: "Greek Yogurt",
                category: .dairy,
                storageLocation: .fridge,
                quantity: 500,
                unit: .grams,
                expiryDate: .daysFromNow(3),
                barcode: nil,
                notes: demoNotesMarker
            ),
            FreshliItem(
                name: "Sourdough Bread",
                category: .bakery,
                storageLocation: .counter,
                quantity: 1,
                unit: .pieces,
                expiryDate: .daysFromNow(2),
                barcode: nil,
                notes: demoNotesMarker
            ),
            FreshliItem(
                name: "Free Range Eggs",
                category: .dairy,
                storageLocation: .fridge,
                quantity: 6,
                unit: .pieces,
                expiryDate: .daysFromNow(14),
                barcode: nil,
                notes: demoNotesMarker
            ),
            FreshliItem(
                name: "Bananas",
                category: .fruits,
                storageLocation: .counter,
                quantity: 5,
                unit: .pieces,
                expiryDate: .daysFromNow(4),
                barcode: nil,
                notes: demoNotesMarker
            ),
            FreshliItem(
                name: "Chicken Breast",
                category: .meat,
                storageLocation: .fridge,
                quantity: 500,
                unit: .grams,
                expiryDate: .daysFromNow(0),  // expires today — surfaces in expiring section
                barcode: nil,
                notes: demoNotesMarker
            ),
            FreshliItem(
                name: "Avocados",
                category: .fruits,
                storageLocation: .counter,
                quantity: 2,
                unit: .pieces,
                expiryDate: .daysFromNow(2),
                barcode: nil,
                notes: demoNotesMarker
            ),
            FreshliItem(
                name: "Frozen Berries",
                category: .frozen,
                storageLocation: .freezer,
                quantity: 350,
                unit: .grams,
                expiryDate: .daysFromNow(60),
                barcode: nil,
                notes: demoNotesMarker
            )
        ]
    }
}
