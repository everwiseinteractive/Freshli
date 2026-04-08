import SwiftUI
import SwiftData
import PhotosUI

struct ReceiptScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(PSToastManager.self) private var toastManager: PSToastManager?

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
                PSColors.backgroundSecondary
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
                            .foregroundStyle(PSColors.textSecondary)
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
            HStack(spacing: PSSpacing.md) {
                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                    Text("Receipt Scanner")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)

                    if case .complete = receiptScanner.scanningState, !receiptScanner.scannedItems.isEmpty {
                        Text("\(receiptScanner.scannedItems.count) items found")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(PSColors.textSecondary)
                    }
                }

                Spacer()

                if case .complete = receiptScanner.scanningState {
                    Text("\(selectedItemIndices.count)/\(receiptScanner.scannedItems.count)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PSColors.primaryGreen)
                        .padding(.horizontal, PSSpacing.md)
                        .padding(.vertical, PSSpacing.sm)
                        .background(PSColors.green100)
                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
                }
            }
            .padding(PSSpacing.screenHorizontal)
            .padding(.vertical, PSSpacing.lg)

            Divider()
                .foregroundStyle(PSColors.borderLight)
        }
        .background(PSColors.surfaceCard)
    }

    private var emptyStateView: some View {
        VStack(spacing: PSSpacing.xl) {
            Spacer()

            VStack(spacing: PSSpacing.lg) {
                Image(systemName: "receipt.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(PSColors.primaryGreen)

                VStack(spacing: PSSpacing.sm) {
                    Text("Scan Your Receipt")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)

                    Text("Take a photo or upload a receipt to automatically add items to your pantry")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(PSColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            VStack(spacing: PSSpacing.md) {
                PSButton(
                    title: "Take Photo",
                    icon: "camera.fill",
                    style: .primary,
                    isFullWidth: true,
                    action: { showCamera = true }
                )

                PSButton(
                    title: "Choose from Photos",
                    icon: "photo.fill",
                    style: .secondary,
                    isFullWidth: true,
                    action: { selectedPhotoItem = nil }  // Trigger picker
                )
            }
            .padding(PSSpacing.screenHorizontal)
            .padding(.bottom, PSSpacing.xl)
        }
    }

    private var loadingView: some View {
        VStack(spacing: PSSpacing.lg) {
            Spacer()

            VStack(spacing: PSSpacing.lg) {
                if case .scanning = receiptScanner.scanningState {
                    PSShimmerView(height: 120, cornerRadius: PSSpacing.radiusMd)
                        .padding(PSSpacing.screenHorizontal)

                    Text("Scanning receipt...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(PSColors.textPrimary)
                } else if case .parsing = receiptScanner.scanningState {
                    PSShimmerView(height: 120, cornerRadius: PSSpacing.radiusMd)
                        .padding(PSSpacing.screenHorizontal)

                    Text("Extracting items...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(PSColors.textPrimary)
                } else if case .error(let message) = receiptScanner.scanningState {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(PSColors.expiredRed)

                    VStack(spacing: PSSpacing.sm) {
                        Text("Scan Failed")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(PSColors.textPrimary)

                        Text(message)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(PSColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    PSButton(
                        title: "Try Again",
                        icon: "arrow.clockwise",
                        style: .primary,
                        isFullWidth: true,
                        action: {
                            receiptScanner.reset()
                            selectedItemIndices.removeAll()
                        }
                    )
                    .padding(PSSpacing.screenHorizontal)
                }
            }

            Spacer()
        }
    }

    private var contentView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: PSSpacing.md) {
                    ForEach(Array(receiptScanner.scannedItems.enumerated()), id: \.element.id) { index, item in
                        itemRowView(index: index, item: item)
                    }
                }
                .padding(PSSpacing.screenHorizontal)
                .padding(.vertical, PSSpacing.lg)
            }

            Divider()
                .foregroundStyle(PSColors.borderLight)

            // Action buttons
            VStack(spacing: PSSpacing.md) {
                PSButton(
                    title: "Add \(selectedItemIndices.count) to Pantry",
                    icon: "checkmark.circle.fill",
                    style: .primary,
                    isFullWidth: true,
                    isLoading: false,
                    action: { addItemsToPantry() }
                )
                .disabled(selectedItemIndices.isEmpty)
                .opacity(selectedItemIndices.isEmpty ? 0.5 : 1.0)

                PSButton(
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
            .padding(PSSpacing.screenHorizontal)
            .padding(.vertical, PSSpacing.lg)
        }
        .background(PSColors.backgroundSecondary)
    }

    private func itemRowView(index: Int, item: ParsedReceiptItem) -> some View {
        VStack(spacing: PSSpacing.sm) {
            HStack(spacing: PSSpacing.md) {
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
                        .foregroundStyle(selectedItemIndices.contains(index) ? PSColors.primaryGreen : PSColors.textSecondary)
                }

                // Item info
                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                    HStack(spacing: PSSpacing.sm) {
                        Text(itemNameEdits[item.id] ?? item.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(PSColors.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        Text(item.category.emoji)
                            .font(.system(size: 16))
                    }

                    HStack(spacing: PSSpacing.md) {
                        Text("\(Int(itemQuantityEdits[item.id] ?? item.quantity)) \(item.unit.displayName)")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(PSColors.textSecondary)

                        Text("Expires in \(daysUntilExpiry(item.estimatedExpiry))d")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(PSColors.warningAmber)
                    }
                }

                Spacer()

                // Edit button
                Button(action: {
                    editingItemId = editingItemId == item.id ? nil : item.id
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(PSColors.primaryGreen)
                }
            }
            .padding(PSSpacing.md)
            .background(PSColors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))

            // Editing form
            if editingItemId == item.id {
                editingFormView(item: item)
            }
        }
    }

    private func editingFormView(item: ParsedReceiptItem) -> some View {
        VStack(spacing: PSSpacing.md) {
            // Item name
            VStack(alignment: .leading, spacing: PSSpacing.xs) {
                Text("Item Name")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PSColors.textSecondary)

                TextField("Item name", text: .init(
                    get: { itemNameEdits[item.id] ?? item.name },
                    set: { itemNameEdits[item.id] = $0 }
                ))
                .font(.system(size: 15, weight: .regular))
                .padding(PSSpacing.md)
                .background(PSColors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous)
                        .strokeBorder(PSColors.borderLight, lineWidth: 1)
                )
            }

            // Quantity
            VStack(alignment: .leading, spacing: PSSpacing.xs) {
                Text("Quantity")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PSColors.textSecondary)

                HStack(spacing: PSSpacing.md) {
                    Button(action: {
                        let current = itemQuantityEdits[item.id] ?? item.quantity
                        if current > 1 {
                            itemQuantityEdits[item.id] = current - 1
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(PSColors.primaryGreen)
                    }

                    Spacer()

                    Text("\(Int(itemQuantityEdits[item.id] ?? item.quantity))")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PSColors.textPrimary)

                    Spacer()

                    Button(action: {
                        let current = itemQuantityEdits[item.id] ?? item.quantity
                        itemQuantityEdits[item.id] = current + 1
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(PSColors.primaryGreen)
                    }
                }
                .padding(PSSpacing.md)
                .background(PSColors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
            }

            // Category
            VStack(alignment: .leading, spacing: PSSpacing.xs) {
                Text("Category")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PSColors.textSecondary)

                Picker("Category", selection: .init(
                    get: { itemCategoryEdits[item.id] ?? item.category },
                    set: { itemCategoryEdits[item.id] = $0 }
                )) {
                    ForEach(FoodCategory.allCases, id: \.self) { category in
                        HStack(spacing: PSSpacing.sm) {
                            Text(category.emoji)
                            Text(category.displayName)
                        }
                        .tag(category)
                    }
                }
                .tint(PSColors.primaryGreen)
            }

            Button(action: {
                editingItemId = nil
            }) {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PSColors.primaryGreen)
                    .frame(maxWidth: .infinity)
                    .padding(PSSpacing.md)
                    .background(PSColors.green100)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
            }
        }
        .padding(PSSpacing.md)
        .background(PSColors.green50)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Helpers

    private func addItemsToPantry() {
        let itemsToAdd = receiptScanner.scannedItems.enumerated()
            .filter { selectedItemIndices.contains($0.offset) }
            .map { index, item -> PantryItem in
                let name = itemNameEdits[item.id] ?? item.name
                let quantity = itemQuantityEdits[item.id] ?? item.quantity
                let category = itemCategoryEdits[item.id] ?? item.category

                return PantryItem(
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
        .modelContainer(for: PantryItem.self, inMemory: true)
}
