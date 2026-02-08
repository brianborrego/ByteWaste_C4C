import SwiftUI

struct PantryView: View {
    @ObservedObject var viewModel: PantryViewModel
    @State private var isEditMode = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Cream background
                Color.appCream.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Custom gradient title with Done button
                    HStack {
                        Text("Pantry")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.linearGradient(
                                colors: [.appGradientTop, .appGradientBottom],
                                startPoint: .top,
                                endPoint: .bottom
                            ))

                        Spacer()

                        if isEditMode {
                            Button("Done") {
                                withAnimation {
                                    isEditMode = false
                                }
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.appPrimaryGreen)
                            .cornerRadius(20)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    if viewModel.isLoading {
                        // Loading state
                        Spacer()
                        ProgressView("Loading pantry...")
                        Spacer()
                    } else if viewModel.items.isEmpty {
                        // Empty state
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "tray")
                                .font(.system(size: 64))
                                .foregroundColor(.appIconGray.opacity(0.5))

                            Text("Pantry is empty")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.appIconGray)

                            Text("Tap the + button below to add items")
                                .font(.subheadline)
                                .foregroundColor(.appIconGray.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        Spacer()
                    } else {
                        // Items list
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.items, id: \.id) { item in
                                    ZStack(alignment: .topLeading) {
                                        // Card with navigation
                                        NavigationLink(destination: PantryItemDetailView(item: item, viewModel: viewModel)) {
                                            PantryItemCard(item: item)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .disabled(isEditMode)
                                        .simultaneousGesture(
                                            LongPressGesture(minimumDuration: 2.0)
                                                .onEnded { _ in
                                                    print("🔴 Long press detected!")
                                                    withAnimation(.spring()) {
                                                        isEditMode = true
                                                    }
                                                }
                                        )

                                        // Delete button overlay when in edit mode
                                        if isEditMode {
                                            Button {
                                                withAnimation {
                                                    viewModel.disposeItem(item, method: .thrownAway)
                                                }
                                            } label: {
                                                ZStack {
                                                    Circle()
                                                        .fill(Color.red)
                                                        .frame(width: 30, height: 30)
                                                    Image(systemName: "minus")
                                                        .font(.system(size: 16, weight: .bold))
                                                        .foregroundColor(.white)
                                                }
                                            }
                                            .offset(x: 8, y: 8)
                                            .transition(.scale)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 80) // Extra padding for tab bar
                        }
                        .refreshable {
                            await viewModel.refreshItems()
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.loadItems()
            }
        }
    }
}

