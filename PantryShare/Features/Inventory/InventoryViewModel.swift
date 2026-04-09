import SwiftUI
import Observation
import Combine

// MARK: - Inventory ViewModel

@Observable
final class InventoryViewModel {

    // MARK: - Published State

    var items: [SupabaseFreshliItem] = []
    var filteredItems: [SupabaseFreshliItem] = []
    var selectedCategory: FoodCategory?
    var searchText: String = ""
    var sortOrder: SortOrder = .expiryAscending
    var isLoading = false
    var errorMessage: String?
    var selectedItemId: UUID?
    var showDetail = false

    // MARK: - Swipe Action State

    var consumedItemId: UUID?
    var sharedItemId: UUID?
    var showConfetti = false
    var showSharePreview = false

    // MARK: - Freshness Score

    /// Average freshness ratio across all items (0.0 = all expired, 1.0 = all fresh)
    var averageFreshness: Double {
        guard !items.isEmpty else { return 1.0 }
        let now = Date()
        let ratios = items.compactMap { item -> Double? in
            guard !item.isConsumed && !item.isShared && !item.isDonated else { return nil }
            let totalLife = item.expiryDate.timeIntervalSince(item.dateAdded)
            guard totalLife > 0 else { return 0 }
            let remaining = item.expiryDate.timeIntervalSince(now)
            return max(0, min(1, remaining / totalLife))
        }
        guard !ratios.isEmpty else { return 1.0 }
        return ratios.reduce(0, +) / Double(ratios.count)
    }

    // MARK: - Sort Order

    enum SortOrder: String, CaseIterable, Identifiable {
        case expiryAscending = "Expiring Soon"
        case expiryDescending = "Freshest First"
        case nameAscending = "A–Z"
        case nameDescending = "Z–A"
        case categoryGrouped = "Category"

        var id: String { rawValue }
    }

    // MARK: - Dependencies

    private let pantryService = FreshliSupabaseService()
    private let hapticService = HapticHarvestService.shared
    private var userId: UUID?

    // MARK: - Init

    init() {}

    // MARK: - Data Loading

    func loadItems(userId: UUID) async {
        self.userId = userId
        isLoading = true
        errorMessage = nil
        do {
            items = try await pantryService.fetchItems(for: userId)
            applyFilters()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        guard let userId else { return }
        await loadItems(userId: userId)
    }

    // MARK: - Filtering & Sorting

    func applyFilters() {
        var result = items.filter { !$0.isConsumed && !$0.isShared && !$0.isDonated }

        // Category filter
        if let category = selectedCategory {
            result = result.filter { $0.category.lowercased() == category.rawValue.lowercased() }
        }

        // Search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { $0.name.lowercased().contains(query) }
        }

        // Sort
        switch sortOrder {
        case .expiryAscending:
            result.sort { $0.expiryDate < $1.expiryDate }
        case .expiryDescending:
            result.sort { $0.expiryDate > $1.expiryDate }
        case .nameAscending:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDescending:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .categoryGrouped:
            result.sort {
                if $0.category == $1.category {
                    return $0.expiryDate < $1.expiryDate
                }
                return $0.category < $1.category
            }
        }

        filteredItems = result
    }

    func setCategory(_ category: FoodCategory?) {
        selectedCategory = category
        applyFilters()
    }

    func setSearch(_ text: String) {
        searchText = text
        applyFilters()
    }

    func setSort(_ order: SortOrder) {
        sortOrder = order
        applyFilters()
    }

    // MARK: - Swipe Actions

    func markConsumed(_ item: SupabaseFreshliItem) async {
        guard let userId else { return }
        consumedItemId = item.id

        // Haptic celebration
        hapticService.harvestCelebration()

        // Trigger confetti
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showConfetti = true
        }

        do {
            try await pantryService.markAsConsumed(id: item.id, userId: userId)
            // Remove from local array after animation
            try? await Task.sleep(for: .milliseconds(600))
            withAnimation(.easeInOut(duration: 0.35)) {
                items.removeAll { $0.id == item.id }
                applyFilters()
            }
        } catch {
            errorMessage = "Failed to mark as consumed"
        }

        // Reset confetti after delay
        try? await Task.sleep(for: .seconds(2))
        showConfetti = false
        consumedItemId = nil
    }

    func markShared(_ item: SupabaseFreshliItem) async {
        guard let userId else { return }
        sharedItemId = item.id

        // Gentle haptic
        PSHaptics.shared.selection()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showSharePreview = true
        }

        do {
            try await pantryService.markAsShared(id: item.id, userId: userId)
            try? await Task.sleep(for: .milliseconds(800))
            withAnimation(.easeInOut(duration: 0.35)) {
                items.removeAll { $0.id == item.id }
                applyFilters()
            }
        } catch {
            errorMessage = "Failed to share item"
        }

        try? await Task.sleep(for: .seconds(1))
        showSharePreview = false
        sharedItemId = nil
    }

    // MARK: - Item Selection

    func selectItem(_ item: SupabaseFreshliItem) {
        selectedItemId = item.id
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            showDetail = true
        }
    }

    func dismissDetail() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            showDetail = false
        }
        // Small delay so matchedGeometry animates back
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.selectedItemId = nil
        }
    }

    // MARK: - Helpers

    func expiryStatus(for item: SupabaseFreshliItem) -> ExpiryStatus {
        ExpiryStatus.from(expiryDate: item.expiryDate)
    }

    func freshnessRatio(for item: SupabaseFreshliItem) -> Double {
        let totalLife = item.expiryDate.timeIntervalSince(item.dateAdded)
        guard totalLife > 0 else { return 0 }
        let remaining = item.expiryDate.timeIntervalSince(Date())
        return max(0, min(1, remaining / totalLife))
    }

    func categoryEnum(for item: SupabaseFreshliItem) -> FoodCategory {
        FoodCategory(rawValue: item.category.lowercased()) ?? .other
    }
}
