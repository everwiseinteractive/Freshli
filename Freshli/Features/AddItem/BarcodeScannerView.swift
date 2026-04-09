import SwiftUI
import AVFoundation

struct BarcodeScannerView: View {
    var onScanned: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scannedCode: String?
    @State private var isCameraAvailable = true
    @State private var hasPermission = false
    @State private var showManualEntry = false
    @State private var manualBarcode = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: PSSpacing.xxl) {
                if !isCameraAvailable || !hasPermission {
                    fallbackView
                } else {
                    cameraPlaceholderView
                }
            }
            .padding(PSSpacing.screenHorizontal)
            .background(PSColors.backgroundPrimary)
            .navigationTitle(String(localized: "Scan Barcode"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
            }
            .task {
                let device = AVCaptureDevice.default(for: .video)
                isCameraAvailable = device != nil
                if isCameraAvailable {
                    let status = AVCaptureDevice.authorizationStatus(for: .video)
                    switch status {
                    case .authorized:
                        hasPermission = true
                    case .notDetermined:
                        hasPermission = await AVCaptureDevice.requestAccess(for: .video)
                    default:
                        hasPermission = false
                    }
                }
            }
        }
    }

    private var cameraPlaceholderView: some View {
        VStack(spacing: PSSpacing.xxl) {
            Spacer()

            // Camera viewfinder placeholder
            ZStack {
                RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                    .fill(Color.black.opacity(0.05))
                    .frame(height: 280)
                    .overlay {
                        RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                            .strokeBorder(PSColors.primaryGreen.opacity(0.5), lineWidth: 2)
                    }

                VStack(spacing: PSSpacing.lg) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(PSColors.primaryGreen)
                        .symbolEffect(.pulse, options: .repeating.speed(0.5))

                    Text(String(localized: "Point camera at a barcode"))
                        .font(PSTypography.callout)
                        .foregroundStyle(PSColors.textSecondary)
                }
            }

            // Simulated scan for demo
            PSButton(title: String(localized: "Simulate Scan"), icon: "barcode", style: .secondary) {
                let demoCodes = ["5000159407236", "5010477348678", "5000128654296"]
                let code = demoCodes.randomElement() ?? "5000159407236"
                onScanned(code)
                dismiss()
            }

            Divider()

            // Manual entry fallback
            VStack(spacing: PSSpacing.md) {
                Text(String(localized: "Or enter barcode manually"))
                    .font(PSTypography.caption1)
                    .foregroundStyle(PSColors.textSecondary)

                HStack(spacing: PSSpacing.md) {
                    TextField(String(localized: "Barcode number"), text: $manualBarcode)
                        .font(PSTypography.body)
                        .keyboardType(.numberPad)
                        .padding(PSSpacing.md)
                        .background(PSColors.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous))

                    PSButton(title: String(localized: "Go"), size: .medium, isFullWidth: false) {
                        guard !manualBarcode.isEmpty else { return }
                        onScanned(manualBarcode)
                        dismiss()
                    }
                }
            }

            Spacer()
        }
    }

    private var fallbackView: some View {
        VStack(spacing: PSSpacing.xxl) {
            Spacer()

            PSEmptyState(
                icon: "camera.fill",
                title: !isCameraAvailable
                    ? String(localized: "Camera Not Available")
                    : String(localized: "Camera Access Needed"),
                message: !isCameraAvailable
                    ? String(localized: "Barcode scanning requires a camera. You can enter the barcode manually below.")
                    : String(localized: "Allow camera access in Settings to scan barcodes, or enter the barcode manually below.")
            )

            VStack(spacing: PSSpacing.md) {
                HStack(spacing: PSSpacing.md) {
                    TextField(String(localized: "Barcode number"), text: $manualBarcode)
                        .font(PSTypography.body)
                        .keyboardType(.numberPad)
                        .padding(PSSpacing.md)
                        .background(PSColors.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous))

                    PSButton(title: String(localized: "Look Up"), size: .medium, isFullWidth: false) {
                        guard !manualBarcode.isEmpty else { return }
                        onScanned(manualBarcode)
                        dismiss()
                    }
                }

                PSButton(title: String(localized: "Skip — Add Manually"), style: .tertiary) {
                    dismiss()
                }
            }

            Spacer()
        }
    }
}

#Preview {
    BarcodeScannerView { code in
        print("Scanned: \(code)")
    }
}
