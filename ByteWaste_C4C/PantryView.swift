import SwiftUI

struct PantryView: View {
    @StateObject private var model = PantryViewModel()

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.headline)
                            Text(item.unit.display(quantity: item.quantity))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let barcode = item.barcode {
                                Text(barcode)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .monospaced()
                            }
                        }
                        Spacer()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(item.name), \(item.unit.display(quantity: item.quantity))")
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
                BarcodeScannerSheetView(viewModel: model)
            }
        }
    }
}

private struct AddPantryItemView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var quantity: Double = 1
    @State private var unit: PantryItem.Unit = .count

    var onAdd: (PantryItem) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name", text: $name)
                }
                Section("Quantity") {
                    Stepper(value: $quantity, in: 0.0...999.0, step: unit == .ounces ? 1 : 0.5) {
                        Text(unit.display(quantity: quantity))
                    }
                    Picker("Unit", selection: $unit) {
                        ForEach(PantryItem.Unit.allCases) { unit in
                            Text(unit.rawValue.capitalized).tag(unit)
                        }
                    }
                }
            }
            .navigationTitle("Add Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let item = PantryItem(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            barcode: nil,
                            quantity: quantity,
                            unit: unit
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
