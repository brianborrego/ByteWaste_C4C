//
//  PantryViewModel.swift
//  ByteWaste_C4C
//
//  Created by Matthew Segura on 2/7/26.
//

import SwiftUI
import Combine

// MARK: - Models
struct PantryItem: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var barcode: String?
    var quantity: Double
    var unit: Unit

    enum Unit: String, CaseIterable, Identifiable {
        case count, pounds, ounces, liters, gallons
        var id: String { rawValue }

        func display(quantity: Double) -> String {
            switch self {
            case .count:
                return "\(Int(quantity)) items"
            case .pounds:
                return String(format: "%.1f lb", quantity)
            case .ounces:
                return String(format: "%.0f oz", quantity)
            case .liters:
                return String(format: "%.1f L", quantity)
            case .gallons:
                return String(format: "%.1f gal", quantity)
            }
        }
    }
}

// MARK: - View Model
class PantryViewModel: ObservableObject {
    @Published var items: [PantryItem] = []
    @Published var isPresentingAddSheet = false
    @Published var isPresentingScannerSheet = false
    @Published var scannedBarcode: String?

    init() {
        self.items = [
            PantryItem(name: "Apples", barcode: "0123456789012", quantity: 4, unit: .count),
            PantryItem(name: "Flour", barcode: "0123456789013", quantity: 2, unit: .pounds),
            PantryItem(name: "Milk", barcode: "0123456789014", quantity: 1, unit: .gallons)
        ]
    }

    func add(_ item: PantryItem) {
        items.append(item)
        isPresentingAddSheet = false
    }

    func addFromBarcode(barcode: String, name: String) {
        let newItem = PantryItem(
            name: name,
            barcode: barcode,
            quantity: 1,
            unit: .count
        )
        items.append(newItem)
        isPresentingScannerSheet = false
    }

    func delete(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
}
