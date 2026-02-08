import SwiftUI

struct PantryView: View {
    @StateObject private var model = PantryViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                if model.isLoading {
                    // Loading state
                    ProgressView("Loading pantry...")
                } else if model.items.isEmpty {
                    // Empty state (only shown after loading completes)
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 64))
                            .foregroundColor(.gray.opacity(0.5))

                        Text("Pantry is empty")
                            .font(.title2)
                            .foregroundColor(.gray)

                        Text("Add an item with the buttons on the top right")
                            .font(.subheadline)
                            .foregroundColor(.gray.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    List {
                        ForEach(model.items) { item in
                            NavigationLink(destination: PantryItemDetailView(item: item, viewModel: model)) {
                                PantryItemRow(item: item)
                            }
                        }
                        .onDelete(perform: model.delete)
                    }
                }
            }
            .navigationTitle("Pantry")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        model.isPresentingScannerSheet = true
                    } label: {
                        Label("Scan", systemImage: "barcode.viewfinder")
                    }
                    Button {
                        model.isPresentingAddSheet = true
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $model.isPresentingAddSheet) {
                AddPantryItemView(
                    viewModel: model,
                    initialBarcode: model.barcodeForManualEntry
                )
            }
            .onChange(of: model.isPresentingAddSheet) { _, isPresenting in
                // Clear barcode when sheet is dismissed
                if !isPresenting {
                    model.barcodeForManualEntry = nil
                }
            }
            .sheet(isPresented: $model.isPresentingScannerSheet) {
                // Use the new Real-time Camera with live detection
                RealtimeCameraView(viewModel: model)
            }
            .task {
                await model.loadItems()
            }
        }
    }
}

// MARK: - Pantry Item Row
private struct PantryItemRow: View {
    let item: PantryItem

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)

                    if let brand = item.brand {
                        Text(brand)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        Text("\(item.storageLocation.icon) \(item.storageLocation.rawValue.capitalized)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if !item.isExpired {
                            Text("• \(item.formattedTimeRemaining) left")
                                .font(.caption)
                                .foregroundColor(item.urgencyColor)
                        } else {
                            Text("• Expired")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }

                Spacer()

                // Thumbnail if available
                if let imageURL = item.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.2)
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.vertical, 4)

            // Progress bar showing amount remaining
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 3)

                    Rectangle()
                        .fill(item.amountRemaining > 0.5 ? Color.green : item.amountRemaining > 0.25 ? Color.orange : Color.red)
                        .frame(width: geometry.size.width * item.amountRemaining, height: 3)
                }
            }
            .frame(height: 3)
        }
    }
}

// MARK: - Pantry Item Detail View
private struct PantryItemDetailView: View {
    let item: PantryItem
    @ObservedObject var viewModel: PantryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var amountRemaining: Double
    @State private var showingDisposalAlert = false
    @State private var previousAmount: Double

