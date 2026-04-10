import SwiftUI
import SwiftData

/// Smart Add — the main scanning flow.
/// Layers a live camera scanner, bounding-box highlights, a glassmorphic
/// search bar, and a spring-animated pending tray.
struct SmartAddView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(PSToastManager.self) private var toastManager: PSToastManager?
    @Environment(CelebrationManager.self) private var celebrationManager: CelebrationManager?

    @State private var viewModel = SmartAddViewModel()
    @State private var scannerCoordinator: LiveScannerView.Coordinator?
    @State private var showUnsupportedAlert = false

    private var isDeviceSupported: Bool {
        LiveScannerView.isDeviceSupported
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Layer 1: Camera / fallback
                if isDeviceSupported {
                    cameraLayer
                } else {
                    fallbackLayer
                }

                // Layer 2: Gradient overlays for readability
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [.black.opacity(0.5), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)

                    Spacer()

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 200)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)

                // Layer 3: Controls
                VStack(spacing: 0) {
                    // Status indicator
                    scanStatusBadge
                        .padding(.top, PSSpacing.sm)

                    Spacer()

                    // Search bar
                    SmartAddSearchBar(viewModel: viewModel)
                        .padding(.horizontal, PSSpacing.screenHorizontal)
                        .padding(.bottom, PSSpacing.md)

                    // Pending tray
                    if !viewModel.pendingItems.isEmpty {
                        PendingTrayView(viewModel: viewModel, onSaveAll: saveAllItems)
                            .transition(PSMotion.slideUp)
                    }
                }
                .animation(PSMotion.springDefault, value: viewModel.pendingItems.isEmpty)
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: PSLayout.iconButtonSize, height: PSLayout.iconButtonSize)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(
                                Circle().strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                            )
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("Smart Add")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        toggleFlashlight()
                    } label: {
                        Image(systemName: "flashlight.off.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: PSLayout.iconButtonSize, height: PSLayout.iconButtonSize)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(
                                Circle().strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                            )
                    }
                }
            }
            .onAppear {
                if isDeviceSupported {
                    viewModel.scanState = .scanning
                }
            }
            .onDisappear {
                scannerCoordinator?.stopScanning()
                viewModel.reset()
            }
            .alert("Scanner Not Available", isPresented: $showUnsupportedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Live text scanning requires an iPhone or iPad with an A12 chip or later. You can still add items manually using the search bar below.")
            }
        }
    }

    // MARK: - Camera Layer

    private var cameraLayer: some View {
        LiveScannerView { texts in
            viewModel.handleRecognizedTexts(texts)
        }
        .ignoresSafeArea()
        .onAppear {
            // Start scanning after a brief delay to let the camera warm up
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                scannerCoordinator?.startScanning()
            }
        }
    }

    // MARK: - Fallback (Simulator / unsupported devices)

    private var fallbackLayer: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: PSSpacing.xl) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 64, weight: .thin))
                    .foregroundStyle(.white.opacity(0.4))

                VStack(spacing: PSSpacing.sm) {
                    Text("Camera Not Available")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))

                    Text("Use the search bar below to add items manually")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }

                // Demo button for testing the parser flow
                Button {
                    Task {
                        let demoTexts = [
                            "Organic Bananas 2.49",
                            "Greek Yogurt Plain 4.99",
                            "Salmon Fillet 12.99",
                            "Baby Spinach 3.49",
                            "Sourdough Bread 5.99",
                            "Fresh Eggs Large 4.29",
                            "Whole Milk 1 Gal 3.79",
                        ]
                        viewModel.handleRecognizedTexts(demoTexts)
                    }
                } label: {
                    HStack(spacing: PSSpacing.sm) {
                        Image(systemName: "text.viewfinder")
                        Text("Demo Scan")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, PSSpacing.xl)
                    .padding(.vertical, PSSpacing.md)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                    )
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.top, PSSpacing.md)
            }
            .padding(PSSpacing.screenHorizontal)
        }
    }

    // MARK: - Status Badge

    private var scanStatusBadge: some View {
        HStack(spacing: PSSpacing.sm) {
            switch viewModel.scanState {
            case .idle:
                Image(systemName: "viewfinder")
                    .foregroundStyle(.white.opacity(0.7))
                Text("Point at a receipt or label")
                    .foregroundStyle(.white.opacity(0.7))

            case .scanning:
                Circle()
                    .fill(PSColors.primaryGreen)
                    .frame(width: 8, height: 8)
                    .modifier(PulsingDotModifier())
                Text("Scanning...")
                    .foregroundStyle(.white.opacity(0.9))

            case .parsing:
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.7)
                Text("Recognizing items...")
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .font(.system(size: 13, weight: .medium))
        .padding(.horizontal, PSSpacing.lg)
        .padding(.vertical, PSSpacing.sm)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
        )
        .animation(PSMotion.springQuick, value: viewModel.scanState)
    }

    // MARK: - Actions

    private func saveAllItems() {
        let count = viewModel.saveAllItems(modelContext: modelContext)
        PSHaptics.shared.success()

        // Trigger celebration
        celebrationManager?.fireItemAdded(modelContext: modelContext)

        toastManager?.show(.itemAdded("\(count) items added to pantry!"))

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }

    private func toggleFlashlight() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = device.torchMode == .on ? .off : .on
        device.unlockForConfiguration()
        PSHaptics.shared.lightTap()
    }
}

// MARK: - Pulsing Dot

private struct PulsingDotModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.4 : 1.0)
            .opacity(isPulsing ? 0.6 : 1.0)
            .animation(
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}

// MARK: - AVFoundation import for flashlight

import AVFoundation

// MARK: - Preview

#Preview {
    SmartAddView()
        .modelContainer(for: FreshliItem.self, inMemory: true)
}
