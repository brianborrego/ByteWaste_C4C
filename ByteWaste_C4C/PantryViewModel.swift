//
//  PantryViewModel.swift
//  ByteWaste_C4C
//
//  Created by Matthew Segura on 2/7/26.
//

import SwiftUI
import Combine

// MARK: - Models
struct PantryItem: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var storageLocation: StorageLocation
    let scanDate: Date  // NEVER changes - original add date
    var currentExpirationDate: Date
    var shelfLifeEstimates: ShelfLifeEstimates  // AI estimates for all 3 storage types
    var edamamFoodId: String?
    var imageURL: String?
    var category: String?

    // Optional
    var quantity: String?
    var brand: String?
    var notes: String?

    // Computed properties
    var daysUntilExpiration: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: currentExpirationDate).day ?? 0
    }
    
    var isExpired: Bool {
        currentExpirationDate < Date()
    }
    
    var urgencyColor: Color {
        let days = daysUntilExpiration
        if days <= 3 { return .red }
        else if days <= 7 { return .orange }
        else { return .green }
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        storageLocation: StorageLocation,
        scanDate: Date = Date(),
        currentExpirationDate: Date,
        shelfLifeEstimates: ShelfLifeEstimates,
        edamamFoodId: String? = nil,
        imageURL: String? = nil,
        category: String? = nil,
        quantity: String? = nil,
        brand: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.storageLocation = storageLocation
        self.scanDate = scanDate
        self.currentExpirationDate = currentExpirationDate
        self.shelfLifeEstimates = shelfLifeEstimates
        self.edamamFoodId = edamamFoodId
        self.imageURL = imageURL
        self.category = category
        self.quantity = quantity
        self.brand = brand
        self.notes = notes
    }
}

// MARK: - View Model
class PantryViewModel: ObservableObject {
    @Published var items: [PantryItem] = []
    @Published var isPresentingAddSheet = false
    @Published var isPresentingScannerSheet = false
    @Published var isAnalyzing = false
    @Published var errorMessage: String?
    
    private let foodService = FoodExpirationService()

    init() {
        // Sample data for testing
        let sampleEstimates = ShelfLifeEstimates(fridge: 7, freezer: 30, shelf: 3)
        self.items = [
            PantryItem(
                name: "Sample Apple",
                storageLocation: .fridge,
                currentExpirationDate: Date().addingTimeInterval(86400 * 5),
                shelfLifeEstimates: sampleEstimates,
                category: "Fruit"
            )
        ]
    }

    func add(_ item: PantryItem) {
        items.append(item)
        isPresentingAddSheet = false
    }

    /// Add item from barcode scan with AI analysis
    func addFromBarcode(barcode: String) async {
        await MainActor.run {
            isAnalyzing = true
            errorMessage = nil
        }
        
        do {
            let result = try await foodService.analyzeFood(barcode: barcode)
            
            let newItem = PantryItem(
                name: result.name,
                storageLocation: result.recommendedStorage,
                scanDate: Date(),
                currentExpirationDate: result.expirationDate,
                shelfLifeEstimates: result.shelfLifeEstimates,
                edamamFoodId: result.edamamFoodId,
                imageURL: result.imageURL,
                category: result.category,
                quantity: "1",
                brand: result.brand,
                notes: result.notes
            )
            
            await MainActor.run {
                items.append(newItem)
                isAnalyzing = false
                // Don't auto-dismiss - let the view handle it
                // isPresentingScannerSheet = false
                
                // Print JSON for debugging
                printItemJSON(newItem)
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isAnalyzing = false
                print("❌ Error adding item from barcode: \(error.localizedDescription)")
            }
        }
    }

    /// Add item from image classification with AI analysis
    func addFromImageClassification(foodName: String) async {
        await MainActor.run {
            isAnalyzing = true
            errorMessage = nil
        }
        
        do {
            let result = try await foodService.analyzeFoodFromImage(foodName: foodName)
            
            let newItem = PantryItem(
                name: result.name,
                storageLocation: result.recommendedStorage,
                scanDate: Date(),
                currentExpirationDate: result.expirationDate,
                shelfLifeEstimates: result.shelfLifeEstimates,
                edamamFoodId: result.edamamFoodId,
                imageURL: result.imageURL,
                category: result.category,
                quantity: "1",
                brand: result.brand,
                notes: result.notes
            )
            
            await MainActor.run {
                items.append(newItem)
                isAnalyzing = false
                // Don't auto-dismiss - let the view handle it
                // isPresentingScannerSheet = false
                
                // Print JSON for debugging
                printItemJSON(newItem)
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isAnalyzing = false
                print("❌ Error adding item from image: \(error.localizedDescription)")
            }
        }
    }

    /// Print item as JSON
    func printItemJSON(_ item: PantryItem) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        if let jsonData = try? encoder.encode(item),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("\n" + String(repeating: "=", count: 60))
            print("PANTRY ITEM JSON:")
            print(String(repeating: "=", count: 60))
            print(jsonString)
            print(String(repeating: "=", count: 60) + "\n")
        }
    }

    func delete(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
}
