import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation

struct FoodScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(PSToastManager.self) private var toastManager: PSToastManager?

    @State private var foodScanner = FoodIdentificationService()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var selectedResultIndices: Set<Int> = []
    @State private var expandedResultId: UUID?
    @State private var resultQuantityEdits: [UUID: Double] = [:]
    @State private var isAddingItems = false

    var resultsToAdd: [FoodIdentificationResult] {
        foodScanner.results.enumerated()
            .filter { selectedResultIndices.contains($0.offset) }
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
                    if case .identified = foodScanner.identificationState, !foodScanner.results.isEmpty {
                        contentView
                    } else if case .idle = foodScanner.identificationState {
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
                isPresented: $showCamera,
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            )
            .onChange(of: selectedPhotoItem) { oldValue, newValue in
                if let newValue {
                    Task {
                        if let data = try await newValue.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            await foodScanner.identifyFood(uiImage)
                        }
                        selectedPhotoItem = nil
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
                    Text("Food Scanner")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)

                    if case .identified = foodScanner.identificationState, !foodScanner.results.isEmpty {
                        Text("\(foodScanner.results.count) items identified")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(PSColors.textSecondary)
                    }
                }

                Spacer()

                if case .identified = foodScanner.identificationState {
                    Text("\(selectedResultIndices.count)/\(foodScanner.results.count)")
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
                Image(systemName: "camera.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(PSColors.primaryGreen)

                VStack(spacing: PSSpacing.sm) {
                    Text("Identify Foods")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)

                    Text("Take a photo or upload an image to identify produce and automatically add items to your pantry")
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
                    action: {
                        // Trigger photos picker
                        selectedPhotoItem = nil
                        showCamera = true
                    }
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
                if case .analyzing = foodScanner.identificationState {
                    PSShimmerView(height: 120, cornerRadius: PSSpacing.radiusMd)
                        .padding(PSSpacing.screenHorizontal)

                    Text("Analyzing image...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(PSColors.textPrimary)
                } else if case .error(let message) = foodScanner.identificationState {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(PSColors.expiredRed)

                    VStack(spacing: PSSpacing.sm) {
                        Text("Identification Failed")
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
                            foodScanner.reset()
                            selectedResultIndices.removeAll()
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
                    ForEach(Array(foodScanner.results.enumerated()), id: \.element.id) { index, result in
                        resultRowView(index: index, result: result)
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
                    title: "Add \(selectedResultIndices.count) to Pantry",
                    icon: "checkmark.circle.fill",
                    style: .primary,
                    isFullWidth: true,
                    isLoading: isAddingItems,
                    action: { addItemsToPantry() }
                )
                .disabled(selectedResultIndices.isEmpty || isAddingItems)
                .opacity(selectedResultIndices.isEmpty || isAddingItems ? 0.5 : 1.0)

                PSButton(
                    title: "Scan Again",
                    icon: "arrow.clockwise",
                    style: .secondary,
                    isFullWidth: true,
                    action: {
                        foodScanner.reset()
                        selectedResultIndices.removeAll()
                        resultQuantityEdits.removeAll()
                    }
                )
            }
            .padding(PSSpacing.screenHorizontal)
            .padding(.vertical, PSSpacing.lg)
        }
        .background(PSColors.backgroundSecondary)
    }

    private func resultRowView(index: Int, result: FoodIdentificationResult) -> some View {
        VStack(spacing: PSSpacing.sm) {
            HStack(spacing: PSSpacing.md) {
                // Checkbox
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if selectedResultIndices.contains(index) {
                            selectedResultIndices.remove(index)
                        } else {
                            selectedResultIndices.insert(index)
                        }
                    }
                }) {
                    Image(systemName: selectedResultIndices.contains(index) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(selectedResultIndices.contains(index) ? PSColors.primaryGreen : PSColors.textSecondary)
                }

                // Item info
                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                    HStack(spacing: PSSpacing.sm) {
                        Text(result.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(PSColors.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        Text(result.category.emoji)
                            .font(.system(size: 16))
                    }

                    HStack(spacing: PSSpacing.md) {
                        HStack(spacing: PSSpacing.xs) {
                            Image(systemName: "percent")
                                .font(.system(size: 11, weight: .semibold))
                            Text("\(Int(result.confidence * 100))% confident")
                        }
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(PSColors.textSecondary)

                        Spacer()

                        Text("Expires in \(result.estimatedShelfLifeDays)d")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(PSColors.warningAmber)
                    }
                }

                Spacer()

                // Expand button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        expandedResultId = expandedResultId == result.id ? nil : result.id
                    }
                }) {
                    Image(systemName: expandedResultId == result.id ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PSColors.primaryGreen)
                }
            }
            .padding(PSSpacing.md)
            .background(PSColors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))

            // Expanded details
            if expandedResultId == result.id {
                expandedDetailsView(result: result)
            }
        }
    }

    private func expandedDetailsView(result: FoodIdentificationResult) -> some View {
        VStack(spacing: PSSpacing.md) {
            // Category & Storage
            HStack(spacing: PSSpacing.md) {
                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                    Text("Category")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PSColors.textSecondary)

                    HStack(spacing: PSSpacing.sm) {
                        Image(systemName: result.category.icon)
                            .foregroundStyle(PSColors.primaryGreen)
                        Text(result.category.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PSColors.textPrimary)
                    }
                }

                Spacer()

                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                    Text("Storage")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PSColors.textSecondary)

                    HStack(spacing: PSSpacing.sm) {
                        Image(systemName: result.storageLocation.icon)
                            .foregroundStyle(PSColors.primaryGreen)
                        Text(result.storageLocation.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PSColors.textPrimary)
                    }
                }
            }

            // Quantity
            VStack(alignment: .leading, spacing: PSSpacing.xs) {
                Text("Quantity")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PSColors.textSecondary)

                HStack(spacing: PSSpacing.md) {
                    Button(action: {
                        let current = resultQuantityEdits[result.id] ?? 1.0
                        if current > 1 {
                            resultQuantityEdits[result.id] = current - 1
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(PSColors.primaryGreen)
                    }

                    Spacer()

                    VStack(alignment: .center, spacing: PSSpacing.xs) {
                        Text("\(Int(resultQuantityEdits[result.id] ?? 1.0))")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(PSColors.textPrimary)

                        Text(result.defaultUnit.displayName)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(PSColors.textSecondary)
                    }

                    Spacer()

                    Button(action: {
                        let current = resultQuantityEdits[result.id] ?? 1.0
                        resultQuantityEdits[result.id] = current + 1
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

            // Add button
            Button(action: {
                addSingleItemToPantry(result)
            }) {
                HStack(spacing: PSSpacing.sm) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add This Item")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(PSSpacing.md)
                .background(PSColors.primaryGreen)
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
        isAddingItems = true

        let itemsToAdd = foodScanner.results.enumerated()
            .filter { selectedResultIndices.contains($0.offset) }
            .map { index, result -> PantryItem in
                let quantity = resultQuantityEdits[result.id] ?? 1.0
                return foodScanner.convertToPantryItem(result, quantity: quantity)
            }

        do {
            for item in itemsToAdd {
                modelContext.insert(item)
            }
            try modelContext.save()

            toastManager?.show(.success("Added \(itemsToAdd.count) items to your pantry!"))
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                dismiss()
            }
        } catch {
            isAddingItems = false
            toastManager?.show(.error("Failed to add items: \(error.localizedDescription)"))
        }
    }

    private func addSingleItemToPantry(_ result: FoodIdentificationResult) {
        let quantity = resultQuantityEdits[result.id] ?? 1.0
        let item = foodScanner.convertToPantryItem(result, quantity: quantity)

        do {
            modelContext.insert(item)
            try modelContext.save()

            toastManager?.show(.success("Added \(result.displayName) to your pantry!"))

            // Remove from view and deselect
            if let index = foodScanner.results.firstIndex(where: { $0.id == result.id }) {
                selectedResultIndices.remove(index)
            }
            expandedResultId = nil
            resultQuantityEdits.removeValue(forKey: result.id)
        } catch {
            toastManager?.show(.error("Failed to add item: \(error.localizedDescription)"))
        }
    }
}

#Preview {
    FoodScannerView()
        .modelContainer(for: PantryItem.self, inMemory: true)
}
