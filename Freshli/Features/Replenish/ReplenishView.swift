import SwiftUI
import UniformTypeIdentifiers

// MARK: - Freshli Replenish View
// Smart shopping list that auto-populates when items are consumed/wasted.
// Features: Needed tab, Budget Tracker, Drag-and-Drop from recipes,
// Link Previews, Purchase with Delivery.

@Observable @MainActor
final class ReplenishViewModel {
    var service = ReplenishService()
    var showAddItemSheet = false
    var showDeliverySheet = false
    var selectedItem: ReplenishItem?
    var selectedTab: ReplenishTab = .needed
    var searchText = ""

    enum ReplenishTab: String, CaseIterable {
        case needed = "Needed"
        case purchased = "Purchased"

        var icon: String {
            switch self {
            case .needed: return "cart.fill"
            case .purchased: return "checkmark.circle.fill"
            }
        }
    }

    var filteredNeededItems: [ReplenishItem] {
        let items = service.neededItems
        guard !searchText.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var filteredPurchasedItems: [ReplenishItem] {
        let items = service.purchasedItems
        guard !searchText.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    func deleteItem(_ item: ReplenishItem) {
        service.removeItem(id: item.id)
    }

    func togglePurchased(_ item: ReplenishItem) {
        service.togglePurchased(id: item.id)
    }

    func toggleUrgent(_ item: ReplenishItem) {
        service.toggleUrgent(id: item.id)
    }

    func openDelivery(for item: ReplenishItem) {
        selectedItem = item
        showDeliverySheet = true
    }
}

// MARK: - Main View

struct ReplenishView: View {
    @State private var viewModel = ReplenishViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Budget Tracker
                BudgetTrackerView(summary: viewModel.service.budgetSummary)
                    .padding(.horizontal, PSSpacing.screenHorizontal)
                    .padding(.top, PSSpacing.lg)

                // Tab Selector
                tabSelector
                    .padding(.top, PSSpacing.lg)

                // Search
                searchBar
                    .padding(.horizontal, PSSpacing.screenHorizontal)
                    .padding(.top, PSSpacing.md)

                // Content
                if viewModel.service.items.isEmpty {
                    emptyState
                        .padding(.top, PSSpacing.xxxl)
                    Spacer()
                } else {
                    itemList
                }
            }
            .background(PSColors.backgroundPrimary)
            .navigationTitle("Freshli Replenish")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: PSSpacing.sm) {
                        if !viewModel.service.purchasedItems.isEmpty {
                            Button(action: {
                                PSHaptics.shared.mediumTap()
                                viewModel.service.archivePurchasedItems()
                            }) {
                                Image(systemName: "archivebox.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(PSColors.textSecondary)
                            }
                        }

                        Button(action: { viewModel.showAddItemSheet = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(PSColors.primaryGreen)
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddItemSheet) {
                AddReplenishItemSheet(viewModel: viewModel)
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $viewModel.selectedItem) { item in
                ReplenishDeliverySheet(item: item)
                    .presentationDragIndicator(.visible)
            }
            // Drop target for recipe ingredients
            .dropDestination(for: ReplenishIngredientTransfer.self) { ingredients, _ in
                viewModel.service.addRecipeIngredients(ingredients)
                PSHaptics.shared.success()
                return true
            }
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: PSSpacing.sm) {
            ForEach(ReplenishViewModel.ReplenishTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(PSMotion.springQuick) {
                        viewModel.selectedTab = tab
                    }
                    PSHaptics.shared.lightTap()
                } label: {
                    HStack(spacing: PSSpacing.xs) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12, weight: .semibold))

                        Text(tab.rawValue)
                            .font(PSTypography.caption1Medium)

                        // Item count badge
                        let count = tab == .needed
                            ? viewModel.service.neededItems.count
                            : viewModel.service.purchasedItems.count
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    viewModel.selectedTab == tab
                                        ? PSColors.primaryGreen
                                        : PSColors.textTertiary
                                )
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    viewModel.selectedTab == tab
                                        ? PSColors.primaryGreen.opacity(0.15)
                                        : PSColors.backgroundSecondary
                                )
                                .clipShape(Capsule())
                        }
                    }
                    .foregroundStyle(
                        viewModel.selectedTab == tab
                            ? PSColors.primaryGreen
                            : PSColors.textSecondary
                    )
                    .padding(.horizontal, PSSpacing.lg)
                    .padding(.vertical, PSSpacing.sm)
                    .background(
                        viewModel.selectedTab == tab
                            ? PSColors.primaryGreen.opacity(0.12)
                            : Color.clear
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, PSSpacing.screenHorizontal)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: PSSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(PSColors.textTertiary)

            TextField("Search items...", text: $viewModel.searchText)
                .font(PSTypography.callout)
                .foregroundStyle(PSColors.textPrimary)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(PSColors.textTertiary)
                }
            }
        }
        .padding(.horizontal, PSSpacing.md)
        .padding(.vertical, PSSpacing.sm)
        .background(PSColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd))
    }

    // MARK: - Item List

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: PSSpacing.md) {
                switch viewModel.selectedTab {
                case .needed:
                    // Urgent items first
                    let urgentItems = viewModel.filteredNeededItems.filter(\.isUrgent)
                    let regularItems = viewModel.filteredNeededItems.filter { !$0.isUrgent }

                    if !urgentItems.isEmpty {
                        sectionHeader("Urgent", icon: "flame.fill", tint: PSColors.warningAmber)

                        ForEach(urgentItems) { item in
                            ReplenishItemRow(
                                item: item,
                                onTogglePurchased: { viewModel.togglePurchased(item) },
                                onToggleUrgent: { viewModel.toggleUrgent(item) },
                                onDelete: { viewModel.deleteItem(item) },
                                onDelivery: { viewModel.openDelivery(for: item) }
                            )
                            .transition(PSMotion.fadeSlide)
                        }
                    }

                    if !regularItems.isEmpty {
                        if !urgentItems.isEmpty {
                            sectionHeader("Other Items", icon: "cart", tint: PSColors.textSecondary)
                        }

                        ForEach(regularItems) { item in
                            ReplenishItemRow(
                                item: item,
                                onTogglePurchased: { viewModel.togglePurchased(item) },
                                onToggleUrgent: { viewModel.toggleUrgent(item) },
                                onDelete: { viewModel.deleteItem(item) },
                                onDelivery: { viewModel.openDelivery(for: item) }
                            )
                            .transition(PSMotion.fadeSlide)
                        }
                    }

                    if viewModel.filteredNeededItems.isEmpty && !viewModel.searchText.isEmpty {
                        noSearchResults
                    }

                case .purchased:
                    ForEach(viewModel.filteredPurchasedItems) { item in
                        ReplenishItemRow(
                            item: item,
                            onTogglePurchased: { viewModel.togglePurchased(item) },
                            onToggleUrgent: { viewModel.toggleUrgent(item) },
                            onDelete: { viewModel.deleteItem(item) },
                            onDelivery: { viewModel.openDelivery(for: item) }
                        )
                    }

                    if viewModel.filteredPurchasedItems.isEmpty && !viewModel.searchText.isEmpty {
                        noSearchResults
                    }
                }
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.vertical, PSSpacing.lg)
            .animation(PSMotion.springDefault, value: viewModel.service.items.map(\.id))
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: PSSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)

            Text(title)
                .font(PSTypography.footnoteMedium)
                .foregroundStyle(tint)

            Spacer()
        }
        .padding(.top, PSSpacing.sm)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        PSEmptyState(
            icon: "arrow.triangle.2.circlepath",
            title: "Freshli Replenish",
            message: "Items appear here automatically when you consume or waste pantry items. You can also drag recipe ingredients here.",
            actionTitle: "Add Item",
            action: { viewModel.showAddItemSheet = true }
        )
        .padding(.horizontal, PSSpacing.screenHorizontal)
    }

    private var noSearchResults: some View {
        VStack(spacing: PSSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(PSColors.textTertiary)

            Text("No items match \"\(viewModel.searchText)\"")
                .font(PSTypography.callout)
                .foregroundStyle(PSColors.textSecondary)
        }
        .padding(.top, PSSpacing.xxxl)
    }
}

