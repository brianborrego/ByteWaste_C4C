//
//  RealtimeCameraView.swift
//  ByteWaste_C4C
//
//  Unified camera view with real-time barcode scanning and image recognition
//

import SwiftUI
import AVFoundation
import VisionKit
import Vision
import UIKit

// MARK: - Camera Mode

enum CameraMode: String, CaseIterable {
    case barcode = "Barcode"
    case imageRecognition = "Food Recognition"

    var icon: String {
        switch self {
        case .barcode: return "barcode.viewfinder"
        case .imageRecognition: return "camera.viewfinder"
        }
    }

    var instructionText: String {
        switch self {
        case .barcode: return "Point at a barcode to scan"
        case .imageRecognition: return "Point at food to identify"
        }
    }
}

// MARK: - Unified Camera View

struct RealtimeCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PantryViewModel

    @State private var selectedMode: CameraMode = .barcode
    @State private var detectedBarcode: String?
    @State private var foodClassifications: [FoodClassification] = []
    @State private var showingConfirmation = false
    @State private var isProcessing = false

    var body: some View {
        ZStack {
            // Camera Layer
            Color.clear
                .overlay {
                    if selectedMode == .barcode {
                        BarcodeScannerLiveView(onBarcodeDetected: { barcode in
                            detectedBarcode = barcode
                            handleBarcodeDetection(barcode)
                        })
                    } else {
                        RealtimeFoodRecognitionView(
                            classifications: $foodClassifications,
                            onFoodSelected: { foodName in
                                handleFoodSelection(foodName)
                            }
                        )
                    }
                }
                .ignoresSafeArea()

            // Overlay UI
            VStack(spacing: 0) {
                // Top Bar Container
                VStack(spacing: 12) {
                    // Close Button Row
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .shadow(radius: 4)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    // Mode Selector
                    Picker("Camera Mode", selection: $selectedMode.animation()) {
                        ForEach(CameraMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)

                    // Instruction Text
                    Text(selectedMode.instructionText)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.6))
                        .clipShape(Capsule())
                        .padding(.bottom, 12)
                }
                .background(
                    LinearGradient(
                        colors: [
                            .black.opacity(0.5),
                            .black.opacity(0.3),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Spacer()

                // Real-time Classifications Overlay (Image Recognition Mode)
                if selectedMode == .imageRecognition && !foodClassifications.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Detected Food:")
                            .font(.headline)
                            .foregroundStyle(.white)

                        ForEach(foodClassifications.prefix(3).indices, id: \.self) { index in
                            let classification = foodClassifications[index]
                            Button {
                                handleFoodSelection(classification.identifier)
                            } label: {
                                HStack {
                                    Text(classification.displayName)
                                        .font(.body)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text("\(classification.confidencePercentage)%")
                                        .font(.caption)
                                }
                                .foregroundStyle(.white)
                                .padding()
                                .background(.black.opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // Loading Overlay
            if viewModel.isAnalyzing {
                ZStack {
                    Color.black.opacity(0.7)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)

                        Text("Analyzing...")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    // MARK: - Handlers

    private func handleBarcodeDetection(_ barcode: String) {
        // Prevent multiple detections while processing
        guard !isProcessing else {
            print("⚠️ Already processing, ignoring barcode: \(barcode)")
            return
        }
        isProcessing = true

        print("📷 Barcode detected: \(barcode)")

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        Task {
            print("🔄 Starting barcode analysis...")
            await viewModel.addFromBarcode(barcode: barcode)

            await MainActor.run {
                print("✅ Barcode processing complete. Error: \(viewModel.errorMessage ?? "none")")
                print("📦 Items in pantry: \(viewModel.items.count)")

                // Small delay to ensure the item is added before dismissing
                Task {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    dismiss()
                }
            }
        }
    }

    private func handleFoodSelection(_ foodName: String) {
        // Prevent multiple selections while processing
        guard !isProcessing else {
            print("⚠️ Already processing, ignoring selection: \(foodName)")
            return
        }
        isProcessing = true

        print("🍎 Food selected: \(foodName)")

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        let imageService = ImageClassificationService()
        let cleanedName = imageService.cleanFoodName(foodName)

        print("🧹 Cleaned name: \(cleanedName)")

        Task {
            print("🔄 Starting food analysis...")
            await viewModel.addFromImageClassification(foodName: cleanedName)

            await MainActor.run {
                print("✅ Food processing complete. Error: \(viewModel.errorMessage ?? "none")")
                print("📦 Items in pantry: \(viewModel.items.count)")

                // Small delay to ensure the item is added before dismissing
                Task {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Barcode Scanner Live View

struct BarcodeScannerLiveView: UIViewControllerRepresentable {
    var onBarcodeDetected: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isGuidanceEnabled: false, // Custom guidance provided by parent view
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator

        try? controller.startScanning()

        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: BarcodeScannerLiveView
        var hasDetectedBarcode = false

        init(_ parent: BarcodeScannerLiveView) {
            self.parent = parent
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didUpdate addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            // Only detect once, then stop
            guard !hasDetectedBarcode else { return }

            for item in addedItems {
                if case .barcode(let barcode) = item,
                   let barcodeValue = barcode.payloadStringValue {

                    hasDetectedBarcode = true
                    dataScanner.stopScanning()
                    parent.onBarcodeDetected(barcodeValue)
                    break
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

// MARK: - Real-time Food Recognition View

struct RealtimeFoodRecognitionView: UIViewControllerRepresentable {
    @Binding var classifications: [FoodClassification]
    var onFoodSelected: (String) -> Void

    func makeUIViewController(context: Context) -> RealtimeFoodRecognitionViewController {
        let controller = RealtimeFoodRecognitionViewController()
        controller.onClassificationUpdate = { results in
            DispatchQueue.main.async {
                self.classifications = results
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: RealtimeFoodRecognitionViewController, context: Context) {}
}

// MARK: - Real-time Food Recognition UIViewController

class RealtimeFoodRecognitionViewController: UIViewController {
    var onClassificationUpdate: (([FoodClassification]) -> Void)?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoOutput: AVCaptureVideoDataOutput?

    // Vision request
    private lazy var classificationRequest: VNClassifyImageRequest = {
        let request = VNClassifyImageRequest { [weak self] request, error in
            self?.processClassifications(for: request, error: error)
        }
        return request
    }()

    // Throttle classification to avoid overload
    private var lastClassificationTime = Date()
    private let classificationInterval: TimeInterval = 0.5 // Classify twice per second

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .high

        guard let captureSession = captureSession,
              let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Failed to get camera device")
            return
        }

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)

            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }

            // Setup video output
            videoOutput = AVCaptureVideoDataOutput()
            videoOutput?.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))

            if let videoOutput = videoOutput,
               captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            }

            // Setup preview layer
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer?.videoGravity = .resizeAspectFill
            previewLayer?.frame = view.bounds

            if let previewLayer = previewLayer {
                view.layer.addSublayer(previewLayer)
            }

            // Start session
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
            }

        } catch {
            print("Error setting up camera: \(error)")
        }
    }

    private func processClassifications(for request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNClassificationObservation] else {
            return
        }

        let foodClassifications = observations
            .filter { $0.confidence > 0.15 } // Slightly higher threshold for real-time
            .prefix(5)
            .map { observation in
                FoodClassification(
                    identifier: observation.identifier,
                    confidence: observation.confidence
                )
            }

        if !foodClassifications.isEmpty {
            onClassificationUpdate?(Array(foodClassifications))
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension RealtimeFoodRecognitionViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Throttle classification
        let now = Date()
        guard now.timeIntervalSince(lastClassificationTime) >= classificationInterval else {
            return
        }
        lastClassificationTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        // Perform classification
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try requestHandler.perform([classificationRequest])
        } catch {
            print("Classification error: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    RealtimeCameraView(viewModel: PantryViewModel())
}
