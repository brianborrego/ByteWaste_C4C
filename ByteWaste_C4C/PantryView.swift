import SwiftUI

struct PantryView: View {
    @StateObject private var model = PantryViewModel()

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.items) { item in
                    PantryItemRow(item: item)
                }
                .onDelete(perform: model.delete)
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
            .task {
                await model.loadItems()
            }
            .overlay {
                if model.isLoading && model.items.isEmpty {
                    ProgressView("Loading pantry...")
                }
            }
        }
    }
}

// MARK: - Pantry Item Row
private struct PantryItemRow: View {
    let item: PantryItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Urgency indicator
            Circle()
                .fill(item.urgencyColor)
                .frame(width: 12, height: 12)
            
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
                        Text("• \(item.daysUntilExpiration)d left")
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
