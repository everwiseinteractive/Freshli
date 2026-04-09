import SwiftUI
import PhotosUI

struct ReceiptPhotoScannerView: View {
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var scannedReceipt: GroceryReceipt?
    @State private var isScanning = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var scanProgress: Double = 0

    let service = ReceiptImportService()

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

                        if isScanning {
                            VStack(spacing: PSSpacing.md) {
                                ProgressView(value: scanProgress)
                                    .tint(PSColors.primaryGreen)

                                Text("Scanning receipt...")
                                    .font(PSTypography.callout)
                                    .foregroundStyle(PSColors.textSecondary)
                            }
                            .padding(PSSpacing.lg)
                            .background(PSColors.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd))
                        }

                        if let receipt = scannedReceipt {
                            VStack(alignment: .leading, spacing: PSSpacing.md) {
                                Text("Detected Items")
                                    .font(PSTypography.headline)
                                    .foregroundStyle(PSColors.textPrimary)

                                ForEach(receipt.items.prefix(5), id: \.name) { item in
                                    HStack(spacing: PSSpacing.md) {
                                        VStack(alignment: .leading, spacing: PSSpacing.xs) {
                                            Text(item.name)
                                                .font(PSTypography.callout)
                                                .foregroundStyle(PSColors.textPrimary)

                                            Text("\(String(format: "%.1f", item.quantity)) \(item.unit)")
                                                .font(PSTypography.caption2)
                                                .foregroundStyle(PSColors.textSecondary)
                                        }

                                        Spacer()

                                        PSBadge(text: item.category.uppercased(), variant: .default)
                                    }
                                    .padding(PSSpacing.md)
                                    .background(PSColors.backgroundSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm))
                                }

                                if receipt.items.count > 5 {
                                    Text("+ \(receipt.items.count - 5) more items")
                                        .font(PSTypography.caption1)
                                        .foregroundStyle(PSColors.textSecondary)
                                }
                            }
                        }

                        Spacer()

                        VStack(spacing: PSSpacing.md) {
                            if scannedReceipt != nil {
                                NavigationLink(destination: ReceiptImportView()) {
                                    PSButton(
                                        title: "Review & Import",
                                        style: .primary,
                                        size: .medium,
                                        isFullWidth: true,
                                        action: {}
                                    )
                                }
                            } else if !isScanning {
                                PSButton(
                                    title: "Scan Receipt",
                                    style: .primary,
                                    size: .medium,
                                    isFullWidth: true,
                                    action: { performOCRScan() }
                                )
                            }

                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                PSButton(
                                    title: "Choose Another Photo",
                                    style: .secondary,
                                    size: .medium,
                                    isFullWidth: true,
                                    action: {}
                                )
                            }
                            .onChange(of: selectedPhotoItem) { _, newItem in
                                Task {
                                    if let data = try await newItem?.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data) {
                                        selectedImage = uiImage
                                        scannedReceipt = nil
                                        scanProgress = 0
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

                                    Text("Align the entire receipt within the frame and ensure good lighting")
                                        .font(PSTypography.callout)
                                        .foregroundStyle(PSColors.textSecondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .padding(PSSpacing.xl)
                        }

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            PSButton(
                                title: "Take Photo",
                                icon: "camera.fill",
                                style: .primary,
                                size: .large,
                                isFullWidth: true,
                                action: {}
                            )
                        }
                        .onChange(of: selectedPhotoItem) { _, newItem in
                            Task {
                                if let data = try await newItem?.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    selectedImage = uiImage
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
            .alert("Scan Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func performOCRScan() {
        guard let image = selectedImage else { return }

        isScanning = true
        scanProgress = 0

        // Simulate OCR processing with progress
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            scanProgress = 0.3
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            scanProgress = 0.7
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Stub for VNRecognizeTextRequest integration
            // let request = VNRecognizeTextRequest()
            // request.recognitionLevel = .accurate
            // let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            // do {
            //     try handler.perform([request])
            //     guard let results = request.results else {
            //         showOCRError()
            //         return
            //     }
            //     let recognizedText = results.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            //     let receipt = service.parseReceiptFromText(recognizedText)
            //     scannedReceipt = receipt
            // } catch {
            //     showOCRError()
            // }

            // Mock result for demo
            let mockReceipt = GroceryReceipt(
                id: UUID(),
                storeName: "Whole Foods Market",
                date: Date(),
                items: [
                    ReceiptItem(name: "Organic Bananas", quantity: 2.0, unit: "bunches", price: 1.99, category: "fruits"),
                    ReceiptItem(name: "Greek Yogurt", quantity: 2.0, unit: "containers", price: 4.49, category: "dairy"),
                    ReceiptItem(name: "Salmon Fillets", quantity: 1.0, unit: "packages", price: 12.99, category: "seafood"),
                    ReceiptItem(name: "Broccoli", quantity: 1.0, unit: "heads", price: 3.49, category: "vegetables")
                ],
                totalAmount: 22.96,
                receiptSource: .photoScan
            )

            scannedReceipt = mockReceipt
            scanProgress = 1.0
            isScanning = false
        }
    }

    private func showOCRError() {
        errorMessage = "Unable to read receipt. Please try again with better lighting and a clearer image."
        showError = true
        isScanning = false
    }
}

#Preview {
    ReceiptPhotoScannerView()
}
