import SwiftUI
import SwiftData
import PhotosUI

struct ReceiptScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(PSToastManager.self) private var toastManager

    @State private var receiptScanner = ReceiptScannerService()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showPhotoPicker = false
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
                isPresented: $showPhotoPicker,
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            )
            .fullScreenCover(isPresented: $showCamera) {
                CameraPickerView { image in
                    Task {
                        await receiptScanner.scanReceipt(image)
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { oldValue, newValue in
                if let newValue {
                    Task {
                        if let data = try? await newValue.loadTransferable(type: Data.self),
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
        ScrollView {
            VStack(spacing: PSSpacing.xl) {
                receiptHero
                    .padding(.top, PSSpacing.xl)

                VStack(spacing: PSSpacing.sm) {
                    Text(String(localized: "Turn any receipt into a stocked pantry"))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(PSColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, PSSpacing.screenHorizontal)

                    Text(String(localized: "Snap your shopping receipt and Freshli's on-device OCR pulls every item, category, and price — all parsed in a heartbeat."))
                        .font(.system(size: 15))
                        .foregroundStyle(PSColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.horizontal, PSSpacing.xxl)
                }

                receiptFeaturePills

                receiptPrivacyChip

                Spacer(minLength: PSSpacing.xl)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: PSSpacing.md) {
                PSButton(
                    title: String(localized: "Take Photo"),
                    icon: "camera.fill",
                    style: .primary,
                    isFullWidth: true,
                    action: { showCamera = true }
                )

                PSButton(
                    title: String(localized: "Choose from Photos"),
                    icon: "photo.fill",
                    style: .secondary,
                    isFullWidth: true,
                    action: { showPhotoPicker = true }
                )
            }
            .padding(PSSpacing.screenHorizontal)
            .padding(.top, PSSpacing.md)
            .padding(.bottom, PSSpacing.xl)
            .background {
                LinearGradient(
                    colors: [
                        PSColors.backgroundSecondary.opacity(0),
                        PSColors.backgroundSecondary
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
            }
        }
    }

    // MARK: - Empty-state hero
    //
    // Layered composition: aurora gradient halo → glass-plate
    // backdrop → stylised receipt with three "scanned" line items
    // → animated horizontal scan beam that sweeps top-to-bottom.
    // The beam is the single dynamic element so the layout stays
    // GPU-cheap; everything else is static SF Symbols + shapes.

    @State private var receiptScanLineY: CGFloat = -40
    @State private var receiptHaloPulse: Bool = false

    private var receiptHero: some View {
        ZStack {
            // Layer 1 — soft aurora halo
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            PSColors.primaryGreen.opacity(0.55),
                            PSColors.accentTeal.opacity(0.45),
                            PSColors.infoBlue.opacity(0.50),
                            PSColors.primaryGreen.opacity(0.55)
                        ],
                        center: .center
                    )
                )
                .blur(radius: 28)
                .frame(width: 220, height: 220)
                .opacity(receiptHaloPulse ? 1.0 : 0.78)
                .scaleEffect(receiptHaloPulse ? 1.04 : 0.96)

            // Layer 2 — glass plate
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(.white.opacity(0.5), lineWidth: 1)
                )
                .frame(width: 180, height: 200)
                .shadow(color: PSColors.primaryGreen.opacity(0.20), radius: 22, x: 0, y: 12)

            // Layer 3 — stylised receipt with scan beam + item lines
            ZStack(alignment: .top) {
                receiptCard
                // The beam — clipped to the receipt rect so it never
                // bleeds outside the paper.
                LinearGradient(
                    colors: [
                        PSColors.primaryGreen.opacity(0),
                        PSColors.primaryGreen.opacity(0.85),
                        PSColors.primaryGreen.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: 110, height: 26)
                .blur(radius: 4)
                .offset(y: receiptScanLineY)
                .mask(receiptCard)
            }
        }
        .frame(height: 240)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                receiptHaloPulse = true
            }
            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                receiptScanLineY = 180
            }
        }
    }

    /// The little paper-receipt rectangle with three "scanned" item
    /// lines. Used both as the visible card and as the mask for the
    /// scan-beam so the highlight stays inside the paper outline.
    private var receiptCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header band — represents the store name strip
            RoundedRectangle(cornerRadius: 4)
                .fill(PSColors.primaryGreen.opacity(0.85))
                .frame(width: 60, height: 6)
                .padding(.top, 14)
                .padding(.leading, 14)

            VStack(spacing: 7) {
                receiptItemLine(width: 80)
                receiptItemLine(width: 64)
                receiptItemLine(width: 72)
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

            Spacer(minLength: 0)

            // Total row — bolder bar at the bottom
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(PSColors.textPrimary.opacity(0.65))
                    .frame(width: 40, height: 8)
                Spacer()
                RoundedRectangle(cornerRadius: 3)
                    .fill(PSColors.primaryGreen)
                    .frame(width: 28, height: 8)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .frame(width: 110, height: 150)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(PSColors.borderLight, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 4)
    }

    private func receiptItemLine(width: CGFloat) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(PSColors.textPrimary.opacity(0.55))
                .frame(width: width, height: 5)
            Spacer()
            RoundedRectangle(cornerRadius: 2)
                .fill(PSColors.textSecondary.opacity(0.5))
                .frame(width: 18, height: 5)
        }
    }

    private var receiptFeaturePills: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            receiptPillRow(
                icon: "tag.fill",
                tint: PSColors.primaryGreen,
                title: String(localized: "Auto-categorise every item"),
                detail: String(localized: "Produce, dairy, bakery — sorted instantly")
            )
            receiptPillRow(
                icon: "calendar.badge.plus",
                tint: PSColors.secondaryAmber,
                title: String(localized: "Pulls expiry dates"),
                detail: String(localized: "Smart shelf-life estimates per item, ready to edit")
            )
            receiptPillRow(
                icon: "sterlingsign.circle.fill",
                tint: PSColors.accentTeal,
                title: String(localized: "Tracks what you spend"),
                detail: String(localized: "Builds your impact dashboard from real receipts")
            )
        }
        .padding(.horizontal, PSSpacing.screenHorizontal)
    }

    private func receiptPillRow(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(spacing: PSSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.16))
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PSColors.textPrimary)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(PSColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(PSSpacing.md)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                .strokeBorder(PSColors.borderLight, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    private var receiptPrivacyChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PSColors.primaryGreen)
            Text(String(localized: "On-device OCR — receipts never leave your iPhone"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PSColors.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(PSColors.primaryGreen.opacity(0.08))
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(PSColors.primaryGreen.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, PSSpacing.screenHorizontal)
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
                    withAnimation(PSMotion.springQuick) {
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
                        Text("\(Int(itemQuantityEdits[item.id] ?? item.quantity)) \(item.unit.displayName(for: Double(Int(itemQuantityEdits[item.id] ?? item.quantity))))")
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

            toastManager.show(.success("Added \(itemsToAdd.count) items to your pantry!"))
            dismiss()
        } catch {
            toastManager.show(.error("Failed to add items: \(error.localizedDescription)"))
        }
    }

    private func daysUntilExpiry(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: date)
        return max(components.day ?? 0, 0)
    }
}

// MARK: - Camera Picker

private struct CameraPickerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    ReceiptScannerView()
        .modelContainer(for: FreshliItem.self, inMemory: true)
}
