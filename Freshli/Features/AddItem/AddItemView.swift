import SwiftUI
import SwiftData
import os

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
    @Environment(NetworkMonitor.self) private var networkMonitor: NetworkMonitor?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    @State private var saveError: String?
    @State private var saveMessage: String?

    private let logger = Logger(subsystem: "com.freshli.app", category: "AddItemView")

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && quantity > 0
    }

    private var expiryWarning: String? {
        if expiryDate < Date() {
            return String(localized: "This date is in the past")
        }
        return nil
    }

    var body: some View {
        ZStack {
            // Main form with keyboard avoidance
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
                .ignoresSafeArea(.keyboard)

                // Figma: sticky save button at bottom
                saveButton
            }
            .background(PSColors.surfaceCard)
            .onAppear {
                logger.info("AddItemView appeared — category: \(category.rawValue)")
                // Adjust scroll position when keyboard appears
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(100))
                    UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .first?.windows
                        .first?.rootViewController?.view.layoutIfNeeded()
                }
            }

            // Figma: success overlay — emerald-600/90 with CheckCircle
            if showSuccess {
                successOverlay
            }
        }
        .sensoryFeedback(.success, trigger: showSuccess)
        .navigationTitle(String(localized: "Add Item"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(String(localized: "Error Saving Item"), isPresented: .constant(saveError != nil)) {
            Button(String(localized: "OK"), role: .cancel) {
                saveError = nil
            }
        } message: {
            if let error = saveError {
                Text(error)
            }
        }
        .alert(String(localized: "Item Saved"), isPresented: .constant(saveMessage != nil)) {
            Button(String(localized: "OK"), role: .cancel) {
                saveMessage = nil
            }
        } message: {
            if let message = saveMessage {
                Text(message)
            }
        }
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
        // Smart Defaults: auto-update expiry date when category changes
        .onChange(of: category) { _, newCategory in
            // Only auto-adjust if expiry hasn't been manually changed from the default
            let previousDefault = Date.daysFromNow(7) // original default
            let tolerance: TimeInterval = 86400 // 1 day tolerance
            if abs(expiryDate.timeIntervalSince(previousDefault)) < tolerance || barcode == nil {
                withAnimation(FLMotion.springQuick) {
                    expiryDate = Date.daysFromNow(newCategory.defaultExpiryDays)
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
        HStack(spacing: PSSpacing.lg) {
            // Figma: Scan Barcode button
            Button { showScanner = true } label: {
                VStack(spacing: PSSpacing.md) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: PSLayout.scaledFont(32), weight: .light))
                        .foregroundStyle(PSColors.primaryGreen)
                    Text(String(localized: "Scan Barcode"))
                        .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                        .foregroundStyle(Color(hex: 0x065F46))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, PSSpacing.xl)
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
                VStack(spacing: PSSpacing.md) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: PSLayout.scaledFont(32), weight: .light))
                        .foregroundStyle(PSColors.primaryGreen)
                    Text(String(localized: "Scan Receipt"))
                        .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                        .foregroundStyle(Color(hex: 0x065F46))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, PSSpacing.xl)
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
        HStack(spacing: PSSpacing.lg) {
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
        VStack(spacing: PSSpacing.xl) {
            // Item Name
            emeraldField(label: String(localized: "Item Name")) {
                TextField(String(localized: "e.g. Organic Milk"), text: $name)
                    .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
                    .padding(PSSpacing.lg)
            }

            // Quantity + Expiry Date (adaptive 2-col / 1-col)
            AdaptiveFormRow {
                emeraldField(label: String(localized: "Quantity")) {
                    TextField(String(localized: "1"), value: $quantity, format: .number)
                        .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
                        .keyboardType(.decimalPad)
                        .padding(PSSpacing.lg)
                }

                VStack(alignment: .leading, spacing: PSSpacing.sm) {
                    emeraldField(label: String(localized: "Expiry Date")) {
                        HStack(spacing: PSSpacing.sm) {
                            Image(systemName: "calendar")
                                .font(.system(size: PSLayout.scaledFont(18)))
                                .foregroundStyle(PSColors.primaryGreen.opacity(0.6))
                            // Prevent DatePicker from expanding beyond bounds on SE
                            DatePicker("", selection: $expiryDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(PSColors.primaryGreen)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, PSSpacing.lg)
                        .padding(.vertical, PSSpacing.md)
                    }
                    if let warning = expiryWarning {
                        Text(warning)
                            .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                            .foregroundStyle(PSColors.secondaryAmber)
                            .padding(.leading, 4)
                    }
                }
            }

            // Location + Category (adaptive 2-col / 1-col)
            AdaptiveFormRow {
                emeraldField(label: String(localized: "Location")) {
                    HStack(spacing: PSSpacing.sm) {
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
                    .padding(.horizontal, PSSpacing.lg)
                    .padding(.vertical, PSSpacing.md)
                }

                emeraldField(label: String(localized: "Category")) {
                    HStack(spacing: PSSpacing.sm) {
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
                    .padding(.horizontal, PSSpacing.lg)
                    .padding(.vertical, PSSpacing.md)
                }
            }
        }
    }

    private func emeraldField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            Text(label)
                .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                .foregroundStyle(Color(hex: 0x064E3B))
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)
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

            VStack(spacing: PSSpacing.xxl) {
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
        .transition(.flCelebrationPop)
        .flAnimation(PSMotion.springBouncy, value: showSuccess)
        .accessibilityLabel(String(localized: "Success"))
        .accessibilityValue(String(localized: "\(name) added to pantry"))
        .accessibilityElement(children: .ignore)
    }

    // MARK: - Actions

    private func saveItem() {
        PSHaptics.shared.success()
        let item = FreshliItem(
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

        do {
            try modelContext.save()

            let notificationService = NotificationService()
            notificationService.scheduleExpiryReminder(for: item)

            // Trigger celebration system
            celebrationManager?.fireItemAdded(modelContext: modelContext)

            // Update widget data
            WidgetDataService.updateWidgetData(modelContext: modelContext)

            let isOnline = networkMonitor?.isConnected ?? true

            // Sync to Supabase if authenticated and online
            if let userId = authManager?.currentUserId {
                if isOnline {
                    Task {
                        await syncService?.pushFreshliItem(item, userId: userId)
                        await syncService?.recordImpactEvent(
                            userId: userId,
                            eventType: "item_saved",
                            itemName: item.name,
                            quantity: item.quantity
                        )
                    }
                } else {
                    // Add to offline sync queue
                    if let data = try? JSONEncoder().encode(FreshliItemDTO(from: item, userId: userId)) {
                        OfflineSyncQueue.shared.enqueueItemPush(itemData: data)
                    }
                    saveMessage = String(localized: "Item saved. Will sync when you're back online.")
                }
            }

            withAnimation(FLMotion.adaptive(PSMotion.springBouncy, reduceMotion: reduceMotion)) { showSuccess = true }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1200))
                dismiss()
            }
        } catch {
            saveError = String(localized: "Failed to save item. Please try again.")
            PSHaptics.shared.warning()
        }
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
            VStack(spacing: PSSpacing.lg) {
                first
                second
            }
        } else {
            HStack(spacing: PSSpacing.lg) {
                first
                second
            }
        }
    }
}

#Preview("AddItemView - iPhone SE") {
    NavigationStack {
        AddItemView()
    }
}

#Preview("AddItemView - iPhone 16 Pro Max") {
    NavigationStack {
        AddItemView()
    }
}
