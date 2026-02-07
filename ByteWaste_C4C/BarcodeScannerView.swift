import SwiftUI
import VisionKit
import AVFoundation

struct BarcodeScannerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    var onBarcodeDetected: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        
        // Start scanning immediately
        try? controller.startScanning()
        
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        // Ensure scanning is active when view updates
        if !uiViewController.isScanning {
            try? uiViewController.startScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: BarcodeScannerView

        init(_ parent: BarcodeScannerView) {
            self.parent = parent
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didTapOn item: RecognizedItem
        ) {
            switch item {
            case .barcode(let barcode):
                if let barcodeValue = barcode.payloadStringValue {
                    parent.onBarcodeDetected(barcodeValue)
                    parent.dismiss()
                }
            default:
                break
            }
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didUpdate addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            for item in addedItems {
                if case .barcode(let barcode) = item {
                    if let barcodeValue = barcode.payloadStringValue {
                        parent.onBarcodeDetected(barcodeValue)
                        parent.dismiss()
                    }
                }
            }
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didRemoveItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {}

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable
        ) {
            print("Scanner unavailable: \(error)")
        }
    }
}

struct BarcodeScannerSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PantryViewModel
    @State private var scannedBarcode: String = ""
    @State private var showingScanner = false

    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.isAnalyzing {
                    // Show loading state
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Analyzing Product...")
                            .font(.headline)
                        
                        Text("Using AI to estimate shelf life")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if !scannedBarcode.isEmpty {
                            Text(scannedBarcode)
                                .font(.monospaced(.caption)())
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                } else if !scannedBarcode.isEmpty && viewModel.errorMessage != nil {
                    // Show error state
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)

                        Text("Analysis Failed")
                            .font(.headline)
                        
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding()
                        }

                        Text("Scanned: \(scannedBarcode)")
                            .font(.monospaced(.caption)())
                            .textSelection(.enabled)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)

                        HStack(spacing: 12) {
                            Button("Try Again") {
                                scannedBarcode = ""
                                viewModel.errorMessage = nil
                                showingScanner = true
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Cancel") {
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()

                        Spacer()
                    }
                    .padding()
                    
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "barcode")
                            .font(.system(size: 64))
                            .foregroundColor(.blue)

                        Text("Ready to Scan")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Point your camera at a barcode to automatically analyze and add the product")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button("Start Scanning") {
                            showingScanner = true
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle("Scan Product")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { 
                        dismiss() 
                    }
                    .disabled(viewModel.isAnalyzing)
                }
            }
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerView { barcode in
                    scannedBarcode = barcode
                    showingScanner = false
                    
                    // Trigger AI analysis
                    Task {
                        await viewModel.addFromBarcode(barcode: barcode)
                    }
                }
                .ignoresSafeArea()
            }
        }
    }
}

#Preview {
    BarcodeScannerSheetView(viewModel: PantryViewModel())
}
