import SwiftUI
import SwiftData
import ARKit
import RealityKit
import AVFoundation

// MARK: - AR Pantry Scanner View
//
// Real ARKit camera feed (RealityKit `ARView` with world-tracking)
// overlaid with floating Liquid-Glass "Digital Tags" — one per
// expiring pantry item — and a sweeping cyan scan beam.
//
// On hardware: live camera + AR tracking. On simulator (or any
// device that doesn't support ARWorldTrackingConfiguration), the
// view falls back to the original dark-gradient backdrop so
// previews and simulator runs still render every overlay correctly
// and don't crash.
//
// Permission: relies on `NSCameraUsageDescription` already present
// in Info.plist for FreshliVision. If the user has denied camera
// access, the view shows an inline copy block instead of the AR
// feed and exposes a deep-link to Settings.

struct ARPantryScannerView: View {
    @Query(filter: #Predicate<FreshliItem> { !$0.isConsumed && !$0.isShared && !$0.isDonated },
           sort: [SortDescriptor(\FreshliItem.expiryDate)])
    private var activeItems: [FreshliItem]

    @State private var scannedOffset: CGFloat = 0
    @State private var isScanning = true
    @State private var selectedTag: FreshliItem?
    /// Live camera authorisation state. Drives whether we render the
    /// AR feed, the permission prompt, or the dark-gradient mock.
    @State private var cameraAuthorisation: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Simulated camera background
            cameraBackground
            scanlineOverlay
            tagOverlays
            topBar
            if let selected = selectedTag {
                bottomDetailPanel(for: selected)
            } else {
                bottomHint
            }
        }
        .ignoresSafeArea()
        .onAppear { startScanning() }
    }

    // MARK: - Background
    //
    // Live AR camera feed when the device supports
    // `ARWorldTrackingConfiguration` AND the user has authorised
    // camera access; otherwise falls through to:
    //   • the camera-permission card (.notDetermined / .denied)
    //   • the dark-gradient mock (simulator, unsupported devices)
    //
    // Wrapping in `@ViewBuilder` lets us return three different
    // concrete view types without `AnyView` overhead.

    @ViewBuilder
    private var cameraBackground: some View {
        if ARWorldTrackingConfiguration.isSupported {
            switch cameraAuthorisation {
            case .authorized:
                ARLiveCameraView()
                    .ignoresSafeArea()
                    // The 18% darkening overlay improves contrast for
                    // the floating tags so item names remain legible
                    // against bright pantry interiors.
                    .overlay(Color.black.opacity(0.18).ignoresSafeArea())

            case .notDetermined:
                permissionPrompt(determinable: true)

            case .denied, .restricted:
                permissionPrompt(determinable: false)

            @unknown default:
                fallbackBackground
            }
        } else {
            fallbackBackground
        }
    }

    /// The original dark-gradient backdrop. Stays available for the
    /// simulator (which has no camera) and as a courtesy fallback
    /// for unsupported hardware. Visually consistent with the live
    /// feed's 18% darkening so the floating tags read the same way.
    private var fallbackBackground: some View {
        LinearGradient(
            colors: [Color(hex: 0x0F172A), Color(hex: 0x1E293B), Color(hex: 0x0F172A)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    /// Permission card shown when camera access hasn't been granted.
    /// `determinable` distinguishes "ask for the first time" (true)
    /// from "already declined — open Settings" (false), so the CTA
    /// label and behaviour match the user's actual next step.
    @ViewBuilder
    private func permissionPrompt(determinable: Bool) -> some View {
        ZStack {
            fallbackBackground
            VStack(spacing: 16) {
                Image(systemName: "camera.metering.unknown")
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(Color(hex: 0x22D3EE))
                Text(String(localized: "Camera access needed"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                Text(String(localized: "Freshli uses your camera to overlay digital tags on your pantry items in AR. Your photos stay private — nothing is uploaded."))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 28)

                if determinable {
                    Button {
                        Task { await requestCameraPermission() }
                    } label: {
                        Text(String(localized: "Allow camera access"))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .background(.white, in: Capsule())
                    }
                } else if let url = URL(string: UIApplication.openSettingsURLString) {
                    Link(destination: url) {
                        Text(String(localized: "Open Settings"))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .background(.white, in: Capsule())
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    /// Triggers the system camera-access prompt and updates the
    /// view's authorisation state. iOS only fires the prompt once
    /// per app install — subsequent calls return the cached result
    /// instantly.
    private func requestCameraPermission() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        cameraAuthorisation = granted ? .authorized : .denied
    }

    private var scanlineOverlay: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [Color(hex: 0x22D3EE).opacity(0), Color(hex: 0x22D3EE).opacity(0.4), Color(hex: 0x22D3EE).opacity(0)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 3)
            .offset(y: scannedOffset)
            .onAppear {
                withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
                    scannedOffset = geo.size.height
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Tag Overlays

    private var tagOverlays: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Array(activeItems.prefix(8).enumerated()), id: \.element.id) { idx, item in
                    let pos = position(for: idx, in: geo.size)
                    Button {
                        PSHaptics.shared.lightTap()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedTag = (selectedTag?.id == item.id) ? nil : item
                        }
                    } label: {
                        digitalTag(for: item)
                    }
                    .buttonStyle(.plain)
                    .position(pos)
                }
            }
        }
    }

    private func position(for index: Int, in size: CGSize) -> CGPoint {
        let cols = 3
        let col = index % cols
        let row = index / cols
        let x = size.width * (0.2 + Double(col) * 0.3)
        let y = size.height * (0.25 + Double(row) * 0.2)
        return CGPoint(x: x, y: y)
    }

    private func digitalTag(for item: FreshliItem) -> some View {
        let status = item.expiryStatus
        let color: Color = {
            switch status {
            case .fresh: return Color(hex: 0x22C55E)
            case .expiringSoon: return Color(hex: 0xF59E0B)
            case .expiringToday: return Color(hex: 0xF97316)
            case .expired: return Color(hex: 0xEF4444)
            }
        }()
        let progress: Double = {
            switch status {
            case .fresh: return 0.85
            case .expiringSoon: return 0.45
            case .expiringToday: return 0.2
            case .expired: return 0.05
            }
        }()

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(item.name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            // Health bar
            GeometryReader { bar in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15)).frame(height: 4)
                    Capsule().fill(color).frame(width: bar.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(width: 110)
        .background(.ultraThinMaterial.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(color.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.4), radius: 8, y: 2)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        VStack {
            HStack {
                Button {
                    PSHaptics.shared.lightTap()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .glassEffect(.regular, in: Circle())
                }
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: 0x22D3EE)).frame(width: 8, height: 8)
                    Text("AR SCAN")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .tracking(1.5)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            Spacer()
        }
    }

    // MARK: - Bottom Panels

    private var bottomHint: some View {
        VStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "viewfinder.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color(hex: 0x22D3EE))
                Text("Tap a tag for details")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(activeItems.count) items detected in your pantry")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(20)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.bottom, 60)
        }
    }

    private func bottomDetailPanel(for item: FreshliItem) -> some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(item.name)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        withAnimation { selectedTag = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                HStack(spacing: 16) {
                    detailStat(label: "Quantity", value: "\(Int(item.quantity)) \(item.unit.rawValue)")
                    detailStat(label: "Category", value: item.category.rawValue.capitalized)
                    detailStat(label: "Location", value: item.storageLocation.rawValue.capitalized)
                }
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color(hex: 0x22D3EE))
                    Text("Recipe match: 3 rescue recipes available")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(10)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(20)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.bottom, 60)
        }
    }

    private func detailStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(0.8)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private func startScanning() {
        isScanning = true
    }
}

