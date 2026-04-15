import SwiftUI
import Observation

@Observable @MainActor
final class ReceiptImportViewModel {
    var selectedTab: Int = 0
    var showReviewSheet = false
    var currentReceipt: GroceryReceipt?
    var selectedItems: Set<UUID> = []
    var isLoading = false

    let service = ReceiptImportService()
}

struct ReceiptImportView: View {
    @State private var viewModel = ReceiptImportViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: PSSpacing.md) {
                    Text("Import Receipt")
                        .font(PSTypography.title1)
                        .foregroundStyle(PSColors.textPrimary)

                    Text("Add items to your pantry from grocery receipts")
                        .font(PSTypography.body)
                        .foregroundStyle(PSColors.textSecondary)
                }
                .padding(PSSpacing.screenHorizontal)
                .padding(.vertical, PSSpacing.lg)

                // Tab Selection
                Picker("Import Method", selection: $viewModel.selectedTab) {
                    Text("Scan Receipt").tag(0)
                    Text("Enter Manually").tag(1)
                    Text("Connect Service").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(PSSpacing.screenHorizontal)
                .padding(.bottom, PSSpacing.lg)

                // Content
                TabView(selection: $viewModel.selectedTab) {
                    // Scan Receipt Tab
                    ScanReceiptTabView(viewModel: viewModel)
                        .tag(0)

                    // Enter Manually Tab
                    ManualEntryTabView(viewModel: viewModel)
                        .tag(1)

                    // Connect Service Tab
                    ConnectedServicesTabView(viewModel: viewModel)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                Spacer()

                // Recent Imports
                if !viewModel.service.recentReceipts.isEmpty {
                    VStack(alignment: .leading, spacing: PSSpacing.md) {
                        Text("Recent Imports")
                            .font(PSTypography.headline)
                            .foregroundStyle(PSColors.textPrimary)
                            .padding(.horizontal, PSSpacing.screenHorizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: PSSpacing.md) {
                                ForEach(viewModel.service.recentReceipts.prefix(3)) { receipt in
                                    VStack(alignment: .leading, spacing: PSSpacing.sm) {
                                        Text(receipt.storeName)
                                            .font(PSTypography.callout)
                                            .foregroundStyle(PSColors.textPrimary)

                                        Text("\(receipt.items.count) items")
                                            .font(PSTypography.caption1)
                                            .foregroundStyle(PSColors.textSecondary)

                                        Text(receipt.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(PSTypography.caption2)
                                            .foregroundStyle(PSColors.textTertiary)
                                    }
                                    .padding(PSSpacing.md)
                                    .frame(minWidth: 140)
                                    .background(PSColors.backgroundSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd))
                                    .onTapGesture {
                                        viewModel.currentReceipt = receipt
                                        viewModel.showReviewSheet = true
                                    }
                                }
                            }
                            .padding(.horizontal, PSSpacing.screenHorizontal)
                        }
                    }
                    .padding(.vertical, PSSpacing.lg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(PSColors.textTertiary)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showReviewSheet) {
                if let receipt = viewModel.currentReceipt {
                    ReceiptReviewSheet(receipt: receipt, viewModel: viewModel)
                        .presentationDragIndicator(.visible)
                        .sheetTransition()
                }
            }
        }
    }
}

// MARK: - Scan Receipt Tab

struct ScanReceiptTabView: View {
    let viewModel: ReceiptImportViewModel

    var body: some View {
        VStack(spacing: PSSpacing.lg) {
            PSCard {
                VStack(spacing: PSSpacing.md) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(PSColors.primaryGreen)

                    Text("Scan Receipt Photo")
                        .font(PSTypography.headline)
                        .foregroundStyle(PSColors.textPrimary)

                    Text("Take a photo of your receipt and we'll extract the items automatically")
                        .font(PSTypography.callout)
                        .foregroundStyle(PSColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(PSSpacing.xl)
            }

            NavigationLink(destination: ReceiptPhotoScannerView()) {
                PSButton(
                    title: "Open Camera",
                    icon: "camera.fill",
                    style: .primary,
                    size: .medium,
                    isFullWidth: true,
                    action: {}
                )
            }

            Spacer()
        }
        .padding(PSSpacing.screenHorizontal)
    }
}

// MARK: - Manual Entry Tab

struct ManualEntryTabView: View {
    @State private var storeName = ""
    @State private var receiptText = ""
    let viewModel: ReceiptImportViewModel

