import SwiftUI

struct PantryView: View {
    @StateObject private var model = PantryViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                if model.items.isEmpty {
                    // Empty state
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
                AddPantryItemView { newItem in
                    model.add(newItem)
                }
            }
            .sheet(isPresented: $model.isPresentingScannerSheet) {
                // Use the new Smart Scanner instead of the basic barcode scanner
                SmartScannerSheetView(viewModel: model)
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

    @State private var name: String = ""
    @State private var quantity: String = "1"
    @State private var storageLocation: StorageLocation = .shelf

    var onAdd: (PantryItem) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name", text: $name)
                }
                
                Section("Storage") {
                    Picker("Location", selection: $storageLocation) {
                        ForEach(StorageLocation.allCases, id: \.self) { location in
                            Text("\(location.icon) \(location.displayName)").tag(location)
                        }
                    }
                }
                
                Section("Quantity") {
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Add Item Manually")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        // Create a basic item (without AI analysis)
                        let expirationDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                        let estimates = ShelfLifeEstimates(fridge: 7, freezer: 30, shelf: 7)
                        
                        let item = PantryItem(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            storageLocation: storageLocation,
                            currentExpirationDate: expirationDate,
                            shelfLifeEstimates: estimates,
                            quantity: quantity
                        )
                        onAdd(item)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}


#Preview {
    PantryView()
}
