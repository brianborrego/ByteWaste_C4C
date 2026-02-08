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

    // Map Swift camelCase to DB snake_case columns
    enum CodingKeys: String, CodingKey {
        case id, name, category, quantity, brand, notes
        case storageLocation = "storage_location"
        case scanDate = "scan_date"
        case currentExpirationDate = "current_expiration_date"
        case shelfLifeEstimates = "shelf_life_estimates"
        case edamamFoodId = "edamam_food_id"
        case imageURL = "image_url"
    }

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
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let foodService = FoodExpirationService()
    private let supabase = SupabaseService.shared

    // MARK: - Load from Supabase

    func loadItems() async {
        await MainActor.run { isLoading = true }
        do {
            let fetched = try await supabase.fetchItems()
            await MainActor.run {
                items = fetched
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load items: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    // MARK: - Add (optimistic update + Supabase save)

    func add(_ item: PantryItem) {
        items.append(item)
        isPresentingAddSheet = false
        Task {
            do {
                try await supabase.insertItem(item)
            } catch {
                await MainActor.run {
                    items.removeAll { $0.id == item.id }
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Add from barcode scan with AI analysis

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

            // Save to Supabase
            try await supabase.insertItem(newItem)

            await MainActor.run {
                items.append(newItem)
                isAnalyzing = false
                isPresentingScannerSheet = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isAnalyzing = false
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

            // Save to Supabase
            try await supabase.insertItem(newItem)

            await MainActor.run {
                items.append(newItem)
                isAnalyzing = false
                isPresentingScannerSheet = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isAnalyzing = false
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

    // MARK: - Delete (optimistic update + Supabase delete)

    func delete(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { items[$0] }
        items.remove(atOffsets: offsets)
        Task {
            for item in itemsToDelete {
                do {
                    try await supabase.deleteItem(id: item.id)
                } catch {
                    await MainActor.run {
                        errorMessage = "Failed to delete: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}