    var body: some View {
        VStack(spacing: PSSpacing.lg) {
            PSCard {
                VStack(spacing: PSSpacing.md) {
                    VStack(alignment: .leading, spacing: PSSpacing.sm) {
                        Text("Store Name")
                            .font(PSTypography.callout)
                            .foregroundStyle(PSColors.textPrimary)

                        TextField("e.g., Whole Foods", text: $storeName)
                            .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
                            .padding(.horizontal, PSSpacing.lg)
                            .padding(.vertical, PSSpacing.md)
                            .background(PSColors.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous)
                                    .strokeBorder(PSColors.borderLight, lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: PSSpacing.sm) {
                        Text("Receipt Items")
                            .font(PSTypography.callout)
                            .foregroundStyle(PSColors.textPrimary)

                        TextEditor(text: $receiptText)
                            .frame(minHeight: 150)
                            .padding(PSSpacing.sm)
                            .background(PSColors.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd))
                            .font(PSTypography.body)
                    }
                }
            }

            PSButton(
                title: "Parse Receipt",
                style: .primary,
                size: .medium,
                isFullWidth: true,
                action: {
                    var receipt = viewModel.service.parseReceiptFromText(receiptText)
                    let convertedItems = receipt.items.map { ReceiptItem(name: $0.name, quantity: $0.quantity, unit: $0.unit, price: $0.price, category: $0.category) }
                    receipt = GroceryReceipt(
                        id: receipt.id,
                        storeName: storeName.isEmpty ? "Manual Receipt" : storeName,
                        date: receipt.date,
                        items: convertedItems,
                        totalAmount: receipt.totalAmount,
                        receiptSource: .manual
                    )
                    viewModel.currentReceipt = receipt
                    viewModel.showReviewSheet = true
                }
            )

            Spacer()
        }
        .padding(PSSpacing.screenHorizontal)
    }
}

// MARK: - Connected Services Tab

struct ConnectedServicesTabView: View {
    let viewModel: ReceiptImportViewModel

    let services: [(name: String, icon: String, source: ReceiptSource)] = [
        ("Instacart", "cart.fill", .instacartDigital),
        ("Amazon Fresh", "bag.fill", .amazonFresh),
        ("Kroger", "fork.knife", .krogerDigital),
        ("Ocado", "storefront.fill", .ocadoDigital)
    ]

    var body: some View {
        VStack(spacing: PSSpacing.lg) {
            VStack(alignment: .leading, spacing: PSSpacing.md) {
                Text("Connected Services")
                    .font(PSTypography.headline)
                    .foregroundStyle(PSColors.textPrimary)

                ForEach(services, id: \.name) { service in
                    let isConnected = viewModel.service.connectedServices.contains { $0.source == service.source.rawValue }

                    PSActionCard(
                        icon: service.icon,
                        title: service.name,
                        subtitle: isConnected ? "Connected" : "Tap to connect",
                        iconColor: isConnected ? PSColors.primaryGreen : PSColors.textTertiary,
                        action: {
                            if isConnected {
                                viewModel.service.disconnectService(service.source)
                            } else {
                                viewModel.service.connectService(service.source)
                            }
                        }
                    )
                }
            }

            Spacer()
        }
        .padding(PSSpacing.screenHorizontal)
    }
}

// MARK: - Receipt Review Sheet

struct ReceiptReviewSheet: View {
    let receipt: GroceryReceipt
    @State private var viewModel: ReceiptImportViewModel
    @State private var selectedItems: Set<UUID> = []
    @Environment(\.dismiss) var dismiss

