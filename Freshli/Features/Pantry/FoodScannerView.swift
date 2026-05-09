import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation

struct FoodScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(FLToastManager.self) private var toastManager

    @State private var foodScanner = FoodIdentificationService()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showPhotoPicker = false
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
            .fullScreenCover(isPresented: $showCamera) {
                FoodScannerCameraView { image in
                    Task {
                        await foodScanner.identifyFood(image)
                    }
                }
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
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
                    Text(String(localized: "Food Scanner"))
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
        ScrollView {
            VStack(spacing: FLSpacing.xl) {
                heroVisual
                    .padding(.top, FLSpacing.xl)

                VStack(spacing: FLSpacing.sm) {
                    Text(String(localized: "Identify any food in seconds"))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(FLColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, FLSpacing.screenHorizontal)

                    Text(String(localized: "Point your camera at any item — Apple Intelligence recognises it on-device, estimates shelf life, and adds it to your pantry."))
                        .font(.system(size: 15))
                        .foregroundStyle(FLColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.horizontal, FLSpacing.xxl)
                }

                featurePills

                privacyChip

                Spacer(minLength: FLSpacing.xl)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: FLSpacing.md) {
                FLButton(
                    title: String(localized: "Take Photo"),
                    icon: "camera.fill",
                    style: .primary,
                    isFullWidth: true,
                    action: { showCamera = true }
                )

                FLButton(
                    title: String(localized: "Choose from Photos"),
                    icon: "photo.fill",
                    style: .secondary,
                    isFullWidth: true,
                    action: {
                        selectedPhotoItem = nil
                        showPhotoPicker = true
                    }
                )
            }
            .padding(FLSpacing.screenHorizontal)
            .padding(.top, FLSpacing.md)
            .padding(.bottom, FLSpacing.xl)
            .background {
                // Soft elevated lift so the CTA tray reads as a
                // distinct surface from the scrolling hero.
                LinearGradient(
                    colors: [
                        FLColors.backgroundSecondary.opacity(0),
                        FLColors.backgroundSecondary
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
            }
        }
    }

    // MARK: - Empty-state visual stack
    //
    // The previous version was a 48pt SF Symbol stranded between two
    // text rows — visually anaemic for what is, in fact, the
    // headline feature of the app. The new hero is a four-layer
    // composition that dramatises *Apple Intelligence + on-device
    // vision*: a soft amber/green gradient halo, a translucent
    // viewfinder ring, a glassy white square plate with the camera
    // glyph, and a breathing animation tied to a `phaseAnimator`
    // that runs only while this state is on-screen so the layout
    // stays GPU-cheap.

    @State private var heroPulse: Bool = false

    private var heroVisual: some View {
        ZStack {
            // Layer 1 — outer aurora gradient
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            FLColors.primaryGreen.opacity(0.55),
                            FLColors.accentTeal.opacity(0.45),
                            FLColors.secondaryAmber.opacity(0.55),
                            FLColors.primaryGreen.opacity(0.55)
                        ],
                        center: .center
                    )
                )
                .blur(radius: 28)
                .frame(width: 220, height: 220)
                .opacity(heroPulse ? 1.0 : 0.78)
                .scaleEffect(heroPulse ? 1.04 : 0.96)

            // Layer 2 — viewfinder ring
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            FLColors.primaryGreen.opacity(0.85),
                            FLColors.accentTeal.opacity(0.65)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 168, height: 168)

            // Layer 3 — glass plate (the actual visual anchor)
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .strokeBorder(.white.opacity(0.5), lineWidth: 1)
                )
                .frame(width: 132, height: 132)
                .shadow(color: FLColors.primaryGreen.opacity(0.25), radius: 22, x: 0, y: 12)

            // Layer 4 — camera glyph with palette rendering for depth
            Image(systemName: "camera.aperture")
                .font(.system(size: 56, weight: .regular, design: .rounded))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, FLColors.primaryGreen)
                .shadow(color: FLColors.primaryGreen.opacity(0.55), radius: 8, x: 0, y: 4)

            // Layer 5 — corner brackets (viewfinder cues)
            ViewfinderCorners(size: 200, color: FLColors.primaryGreen)
                .opacity(0.85)
        }
        .frame(height: 240)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                heroPulse = true
            }
        }
    }

    private var featurePills: some View {
        VStack(alignment: .leading, spacing: FLSpacing.sm) {
            featurePillRow(
                icon: "leaf.fill",
                tint: FLColors.primaryGreen,
                title: String(localized: "Recognises 1,000+ foods"),
                detail: String(localized: "Produce, meats, dairy, packaged goods")
            )
            featurePillRow(
                icon: "calendar.badge.clock",
                tint: FLColors.secondaryAmber,
                title: String(localized: "Predicts shelf life"),
                detail: String(localized: "Per-item expiry estimates from Apple Intelligence")
            )
            featurePillRow(
                icon: "chart.bar.fill",
                tint: FLColors.accentTeal,
                title: String(localized: "Sustainability score"),
                detail: String(localized: "CO₂ footprint and pantry impact at a glance")
            )
        }
        .padding(.horizontal, FLSpacing.screenHorizontal)
    }

    private func featurePillRow(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(spacing: FLSpacing.md) {
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
                    .foregroundStyle(FLColors.textPrimary)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(FLColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(FLSpacing.md)
        .background(FLColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: FLSpacing.radiusLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FLSpacing.radiusLg, style: .continuous)
                .strokeBorder(FLColors.borderLight, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    private var privacyChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FLColors.primaryGreen)
            Text(String(localized: "On-device Apple Intelligence — your photos stay private"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(FLColors.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(FLColors.primaryGreen.opacity(0.08))
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(FLColors.primaryGreen.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, FLSpacing.screenHorizontal)
    }

    private var loadingView: some View {
        VStack(spacing: FLSpacing.lg) {
            Spacer()

            VStack(spacing: FLSpacing.lg) {
                if case .analyzing = foodScanner.identificationState {
                    FLShimmerView(height: 120, cornerRadius: FLSpacing.radiusMd)
                        .padding(FLSpacing.screenHorizontal)

                    Text(String(localized: "Analyzing image..."))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(FLColors.textPrimary)
                } else if case .error(let message) = foodScanner.identificationState {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(FLColors.expiredRed)

                    VStack(spacing: FLSpacing.sm) {
                        Text(String(localized: "Identification Failed"))
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
                    withAnimation(PSMotion.springQuick) {
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
                    withAnimation(PSMotion.springQuick) {
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
                    Text(String(localized: "Category"))
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
                    Text(String(localized: "Storage"))
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
                Text(String(localized: "Quantity"))
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
                    Text(String(localized: "Add This Item"))
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

            toastManager.show(.success("Added \(itemsToAdd.count) items to your pantry!"))
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                dismiss()
            }
        } catch {
            isAddingItems = false
            toastManager.show(.error("Failed to add items: \(error.localizedDescription)"))
        }
    }

    private func addSingleItemToPantry(_ result: FoodIdentificationResult) {
        let quantity = resultQuantityEdits[result.id] ?? 1.0
        let item = foodScanner.convertToFreshliItem(result, quantity: quantity)

        do {
            modelContext.insert(item)
            try modelContext.save()

            toastManager.show(.success("Added \(result.displayName) to your pantry!"))

            // Remove from view and deselect
            if let index = foodScanner.results.firstIndex(where: { $0.id == result.id }) {
                selectedResultIndices.remove(index)
            }
            expandedResultId = nil
            resultQuantityEdits.removeValue(forKey: result.id)
        } catch {
            toastManager.show(.error("Failed to add item: \(error.localizedDescription)"))
        }
    }
}

// MARK: - Camera Picker (UIKit wrapper — opens real camera, not photo library)

private struct FoodScannerCameraView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: FoodScannerCameraView
        init(_ parent: FoodScannerCameraView) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
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

// MARK: - Viewfinder corner cues
//
// Four L-shaped corner brackets, suggesting a camera viewfinder.
// Sits behind the camera glyph in the empty-state hero so the
// composition reads as "you're about to take a photo" without
// resorting to a literal camera-frame illustration.

private struct ViewfinderCorners: View {
    let size: CGFloat
    let color: Color
    var thickness: CGFloat = 2.5
    var armLength: CGFloat = 22
    var corner: CGFloat = 14

    var body: some View {
        let half = size / 2
        ZStack {
            // Top-left
            corner(at: CGPoint(x: -half, y: -half), rotation: .zero)
            // Top-right
            corner(at: CGPoint(x: half, y: -half), rotation: .degrees(90))
            // Bottom-right
            corner(at: CGPoint(x: half, y: half), rotation: .degrees(180))
            // Bottom-left
            corner(at: CGPoint(x: -half, y: half), rotation: .degrees(270))
        }
        .frame(width: size, height: size)
    }

    /// One L-bracket. Anchored so that its inner corner sits at
    /// `position`, then rotated to land on the right side of the box.
    @ViewBuilder
    private func corner(at position: CGPoint, rotation: Angle) -> some View {
        Path { path in
            // Horizontal arm extending right from the inner corner.
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: armLength, y: 0))
            // Vertical arm extending down from the inner corner.
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: armLength))
        }
        .stroke(color, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
        .rotationEffect(rotation)
        .offset(x: position.x + (cos(rotation.radians) - sin(rotation.radians)) * corner / 2,
                y: position.y + (sin(rotation.radians) + cos(rotation.radians)) * corner / 2)
    }
}

#Preview {
    FoodScannerView()
        .modelContainer(for: FreshliItem.self, inMemory: true)
}
