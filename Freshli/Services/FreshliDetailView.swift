import SwiftUI
import SwiftData

struct FreshliDetailView: View {
    let item: FreshliItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: PSSpacing.xl) {
                // Item Header
                VStack(spacing: PSSpacing.md) {
                    Text(item.category.emoji)
                        .font(.system(size: 80))
                    
                    Text(item.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                    
                    // Expiry Status Badge
                    HStack(spacing: PSSpacing.xs) {
                        Image(systemName: item.expiryStatus.icon)
                        Text(item.expiryDate.expiryDisplayText)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PSColors.statusColor(for: item.expiryStatus))
                    .padding(.horizontal, PSSpacing.md)
                    .padding(.vertical, PSSpacing.xs)
                    .background(PSColors.statusColor(for: item.expiryStatus).opacity(0.1))
                    .clipShape(Capsule())
                }
                .padding(.top, PSSpacing.xl)
                
                // Details
                VStack(spacing: PSSpacing.lg) {
                    DetailRow(icon: "tag.fill", label: "Category", value: item.category.displayName)
                    DetailRow(icon: item.storageLocation.icon, label: "Location", value: item.storageLocation.displayName)
                    DetailRow(icon: "number", label: "Quantity", value: item.quantityDisplay)
                    DetailRow(icon: "calendar", label: "Added", value: item.dateAdded.relativeDescription)
                    
                    if let notes = item.notes {
                        VStack(alignment: .leading, spacing: PSSpacing.xs) {
                            HStack {
                                Image(systemName: "note.text")
                                    .foregroundStyle(PSColors.primaryGreen)
                                Text("Notes")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(PSColors.textSecondary)
                            }
                            Text(notes)
                                .font(.system(size: 14))
                                .foregroundStyle(PSColors.textPrimary)
                                .padding(PSSpacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(PSColors.surfaceCard)
                                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd))
                        }
                    }
                }
                .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
                
                // Actions
                VStack(spacing: PSSpacing.md) {
                    Button {
                        markAsConsumed()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Mark as Consumed")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, PSSpacing.lg)
                        .background(PSColors.primaryGreen)
                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg))
                    }
                    
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Item")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PSColors.expiredRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, PSSpacing.lg)
                        .background(PSColors.expiredRed.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg))
                    }
                }
                .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
            }
            .padding(.bottom, PSSpacing.hero)
        }
        .background(PSColors.backgroundSecondary)
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete Item?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteItem()
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    private func markAsConsumed() {
        item.isConsumed = true
        try? modelContext.save()
        PSHaptics.shared.success()
        dismiss()
    }
    
    private func deleteItem() {
        modelContext.delete(item)
        try? modelContext.save()
        PSHaptics.shared.success()
        dismiss()
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(PSColors.primaryGreen)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PSColors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundStyle(PSColors.textPrimary)
        }
        .padding(PSSpacing.md)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd))
    }
}

#Preview {
    NavigationStack {
        FreshliDetailView(item: FreshliItem(
            name: "Milk",
            category: .dairy,
            storageLocation: .fridge,
            quantity: 1,
            unit: .liters,
            expiryDate: Date.daysFromNow(3),
            notes: "Organic whole milk"
        ))
        .modelContainer(for: FreshliItem.self, inMemory: true)
    }
}