    init(item: PantryItem, viewModel: PantryViewModel) {
        self.item = item
        self.viewModel = viewModel
        _amountRemaining = State(initialValue: item.amountRemaining)
        _previousAmount = State(initialValue: item.amountRemaining)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Product image at top
                if let imageURL = item.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                ProgressView()
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                // Item information
                VStack(spacing: 12) {
                    Text(item.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    if let brand = item.brand {
                        Text(brand)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 16) {
                        VStack {
                            Text(item.storageLocation.icon)
                                .font(.title2)
                            Text(item.storageLocation.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()
                            .frame(height: 40)

                        VStack {
                            Text(item.formattedTimeRemaining)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(item.urgencyColor)
                            Text(item.isExpired ? "Expired" : "Remaining")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                // Amount remaining slider
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Amount Left:")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(amountRemaining * 100))%")
                            .font(.headline)
                            .foregroundColor(amountRemaining > 0.5 ? .green : amountRemaining > 0.25 ? .orange : .red)
                    }

                    Slider(value: $amountRemaining, in: 0...1, step: 0.01)
                        .tint(amountRemaining > 0.5 ? .green : amountRemaining > 0.25 ? .orange : .red)
                        .onChange(of: amountRemaining) { oldValue, newValue in
                            // Update the item in viewModel
                            viewModel.updateItemAmount(item, newAmount: newValue)

                            // If slider reaches 0 and was previously above 0, show disposal alert
                            if newValue == 0 && oldValue > 0 {
                                showingDisposalAlert = true
                            }
                        }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // Additional info
                if let category = item.category {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(category)
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                if let notes = item.notes {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Storage Notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(notes)
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                if let sustainabilityNotes = item.sustainabilityNotes, !sustainabilityNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sustainability Notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .top, spacing: 8) {
                            Text("♻️")
                                .font(.title3)
                            Text(sustainabilityNotes)
                                .font(.body)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top)
        }
        .navigationTitle("Item Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("How was this item used?", isPresented: $showingDisposalAlert) {
            Button("Used Fully") {
                viewModel.disposeItem(item, method: .usedFully)
                dismiss()
            }
            Button("Used Partially") {
                viewModel.disposeItem(item, method: .usedPartially)
                dismiss()
            }
            Button("Thrown Away", role: .destructive) {
                viewModel.disposeItem(item, method: .thrownAway)
                dismiss()
            }
            Button("Cancel", role: .cancel) {
                // Reset slider to previous value
                amountRemaining = previousAmount
                viewModel.updateItemAmount(item, newAmount: previousAmount)
            }
        } message: {
            Text("Used Fully: Composted inedible parts (e.g., pepper stem)\nUsed Partially: Threw away inedible parts\nThrown Away: Item went bad before use")
        }
    }
}

private struct AddPantryItemView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PantryViewModel

    @State private var name: String = ""
    @State private var additionalContext: String = ""
    @State private var barcode: String = ""
    @State private var showingBarcodeScanner = false
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var selectedImage: UIImage?

    // Initial barcode to pre-fill (for barcode-not-found flow)
    var initialBarcode: String?

    init(viewModel: PantryViewModel, initialBarcode: String? = nil) {
        self.viewModel = viewModel
        self.initialBarcode = initialBarcode
        _barcode = State(initialValue: initialBarcode ?? "")
        print("📝 AddPantryItemView initialized with barcode: \(initialBarcode ?? "nil")")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item Name") {
                    TextField("Enter food name", text: $name)
                        .textContentType(.none)
                }

                Section("Additional Context (Optional)") {
                    TextEditor(text: $additionalContext)
                        .frame(minHeight: 80)
                        .overlay(alignment: .topLeading) {
                            if additionalContext.isEmpty {
                                Text("e.g., organic, 6 count, brand name...")
                                    .foregroundColor(.gray.opacity(0.5))
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                Section("Barcode (Optional)") {
                    HStack {
                        TextField("Scan or enter barcode", text: $barcode)
                            .keyboardType(.numberPad)

                        Button {
                            showingBarcodeScanner = true
                        } label: {
                            Image(systemName: "barcode.viewfinder")
                                .font(.title3)
                        }
                    }
                }

                Section("Photo (Optional)") {
                    if let image = selectedImage {
                        HStack {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Spacer()

                            Button("Remove") {
                                selectedImage = nil
                            }
                            .foregroundColor(.red)
                        }
                    } else {
                        HStack {
                            Button {
                                showingCamera = true
                            } label: {
                                Label("Take Photo", systemImage: "camera")
                            }

                            Spacer()

                            Button {
                                showingImagePicker = true
                            } label: {
                                Label("Choose from Library", systemImage: "photo")
                            }
                        }
                    }
                }

                if viewModel.isAnalyzing {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Add Item Manually")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(viewModel.isAnalyzing)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await addItem()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isAnalyzing)
                }
            }
            .sheet(isPresented: $showingBarcodeScanner) {
                ManualEntryBarcodeScannerView(scannedBarcode: $barcode)
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(sourceType: .photoLibrary, selectedImage: $selectedImage)
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(sourceType: .camera, selectedImage: $selectedImage)
            }
        }
    }

    private func addItem() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContext = additionalContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)

        // Convert UIImage to URL if needed (for now, we'll skip upload and just use nil)
        let imageURL: String? = nil  // TODO: Upload image to storage and get URL

        await viewModel.addFromManualEntry(
            name: trimmedName,
            additionalContext: trimmedContext,
            barcode: trimmedBarcode.isEmpty ? nil : trimmedBarcode,
            imageURL: imageURL
        )
    }
}


// MARK: - Manual Entry Barcode Scanner
private struct ManualEntryBarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var scannedBarcode: String
    @State private var hasScannedOnce = false

    var body: some View {
        BarcodeScannerView { barcode in
            guard !hasScannedOnce else { return }
            hasScannedOnce = true
            scannedBarcode = barcode
            dismiss()
        }
        .ignoresSafeArea()
    }
}

#Preview {
    PantryView()
}
