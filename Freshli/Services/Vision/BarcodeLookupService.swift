import Foundation
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - BarcodeLookupService
//
// Real product-database barcode lookup. Replaces the prior 3-product
// hardcoded dictionary with the Open Food Facts public database
// (https://world.openfoodfacts.org) — a free, no-auth, ~3.5 million
// product catalogue with permissive Open Database License terms.
//
// Pipeline:
//   1. AVFoundation reads the EAN/UPC barcode (handled by ScannerService).
//   2. This service hits  GET /api/v2/product/{barcode}.json
//   3. JSON response is decoded into ProductData (name, brand, category,
//      image, nutriscore — only the fields we use are decoded).
//   4. We map Open Food Facts categories to Freshli's `FoodCategory` /
//      `StorageLocation` taxonomy, estimate shelf life from category,
//      and return a `FreshliItem` ready to insert.
//
// Failure modes are explicit (.notFound, .networkUnavailable, .decodeError)
// so the UI can show the right empty / retry / fallback state instead of
// silently producing garbage.
//
// Privacy: no API key, no user identifier sent. Only the barcode digits
// reach the API. The User-Agent string is required by Open Food Facts'
// rate-limit policy and identifies us as the Freshli iOS app — no PII.
// ══════════════════════════════════════════════════════════════════

@Observable @MainActor
final class BarcodeLookupService {

    enum LookupError: LocalizedError, Sendable {
        case notFound
        case networkUnavailable
        case decodeError
        case rateLimited
        case unknown(String)

        var errorDescription: String? {
            switch self {
            case .notFound:
                return String(localized: "We couldn't find that barcode in the product database. You can still add the item manually.")
            case .networkUnavailable:
                return String(localized: "Couldn't reach the product database. Check your connection and try again.")
            case .decodeError:
                return String(localized: "The product database returned an unexpected response. Please add the item manually.")
            case .rateLimited:
                return String(localized: "Too many lookups in a short time. Wait a moment and try again.")
            case .unknown(let message):
                return message
            }
        }
    }

    private let session: URLSession
    private let logger = Logger(subsystem: "com.freshli.app", category: "BarcodeLookup")
    private let userAgent = "Freshli/1.0 iOS — https://freshli.app"

    /// In-memory cache keyed by barcode. Open Food Facts data updates
    /// rarely; one cache hit per session is good UX. Cleared on memory
    /// warning by the system since this is a class held in @State.
    private var cache: [String: FreshliItem] = [:]

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public API

    /// Look up a barcode in Open Food Facts. Returns a FreshliItem
    /// pre-filled with the product's name, category, storage, and a
    /// reasonable shelf-life estimate. The user can review/edit before
    /// saving — we never auto-insert silently.
    func lookup(barcode: String) async throws -> FreshliItem {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else { throw LookupError.notFound }
        guard trimmed.allSatisfy(\.isNumber) else { throw LookupError.notFound }

        // Cache hit
        if let cached = cache[trimmed] {
            logger.debug("Barcode cache hit for \(trimmed, privacy: .public)")
            return cached
        }

        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(trimmed).json?fields=product_name,brands,categories_tags,quantity,image_url,nutriscore_grade") else {
            throw LookupError.unknown("Invalid barcode URL")
        }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8.0

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlErr as URLError where urlErr.code == .notConnectedToInternet || urlErr.code == .networkConnectionLost {
            throw LookupError.networkUnavailable
        } catch {
            throw LookupError.unknown(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 { throw LookupError.rateLimited }
            if http.statusCode == 404 { throw LookupError.notFound }
            if !(200...299).contains(http.statusCode) {
                throw LookupError.unknown("Server returned \(http.statusCode)")
            }
        }

        let envelope: ProductEnvelope
        do {
            envelope = try JSONDecoder().decode(ProductEnvelope.self, from: data)
        } catch {
            logger.error("Decode failure: \(error.localizedDescription, privacy: .public)")
            throw LookupError.decodeError
        }

        // Open Food Facts returns status: 0 + status_verbose: "product not found"
        // when the barcode exists in the API but no record matches.
        guard envelope.status == 1, let product = envelope.product else {
            throw LookupError.notFound
        }

        let item = mapToFreshliItem(product: product, barcode: trimmed)
        cache[trimmed] = item
        logger.info("Barcode lookup success: \(item.name, privacy: .public) [\(trimmed, privacy: .public)]")
        return item
    }

    // MARK: - Mapping

    /// Map an Open Food Facts product → FreshliItem. The category mapping
    /// is intentionally conservative: when the OFF tags are ambiguous, we
    /// default to `.other` rather than guessing wrong.
    private func mapToFreshliItem(product: ProductPayload, barcode: String) -> FreshliItem {
        let name = displayName(from: product)
        let category = inferCategory(from: product.categoriesTags ?? [])
        let storage = preferredStorage(for: category)
        let shelfLifeDays = estimatedShelfLife(category: category, storage: storage)
        let unit = preferredUnit(for: category)

        return FreshliItem(
            name: name,
            category: category,
            storageLocation: storage,
            quantity: 1,
            unit: unit,
            expiryDate: Calendar.current.date(byAdding: .day, value: shelfLifeDays, to: Date()) ?? Date(),
            barcode: barcode,
            notes: product.brands?.split(separator: ",").first.map(String.init)
        )
    }

