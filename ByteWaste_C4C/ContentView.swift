//
//  ContentView.swift
//  ByteWaste_C4C
//
//  Created by Matthew Segura on 2/7/26.
//

import SwiftUI
import VisionKit

struct PantryItem: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var barcode: String?
    var quantity: Int
}

struct ContentView: View {
    var body: some View {
        TabView {
            PantryView()
                .tabItem {
                    Label("Pantry", systemImage: "cabinet")
                }
            Text("Recipes (coming soon)")
                .tabItem {
                    Label("Recipes", systemImage: "book")
                }
            Text("Shopping List (coming soon)")
                .tabItem {
                    Label("Shopping", systemImage: "cart")
                }
        }
    }
}

struct PantryView: View {
    @State private var items: [PantryItem] = []
    @State private var showingScanner = false
    @State private var lastScannedCode: String? = nil
    @State private var alertMessage: String? = nil

    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.name).font(.headline)
                            if let code = item.barcode {
                                Text("Barcode: \(code)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text("x\(item.quantity)")
                            .monospacedDigit()
                    }
                }
                .onDelete { indexSet in
                    items.remove(atOffsets: indexSet)
                }
            }
            .navigationTitle("Pantry")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingScanner = true
                    } label: {
                        Label("Scan Barcode", systemImage: "barcode.viewfinder")
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerView { code in
                    showingScanner = false
                    handleScannedBarcode(code)
                } onCancel: {
                    showingScanner = false
                }
            }
            .alert("Scanned", isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) { alertMessage = nil }
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private func handleScannedBarcode(_ code: String) {
        lastScannedCode = code
        // Stub: In a real app, look up the product by barcode via a local database or API.
        // For now, create a placeholder item using the barcode as the name.
        let guessedName = lookupProductName(from: code)
        let newItem = PantryItem(name: guessedName, barcode: code, quantity: 1)
        items.append(newItem)
        alertMessage = "Added \"\(guessedName)\" (\(code)) to your pantry."
    }

    private func lookupProductName(from barcode: String) -> String {
        // Placeholder heuristic. Replace with a real lookup service later.
        if barcode.hasPrefix("0") || barcode.hasPrefix("1") { return "Grocery Item" }
        if barcode.hasPrefix("4") { return "Produce" }
        if barcode.hasPrefix("8") { return "Imported Item" }
        return "Item"
    }
}

// MARK: - Barcode Scanner View (VisionKit DataScanner)

struct BarcodeScannerView: View {
    var onScan: (String) -> Void
    var onCancel: () -> Void

    var body: some View {
        ScannerContainer(onScan: onScan, onCancel: onCancel)
            .ignoresSafeArea()
    }
}

private struct ScannerContainer: UIViewControllerRepresentable {
    var onScan: (String) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        // If DataScanner is unavailable (e.g., on Simulator/older devices), show a fallback UI.
        guard DataScannerViewController.isSupported && DataScannerViewController.isAvailable else {
            let vc = UIHostingController(rootView: FallbackScannerView(onCancel: onCancel))
            return vc
        }

        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true
        )
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let scanner = uiViewController as? DataScannerViewController {
            // Start scanning when presented
            Task { try? await scanner.startScanning() }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onCancel: onCancel)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        let onCancel: () -> Void

        init(onScan: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
            self.onScan = onScan
            self.onCancel = onCancel
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            handle(item: item, from: dataScanner)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd item: RecognizedItem, allItems: [RecognizedItem]) {
            // Auto-capture first recognized barcode
            handle(item: item, from: dataScanner)
        }

        private func handle(item: RecognizedItem, from scanner: DataScannerViewController) {
            if case let .barcode(barcode) = item {
                if let payload = barcode.payloadStringValue, !payload.isEmpty {
                    scanner.stopScanning()
                    onScan(payload)
                }
            }
        }
    }
}

private struct FallbackScannerView: View {
    var onCancel: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "barcode.viewfinder").font(.system(size: 48))
            Text("Barcode scanning is not supported on this device.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Close") { onCancel() }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