// MARK: - Pantry Item Card (New Design)
private struct PantryItemCard: View {
    let item: PantryItem

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Thumbnail if available
                if let imageURL = item.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.2)
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    // Placeholder icon
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.appIconGray.opacity(0.15))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundColor(.appIconGray.opacity(0.5))
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)

                    if let brand = item.brand {
                        Text(brand)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 8) {
                        Text("\(item.storageLocation.icon) \(item.storageLocation.rawValue.capitalized)")
                            .font(.system(size: 13))
                            .foregroundColor(.appIconGray)

                        if !item.isExpired {
                            Text("• \(item.formattedTimeRemaining)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(item.urgencyColor)
                        } else {
                            Text("• Expired")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.red)
                        }
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.appIconGray.opacity(0.5))
            }
            .padding(16)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 4)

                    Rectangle()
                        .fill(item.amountRemaining > 0.5 ? Color.appPrimaryGreen : item.amountRemaining > 0.25 ? Color.orange : Color.red)
                        .frame(width: geometry.size.width * item.amountRemaining, height: 4)
                }
            }
            .frame(height: 4)
        }
        .cardStyle()
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
        ZStack {
            // Cream background
            Color.appCream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Product image at top
                    if let imageURL = item.imageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay(
                                        ProgressView()
                                    )
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 250)
                        .background(Color.clear)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
                        .padding(.horizontal, 16)
                    }

                // Item information
                VStack(spacing: 12) {
                    Text(item.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.linearGradient(
                            colors: [.appGradientTop, .appGradientBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        ))

                    if let brand = item.brand {
                        Text(brand)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.appIconGray)
                    }

                    HStack(spacing: 16) {
                        VStack {
                            Text(item.storageLocation.icon)
                                .font(.title2)
                            Text(item.storageLocation.displayName)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.appIconGray)
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
                                .fontWeight(.bold)
                                .foregroundColor(.appIconGray)
                        }
                    }
                    .padding()
                }
                .padding(.horizontal, 16)

                // Amount remaining slider
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Spacer()
                        Text("\(Int(amountRemaining * 100))%")
                            .font(.headline)
                            .fontWeight(.bold)
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
                .padding(.horizontal, 16)

                // Additional info
                if let category = item.category {
                    Text(category)
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(.appIconGray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                }

                if let notes = item.notes {
                    Text(notes)
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(.appIconGray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                }

                if let sustainabilityNotes = item.sustainabilityNotes, !sustainabilityNotes.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Text("♻️")
                            .font(.title3)
                        Text(sustainabilityNotes)
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundColor(.appIconGray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                }

                    Spacer()
                }
                .padding(.top)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appCream, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Item Details")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.linearGradient(
                        colors: [.appGradientTop, .appGradientBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
            }
        }
        .alert("How was this item used?", isPresented: $showingDisposalAlert) {
            Button("Used Fully") {
                Task {
                    await MainActor.run {
                        viewModel.disposeItem(item, method: .usedFully)
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
                    await MainActor.run {
                        dismiss()
                    }
                }
            }
            Button("Used Partially") {
                Task {
                    await MainActor.run {
                        viewModel.disposeItem(item, method: .usedPartially)
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
                    await MainActor.run {
                        dismiss()
                    }
                }
            }
            Button("Thrown Away", role: .destructive) {
                Task {
                    await MainActor.run {
                        viewModel.disposeItem(item, method: .thrownAway)
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
                    await MainActor.run {
                        dismiss()
                    }
                }
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

struct AddPantryItemView: View {
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
            ZStack {
                // Cream background
                Color.appCream.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Item Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Item Name *")
                                .font(.caption)
                                .foregroundStyle(.linearGradient(
                                    colors: [.appGradientTop, .appGradientBottom],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                                .padding(.horizontal, 16)

                            ZStack(alignment: .leading) {
                                if name.isEmpty {
                                    Text("Enter food name")
                                        .foregroundColor(.gray.opacity(0.5))
                                        .padding(.leading, 4)
                                }
                                TextField("", text: $name)
                                    .textContentType(.none)
                            }
                            .padding()
                            .cardStyle()
                        }

                        // Additional Context
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Additional Context")
                                .font(.caption)
                                .foregroundStyle(.linearGradient(
                                    colors: [.appGradientTop, .appGradientBottom],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                                .padding(.horizontal, 16)

                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $additionalContext)
                                    .frame(minHeight: 80)
                                    .scrollContentBackground(.hidden)

                                if additionalContext.isEmpty {
                                    Text("e.g., organic, 6 count, brand name...")
                                        .foregroundColor(.gray.opacity(0.5))
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                        .allowsHitTesting(false)
                                }
                            }
                            .padding()
                            .cardStyle()
                        }

                        // Barcode
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Barcode")
                                .font(.caption)
                                .foregroundStyle(.linearGradient(
                                    colors: [.appGradientTop, .appGradientBottom],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                                .padding(.horizontal, 16)

                            HStack {
                                ZStack(alignment: .leading) {
                                    if barcode.isEmpty {
                                        Text("Scan or enter barcode")
                                            .foregroundColor(.gray.opacity(0.5))
                                            .padding(.leading, 4)
                                    }
                                    TextField("", text: $barcode)
                                        .keyboardType(.numberPad)
                                }

                                Button {
                                    showingBarcodeScanner = true
                                } label: {
                                    Image(systemName: "barcode.viewfinder")
                                        .font(.title3)
                                        .foregroundColor(.appPrimaryGreen)
                                }
                            }
                            .padding()
                            .cardStyle()
                        }

                        // Photo
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Photo")
                                .font(.caption)
                                .foregroundStyle(.linearGradient(
                                    colors: [.appGradientTop, .appGradientBottom],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                                .padding(.horizontal, 16)

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
                                .padding()
                                .cardStyle()
                            } else {
                                HStack(spacing: 12) {
                                    Button {
                                        showingCamera = true
                                    } label: {
                                        Label("Take Photo", systemImage: "camera")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.appPrimaryGreen)

                                    Button {
                                        showingImagePicker = true
                                    } label: {
                                        Label("Library", systemImage: "photo")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.appPrimaryGreen)
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        if viewModel.isAnalyzing {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .padding()
                            .cardStyle()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Add Item Manually")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appCream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
                    .foregroundColor(.appPrimaryGreen)
                    .fontWeight(.semibold)
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
    PantryView(viewModel: PantryViewModel())
}
