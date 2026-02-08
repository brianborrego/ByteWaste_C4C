//
//  SmartScannerView.swift
//  ByteWaste_C4C
//
//  Smart scanner with barcode and image recognition modes
//

import SwiftUI
import PhotosUI

enum ScanMode: String, CaseIterable {
    case barcode = "Barcode"
    case image = "Image"

    var icon: String {
        switch self {
        case .barcode: return "barcode.viewfinder"
        case .image: return "camera"
        }
    }

    var description: String {
        switch self {
        case .barcode: return "Scan barcodes on packaged foods"
        case .image: return "Photograph produce and non-barcoded items"
        }
    }
}

struct SmartScannerSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PantryViewModel

    @State private var selectedMode: ScanMode = .barcode
    @State private var showingBarcodeScanner = false
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var selectedImage: UIImage?
    @State private var classificationResults: [FoodClassification] = []
    @State private var selectedFoodName: String?
    @State private var scannedBarcode: String = ""

    private let imageService = ImageClassificationService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mode Selector
                Picker("Scan Mode", selection: $selectedMode) {
                    ForEach(ScanMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Content based on mode and state
                if viewModel.isAnalyzing {
                    analyzingView
                } else if viewModel.errorMessage != nil {
                    errorView
                } else {
                    switch selectedMode {
                    case .barcode:
                        barcodeView
                    case .image:
                        imageView
                    }
                }
            }
            .navigationTitle("Smart Scanner")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(viewModel.isAnalyzing)
                }
            }
            .sheet(isPresented: $showingBarcodeScanner) {
                BarcodeScannerView { barcode in
                    scannedBarcode = barcode
                    showingBarcodeScanner = false

                    // Trigger AI analysis
                    Task {
                        await viewModel.addFromBarcode(barcode: barcode)
                        if viewModel.errorMessage == nil {
                            dismiss()
                        }
                    }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(sourceType: .camera, selectedImage: $selectedImage)
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(sourceType: .photoLibrary, selectedImage: $selectedImage)
            }
            .onChange(of: selectedImage) { oldValue, newValue in
                if let image = newValue {
                    classifyImage(image)
                }
            }
        }
    }

    // MARK: - Barcode View

    private var barcodeView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("Scan Barcode")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(ScanMode.barcode.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                showingBarcodeScanner = true
            } label: {
                Label("Start Barcode Scanner", systemImage: "barcode.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }

    // MARK: - Image View

    private var imageView: some View {
        VStack(spacing: 24) {
            if !classificationResults.isEmpty {
                // Show classification results
                classificationResultsView
            } else {
                // Show image capture options
                Spacer()

                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)

                VStack(spacing: 8) {
                    Text("Identify Food by Photo")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(ScanMode.image.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                VStack(spacing: 12) {
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        showingImagePicker = true
                    } label: {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.horizontal)

                Spacer()
            }
        }
        .padding()
    }

    // MARK: - Classification Results View

    private var classificationResultsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 4)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Select the food item:")
                        .font(.headline)

                    ForEach(classificationResults.indices, id: \.self) { index in
                        let classification = classificationResults[index]
                        Button {
                            selectedFoodName = classification.identifier
                            analyzeSelectedFood()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(classification.displayName)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Text("\(classification.confidencePercentage)% confidence")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(.horizontal)

                Button("Try Another Photo") {
                    resetImageState()
                }
                .buttonStyle(.bordered)
                .padding(.top)
            }
            .padding()
        }
    }

    // MARK: - Analyzing View

    private var analyzingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Analyzing Product...")
                .font(.headline)

            Text("Using AI to estimate shelf life")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private var errorView: some View {
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

            HStack(spacing: 12) {
                Button("Try Again") {
                    viewModel.errorMessage = nil
                    resetImageState()
                    scannedBarcode = ""
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
    }

    // MARK: - Helper Methods

    private func classifyImage(_ image: UIImage) {
        Task {
            do {
                let results = try await imageService.classifyFood(from: image)
                await MainActor.run {
                    classificationResults = results
                }
            } catch {
                await MainActor.run {
                    viewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func analyzeSelectedFood() {
        guard let foodName = selectedFoodName else { return }

        Task {
            let cleanedName = imageService.cleanFoodName(foodName)
            await viewModel.addFromImageClassification(foodName: cleanedName)

            if viewModel.errorMessage == nil {
                await MainActor.run {
                    dismiss()
                }
            }
        }
    }

    private func resetImageState() {
        selectedImage = nil
        classificationResults = []
        selectedFoodName = nil
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    enum SourceType {
        case camera
        case photoLibrary

        var uiImagePickerSourceType: UIImagePickerController.SourceType {
            switch self {
            case .camera: return .camera
            case .photoLibrary: return .photoLibrary
            }
        }
    }

    let sourceType: SourceType
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType.uiImagePickerSourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    SmartScannerSheetView(viewModel: PantryViewModel())
}