// MARK: - ARLiveCameraView
//
// `UIViewRepresentable` wrapper around RealityKit's `ARView` so we
// can drop the AR camera feed into SwiftUI. World-tracking gives
// stable visual quality without committing to plane-detection
// (which would force us to handle session warning states); we keep
// the AR feature surface intentionally small for v1.
//
// The view manages its own session lifecycle:
//   • `makeUIView` configures + runs an `ARWorldTrackingConfiguration`
//   • `dismantleUIView` pauses the session on tear-down so the
//     camera light immediately turns off when the user dismisses.

private struct ARLiveCameraView: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let configuration = ARWorldTrackingConfiguration()
        // Light environment-texturing improves the colour
        // temperature of any RealityKit content we add later
        // (e.g. anchored 3D health bars). Cheap.
        configuration.environmentTexturing = .automatic
        // Use the back camera; default for pantry scanning.
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        // We don't need RealityKit physics for HUD overlays.
        arView.automaticallyConfigureSession = false
        arView.renderOptions.insert(.disableMotionBlur)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // No-op — view contents are static; SwiftUI overlays sit on
        // top of the AR feed and update independently.
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: ()) {
        // Stop the ARSession the moment SwiftUI tears down the host
        // view, so the camera-in-use indicator clears immediately.
        uiView.session.pause()
    }
}
