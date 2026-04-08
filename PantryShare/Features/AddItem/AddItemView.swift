import SwiftUI
import SwiftData

// Figma: Add Item — full-screen emerald theme (bg-white, emerald accents)
// Scan Barcode + Scan Receipt buttons (emerald-50, rounded-3xl, border-dashed)
// "or manually" divider
// Fields: Item Name, Quantity, Expiry Date, Location, Category
// All inputs: emerald-50/50 bg, border-emerald-100, rounded-2xl
// Success: emerald-600/90 overlay with CheckCircle + spring animation

struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(CelebrationManager.self) private var celebrationManager: CelebrationManager?
    @Environment(AuthManager.self) private var authManager: AuthManager?
    @Environment(SyncService.self) private var syncService: SyncService?

    @State private var name = ""
    @State private var category: FoodCategory = .other
    @State private var storageLocation: StorageLocation = .pantry
    @State private var quantity: Double = 1
    @State private var unit: MeasurementUnit = .pieces
    @State private var expiryDate = Date.daysFromNow(7)
    @State private var barcode: String?
    @State private var showScanner = false
    @State private var showSuccess = false
    @State private var showReceiptInfo = false

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && quantity > 0
    }

    var body: some View {
        ZStack {
            // Main form
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: PSLayout.cardPadding) {
                        scanButtons
                        orDivider
                        formFields
                    }
                    .adaptiveHPadding()
                    .padding(.vertical, PSLayout.cardPadding)
                }

                // Figma: sticky save button at bottom
                saveButton
            }
            .background(PSColors.surfaceCard)

            // Figma: success overlay — emerald-600/90 with CheckCircle
            if showSuccess {
                successOverlay
            }
        }
        .navigationTitle(String(localized: "Add Item"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                        .foregroundStyle(PSColors.primaryGreen)
                        .frame(width: PSLayout.iconButtonSize, height: PSLayout.iconButtonSize)
                        .background(PSColors.emeraldSurface)
                        .clipShape(Circle())
                }
            }
        }
        .sheet(isPresented: $showScanner) {
            BarcodeScannerView { scannedCode in
                handleScannedBarcode(scannedCode)
            }
        }
        .alert(String(localized: "Receipt Scanning"), isPresented: $showReceiptInfo) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(String(localized: "AI-powered receipt scanning is coming soon! For now, use the barcode scanner or add items manually."))
        }
    }

    // MARK: - Figma: Scan Barcode + Scan Receipt buttons

    private var scanButtons: some View {
        HStack(spacing: 16) {
            // Figma: Scan Barcode button
            Button { showScanner = true } label: {
                VStack(spacing: 12) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: PSLayout.scaledFont(32), weight: .light))
                        .foregroundStyle(PSColors.primaryGreen)
                    Text(String(localized: "Scan Barcode"))
                        .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                        .foregroundStyle(Color(hex: 0x065F46))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(PSColors.emeraldSurface)
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                        .strokeBorder(PSColors.emeraldLight.opacity(0.5), lineWidth: 1)
                )
            }
            .buttonStyle(PressableButtonStyle())

            // Figma: Scan Receipt button
            Button { showReceiptInfo = true } label: {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: PSLayout.scaledFont(32), weight: .light))
                        .foregroundStyle(PSColors.primaryGreen)
                    Text(String(localized: "Scan Receipt"))
                        .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                        .foregroundStyle(Color(hex: 0x065F46))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(PSColors.emeraldSurface)
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                        .strokeBorder(PSColors.emeraldLight.opacity(0.5), lineWidth: 1)
                )
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    // Figma: "or manually" divider
    private var orDivider: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(PSColors.emeraldLight)
                .frame(height: 1)
            Text(String(localized: "OR MANUALLY"))
                .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
                .tracking(1.5)
                .foregroundStyle(PSColors.primaryGreen.opacity(0.5))
            Rectangle()
                .fill(PSColors.emeraldLight)
                .frame(height: 1)
        }
    }

    // MARK: - Figma: Form fields (emerald-50/50 bg, border-emerald-100, rounded-2xl)

    private var formFields: some View {
        VStack(spacing: 20) {
            // Item Name
            emeraldField(label: String(localized: "Item Name")) {
                TextField(String(localized: "e.g. Organic Milk"), text: $name)
                    .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
                    .padding(16)
            }

            // Quantity + Expiry Date (adaptive 2-col / 1-col)
            AdaptiveFormRow {
                emeraldField(label: String(localized: "Quantity")) {
                    TextField(String(localized: "1"), value: $quantity, format: .number)
                        .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
                        .keyboardType(.decimalPad)
                        .padding(16)
                }

                emeraldField(label: String(localized: "Expiry Date")) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: PSLayout.scaledFont(18)))
                            .foregroundStyle(PSColors.primaryGreen.opacity(0.6))
                        DatePicker("", selection: $expiryDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(PSColors.primaryGreen)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }

            // Location + Category (adaptive 2-col / 1-col)
            AdaptiveFormRow {
                emeraldField(label: String(localized: "Location")) {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin")
                            .font(.system(size: PSLayout.scaledFont(18)))
                            .foregroundStyle(PSColors.primaryGreen.opacity(0.6))
                        Picker("", selection: $storageLocation) {
                            ForEach(StorageLocation.allCases) { loc in
                                Text(loc.displayName).tag(loc)
                            }
                        }
                        .tint(PSColors.textPrimary)
                        .labelsHidden()
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                emeraldField(label: String(localized: "Category")) {
                    HStack(spacing: 8) {
                        Image(systemName: "tag")
                            .font(.system(size: PSLayout.scaledFont(18)))
                            .foregroundStyle(PSColors.primaryGreen.opacity(0.6))
                        Picker("", selection: $category) {
                            ForEach(FoodCategory.allCases) { cat in
                                Text(cat.displayName).tag(cat)
                            }
                        }
                        .tint(PSColors.textPrimary)
                        .labelsHidden()
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    private func emeraldField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                .foregroundStyle(Color(hex: 0x064E3B))
                .padding(.leading, 4)
            content()
                .background(PSColors.emeraldSurface.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                        .strokeBorder(PSColors.emeraldLight, lineWidth: 1)
                )
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        VStack {
            PSButton(
                title: String(localized: "Save Item"),
                style: .primary
            ) {
                saveItem()
            }
            .disabled(!isFormValid)
            .opacity(isFormValid ? 1 : 0.5)
        }
        .padding(PSLayout.cardPadding)
        .background(PSColors.surfaceCard)
        .overlay(alignment: .top) { Divider().foregroundStyle(PSColors.emeraldSurface) }
    }

    // MARK: - Figma: Success Overlay

    private var successOverlay: some View {
        ZStack {
            PSColors.primaryGreen.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: PSLayout.scaledFont(80), weight: .regular))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

                Text(String(localized: "Added to Pantry!"))
                    .font(.system(size: PSLayout.scaledFont(30), weight: .bold))
                    .tracking(-0.3)
                    .foregroundStyle(.white)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(PSMotion.springBouncy, value: showSuccess)
    }

    // MARK: - Actions

    private func saveItem() {
        PSHaptics.shared.success()
        let item = PantryItem(
            name: name.trimmingCharacters(in: .whitespaces),
            category: category,
            storageLocation: storageLocation,
            quantity: quantity,
            unit: unit,
            expiryDate: expiryDate,
            barcode: barcode,
            notes: nil
        )
        modelContext.insert(item)
        try? modelContext.save()

        let notificationService = NotificationService()
        notificationService.scheduleExpiryReminder(for: item)

        // Trigger celebration system
        celebrationManager?.onItemAdded(modelContext: modelContext)

        // Update widget data
        WidgetDataService.updateWidgetData(modelContext: modelContext)

        // Sync to Supabase if authenticated
        if let userId = authManager?.currentUserId {
            Task {
                await syncService?.pushPantryItem(item, userId: userId)
                await syncService?.recordImpactEvent(
                    userId: userId,
                    eventType: "item_saved",
                    itemName: item.name,
                    quantity: item.quantity
                )
            }
        }

        withAnimation(PSMotion.springBouncy) { showSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
    }

    private func handleScannedBarcode(_ code: String) {
        PSHaptics.shared.mediumTap()
        barcode = code
        let scannerService = ScannerService()
        if let product = scannerService.lookupBarcode(code) {
            name = product.name
            category = product.category
            storageLocation = product.storageLocation
        }
    }
}

// MARK: - Adaptive Form Row (2-col on standard+, 1-col on compact)

private struct AdaptiveFormRow<A: View, B: View>: View {
    let first: A
    let second: B

    init(@ViewBuilder content: () -> TupleView<(A, B)>) {
        let views = content().value
        self.first = views.0
        self.second = views.1
    }

    var body: some View {
        if PSLayout.shouldStackFormFields {
            VStack(spacing: 16) {
                first
                second
            }
        } else {
            HStack(spacing: 16) {
                first
                second
            }
        }
    }
}
