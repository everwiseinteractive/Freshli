import SwiftUI
import SwiftData

struct FreshliDetailView: View {
    @Bindable var item: FreshliItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(CelebrationManager.self) private var celebrationManager
    @Environment(PSToastManager.self) private var toastManager
    @Environment(AuthManager.self) private var authManager
    @Environment(SyncService.self) private var syncService

    @State private var showDeleteConfirmation = false
    @State private var isEditing = false
    @State private var editedName: String = ""
    @State private var editedQuantity: Double = 1
    @State private var editedUnit: MeasurementUnit = .pieces
    @State private var editedCategory: FoodCategory = .other
    @State private var editedLocation: StorageLocation = .pantry
    @State private var editedExpiryDate: Date = Date()
    @State private var editedNotes: String = ""
    @State private var showSuccessAnimation = false
    @State private var successFlashTrigger = false
    @State private var showPreservationGuide = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: PSSpacing.xxl) {
                headerSection
                detailsSection
                Group {
                    if isEditing { editSection } else { infoSection }
                }
                .flAnimation(PSMotion.springDefault, value: isEditing)
                actionsSection
                    .successFlash(trigger: $successFlashTrigger)
            }
            .padding(.vertical, PSSpacing.lg)
            .padding(.horizontal, PSSpacing.screenHorizontal)
        }
        .background(PSColors.backgroundPrimary)
        .navigationTitle(isEditing ? String(localized: "Edit Item") : item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(String(localized: "Close")) { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? String(localized: "Save") : String(localized: "Edit")) {
                    if isEditing {
                        PSHaptics.shared.mediumTap()
                        saveEdits()
                    } else {
                        PSHaptics.shared.lightTap()
                        startEditing()
                    }
                }
                .fontWeight(.semibold)
                .foregroundStyle(PSColors.primaryGreen)
            }
        }
        .sheet(isPresented: $showPreservationGuide) {
            PreservationGuideView(item: item)
        }
        .confirmationDialog(String(localized: "Delete Item"), isPresented: $showDeleteConfirmation) {
            Button(String(localized: "Delete"), role: .destructive) {
                modelContext.delete(item)
                do {
                    try modelContext.save()
                    PSLogger.general.info("Item deleted successfully")
                    dismiss()
                } catch {
                    PSLogger.general.error("Failed to delete item: \(error.localizedDescription)")
                    toastManager.show(.error(String(localized: "Failed to delete item")))
                }
            }
        } message: {
            Text(String(localized: "This will permanently remove \(item.name) from your pantry."))
        }
        .overlay {
            if showSuccessAnimation {
                successOverlay
            }
        }
    }

    private var headerSection: some View {
        HStack(spacing: PSSpacing.lg) {
            Image(systemName: item.category.icon)
                .font(.system(size: PSLayout.scaledFont(28), weight: .semibold))
                .foregroundStyle(PSColors.categoryColor(for: item.category))
                .frame(width: PSLayout.scaled(60), height: PSLayout.scaled(60))
                .background(PSColors.categoryColor(for: item.category).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))

            VStack(alignment: .leading, spacing: PSSpacing.xxs) {
                Text(item.name)
                    .font(PSTypography.title2)
                    .foregroundStyle(PSColors.textPrimary)
                PSExpiryBadge(status: item.expiryStatus)
            }

            Spacer()
        }
    }

    private var detailsSection: some View {
        HStack(spacing: PSSpacing.md) {
            DetailChip(icon: "number", label: item.quantityDisplay)
            DetailChip(icon: item.storageLocation.icon, label: item.storageLocation.displayName)
            DetailChip(icon: "calendar", label: item.expiryDate.shortDisplay)
            DetailChip(icon: item.category.icon, label: item.category.displayName)
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.lg) {
            if let notes = item.notes, !notes.isEmpty {
                PSCard {
                    Label(String(localized: "Notes"), systemImage: "note.text")
                        .font(PSTypography.caption1Medium)
                        .foregroundStyle(PSColors.textSecondary)
                    Text(notes)
                        .font(PSTypography.body)
                        .foregroundStyle(PSColors.textPrimary)
                }
            }

            PSCard {
                Label(String(localized: "Added"), systemImage: "calendar.badge.plus")
                    .font(PSTypography.caption1Medium)
                    .foregroundStyle(PSColors.textSecondary)
                Text(item.dateAdded, style: .date)
                    .font(PSTypography.body)
                    .foregroundStyle(PSColors.textPrimary)
            }

            if let barcode = item.barcode {
                PSCard {
                    Label(String(localized: "Barcode"), systemImage: "barcode")
                        .font(PSTypography.caption1Medium)
                        .foregroundStyle(PSColors.textSecondary)
                    Text(barcode)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(PSColors.textPrimary)
                }
            }
        }
    }

    private var editSection: some View {
        VStack(spacing: PSSpacing.lg) {
            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                Text(String(localized: "Name")).font(PSTypography.caption1Medium).foregroundStyle(PSColors.textSecondary)
                TextField(String(localized: "Item name"), text: $editedName)
                    .font(PSTypography.body)
                    .padding(PSSpacing.md)
                    .background(PSColors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous))
            }

            HStack(spacing: PSSpacing.lg) {
                VStack(alignment: .leading, spacing: PSSpacing.sm) {
                    Text(String(localized: "Quantity")).font(PSTypography.caption1Medium).foregroundStyle(PSColors.textSecondary)
                    PSQuantityStepper(value: $editedQuantity, unit: editedUnit.displayName)
                }
                VStack(alignment: .leading, spacing: PSSpacing.sm) {
                    Text(String(localized: "Unit")).font(PSTypography.caption1Medium).foregroundStyle(PSColors.textSecondary)
                    Picker("", selection: $editedUnit) {
                        ForEach(MeasurementUnit.allCases) { unit in
                            Text(unit.fullName).tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(PSColors.primaryGreen)
                }
            }

            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                Text(String(localized: "Expiry Date")).font(PSTypography.caption1Medium).foregroundStyle(PSColors.textSecondary)
                DatePicker("", selection: $editedExpiryDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }

            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                Text(String(localized: "Notes")).font(PSTypography.caption1Medium).foregroundStyle(PSColors.textSecondary)
                TextField(String(localized: "Optional notes..."), text: $editedNotes, axis: .vertical)
                    .font(PSTypography.body)
                    .lineLimit(3...6)
                    .padding(PSSpacing.md)
                    .background(PSColors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous))
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: PSSpacing.md) {
            PSButton(title: String(localized: "Mark as Consumed"), icon: "checkmark.circle", style: .secondary) {
                PSHaptics.shared.success()
                let itemName = item.name
                successFlashTrigger = true
                withAnimation(FLMotion.adaptive(PSMotion.springBouncy, reduceMotion: reduceMotion)) {
                    item.isConsumed = true
                    do {
                        try modelContext.save()
                        PSLogger.general.info("Item marked as consumed")
                        showSuccessAnimation = true
                    } catch {
                        PSLogger.general.error("Failed to mark item consumed: \(error.localizedDescription)")
                        toastManager.show(.error(String(localized: "Failed to save")))
                        return
                    }
                }
                celebrationManager.fireFoodSaved(modelContext: modelContext)
                toastManager.show(.itemConsumed(itemName))
                WidgetDataService.updateWidgetData(modelContext: modelContext)
                if let userId = authManager.currentUserId {
                    Task {
                        await syncService.pushFreshliItem(item, userId: userId)
                        await syncService.recordImpactEvent(userId: userId, eventType: "consumed", itemName: itemName, moneySaved: 3.50, co2Avoided: 2.5)
                    }
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(1200))
                    dismiss()
                }
            }

            HStack(spacing: PSSpacing.md) {
                PSButton(title: String(localized: "Share"), icon: "hand.raised", style: .secondary, isFullWidth: true) {
                    PSHaptics.shared.success()
                    let itemName = item.name
                    item.isShared = true
                    do {
                        try modelContext.save()
                        PSLogger.general.info("Item marked as shared")
                    } catch {
                        PSLogger.general.error("Failed to mark item shared: \(error.localizedDescription)")
                        toastManager.show(.error(String(localized: "Failed to save")))
                        return
                    }
                    celebrationManager.fireShareCompleted(itemName: itemName, modelContext: modelContext)
                    toastManager.show(.itemShared(itemName))
                    WidgetDataService.updateWidgetData(modelContext: modelContext)
                    if let userId = authManager.currentUserId {
                        Task {
                            await syncService.pushFreshliItem(item, userId: userId)
                            await syncService.recordImpactEvent(userId: userId, eventType: "shared", itemName: itemName, co2Avoided: 2.5)
                        }
                    }
                    dismiss()
                }
                PSButton(title: String(localized: "Donate"), icon: "heart", style: .secondary, isFullWidth: true) {
                    PSHaptics.shared.success()
                    let itemName = item.name
                    item.isDonated = true
                    do {
                        try modelContext.save()
                        PSLogger.general.info("Item marked as donated")
                    } catch {
                        PSLogger.general.error("Failed to mark item donated: \(error.localizedDescription)")
                        toastManager.show(.error(String(localized: "Failed to save")))
                        return
                    }
                    celebrationManager.fireDonationCompleted(itemName: itemName, modelContext: modelContext)
                    toastManager.show(.itemDonated(itemName))
                    WidgetDataService.updateWidgetData(modelContext: modelContext)
                    if let userId = authManager.currentUserId {
                        Task {
                            await syncService.pushFreshliItem(item, userId: userId)
                            await syncService.recordImpactEvent(userId: userId, eventType: "donated", itemName: itemName, co2Avoided: 2.5)
                        }
                    }
                    dismiss()
                }
            }

            Button {
                PSHaptics.shared.lightTap()
                showPreservationGuide = true
            } label: {
                HStack(spacing: PSSpacing.sm) {
                    Image(systemName: "snowflake")
                        .font(.system(size: PSLayout.scaledFont(15), weight: .semibold))
                    Text(String(localized: "Save it for Later 🧊"))
                        .font(.system(size: PSLayout.scaledFont(15), weight: .semibold))
                }
                .foregroundStyle(PSColors.accentTeal)
                .frame(maxWidth: .infinity)
                .padding(.vertical, PSSpacing.md)
                .background(PSColors.accentTeal.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                    .strokeBorder(PSColors.accentTeal.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(PressableButtonStyle())

            PSButton(title: String(localized: "Delete Item"), icon: "trash", style: .destructive) {
                PSHaptics.shared.heavyTap()
                showDeleteConfirmation = true
            }
        }
        .padding(.top, PSSpacing.md)
    }

    private var successOverlay: some View {
        VStack(spacing: PSSpacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: PSLayout.scaledFont(64)))
                .foregroundStyle(PSColors.freshGreen)
                .symbolEffect(.bounce)
            Text(String(localized: "Item Consumed!"))
                .font(PSTypography.title3)
                .foregroundStyle(PSColors.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .transition(.opacity)
    }

    private func startEditing() {
        editedName = item.name
        editedQuantity = item.quantity
        editedUnit = item.unit
        editedCategory = item.category
        editedLocation = item.storageLocation
        editedExpiryDate = item.expiryDate
        editedNotes = item.notes ?? ""
        withAnimation(FLMotion.adaptive(PSMotion.springDefault, reduceMotion: reduceMotion)) { isEditing = true }
    }

    private func saveEdits() {
        // Validate name is not empty
        guard !editedName.trimmingCharacters(in: .whitespaces).isEmpty else {
            toastManager.show(.error(String(localized: "Item name cannot be empty")))
            return
        }

        let oldExpiryDate = item.expiryDate
        item.name = editedName
        item.quantity = editedQuantity
        item.unit = editedUnit
        item.category = editedCategory
        item.storageLocation = editedLocation
        item.expiryDate = editedExpiryDate
        item.notes = editedNotes.isEmpty ? nil : editedNotes

        do {
            try modelContext.save()
            PSLogger.general.info("Item edited successfully")

            // If expiry date changed, reschedule notification
            if oldExpiryDate != editedExpiryDate {
                // Re-add the notification with the new date
                WidgetDataService.updateWidgetData(modelContext: modelContext)
            }

            successFlashTrigger = true
            withAnimation(FLMotion.adaptive(PSMotion.springDefault, reduceMotion: reduceMotion)) { isEditing = false }
            toastManager.show(.success(String(localized: "Item saved")))
        } catch {
            PSLogger.general.error("Failed to save edits: \(error.localizedDescription)")
            toastManager.show(.error(String(localized: "Failed to save changes")))
        }
    }
}

struct DetailChip: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: PSSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
                .foregroundStyle(PSColors.textSecondary)
            Text(label)
                .font(PSTypography.caption1Medium)
                .foregroundStyle(PSColors.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PSSpacing.md)
        .background(PSColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous))
    }
}
