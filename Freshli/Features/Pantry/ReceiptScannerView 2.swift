import SwiftUI
import SwiftData
import PhotosUI

struct ReceiptScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(FLToastManager.self) private var toastManager: FLToastManager?

    @State private var receiptScanner = ReceiptScannerService()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var selectedItemIndices: Set<Int> = []
    @State private var editingItemId: UUID?
    @State private var itemNameEdits: [UUID: String] = [:]
    @State private var itemCategoryEdits: [UUID: FoodCategory] = [:]
    @State private var itemQuantityEdits: [UUID: Double] = [:]

    var itemsToAdd: [ParsedReceiptItem] {
        receiptScanner.scannedItems.enumerated()
            .filter { selectedItemIndices.contains($0.offset) }
            .map { $0.element }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FLColors.backgroundSecondary
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    headerView

                    // Content
                    if case .complete = receiptScanner.scanningState, !receiptScanner.scannedItems.isEmpty {
                        contentView
                    } else if case .idle = receiptScanner.scanningState {
                        emptyStateView
                    } else {
                        loadingView
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(FLColors.textSecondary)
                    }
                }
            }
            .photosPicker(
                isPresented: .constant(selectedPhotoItem != nil),
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            )
            .onChange(of: selectedPhotoItem) { oldValue, newValue in
                if let newValue {
                    Task {
                        if let data = try await newValue.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            await receiptScanner.scanReceipt(uiImage)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 0) {
            HStack(spacing: FLSpacing.md) {
                VStack(alignment: .leading, spacing: FLSpacing.xs) {
                    Text("Receipt Scanner")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(FLColors.textPrimary)

                    if case .complete = receiptScanner.scanningState, !receiptScanner.scannedItems.isEmpty {
                        Text("\(receiptScanner.scannedItems.count) items found")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(FLColors.textSecondary)
                    }
                }

                Spacer()

                if case .complete = receiptScanner.scanningState {
                    Text("\(selectedItemIndices.count)/\(receiptScanner.scannedItems.count)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FLColors.primaryGreen)
                        .padding(.horizontal, FLSpacing.md)
                        .padding(.vertical, FLSpacing.sm)
                        .background(FLColors.green100)
                        .clipShape(RoundedRectangle(cornerRadius: FLSpacing.radiusMd, style: .continuous))
                }
            }
            .padding(FLSpacing.screenHorizontal)
            .padding(.vertical, FLSpacing.lg)

            Divider()
                .foregroundStyle(FLColors.borderLight)
        }
        .background(FLColors.surfaceCard)
    }

    private var emptyStateView: some View {
        VStack(spacing: FLSpacing.xl) {
            Spacer()

            VStack(spacing: FLSpacing.lg) {
                Image(systemName: "receipt.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(FLColors.primaryGreen)

                VStack(spacing: FLSpacing.sm) {
                    Text("Scan Your Receipt")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(FLColors.textPrimary)

                    Text("Take a photo or upload a receipt to automatically add items to your pantry")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(FLColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            VStack(spacing: FLSpacing.md) {
                FLButton(
                    title: "Take Photo",
                    icon: "camera.fill",
                    style: .primary,
                    isFullWidth: true,
                    action: { showCamera = true }
                )

                FLButton(
                    title: "Choose from Photos",
                    icon: "photo.fill",
                    style: .secondary,
                    isFullWidth: true,
                    action: { selectedPhotoItem = nil }  // Trigger picker
                )
            }
            .padding(FLSpacing.screenHorizontal)
            .padding(.bottom, FLSpacing.xl)
        }
    }

    private var loadingView: some View {
        VStack(spacing: FLSpacing.lg) {
            Spacer()

            VStack(spacing: FLSpacing.lg) {
                if case .scanning = receiptScanner.scanningState {
                    FLShimmerView(height: 120, cornerRadius: FLSpacing.radiusMd)
                        .padding(FLSpacing.screenHorizontal)

                    Text("Scanning receipt...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(FLColors.textPrimary)
                } else if case .parsing = receiptScanner.scanningState {
                    FLShimmerView(height: 120, cornerRadius: FLSpacing.radiusMd)
                        .padding(FLSpacing.screenHorizontal)

                    Text("Extracting items...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(FLColors.textPrimary)
                } else if case .error(let message) = receiptScanner.scanningState {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(FLColors.expiredRed)

                    VStack(spacing: FLSpacing.sm) {
                        Text("Scan Failed")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(FLColors.textPrimary)

                        Text(message)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(FLColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    FLButton(
                        title: "Try Again",
                        icon: "arrow.clockwise",
                        style: .primary,
                        isFullWidth: true,
                        action: {
                            receiptScanner.reset()
                            selectedItemIndices.removeAll()
                        }
                    )
                    .padding(FLSpacing.screenHorizontal)
                }
            }

            Spacer()
        }
    }

    private var contentView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: FLSpacing.md) {
                    ForEach(Array(receiptScanner.scannedItems.enumerated()), id: \.element.id) { index, item in
                        itemRowView(index: index, item: item)
                    }
                }
                .padding(FLSpacing.screenHorizontal)
                .padding(.vertical, FLSpacing.lg)
            }

            Divider()
                .foregroundStyle(FLColors.borderLight)

            // Action buttons
            VStack(spacing: FLSpacing.md) {
                FLButton(
                    title: "Add \(selectedItemIndices.count) to Pantry",
                    icon: "checkmark.circle.fill",
                    style: .primary,
                    isFullWidth: true,
                    isLoading: false,
                    action: { addItemsToPantry() }
                )
                .disabled(selectedItemIndices.isEmpty)
                .opacity(selectedItemIndices.isEmpty ? 0.5 : 1.0)

                FLButton(
                    title: "Start Over",
                    icon: "arrow.clockwise",
                    style: .secondary,
                    isFullWidth: true,
                    action: {
                        receiptScanner.reset()
                        selectedItemIndices.removeAll()
                        itemNameEdits.removeAll()
                        itemCategoryEdits.removeAll()
                        itemQuantityEdits.removeAll()
                    }
                )
            }
            .padding(FLSpacing.screenHorizontal)
            .padding(.vertical, FLSpacing.lg)
        }
        .background(FLColors.backgroundSecondary)
    }

    private func itemRowView(index: Int, item: ParsedReceiptItem) -> some View {
        VStack(spacing: FLSpacing.sm) {
            HStack(spacing: FLSpacing.md) {
                // Checkbox
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if selectedItemIndices.contains(index) {
                            selectedItemIndices.remove(index)
                        } else {
                            selectedItemIndices.insert(index)
                        }
                    }
                }) {
                    Image(systemName: selectedItemIndices.contains(index) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(selectedItemIndices.contains(index) ? FLColors.primaryGreen : FLColors.textSecondary)
                }

                // Item info
                VStack(alignment: .leading, spacing: FLSpacing.xs) {
                    HStack(spacing: FLSpacing.sm) {
                        Text(itemNameEdits[item.id] ?? item.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(FLColors.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        Text(item.category.emoji)
                            .font(.system(size: 16))
                    }

                    HStack(spacing: FLSpacing.md) {
                        Text("\(Int(itemQuantityEdits[item.id] ?? item.quantity)) \(item.unit.displayName)")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(FLColors.textSecondary)

                        Text("Expires in \(daysUntilExpiry(item.estimatedExpiry))d")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(FLColors.warningAmber)
                    }
                }

                Spacer()

                // Edit button
                Button(action: {
                    editingItemId = editingItemId == item.id ? nil : item.id
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(FLColors.primaryGreen)
                }
            }
            .padding(FLSpacing.md)
            .background(FLColors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: FLSpacing.radiusLg, style: .continuous))

            // Editing form
            if editingItemId == item.id {
                editingFormView(item: item)
            }
        }
    }

    private func editingFormView(item: ParsedReceiptItem) -> some View {
        VStack(spacing: FLSpacing.md) {
            // Item name
            VStack(alignment: .leading, spacing: FLSpacing.xs) {
                Text("Item Name")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FLColors.textSecondary)

                TextField("Item name", text: .init(
                    get: { itemNameEdits[item.id] ?? item.name },
                    set: { itemNameEdits[item.id] = $0 }
                ))
                .font(.system(size: 15, weight: .regular))
                .padding(FLSpacing.md)
                .background(FLColors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: FLSpacing.radiusMd, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: FLSpacing.radiusMd, style: .continuous)
                        .strokeBorder(FLColors.borderLight, lineWidth: 1)
                )
            }

            // Quantity
            VStack(alignment: .leading, spacing: FLSpacing.xs) {
                Text("Quantity")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FLColors.textSecondary)

                HStack(spacing: FLSpacing.md) {
                    Button(action: {
                        let current = itemQuantityEdits[item.id] ?? item.quantity
                        if current > 1 {
                            itemQuantityEdits[item.id] = current - 1
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(FLColors.primaryGreen)
                    }

                    Spacer()

                    Text("\(Int(itemQuantityEdits[item.id] ?? item.quantity))")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FLColors.textPrimary)

                    Spacer()

                    Button(action: {
                        let current = itemQuantityEdits[item.id] ?? item.quantity
                        itemQuantityEdits[item.id] = current + 1
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(FLColors.primaryGreen)
                    }
                }
                .padding(FLSpacing.md)
                .background(FLColors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: FLSpacing.radiusMd, style: .continuous))
            }

            // Category
            VStack(alignment: .leading, spacing: FLSpacing.xs) {
                Text("Category")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FLColors.textSecondary)

                Picker("Category", selection: .init(
                    get: { itemCategoryEdits[item.id] ?? item.category },
                    set: { itemCategoryEdits[item.id] = $0 }
                )) {
                    ForEach(FoodCategory.allCases, id: \.self) { category in
                        HStack(spacing: FLSpacing.sm) {
                            Text(category.emoji)
                            Text(category.displayName)
                        }
                        .tag(category)
                    }
                }
                .tint(FLColors.primaryGreen)
            }

            Button(action: {
                editingItemId = nil
            }) {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FLColors.primaryGreen)
                    .frame(maxWidth: .infinity)
                    .padding(FLSpacing.md)
                    .background(FLColors.green100)
                    .clipShape(RoundedRectangle(cornerRadius: FLSpacing.radiusMd, style: .continuous))
            }
        }
        .padding(FLSpacing.md)
        .background(FLColors.green50)
        .clipShape(RoundedRectangle(cornerRadius: FLSpacing.radiusLg, style: .continuous))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Helpers

    private func addItemsToPantry() {
        let itemsToAdd = receiptScanner.scannedItems.enumerated()
            .filter { selectedItemIndices.contains($0.offset) }
            .map { index, item -> FreshliItem in
                let name = itemNameEdits[item.id] ?? item.name
                let quantity = itemQuantityEdits[item.id] ?? item.quantity
                let category = itemCategoryEdits[item.id] ?? item.category

                return FreshliItem(
                    name: name,
                    category: category,
                    storageLocation: item.storageLocation,
                    quantity: quantity,
                    unit: item.unit,
                    expiryDate: item.estimatedExpiry
                )
            }

        do {
            for item in itemsToAdd {
                modelContext.insert(item)
            }
            try modelContext.save()

            toastManager?.show(.success("Added \(itemsToAdd.count) items to your pantry!"))
            dismiss()
        } catch {
            toastManager?.show(.error("Failed to add items: \(error.localizedDescription)"))
        }
    }

    private func daysUntilExpiry(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: date)
        return max(components.day ?? 0, 0)
    }
}

#Preview {
    ReceiptScannerView()
        .modelContainer(for: FreshliItem.self, inMemory: true)
}
