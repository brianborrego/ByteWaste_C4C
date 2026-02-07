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
    @State private var productName: String = ""
    @State private var scannedBarcode: String = ""
    @State private var showingScanner = false
    @State private var showingNamePrompt = false

    var body: some View {
        NavigationStack {
            VStack {
                if !scannedBarcode.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 48))
                            .foregroundColor(.green)

                        Text("Barcode Scanned")
                            .font(.headline)

                        Text(scannedBarcode)
                            .font(.monospaced(.body)())
                            .textSelection(.enabled)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)

                        Form {
                            Section("Product Name") {
                                TextField("Enter product name", text: $productName)
                            }
                        }
                        .frame(maxHeight: 200)

                        HStack(spacing: 12) {
                            Button("Scan Again") {
                                scannedBarcode = ""
                                productName = ""
                                showingScanner = true
                            }
                            .buttonStyle(.bordered)

                            Button("Add Item") {
                                if !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    viewModel.addFromBarcode(
                                        barcode: scannedBarcode,
                                        name: productName.trimmingCharacters(in: .whitespacesAndNewlines)
                                    )
                                    dismiss()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

                        Text("Point your camera at a barcode to scan")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

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
            .navigationTitle("Scan Barcode")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerView { barcode in
                    scannedBarcode = barcode
                    showingScanner = false
                }
                .ignoresSafeArea()
            }
        }
    }
}

#Preview {
    BarcodeScannerSheetView(viewModel: PantryViewModel())
}
