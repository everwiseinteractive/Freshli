import SwiftUI
import Observation

@Observable @MainActor
final class ShoppingListViewModel {
    var service = ShoppingListService()
    var showAddItemSheet = false
    var showMissingIngredientSheet = false
    var selectedMissingIngredient: ShoppingItem?
    var enableAutoReplenish = false

    func deleteItem(_ item: ShoppingItem) {
        service.removeItem(id: item.id)
    }

    func togglePurchased(_ item: ShoppingItem) {
        service.togglePurchased(id: item.id)
    }

    func toggleUrgent(_ item: ShoppingItem) {
        service.toggleUrgent(id: item.id)
    }

    func syncToReminders() async {
        await service.exportToReminders()
    }

    func requestEventKitAccess() async {
        _ = await service.requestEventKitAccess()
    }
}

struct ShoppingListView: View {
    @State private var viewModel = ShoppingListViewModel()
    @State private var newItemName = ""
    @State private var newItemQuantity = "1"
    @State private var newItemUnit = "pieces"

    var neededItems: [ShoppingItem] {
        viewModel.service.currentList.items.filter { !$0.isPurchased }
    }

    var purchasedItems: [ShoppingItem] {
        viewModel.service.currentList.items.filter { $0.isPurchased }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: PSSpacing.sm) {
                    HStack {
                        VStack(alignment: .leading, spacing: PSSpacing.xs) {
                            Text(viewModel.service.currentList.name)
                                .font(PSTypography.title2)
                                .foregroundStyle(PSColors.textPrimary)

                            Text("\(neededItems.count) items")
                                .font(PSTypography.callout)
                                .foregroundStyle(PSColors.textSecondary)
                        }

                        Spacer()

                        if let partner = viewModel.service.suggestDeliveryPartner(for: neededItems) {
                            Image(systemName: partner.icon)
                                .font(.system(size: 20))
                                .foregroundStyle(PSColors.primaryGreen)
                        }
                    }
                }
                .padding(PSSpacing.screenHorizontal)
                .padding(.vertical, PSSpacing.lg)

                Divider()
                    .padding(.vertical, PSSpacing.md)

