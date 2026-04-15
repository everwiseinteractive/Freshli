import SwiftUI
import PhotosUI
import Vision

struct ReceiptPhotoScannerView: View {
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var scannedReceipt: GroceryReceipt?
    @State private var isScanning = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showCamera = false

    @State private var receiptScanner = ReceiptScannerService()
    let importService = ReceiptImportService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let image = selectedImage {
                    // Image Preview
                    VStack(spacing: PSSpacing.lg) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd))

                        if case .scanning = receiptScanner.scanningState {
                            VStack(spacing: PSSpacing.md) {
                                ProgressView()
                                    .tint(PSColors.primaryGreen)

                                Text("Scanning receipt with OCR...")
                                    .font(PSTypography.callout)
                                    .foregroundStyle(PSColors.textSecondary)
                            }
                            .padding(PSSpacing.lg)
                            .background(PSColors.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd))
                        } else if case .parsing = receiptScanner.scanningState {
                            VStack(spacing: PSSpacing.md) {
                                ProgressView()
                                    .tint(PSColors.primaryGreen)

                                Text("Extracting items...")
                                    .font(PSTypography.callout)
                                    .foregroundStyle(PSColors.textSecondary)
                            }
                            .padding(PSSpacing.lg)
                            .background(PSColors.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd))
                        }

                        if case .complete = receiptScanner.scanningState, !receiptScanner.scannedItems.isEmpty {
                            VStack(alignment: .leading, spacing: PSSpacing.md) {
                                HStack(spacing: PSSpacing.md) {
                                    Text("Detected Items")
                                        .font(PSTypography.headline)
                                        .foregroundStyle(PSColors.textPrimary)

                                    Spacer()

                                    PSBadge(text: "\(receiptScanner.scannedItems.count) items", variant: .default)
                                }

                                ForEach(receiptScanner.scannedItems.prefix(5), id: \.id) { item in
                                    HStack(spacing: PSSpacing.md) {
                                        VStack(alignment: .leading, spacing: PSSpacing.xs) {
                                            Text(item.name)
                                                .font(PSTypography.callout)
                                                .foregroundStyle(PSColors.textPrimary)
                                                .lineLimit(1)

                                            HStack(spacing: PSSpacing.md) {
                                                Text("\(String(format: "%.1f", item.quantity)) \(item.unit.displayName(for: item.quantity))")
                                                    .font(PSTypography.caption2)
                                                    .foregroundStyle(PSColors.textSecondary)

                                                Text(String(format: "%.0f%% confident", item.confidenceScore * 100))
                                                    .font(PSTypography.caption2)
                                                    .foregroundStyle(PSColors.textTertiary)
                                            }
                                        }

                                        Spacer()

                                        Text(item.category.emoji)
                                            .font(.system(size: 16))
                                    }
                                    .padding(PSSpacing.md)
                                    .background(PSColors.backgroundSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm))
                                }

                                if receiptScanner.scannedItems.count > 5 {
                                    Text("+ \(receiptScanner.scannedItems.count - 5) more items")
                                        .font(PSTypography.caption1)
                                        .foregroundStyle(PSColors.textSecondary)
                                        .padding(.top, PSSpacing.xs)
                                }
                            }
                        } else if case .error(let message) = receiptScanner.scanningState {
                            VStack(spacing: PSSpacing.md) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(PSColors.expiredRed)

                                VStack(spacing: PSSpacing.sm) {
                                    Text("Scan Failed")
                                        .font(PSTypography.headline)
                                        .foregroundStyle(PSColors.textPrimary)

                                    Text(message)
                                        .font(PSTypography.body)
                                        .foregroundStyle(PSColors.textSecondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .padding(PSSpacing.lg)
                            .background(PSColors.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd))
                        }

                        Spacer()

                        VStack(spacing: PSSpacing.md) {
                            if case .complete = receiptScanner.scanningState, !receiptScanner.scannedItems.isEmpty {
                                NavigationLink(destination: ReceiptImportView()) {
                                    PSButton(
                                        title: "Review & Import",
                                        style: .primary,
                                        size: .medium,
                                        isFullWidth: true,
                                        action: {}
                                    )
                                }
                            } else if case .idle = receiptScanner.scanningState, selectedImage != nil {
                                PSButton(
                                    title: "Scan Receipt",
                                    style: .primary,
                                    size: .medium,
                                    isFullWidth: true,
                                    action: { performOCRScan() }
                                )
                            }

                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Text("Choose Another Photo")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(PSColors.backgroundSecondary)
                                    .foregroundStyle(PSColors.textPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .onChange(of: selectedPhotoItem) { _, newItem in
                                Task {
                                    if let data = try await newItem?.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data) {
                                        selectedImage = uiImage
                                        receiptScanner.reset()
                                    }
                                }
                            }
                        }
                    }
                    .padding(PSSpacing.screenHorizontal)
                } else {
                    // Placeholder
                    VStack(spacing: PSSpacing.xl) {
                        PSCard {
                            VStack(spacing: PSSpacing.lg) {
                                Image(systemName: "doc.viewfinder")
                                    .font(.system(size: 48))
                                    .foregroundStyle(PSColors.primaryGreen)

                                VStack(spacing: PSSpacing.sm) {
                                    Text("Position Receipt in Frame")
                                        .font(PSTypography.headline)
                                        .foregroundStyle(PSColors.textPrimary)

                                    Text("Align the entire receipt within the frame and ensure good lighting for best results")
                                        .font(PSTypography.callout)
                                        .foregroundStyle(PSColors.textSecondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .padding(PSSpacing.xl)
                        }

                        Button {
                            showCamera = true
                        } label: {
                            Label("Take Photo", systemImage: "camera.fill")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(PSColors.primaryGreen)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label("Choose from Photos", systemImage: "photo.fill")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(PSColors.backgroundSecondary)
                                .foregroundStyle(PSColors.textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .onChange(of: selectedPhotoItem) { _, newItem in
                            Task {
                                if let data = try await newItem?.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    selectedImage = uiImage
                                    receiptScanner.reset()
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(PSSpacing.screenHorizontal)
                }
            }
            .navigationTitle("Scan Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showCamera) {
                ReceiptCameraPickerView { image in
                    selectedImage = image
                    receiptScanner.reset()
                }
            }
            .alert("Scan Error", isPresented: $showError) {
                Button("OK", role: .cancel) {
                    receiptScanner.reset()
                }
            } message: {
                Text(errorMessage)
            }
        }
        .onChange(of: receiptScanner.errorMessage) { _, newValue in
            if let error = newValue {
                errorMessage = error
                showError = true
            }
        }
    }

    private func performOCRScan() {
        guard let image = selectedImage else { return }

        Task {
            await receiptScanner.scanReceipt(image)
        }
    }
}

// MARK: - Camera Picker

private struct ReceiptCameraPickerView: UIViewControllerRepresentable {
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
        let parent: ReceiptCameraPickerView
        init(_ parent: ReceiptCameraPickerView) { self.parent = parent }

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

#Preview {
    ReceiptPhotoScannerView()
}