    init(receipt: GroceryReceipt, viewModel: ReceiptImportViewModel) {
        self.receipt = receipt
        self._viewModel = State(initialValue: viewModel)
        self._selectedItems = State(initialValue: Set(receipt.items.map { UUID(uuidString: $0.name) ?? UUID() }))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: PSSpacing.sm) {
                    Text(receipt.storeName)
                        .font(PSTypography.title2)
                        .foregroundStyle(PSColors.textPrimary)

                    HStack(spacing: PSSpacing.md) {
                        Text(receipt.date.formatted(date: .abbreviated, time: .omitted))
                            .font(PSTypography.callout)
                            .foregroundStyle(PSColors.textSecondary)

                        PSBadge(text: "\(receipt.items.count) items", variant: .default)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(PSSpacing.screenHorizontal)
                .padding(.vertical, PSSpacing.lg)

                Divider()
                    .padding(.vertical, PSSpacing.md)

                // Items List
                ScrollView {
                    VStack(spacing: PSSpacing.md) {
                        ForEach(receipt.items.indices, id: \.self) { index in
                            let item = receipt.items[index]
                            let isSelected = selectedItems.contains(UUID(uuidString: item.name) ?? UUID())

                            PSCard {
                                HStack(spacing: PSSpacing.md) {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20))
                                        .foregroundStyle(isSelected ? PSColors.primaryGreen : PSColors.textTertiary)
                                        .onTapGesture {
                                            let id = UUID(uuidString: item.name) ?? UUID()
                                            if selectedItems.contains(id) {
                                                selectedItems.remove(id)
                                            } else {
                                                selectedItems.insert(id)
                                            }
                                        }

                                    VStack(alignment: .leading, spacing: PSSpacing.xs) {
                                        Text(item.name)
                                            .font(PSTypography.callout)
                                            .foregroundStyle(PSColors.textPrimary)

                                        HStack(spacing: PSSpacing.md) {
                                            PSBadge(text: item.category.uppercased(), variant: .default)
                                            Text("\(String(format: "%.1f", item.quantity)) \(item.unit)")
                                                .font(PSTypography.caption2)
                                                .foregroundStyle(PSColors.textSecondary)
                                        }
                                    }

                                    Spacer()

                                    if let price = item.price {
                                        Text("$\(String(format: "%.2f", price))")
                                            .font(PSTypography.headline)
                                            .foregroundStyle(PSColors.textPrimary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(PSSpacing.screenHorizontal)
                }

                Spacer()

                // Action Buttons
                VStack(spacing: PSSpacing.md) {
                    PSButton(
                        title: "Add \(selectedItems.count) Items to Pantry",
                        style: .primary,
                        size: .medium,
                        isFullWidth: true,
                        action: {
                            let itemsToAdd = receipt.items.enumerated()
                                .filter { selectedItems.contains(UUID(uuidString: $0.element.name) ?? UUID()) }
                                .map { ReceiptItem(name: $0.element.name, quantity: $0.element.quantity, unit: $0.element.unit, price: $0.element.price, category: $0.element.category) }

                            let receiptFiltered = GroceryReceipt(
                                id: receipt.id,
                                storeName: receipt.storeName,
                                date: receipt.date,
                                items: itemsToAdd,
                                totalAmount: receipt.totalAmount,
                                receiptSource: ReceiptSource(rawValue: receipt.receiptSource) ?? .manual
                            )

                            viewModel.service.addReceipt(receiptFiltered)
                            dismiss()
                        }
                    )

                    PSButton(
                        title: "Cancel",
                        style: .secondary,
                        size: .medium,
                        isFullWidth: true,
                        action: { dismiss() }
                    )
                }
                .padding(PSSpacing.screenHorizontal)
                .padding(.bottom, PSSpacing.lg)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ReceiptImportView()
}

#Preview("Receipt Review Sheet") {
    let items = [
        ReceiptItem(name: "Organic Bananas", quantity: 2.0, unit: "pieces", price: 1.99, category: "fruits"),
        ReceiptItem(name: "Greek Yogurt", quantity: 1.0, unit: "containers", price: 4.49, category: "dairy"),
        ReceiptItem(name: "Salmon Fillet", quantity: 0.75, unit: "pounds", price: 11.99, category: "seafood")
    ]

    let receipt = GroceryReceipt(
        id: UUID(),
        storeName: "Whole Foods",
        date: Date(),
        items: items,
        totalAmount: 18.47,
        receiptSource: .photoScan
    )

    let viewModel = ReceiptImportViewModel()

    ReceiptReviewSheet(receipt: receipt, viewModel: viewModel)
        .presentationDragIndicator(.visible)
}
