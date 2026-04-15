import SwiftUI
import AVFoundation
import SwiftData
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - Freshli Vision
// AR-style camera scanning with holographic refractive UI overlays.
// Uses the rear camera + Apple Intelligence (Vision framework) to
// identify food items and display instant nutritional / sourcing data
// with a holographic floating glass card interface.
//
// Architecture:
//   1. AVCaptureSession provides the live camera feed
//   2. FoodIdentificationService runs Vision classification
//   3. Holographic overlay cards float above detected items
//   4. Metal shaders create the refractive glass card effect
//   5. FoundationModels (iOS 26+) enriches with nutritional insights
//
// Privacy:
//   - All processing is on-device (Vision + Apple Intelligence)
//   - No camera frames leave the device
//   - Camera feed is never recorded or stored
//   - User must grant camera permission explicitly
// ══════════════════════════════════════════════════════════════════

// MARK: - Vision Scan Result

/// A detected food item with nutritional metadata for holographic display.
struct VisionScanResult: Identifiable {
    let id = UUID()
    let name: String
    let category: FoodCategory
    let confidence: Double
    let nutritionalInfo: NutritionalInfo
    let shelfLifeDays: Int
    let storageHint: String
    let sustainabilityScore: Double  // 0→1 (0 = high impact, 1 = sustainable)

    /// Holographic card display color based on sustainability.
    var holoColor: Color {
        if sustainabilityScore > 0.7 { return Color(hex: 0x22C55E) }  // Green
        if sustainabilityScore > 0.4 { return Color(hex: 0xF59E0B) }  // Amber
        return Color(hex: 0xEF4444)  // Red
    }
}

/// Basic nutritional breakdown for holographic display.
struct NutritionalInfo: Sendable {
    let calories: Int        // per 100g
    let protein: Double      // grams per 100g
    let carbs: Double        // grams per 100g
    let fat: Double          // grams per 100g
    let fiber: Double        // grams per 100g

    static let unknown = NutritionalInfo(calories: 0, protein: 0, carbs: 0, fat: 0, fiber: 0)
}

// MARK: - Freshli Vision View