    private func displayName(from product: ProductPayload) -> String {
        // Prefer product_name. Fall back to "<brand> <quantity>" if missing.
        if let name = product.productName?.trimmingCharacters(in: .whitespaces),
           !name.isEmpty {
            return name
        }
        if let brand = product.brands?.split(separator: ",").first.map(String.init),
           let qty = product.quantity?.trimmingCharacters(in: .whitespaces),
           !qty.isEmpty {
            return "\(brand) — \(qty)"
        }
        return product.brands ?? String(localized: "Unnamed product")
    }

    /// Map Open Food Facts category tags (`en:dairies`, `en:fresh-foods`, etc.)
    /// to Freshli's `FoodCategory`. Only the most common roots are matched.
    /// Unknown tags fall through to `.other`.
    private func inferCategory(from tags: [String]) -> FoodCategory {
        let normalised = tags.map { $0.lowercased() }
        func has(_ keys: String...) -> Bool {
            keys.contains { key in normalised.contains { $0.contains(key) } }
        }

        if has("dairies", "milk", "cheese", "yogurt", "yoghurt", "butter") { return .dairy }
        if has("fruits", "fruit") { return .fruits }
        if has("vegetables", "vegetable", "leafy-vegetables") { return .vegetables }
        if has("meats", "beef", "pork", "chicken", "poultry", "lamb") { return .meat }
        if has("seafood", "fish", "salmon", "tuna", "shellfish") { return .seafood }
        if has("breads", "bread", "bakery", "pastry", "viennoiseries") { return .bakery }
        if has("frozen-foods", "frozen") { return .frozen }
        if has("canned-foods", "canned", "preserves", "tinned") { return .canned }
        if has("condiments", "sauces", "vinegars", "oils") { return .condiments }
        if has("snacks", "biscuits", "chocolates", "candy", "confectionery") { return .snacks }
        if has("beverages", "drinks", "waters", "juices", "sodas") { return .beverages }
        if has("cereals", "grains", "rice", "pastas", "pasta", "flours") { return .grains }
        return .other
    }

    private func preferredStorage(for category: FoodCategory) -> StorageLocation {
        switch category {
        case .dairy, .meat, .seafood:    return .fridge
        case .frozen:                    return .freezer
        case .fruits, .vegetables:       return .fridge   // safer default; user can change to counter
        case .bakery:                    return .counter
        case .canned, .grains,
             .condiments, .snacks,
             .beverages, .other:         return .pantry
        }
    }

    /// Conservative shelf-life defaults by category + storage. The user
    /// is shown the date and can adjust before saving.
    ///
    /// Storage-specific cases must be listed BEFORE the wildcard for the
    /// same category — Swift matches top-to-bottom. The wildcard at the
    /// end of each category bucket guarantees an exhaustive switch
    /// regardless of whether `preferredStorage(for:)` ever returns a
    /// non-fridge / non-freezer value for the perishable categories.
    private func estimatedShelfLife(category: FoodCategory, storage: StorageLocation) -> Int {
        switch (category, storage) {
        // Perishables — explicit per-storage tuning, then a fridge-equivalent fallback.
        case (.meat, .freezer):        return 120
        case (.meat, _):               return 3
        case (.seafood, .freezer):     return 90
        case (.seafood, _):            return 2
        case (.dairy, _):              return 14
        case (.beverages, .fridge):    return 14
        case (.beverages, _):          return 180

        // Storage-insensitive categories — the user can still change
        // storage in the form before saving; the shelf life doesn't
        // shift dramatically with location for these classes.
        case (.fruits, _):             return 7
        case (.vegetables, _):         return 7
        case (.bakery, _):             return 4
        case (.frozen, _):             return 90
        case (.canned, _):             return 365
        case (.grains, _):             return 365
        case (.condiments, _):         return 180
        case (.snacks, _):             return 60
        case (.other, _):              return 30
        }
    }

    private func preferredUnit(for category: FoodCategory) -> MeasurementUnit {
        switch category {
        case .meat, .seafood:                  return .grams
        case .dairy, .beverages:               return .liters
        case .fruits, .vegetables, .bakery,
             .frozen, .canned, .other:         return .pieces
        case .grains, .condiments, .snacks:    return .grams
        }
    }
}

// MARK: - Open Food Facts JSON shapes

private struct ProductEnvelope: Decodable {
    let status: Int
    let product: ProductPayload?
}

private struct ProductPayload: Decodable {
    let productName: String?
    let brands: String?
    let categoriesTags: [String]?
    let quantity: String?
    let imageUrl: String?
    let nutriscoreGrade: String?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
        case categoriesTags = "categories_tags"
        case quantity
        case imageUrl = "image_url"
        case nutriscoreGrade = "nutriscore_grade"
    }
}
