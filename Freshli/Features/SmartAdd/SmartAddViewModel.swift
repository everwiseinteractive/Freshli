import SwiftUI
import SwiftData

/// Central state for the Smart Add flow — coordinates live scanning,
/// AI parsing, manual search, and saving to SwiftData.
@Observable
final class SmartAddViewModel {

    // MARK: - State

    enum ScanState: Equatable {
        case idle
        case scanning
        case parsing
    }

    var scanState: ScanState = .idle
    var pendingItems: [ParsedFoodItem] = []
    var searchQuery = ""
    var searchSuggestions: [FreshliParserService.FoodSuggestion] = []
    var isTrayExpanded = false

    /// Tracks IDs of items already surfaced so we don't re-add duplicates from the scanner.
    private var discoveredNames = Set<String>()

    /// Debounce timer for recognized text bursts.
    private var parseTask: Task<Void, Never>?

    private let parser = FreshliParserService()

    // MARK: - Scanner Callbacks

    /// Called by the LiveScannerView each time new text is recognized.
    func handleRecognizedTexts(_ texts: [String]) {
        // Debounce rapid-fire updates from the scanner
        parseTask?.cancel()
        parseTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await parseTexts(texts)
        }
    }

    @MainActor
    private func parseTexts(_ texts: [String]) async {
        scanState = .parsing
        let items = await parser.parse(recognizedTexts: texts)

        for item in items where !discoveredNames.contains(item.name) {
            discoveredNames.insert(item.name)
            withAnimation(PSMotion.springBouncy) {
                pendingItems.append(item)
                isTrayExpanded = true
            }
            // Haptic per newly discovered item
            PSHaptics.shared.lightTap()

            // Small stagger between items appearing
            try? await Task.sleep(for: .milliseconds(120))
        }

        scanState = .scanning
    }

    // MARK: - Manual Search

    func updateSearchSuggestions() {
        searchSuggestions = parser.suggestions(for: searchQuery)
    }

    func addFromSuggestion(_ suggestion: FreshliParserService.FoodSuggestion) {
        guard !discoveredNames.contains(suggestion.name) else { return }
        discoveredNames.insert(suggestion.name)

        let item = ParsedFoodItem(
            id: UUID(),
            name: suggestion.name,
            category: suggestion.category,
            storageLocation: suggestion.storage,
            estimatedExpiryDays: suggestion.expiryDays,
            quantity: 1,
            unit: suggestion.unit,
            confidence: 1.0
        )

        withAnimation(PSMotion.springBouncy) {
            pendingItems.append(item)
            isTrayExpanded = true
        }
        PSHaptics.shared.lightTap()
        searchQuery = ""
        searchSuggestions = []
    }

    // MARK: - Item Management

    func removeItem(_ item: ParsedFoodItem) {
        withAnimation(PSMotion.springDefault) {
            pendingItems.removeAll { $0.id == item.id }
            discoveredNames.remove(item.name)
        }
    }

    func removeItem(at offsets: IndexSet) {
        for index in offsets {
            let item = pendingItems[index]
            discoveredNames.remove(item.name)
        }
        withAnimation(PSMotion.springDefault) {
            pendingItems.remove(atOffsets: offsets)
        }
    }

    /// Save all pending items to SwiftData and return the count saved.
    @discardableResult
    func saveAllItems(modelContext: ModelContext) -> Int {
        let count = pendingItems.count
        for parsed in pendingItems {
            let pantryItem = FreshliItem(
                name: parsed.name,
                category: parsed.category,
                storageLocation: parsed.storageLocation,
                quantity: parsed.quantity,
                unit: parsed.unit,
                expiryDate: parsed.estimatedExpiryDate,
                barcode: nil,
                notes: nil
            )
            modelContext.insert(pantryItem)
        }

        try? modelContext.save()

        pendingItems.removeAll()
        discoveredNames.removeAll()
        return count
    }

    func reset() {
        parseTask?.cancel()
        pendingItems.removeAll()
        discoveredNames.removeAll()
        searchQuery = ""
        searchSuggestions = []
        scanState = .idle
        isTrayExpanded = false
    }
}
