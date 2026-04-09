import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation

struct FoodScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(FLToastManager.self) private var toastManager: FLToastManager?

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
                FLColors.backgroundSecondary
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
                            .foregroundStyle(FLColors.textSecondary)
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
            HStack(spacing: FLSpacing.md) {
                VStack(alignment: .leading, spacing: FLSpacing.xs) {
                    Text("Food Scanner")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(FLColors.textPrimary)

                    if case .identified = foodScanner.identificationState, !foodScanner.results.isEmpty {
                        Text("\(foodScanner.results.count) items identified")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(FLColors.textSecondary)
                    }
                }

                Spacer()

                if case .identified = foodScanner.identificationState {
                    Text("\(selectedResultIndices.count)/\(foodScanner.results.count)")
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
                Image(systemName: "camera.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(FLColors.primaryGreen)

                VStack(spacing: FLSpacing.sm) {
                    Text("Identify Foods")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(FLColors.textPrimary)

                    Text("Take a photo or upload an image to identify produce and automatically add items to your pantry")
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
                    action: {
                        // Trigger photos picker
                        selectedPhotoItem = nil
                        showCamera = true
                    }
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
                if case .analyzing = foodScanner.identificationState {
                    FLShimmerView(height: 120, cornerRadius: FLSpacing.radiusMd)
                        .padding(FLSpacing.screenHorizontal)

                    Text("Analyzing image...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(FLColors.textPrimary)
                } else if case .error(let message) = foodScanner.identificationState {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(FLColors.expiredRed)

                    VStack(spacing: FLSpacing.sm) {
                        Text("Identification Failed")
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
                            foodScanner.reset()
                            selectedResultIndices.removeAll()
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
                    ForEach(Array(foodScanner.results.enumerated()), id: \.element.id) { index, result in
                        resultRowView(index: index, result: result)
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
                    title: "Add \(selectedResultIndices.count) to Pantry",
                    icon: "checkmark.circle.fill",
                    style: .primary,
                    isFullWidth: true,
                    isLoading: isAddingItems,
                    action: { addItemsToPantry() }
                )
                .disabled(selectedResultIndices.isEmpty || isAddingItems)
                .opacity(selectedResultIndices.isEmpty || isAddingItems ? 0.5 : 1.0)

                FLButton(
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
            .padding(FLSpacing.screenHorizontal)
            .padding(.vertical, FLSpacing.lg)
        }
        .background(FLColors.backgroundSecondary)
    }

    private func resultRowView(index: Int, result: FoodIdentificationResult) -> some View {
        VStack(spacing: FLSpacing.sm) {
            HStack(spacing: FLSpacing.md) {
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
                        .foregroundStyle(selectedResultIndices.contains(index) ? FLColors.primaryGreen : FLColors.textSecondary)
                }

                // Item info
                VStack(alignment: .leading, spacing: FLSpacing.xs) {
                    HStack(spacing: FLSpacing.sm) {
                        Text(result.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(FLColors.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        Text(result.category.emoji)
                            .font(.system(size: 16))
                    }

                    HStack(spacing: FLSpacing.md) {
                        HStack(spacing: FLSpacing.xs) {
                            Image(systemName: "percent")
                                .font(.system(size: 11, weight: .semibold))
                            Text("\(Int(result.confidence * 100))% confident")
                        }
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(FLColors.textSecondary)

                        Spacer()

                        Text("Expires in \(result.estimatedShelfLifeDays)d")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(FLColors.warningAmber)
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
                        .foregroundStyle(FLColors.primaryGreen)
                }
            }
            .padding(FLSpacing.md)
            .background(FLColors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: FLSpacing.radiusLg, style: .continuous))

            // Expanded details
            if expandedResultId == result.id {
                expandedDetailsView(result: result)
            }
        }
    }

    private func expandedDetailsView(result: FoodIdentificationResult) -> some View {
        VStack(spacing: FLSpacing.md) {
            // Category & Storage
            HStack(spacing: FLSpacing.md) {
                VStack(alignment: .leading, spacing: FLSpacing.xs) {
                    Text("Category")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FLColors.textSecondary)

                    HStack(spacing: FLSpacing.sm) {
                        Image(systemName: result.category.icon)
                            .foregroundStyle(FLColors.primaryGreen)
                        Text(result.category.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(FLColors.textPrimary)
                    }
                }

                Spacer()

                VStack(alignment: .leading, spacing: FLSpacing.xs) {
                    Text("Storage")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FLColors.textSecondary)

                    HStack(spacing: FLSpacing.sm) {
                        Image(systemName: result.storageLocation.icon)
                            .foregroundStyle(FLColors.primaryGreen)
                        Text(result.storageLocation.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(FLColors.textPrimary)
                    }
                }
            }

            // Quantity
            VStack(alignment: .leading, spacing: FLSpacing.xs) {
                Text("Quantity")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FLColors.textSecondary)

                HStack(spacing: FLSpacing.md) {
                    Button(action: {
                        let current = resultQuantityEdits[result.id] ?? 1.0
                        if current > 1 {
                            resultQuantityEdits[result.id] = current - 1
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(FLColors.primaryGreen)
                    }

                    Spacer()

                    VStack(alignment: .center, spacing: FLSpacing.xs) {
                        Text("\(Int(resultQuantityEdits[result.id] ?? 1.0))")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(FLColors.textPrimary)

                        Text(result.defaultUnit.displayName)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(FLColors.textSecondary)
                    }

                    Spacer()

                    Button(action: {
                        let current = resultQuantityEdits[result.id] ?? 1.0
                        resultQuantityEdits[result.id] = current + 1
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

            // Add button
            Button(action: {
                addSingleItemToPantry(result)
            }) {
                HStack(spacing: FLSpacing.sm) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add This Item")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(FLSpacing.md)
                .background(FLColors.primaryGreen)
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
        isAddingItems = true

        let itemsToAdd = foodScanner.results.enumerated()
            .filter { selectedResultIndices.contains($0.offset) }
            .map { index, result -> FreshliItem in
                let quantity = resultQuantityEdits[result.id] ?? 1.0
                return foodScanner.convertToFreshliItem(result, quantity: quantity)
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
        let item = foodScanner.convertToFreshliItem(result, quantity: quantity)

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
        .modelContainer(for: FreshliItem.self, inMemory: true)
}