struct FreshliVisionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.shaderQuality) private var quality
    @Environment(\.ambientBrightness) private var ambientBrightness
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel = FreshliVisionViewModel()
    @State private var scanlineOffset: CGFloat = 0
    @State private var selectedResult: VisionScanResult?
    @State private var showAddConfirmation = false
    @State private var addedItemName: String?
    @State private var holoStartDate = Date.now

    var body: some View {
        ZStack {
            // Layer 1: Live camera feed
            cameraFeedLayer

            // Layer 2: Holographic scan overlay
            if viewModel.isScanning {
                holoScanlineOverlay
            }

            // Layer 3: Detected item holographic cards
            holographicCardsLayer

            // Layer 4: HUD chrome (top bar + bottom panel)
            visionHUD

            // Layer 5: Detail panel for selected item
            if let result = selectedResult {
                holoDetailPanel(for: result)
            }
        }
        .ignoresSafeArea()
        .task {
            await viewModel.startSession()
        }
        .onDisappear {
            viewModel.stopSession()
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.scanResults.count)
    }

    // MARK: - Camera Feed

    private var cameraFeedLayer: some View {
        Group {
            switch viewModel.cameraState {
            case .active:
                CameraPreviewRepresentable(session: viewModel.captureSession)
            case .permissionDenied:
                permissionDeniedView
            case .unavailable:
                cameraUnavailableView
            case .initializing:
                Color.black
                    .overlay {
                        ProgressView()
                            .tint(.white)
                    }
            }
        }
    }

    // MARK: - Holographic Scanline

    private var holoScanlineOverlay: some View {
        GeometryReader { geo in
            ZStack {
                // Grid overlay — holographic reference lines
                holoGrid(in: geo.size)

                // Scanning beam
                LinearGradient(
                    colors: [
                        PSColors.primaryGreen.opacity(0),
                        PSColors.primaryGreen.opacity(0.5),
                        Color(hex: 0x22D3EE).opacity(0.3),
                        PSColors.primaryGreen.opacity(0)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 4)
                .blur(radius: 2)
                .offset(y: scanlineOffset)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                        scanlineOffset = geo.size.height
                    }
                }

                // Corner brackets — AR targeting reticle
                reticleBrackets(in: geo.size)
            }
        }
        .allowsHitTesting(false)
    }

    private func holoGrid(in size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let gridSpacing: CGFloat = 60
            let lineColor = Color.white.opacity(0.04)

            // Vertical lines
            var x: CGFloat = 0
            while x < canvasSize.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: canvasSize.height))
                context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
                x += gridSpacing
            }

            // Horizontal lines
            var y: CGFloat = 0
            while y < canvasSize.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: canvasSize.width, y: y))
                context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
                y += gridSpacing
            }
        }
    }

    private func reticleBrackets(in size: CGSize) -> some View {
        let bracketLength: CGFloat = 30
        let inset: CGFloat = 40
        let color = PSColors.primaryGreen.opacity(0.6)

        return ZStack {
            // Top-left
            Path { p in
                p.move(to: CGPoint(x: inset, y: inset + bracketLength))
                p.addLine(to: CGPoint(x: inset, y: inset))
                p.addLine(to: CGPoint(x: inset + bracketLength, y: inset))
            }.stroke(color, lineWidth: 2)

            // Top-right
            Path { p in
                p.move(to: CGPoint(x: size.width - inset - bracketLength, y: inset))
                p.addLine(to: CGPoint(x: size.width - inset, y: inset))
                p.addLine(to: CGPoint(x: size.width - inset, y: inset + bracketLength))
            }.stroke(color, lineWidth: 2)

            // Bottom-left
            Path { p in
                p.move(to: CGPoint(x: inset, y: size.height - inset - bracketLength))
                p.addLine(to: CGPoint(x: inset, y: size.height - inset))
                p.addLine(to: CGPoint(x: inset + bracketLength, y: size.height - inset))
            }.stroke(color, lineWidth: 2)

            // Bottom-right
            Path { p in
                p.move(to: CGPoint(x: size.width - inset - bracketLength, y: size.height - inset))
                p.addLine(to: CGPoint(x: size.width - inset, y: size.height - inset))
                p.addLine(to: CGPoint(x: size.width - inset, y: size.height - inset - bracketLength))
            }.stroke(color, lineWidth: 2)
        }
    }

    // MARK: - Holographic Cards

    private var holographicCardsLayer: some View {
        GeometryReader { geo in
            ForEach(Array(viewModel.scanResults.enumerated()), id: \.element.id) { index, result in
                let position = cardPosition(for: index, total: viewModel.scanResults.count, in: geo.size)

                holographicCard(for: result, index: index)
                    .position(position)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.3).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
            }
        }
    }

    private func cardPosition(for index: Int, total: Int, in size: CGSize) -> CGPoint {
        // Distribute cards in a natural-looking pattern
        let cols = min(total, 3)
        let col = index % cols
        let row = index / cols
        let x = size.width * (0.25 + CGFloat(col) * 0.25)
        let y = size.height * (0.30 + CGFloat(row) * 0.18)
        return CGPoint(x: x, y: y)
    }

    private func holographicCard(for result: VisionScanResult, index: Int) -> some View {
        let isSelected = selectedResult?.id == result.id

        return Button {
            PSHaptics.shared.lightTap()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                selectedResult = isSelected ? nil : result
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                // Header: icon + name + confidence badge
                HStack(spacing: 6) {
                    Image(systemName: result.category.icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(result.holoColor)

                    Text(result.name)
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    Text("\(Int(result.confidence * 100))%")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }

                // Micro nutritional bar
                HStack(spacing: 4) {
                    nutritionPill("P", value: result.nutritionalInfo.protein, color: .cyan)
                    nutritionPill("C", value: result.nutritionalInfo.carbs, color: .yellow)
                    nutritionPill("F", value: result.nutritionalInfo.fat, color: .orange)
                }

                // Shelf life indicator
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("\(result.shelfLifeDays)d shelf life")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(width: 150)
            .background {
                // Holographic glass background
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        result.holoColor.opacity(0.12),
                                        Color(hex: 0x0C1A10).opacity(0.6)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                result.holoColor.opacity(0.6),
                                .white.opacity(0.1),
                                result.holoColor.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: result.holoColor.opacity(0.3), radius: 12, y: 4)
            .scaleEffect(isSelected ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.35), value: isSelected)
    }

    private func nutritionPill(_ label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 7, weight: .black))
                .foregroundStyle(color.opacity(0.8))
            Text(String(format: "%.0f", value))
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - HUD Chrome

    private var visionHUD: some View {
        VStack {
            // Top bar
            HStack {
                Button {
                    PSHaptics.shared.lightTap()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial.opacity(0.7))
                        .clipShape(Circle())
                }

                Spacer()

                // Status indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.isScanning ? PSColors.primaryGreen : .red)
                        .frame(width: 8, height: 8)
                    Text("FRESHLI VISION")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .tracking(1.2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial.opacity(0.7))
                .clipShape(Capsule())

                Spacer()

                // Capture button
                Button {
                    PSHaptics.shared.lightTap()
                    Task {
                        await viewModel.captureAndAnalyze()
                    }
                } label: {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(PSColors.primaryGreen)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial.opacity(0.7))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)

            Spacer()

            // Bottom status bar
            if viewModel.scanResults.isEmpty && !viewModel.isAnalyzing {
                bottomPrompt
            }

            if viewModel.isAnalyzing {
                analyzingIndicator
            }
        }
    }

    private var bottomPrompt: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(PSColors.primaryGreen)
                .symbolEffect(.pulse, options: .repeat(.continuous))

            Text(String(localized: "Point at food to scan"))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)

            Text(String(localized: "Freshli Vision identifies ingredients instantly"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(24)
        .background(.ultraThinMaterial.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 40)
        .padding(.bottom, 60)
    }

    private var analyzingIndicator: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(PSColors.primaryGreen)
                .controlSize(.small)
            Text(String(localized: "Analyzing with Apple Intelligence..."))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.8))
        .clipShape(Capsule())
        .padding(.bottom, 60)
    }

    // MARK: - Detail Panel

    private func holoDetailPanel(for result: VisionScanResult) -> some View {
        VStack {
            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.name)
                            .font(.system(size: 24, weight: .black))
                            .foregroundStyle(.white)

                        HStack(spacing: 8) {
                            Label(result.category.displayName, systemImage: result.category.icon)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))

                            Text("\(Int(result.confidence * 100))% match")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(result.holoColor)
                        }
                    }

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.35)) { selectedResult = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }

                // Nutritional grid
                nutritionalGrid(for: result)

                // Sustainability + storage
                HStack(spacing: 12) {
                    infoChip(
                        icon: "leaf.fill",
                        label: "Sustainability",
                        value: sustainabilityLabel(result.sustainabilityScore),
                        color: result.holoColor
                    )
                    infoChip(
                        icon: "clock.fill",
                        label: "Shelf Life",
                        value: "\(result.shelfLifeDays) days",
                        color: .cyan
                    )
                    infoChip(
                        icon: "tray.fill",
                        label: "Storage",
                        value: result.storageHint,
                        color: .purple
                    )
                }

                // Add to Pantry button
                PSButton(
                    title: String(localized: "Add to Pantry"),
                    icon: "plus.circle.fill",
                    style: .primary,
                    size: .medium
                ) {
                    addScannedItem(result)
                }
            }
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color(hex: 0x0C1A10).opacity(0.75))
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [result.holoColor.opacity(0.4), .white.opacity(0.08)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func nutritionalGrid(for result: VisionScanResult) -> some View {
        let info = result.nutritionalInfo
        return HStack(spacing: 0) {
            nutritionColumn(label: "Calories", value: "\(info.calories)", unit: "kcal", color: .white)
            Divider().frame(height: 36).background(.white.opacity(0.1))
            nutritionColumn(label: "Protein", value: String(format: "%.1f", info.protein), unit: "g", color: .cyan)
            Divider().frame(height: 36).background(.white.opacity(0.1))
            nutritionColumn(label: "Carbs", value: String(format: "%.1f", info.carbs), unit: "g", color: .yellow)
            Divider().frame(height: 36).background(.white.opacity(0.1))
            nutritionColumn(label: "Fat", value: String(format: "%.1f", info.fat), unit: "g", color: .orange)
            Divider().frame(height: 36).background(.white.opacity(0.1))
            nutritionColumn(label: "Fiber", value: String(format: "%.1f", info.fiber), unit: "g", color: .green)
        }
        .padding(.vertical, 12)
        .background(.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func nutritionColumn(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(0.5)
            Text(value)
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(color)
            Text(unit)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    private func infoChip(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Helpers

    private func sustainabilityLabel(_ score: Double) -> String {
        if score > 0.7 { return String(localized: "Excellent") }
        if score > 0.4 { return String(localized: "Good") }
        return String(localized: "Fair")
    }

    private func addScannedItem(_ result: VisionScanResult) {
        let expiryDate = Calendar.current.date(
            byAdding: .day, value: result.shelfLifeDays, to: Date()
        ) ?? Date()

        let item = FreshliItem(
            name: result.name,
            category: result.category,
            storageLocation: storageLocation(for: result.category),
            quantity: 1,
            unit: .pieces,
            expiryDate: expiryDate
        )

        modelContext.insert(item)
        try? modelContext.save()

        PSHaptics.shared.heavyTap()
        addedItemName = result.name
        withAnimation(.spring(response: 0.35)) {
            selectedResult = nil
        }
    }

    private func storageLocation(for category: FoodCategory) -> StorageLocation {
        switch category {
        case .fruits, .vegetables: return .fridge
        case .dairy, .meat, .seafood: return .fridge
        case .frozen: return .freezer
        case .grains, .canned, .condiments, .snacks, .beverages: return .pantry
        case .bakery: return .counter
        case .other: return .pantry
        }
    }

    // MARK: - Permission States

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))
            Text(String(localized: "Camera access required"))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
            Text(String(localized: "Open Settings to grant camera permission for Freshli Vision"))
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .background(Color.black)
    }

    private var cameraUnavailableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))
            Text(String(localized: "Camera unavailable"))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(40)
        .background(Color.black)
    }
}

// MARK: - Camera Preview (UIKit Bridge)

struct CameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
}

class CameraPreviewUIView: UIView {
    var session: AVCaptureSession? {
        didSet {
            guard let session else { return }
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = bounds
            layer.addSublayer(previewLayer)
            self.previewLayer = previewLayer
        }
    }

    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}
