import SwiftUI
import SwiftData

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CelebrationManager.self) private var celebrationManager
    
    @State private var name = ""
    @State private var selectedCategory: FoodCategory = .other
    @State private var selectedLocation: StorageLocation = .fridge
    @State private var quantity: Double = 1.0
    @State private var selectedUnit: MeasurementUnit = .pieces
    @State private var expiryDate = Date.daysFromNow(7)
    @State private var notes = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: PSSpacing.xl) {
                // Header
                Text("Add Item")
                    .font(.system(size: 28, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Name Field
                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                    Text("Item Name")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PSColors.textSecondary)
                    TextField("e.g., Milk, Apples, Bread", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Category Picker
                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                    Text("Category")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PSColors.textSecondary)
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(FoodCategory.allCases) { category in
                            Text("\(category.emoji) \(category.displayName)")
                                .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Storage Location
                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                    Text("Storage Location")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PSColors.textSecondary)
                    Picker("Location", selection: $selectedLocation) {
                        ForEach(StorageLocation.allCases) { location in
                            Label(location.displayName, systemImage: location.icon)
                                .tag(location)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Quantity and Unit
                HStack(spacing: PSSpacing.lg) {
                    VStack(alignment: .leading, spacing: PSSpacing.xs) {
                        Text("Quantity")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PSColors.textSecondary)
                        TextField("1", value: $quantity, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.decimalPad)
                    }
                    
                    VStack(alignment: .leading, spacing: PSSpacing.xs) {
                        Text("Unit")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PSColors.textSecondary)
                        Picker("Unit", selection: $selectedUnit) {
                            ForEach(MeasurementUnit.allCases) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                // Expiry Date
                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                    Text("Expiry Date")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PSColors.textSecondary)
                    DatePicker("Expiry Date", selection: $expiryDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
                
                // Notes
                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                    Text("Notes (Optional)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PSColors.textSecondary)
                    TextField("Add any notes...", text: $notes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...5)
                }
                
                // Save Button
                Button {
                    saveItem()
                } label: {
                    Text("Add to Pantry")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, PSSpacing.lg)
                        .background(name.isEmpty ? Color.gray : PSColors.primaryGreen)
                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg))
                }
                .disabled(name.isEmpty)
            }
            .padding(PSLayout.adaptiveHorizontalPadding)
        }
        .background(PSColors.backgroundSecondary)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
    
    private func saveItem() {
        let item = FreshliItem(
            name: name,
            category: selectedCategory,
            storageLocation: selectedLocation,
            quantity: quantity,
            unit: selectedUnit,
            expiryDate: expiryDate,
            notes: notes.isEmpty ? nil : notes
        )
        
        modelContext.insert(item)
        
        do {
            try modelContext.save()
            PSHaptics.shared.success()
            
            // Trigger celebration
            Task {
                await celebrationManager.onItemAdded(modelContext: modelContext)
            }
            
            dismiss()
        } catch {
            PSHaptics.shared.error()
        }
    }
}

#Preview {
    NavigationStack {
        AddItemView()
            .modelContainer(for: FreshliItem.self, inMemory: true)
    }
}