// MARK: - Replenish Item Row

struct ReplenishItemRow: View {
    let item: ReplenishItem
    let onTogglePurchased: () -> Void
    let onToggleUrgent: () -> Void
    let onDelete: () -> Void
    let onDelivery: () -> Void

    var body: some View {
        PSCard {
            VStack(spacing: PSSpacing.md) {
                // Main row
                HStack(spacing: PSSpacing.md) {
                    // Check button
                    Button(action: {
                        PSHaptics.shared.mediumTap()
                        onTogglePurchased()
                    }) {
                        Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(item.isPurchased ? PSColors.primaryGreen : PSColors.textTertiary)
                    }

                    // Item info
                    VStack(alignment: .leading, spacing: PSSpacing.xs) {
                        Text(item.name)
                            .font(PSTypography.calloutMedium)
                            .foregroundStyle(item.isPurchased ? PSColors.textTertiary : PSColors.textPrimary)
                            .strikethrough(item.isPurchased)

                        HStack(spacing: PSSpacing.sm) {
                            Text("\(String(format: "%.1f", item.quantity)) \(item.unit)")
                                .font(PSTypography.caption1)
                                .foregroundStyle(PSColors.textSecondary)

                            sourceBadge
                        }
                    }

                    Spacer()

                    // Price & actions
                    VStack(alignment: .trailing, spacing: PSSpacing.xs) {
                        if item.isUrgent {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(PSColors.warningAmber)
                        }

                        if let price = item.estimatedPrice {
                            Text(String(format: "$%.2f", price))
                                .font(PSTypography.caption1Medium)
                                .foregroundStyle(PSColors.primaryGreen)
                        }

                        Menu {
                            Button(action: onDelivery) {
                                Label("Purchase with Delivery", systemImage: "shippingbox.fill")
                            }

                            Button(action: {
                                PSHaptics.shared.lightTap()
                                onToggleUrgent()
                            }) {
                                Label(
                                    item.isUrgent ? "Remove Urgent" : "Mark Urgent",
                                    systemImage: item.isUrgent ? "flame.fill" : "flame"
                                )
                            }

                            Divider()

                            Button(role: .destructive, action: {
                                PSHaptics.shared.heavyTap()
                                onDelete()
                            }) {
                                Label("Remove", systemImage: "trash.fill")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(PSColors.textTertiary)
                                .frame(width: 28, height: 28)
                        }
                    }
                }

                // Price comparison bar (when both prices available)
                if let estimated = item.estimatedPrice, let lastPaid = item.lastPricePaid, !item.isPurchased {
                    priceComparisonBar(estimated: estimated, lastPaid: lastPaid)
                }
            }
        }
        .draggable(item)
    }

    // MARK: - Source Badge

    @ViewBuilder
    private var sourceBadge: some View {
        let tint: Color = switch item.source {
        case .consumed: PSColors.primaryGreen
        case .wasted: PSColors.expiredRed
        case .lowStock: PSColors.warningAmber
        case .recipe: PSColors.accentTeal
        case .manual: PSColors.infoBlue
        }

        HStack(spacing: PSSpacing.xxxs) {
            Image(systemName: item.source.icon)
                .font(.system(size: 8))
            Text(item.source.displayName)
                .font(PSTypography.caption2)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Price Comparison

    private func priceComparisonBar(estimated: Double, lastPaid: Double) -> some View {
        HStack(spacing: PSSpacing.sm) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.system(size: 10))
                .foregroundStyle(PSColors.textTertiary)

            Text("Est.")
                .font(PSTypography.caption2)
                .foregroundStyle(PSColors.textTertiary)

            Text(String(format: "$%.2f", estimated))
                .font(PSTypography.caption2Medium)
                .foregroundStyle(PSColors.primaryGreen)

            Text("vs")
                .font(PSTypography.caption2)
                .foregroundStyle(PSColors.textTertiary)

            Text("Last")
                .font(PSTypography.caption2)
                .foregroundStyle(PSColors.textTertiary)

            Text(String(format: "$%.2f", lastPaid))
                .font(PSTypography.caption2Medium)
                .foregroundStyle(PSColors.textSecondary)

            Spacer()

            let diff = estimated - lastPaid
            if diff != 0 {
                Text(String(format: "%@%.0f%%", diff < 0 ? "" : "+", (diff / lastPaid) * 100))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(diff < 0 ? PSColors.primaryGreen : PSColors.expiredRed)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((diff < 0 ? PSColors.primaryGreen : PSColors.expiredRed).opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(.top, PSSpacing.xs)
    }
}

// MARK: - Add Replenish Item Sheet

private struct AddReplenishItemSheet: View {
    let viewModel: ReplenishViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var quantity = "1"
    @State private var unit = "pieces"
    @State private var category = "other"
    @State private var estimatedPrice = ""

    private let units = ["pieces", "grams", "kilograms", "liters", "cups", "pounds", "packs", "bottles", "cans"]
    private let categories = FoodCategory.allCases

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PSSpacing.lg) {
                    PSCard {
                        VStack(spacing: PSSpacing.md) {
                            // Name
                            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                                Text("Item Name")
                                    .font(PSTypography.callout)
                                    .foregroundStyle(PSColors.textPrimary)

                                TextField("e.g., Milk, Bread, Eggs", text: $name)
                                    .textFieldStyle(.roundedBorder)
                            }

                            // Quantity + Unit
                            HStack(spacing: PSSpacing.md) {
                                VStack(alignment: .leading, spacing: PSSpacing.sm) {
                                    Text("Quantity")
                                        .font(PSTypography.callout)
                                        .foregroundStyle(PSColors.textPrimary)

                                    TextField("1", text: $quantity)
                                        .textFieldStyle(.roundedBorder)
                                        .keyboardType(.decimalPad)
                                }

                                VStack(alignment: .leading, spacing: PSSpacing.sm) {
                                    Text("Unit")
                                        .font(PSTypography.callout)
                                        .foregroundStyle(PSColors.textPrimary)

                                    Picker("Unit", selection: $unit) {
                                        ForEach(units, id: \.self) { u in
                                            Text(u).tag(u)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                            }

                            // Category
                            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                                Text("Category")
                                    .font(PSTypography.callout)
                                    .foregroundStyle(PSColors.textPrimary)

                                Picker("Category", selection: $category) {
                                    ForEach(categories) { cat in
                                        Text(cat.displayName).tag(cat.rawValue)
                                    }
                                }
                                .pickerStyle(.menu)
                            }

                            // Estimated Price
                            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                                Text("Estimated Price (optional)")
                                    .font(PSTypography.callout)
                                    .foregroundStyle(PSColors.textPrimary)

                                TextField("$0.00", text: $estimatedPrice)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.decimalPad)
                            }
                        }
                    }

                    Spacer()

                    PSButton(
                        title: "Add to Replenish List",
                        icon: "plus.circle.fill",
                        style: .primary,
                        size: .medium,
                        isFullWidth: true,
                        action: {
                            PSHaptics.shared.mediumTap()
                            let qty = Double(quantity) ?? 1.0
                            let price = Double(estimatedPrice)
                            viewModel.service.addItem(
                                name: name,
                                category: category,
                                quantity: qty,
                                unit: unit,
                                estimatedPrice: price
                            )
                            dismiss()
                        }
                    )
                }
                .padding(PSSpacing.screenHorizontal)
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PSColors.textSecondary)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Empty State") {
    ReplenishView()
}

#Preview("With Items") {
    let vm = ReplenishViewModel()
    vm.service.itemConsumed(name: "Whole Milk", category: "dairy", quantity: 1, unit: "gallon")
    vm.service.itemConsumed(name: "Sourdough Bread", category: "bakery", quantity: 1, unit: "loaf")
    vm.service.itemWasted(name: "Spinach", category: "vegetables", quantity: 1, unit: "bag")
    vm.service.addItem(name: "Eggs", category: "dairy", quantity: 12, unit: "pieces")
    vm.service.recordPrice(for: "Whole Milk", price: 6.49)
    vm.service.recordPrice(for: "Eggs", price: 5.29)

    return ReplenishView()
}