                if viewModel.service.currentList.items.isEmpty {
                    PSEmptyState(
                        icon: "cart",
                        title: "Shopping List Empty",
                        message: "Add items to get started with your shopping",
                        actionTitle: "Add Item",
                        action: { viewModel.showAddItemSheet = true }
                    )
                    .padding(PSSpacing.screenHorizontal)

                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: PSSpacing.xl) {
                            // Delivery Banner
                            if !neededItems.isEmpty,
                               let partner = viewModel.service.suggestDeliveryPartner(for: neededItems) {
                                DeliveryBanner(partner: partner)
                                    .padding(.horizontal, PSSpacing.screenHorizontal)
                            }

                            // Missing Ingredients Section
                            if !viewModel.service.missingIngredients.isEmpty {
                                VStack(alignment: .leading, spacing: PSSpacing.md) {
                                    Text("Missing from Rescue Mission")
                                        .font(PSTypography.headline)
                                        .foregroundStyle(PSColors.expiredRed)
                                        .padding(.horizontal, PSSpacing.screenHorizontal)

                                    ForEach(viewModel.service.missingIngredients) { item in
                                        ShoppingItemRow(
                                            item: item,
                                            onTap: {
                                                viewModel.selectedMissingIngredient = item
                                                viewModel.showMissingIngredientSheet = true
                                            },
                                            onDelete: { viewModel.deleteItem(item) },
                                            onTogglePurchased: { viewModel.togglePurchased(item) },
                                            onToggleUrgent: { viewModel.toggleUrgent(item) }
                                        )
                                        .padding(.horizontal, PSSpacing.screenHorizontal)
                                    }
                                }
                            }

                            // Needed Items Section
                            if !neededItems.isEmpty {
                                VStack(alignment: .leading, spacing: PSSpacing.md) {
                                    Text("Needed")
                                        .font(PSTypography.headline)
                                        .foregroundStyle(PSColors.textPrimary)
                                        .padding(.horizontal, PSSpacing.screenHorizontal)

                                    ForEach(neededItems) { item in
                                        ShoppingItemRow(
                                            item: item,
                                            onTap: { viewModel.togglePurchased(item) },
                                            onDelete: { viewModel.deleteItem(item) },
                                            onTogglePurchased: { viewModel.togglePurchased(item) },
                                            onToggleUrgent: { viewModel.toggleUrgent(item) }
                                        )
                                        .padding(.horizontal, PSSpacing.screenHorizontal)
                                    }
                                }
                            }

                            // Purchased Items Section
                            if !purchasedItems.isEmpty {
                                VStack(alignment: .leading, spacing: PSSpacing.md) {
                                    Text("Purchased")
                                        .font(PSTypography.headline)
                                        .foregroundStyle(PSColors.textSecondary)
                                        .padding(.horizontal, PSSpacing.screenHorizontal)

                                    ForEach(purchasedItems) { item in
                                        ShoppingItemRow(
                                            item: item,
                                            onTap: { viewModel.togglePurchased(item) },
                                            onDelete: { viewModel.deleteItem(item) },
                                            onTogglePurchased: { viewModel.togglePurchased(item) },
                                            onToggleUrgent: { viewModel.toggleUrgent(item) }
                                        )
                                        .padding(.horizontal, PSSpacing.screenHorizontal)
                                    }
                                }
                            }

                            // Reminders Section
                            VStack(spacing: PSSpacing.md) {
                                if viewModel.service.isAuthorized {
                                    // Auto-Replenish Toggle
                                    HStack(spacing: PSSpacing.md) {
                                        VStack(alignment: .leading, spacing: PSSpacing.xs) {
                                            Text("Auto-Replenish")
                                                .font(PSTypography.callout)
                                                .foregroundStyle(PSColors.textPrimary)

                                            Text("Sync with Apple Reminders")
                                                .font(PSTypography.caption1)
                                                .foregroundStyle(PSColors.textSecondary)
                                        }

                                        Spacer()

                                        Toggle("", isOn: $viewModel.enableAutoReplenish)
                                            .tint(PSColors.primaryGreen)
                                    }
                                    .padding(PSSpacing.lg)
                                    .background(PSColors.surfaceCard)
                                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg))

                                    // Sync Button
                                    PSButton(
                                        title: "Sync to Apple Reminders",
                                        icon: "checkmark.circle",
                                        style: .secondary,
                                        size: .medium,
                                        isFullWidth: true,
                                        isLoading: viewModel.service.isSyncing,
                                        action: {
                                            Task {
                                                await viewModel.syncToReminders()
                                                PSHaptics.shared.success()
                                            }
                                        }
                                    )
                                } else {
                                    // Authorization Request Button
                                    PSButton(
                                        title: "Enable Apple Reminders Sync",
                                        icon: "bell.badge.fill",
                                        style: .primary,
                                        size: .medium,
                                        isFullWidth: true,
                                        action: {
                                            Task {
                                                await viewModel.requestEventKitAccess()
                                                PSHaptics.shared.lightTap()
                                            }
                                        }
                                    )

                                    if viewModel.service.authorizationStatus == .denied {
                                        HStack(spacing: PSSpacing.sm) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .font(.system(size: 12))
                                                .foregroundStyle(PSColors.warningAmber)

                                            Text("Enable in Settings to sync with Reminders")
                                                .font(PSTypography.caption1)
                                                .foregroundStyle(PSColors.textSecondary)

                                            Spacer()
                                        }
                                        .padding(.top, PSSpacing.sm)
                                    }
                                }
                            }
                            .padding(.horizontal, PSSpacing.screenHorizontal)
                            .padding(.bottom, PSSpacing.lg)
                        }
                        .padding(.vertical, PSSpacing.lg)
                    }
                }

                Spacer()
            }
            .navigationTitle("Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { viewModel.showAddItemSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(PSColors.primaryGreen)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddItemSheet) {
                AddShoppingItemSheet(viewModel: viewModel, isPresented: $viewModel.showAddItemSheet)
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $viewModel.selectedMissingIngredient) { item in
                MissingIngredientSheet(item: item, viewModel: viewModel)
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - Shopping Item Row

struct ShoppingItemRow: View {
    let item: ShoppingItem
    let onTap: () -> Void
    let onDelete: () -> Void
    let onTogglePurchased: () -> Void
    let onToggleUrgent: () -> Void

    var body: some View {
        PSCard {
            HStack(spacing: PSSpacing.md) {
                Button(action: onTogglePurchased) {
                    Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(item.isPurchased ? PSColors.primaryGreen : PSColors.textTertiary)
                }

                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                    Text(item.name)
                        .font(PSTypography.callout)
                        .foregroundStyle(item.isPurchased ? PSColors.textTertiary : PSColors.textPrimary)
                        .strikethrough(item.isPurchased)

                    HStack(spacing: PSSpacing.md) {
                        PSBadge(text: item.category.uppercased(), variant: .default)

                        Text("\(String(format: "%.1f", item.quantity)) \(item.unit)")
                            .font(PSTypography.caption2)
                            .foregroundStyle(PSColors.textSecondary)

                        if item.source != "manual" {
                            PSBadge(text: item.source.uppercased(), variant: .fresh, style: .subtle)
                        }
                    }
                }

                Spacer()

                VStack(spacing: PSSpacing.xs) {
                    if item.isUrgent {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(PSColors.warningAmber)
                    }

                    Menu {
                        Button(action: onToggleUrgent) {
                            Label(
                                item.isUrgent ? "Remove Urgent" : "Mark Urgent",
                                systemImage: item.isUrgent ? "flame.fill" : "flame"
                            )
                        }

                        Button(role: .destructive, action: onDelete) {
                            Label("Delete", systemImage: "trash.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PSColors.textTertiary)
                    }
                }
            }
        }
    }
}

// MARK: - Delivery Banner

struct DeliveryBanner: View {
    let partner: DeliveryPartner

    var body: some View {
        PSCard {
            HStack(spacing: PSSpacing.md) {
                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                    Text("Get it now")
                        .font(PSTypography.callout)
                        .foregroundStyle(PSColors.textSecondary)

                    HStack(spacing: PSSpacing.sm) {
                        Image(systemName: partner.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PSColors.primaryGreen)

                        Text("\(partner.displayName) • \(partner.estimatedDelivery)")
                            .font(PSTypography.headline)
                            .foregroundStyle(PSColors.textPrimary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PSColors.textTertiary)
            }
            .padding(PSSpacing.lg)
        }
    }
}

// MARK: - Add Item Sheet

struct AddShoppingItemSheet: View {
    @State private var itemName = ""
    @State private var quantity = "1"
    @State private var unit = "pieces"
    let viewModel: ShoppingListViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: PSSpacing.lg) {
                PSCard {
                    VStack(spacing: PSSpacing.md) {
                        VStack(alignment: .leading, spacing: PSSpacing.sm) {
                            Text("Item Name")
                                .font(PSTypography.callout)
                                .foregroundStyle(PSColors.textPrimary)

                            TextField("e.g., Milk", text: $itemName)
                                .textFieldStyle(.roundedBorder)
                        }

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
                                    ForEach(["pieces", "grams", "liters", "cups", "pounds"], id: \.self) { u in
                                        Text(u).tag(u)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                    }
                }

                Spacer()

                PSButton(
                    title: "Add Item",
                    style: .primary,
                    size: .medium,
                    isFullWidth: true,
                    action: {
                        let qty = Double(quantity) ?? 1.0
                        viewModel.service.addItem(name: itemName, quantity: qty, unit: unit)
                        isPresented = false
                    }
                )
            }
            .padding(PSSpacing.screenHorizontal)
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }
}

#Preview {
    ShoppingListView()
}

#Preview("With Items") {
    let viewModel = ShoppingListViewModel()
    viewModel.service.addItem(name: "Milk", quantity: 1, unit: "carton", category: "dairy")
    viewModel.service.addItem(name: "Bread", quantity: 1, unit: "loaf", category: "bakery")
    viewModel.service.addItem(name: "Tomatoes", quantity: 3, unit: "pieces", category: "vegetables", source: "lowStock")

    return ShoppingListView()
        .environment(viewModel)
}
