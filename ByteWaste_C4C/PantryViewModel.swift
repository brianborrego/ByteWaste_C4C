//
//  PantryViewModel.swift
//  ByteWaste_C4C
//
//  Created by Matthew Segura on 2/7/26.
//

import SwiftUI
import Combine
import Supabase

// MARK: - Models
enum DisposalMethod: String, Codable {
    case usedFully = "Used Fully"
    case usedPartially = "Used Partially"
    case thrownAway = "Thrown Away"
}

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
    var barcode: String?  // UPC/EAN barcode for tracking

    // Optional
    var quantity: String?
    var brand: String?
    var notes: String?
    var sustainabilityNotes: String?
    var genericName: String?

    // Amount tracking
    var amountRemaining: Double  // 0.0 to 1.0 (percentage)
    var initialQuantityAmount: Double?  // Optional: actual quantity from barcode (oz, grams, etc.)

    // User association (for Supabase RLS)
    var userId: UUID?

    // Map Swift camelCase to DB snake_case columns
    enum CodingKeys: String, CodingKey {
        case id, name, category, quantity, brand, notes, barcode
        case storageLocation = "storage_location"
        case scanDate = "scan_date"
        case currentExpirationDate = "current_expiration_date"
        case shelfLifeEstimates = "shelf_life_estimates"
        case edamamFoodId = "edamam_food_id"
        case imageURL = "image_url"
        case sustainabilityNotes = "sustainability_notes"
        case genericName = "generic_name"
        case amountRemaining = "amount_remaining"
        case initialQuantityAmount = "initial_quantity_amount"
        case userId = "user_id"
    }

    // Custom decoder to handle database NULLs and provide defaults
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        storageLocation = try container.decode(StorageLocation.self, forKey: .storageLocation)
        scanDate = try container.decode(Date.self, forKey: .scanDate)
        currentExpirationDate = try container.decode(Date.self, forKey: .currentExpirationDate)
        shelfLifeEstimates = try container.decode(ShelfLifeEstimates.self, forKey: .shelfLifeEstimates)

        // Optional fields with nil defaults
        edamamFoodId = try? container.decode(String.self, forKey: .edamamFoodId)
        imageURL = try? container.decode(String.self, forKey: .imageURL)
        category = try? container.decode(String.self, forKey: .category)
        quantity = try? container.decode(String.self, forKey: .quantity)
        brand = try? container.decode(String.self, forKey: .brand)
        notes = try? container.decode(String.self, forKey: .notes)
        sustainabilityNotes = try? container.decode(String.self, forKey: .sustainabilityNotes)
        genericName = try? container.decode(String.self, forKey: .genericName)
        initialQuantityAmount = try? container.decode(Double.self, forKey: .initialQuantityAmount)
        barcode = try? container.decode(String.self, forKey: .barcode)

        // amountRemaining with default value of 1.0 if missing/NULL
        amountRemaining = (try? container.decode(Double.self, forKey: .amountRemaining)) ?? 1.0

        // userId (optional, for auth)
        userId = try? container.decode(UUID.self, forKey: .userId)
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

    var formattedTimeRemaining: String {
        let days = daysUntilExpiration

        if days < 0 {
            return "Expired"
        } else if days < 14 {
            return "\(days)d"
        } else if days < 56 {
            let weeks = days / 7
            return "\(weeks)w"
        } else {
            let months = days / 30
            return "\(months)mo"
        }
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
        barcode: String? = nil,
        quantity: String? = nil,
        brand: String? = nil,
        notes: String? = nil,
        sustainabilityNotes: String? = nil,
        genericName: String? = nil,
        amountRemaining: Double = 1.0,
        initialQuantityAmount: Double? = nil,
        userId: UUID? = nil
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
        self.barcode = barcode
        self.quantity = quantity
        self.brand = brand
        self.notes = notes
        self.sustainabilityNotes = sustainabilityNotes
        self.genericName = genericName
        self.amountRemaining = amountRemaining
        self.initialQuantityAmount = initialQuantityAmount
        self.userId = userId
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
    @Published var barcodeForManualEntry: String?  // Barcode to pre-fill in manual entry

    var onItemAdded: (([PantryItem]) -> Void)?
    var onItemsRemoved: (([PantryItem]) -> Void)?

    private let foodService = FoodExpirationService()
    private let supabase = SupabaseService.shared
    // Cache flag to avoid reloading pantry on tab switches
    private(set) var hasInitializedPantry = false

    // MARK: - Helper to get current user ID

    private var currentUserId: UUID? {
        get async {
            try? await supabase.client.auth.session.user.id
        }
    }

    // MARK: - Load from Supabase

    func loadItems() async {
        // Skip if already loaded (cached)
        if hasInitializedPantry {
            print("⚡ Pantry already cached, skipping reload")
            return
        }

        print("🔄 Loading items from Supabase...")
        await MainActor.run { isLoading = true }
        // Capture previous state so we can notify callbacks about changes
        let previousItems = items
        do {
            let fetched = try await supabase.fetchItems()
            print("✅ Successfully fetched \(fetched.count) items from Supabase")
            await MainActor.run {
                items = fetched
                isLoading = false
                hasInitializedPantry = true

                // Notify listeners about additions/removals compared to previous snapshot
                let previousIDs = Set(previousItems.map { $0.id })
                let fetchedIDs = Set(fetched.map { $0.id })

                let removed = previousIDs.subtracting(fetchedIDs)
                let added = fetchedIDs.subtracting(previousIDs)

                if !removed.isEmpty {
                    onItemsRemoved?(items)
                } else if !added.isEmpty {
                    onItemAdded?(items)
                }
            }
        } catch {
            // Ignore cancellation errors (tab switching, view lifecycle, pull-to-refresh cancelled)
            if (error is CancellationError) || ((error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorCancelled) {
                print("ℹ️ Load pantry items request was cancelled")
                await MainActor.run { isLoading = false }
                return
            }

            print("❌ Failed to load items from Supabase: \(error)")
            await MainActor.run {
                errorMessage = "Failed to load items: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    /// Force-refresh pantry from the database (clears cache and reloads).
    /// Uses Task.detached so the Supabase fetch survives SwiftUI .refreshable cancellation.
    func refreshItems() async {
        hasInitializedPantry = false
        await MainActor.run { isLoading = true }

        let result: Result<[PantryItem], Error> = await withCheckedContinuation { continuation in
            Task.detached { [supabase] in
                do {
                    let fetched = try await supabase.fetchItems()
                    continuation.resume(returning: .success(fetched))
                } catch {
                    continuation.resume(returning: .failure(error))
                }
            }
        }

        switch result {
        case .success(let fetched):
            let previousItems = items
            await MainActor.run {
                items = fetched
                isLoading = false
                hasInitializedPantry = true

                let previousIDs = Set(previousItems.map { $0.id })
                let fetchedIDs = Set(fetched.map { $0.id })
                let removed = previousIDs.subtracting(fetchedIDs)
                let added = fetchedIDs.subtracting(previousIDs)

                if !removed.isEmpty {
                    onItemsRemoved?(items)
                } else if !added.isEmpty {
                    onItemAdded?(items)
                }
            }
        case .failure(let error):
            print("❌ Failed to refresh items from Supabase: \(error)")
            await MainActor.run {
                errorMessage = "Failed to refresh items: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    // MARK: - Add (optimistic update + Supabase save)

    func add(_ item: PantryItem) {
        items.append(item)
        isPresentingAddSheet = false
        onItemAdded?(items)
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
            // First, check if this barcode already exists in Supabase
            if let cachedItem = try await supabase.fetchItemByBarcode(barcode) {
                print("✅ Found cached item for barcode \(barcode): \(cachedItem.name)")
                // Create new instance with same properties but new ID and dates
                let newItem = PantryItem(
                    name: cachedItem.name,
                    storageLocation: cachedItem.storageLocation,
                    scanDate: Date(),
                    currentExpirationDate: Calendar.current.date(
                        byAdding: .day,
                        value: cachedItem.daysUntilExpiration,
                        to: Date()
                    ) ?? Date(),
                    shelfLifeEstimates: cachedItem.shelfLifeEstimates,
                    edamamFoodId: cachedItem.edamamFoodId,
                    imageURL: cachedItem.imageURL,
                    category: cachedItem.category,
                    barcode: barcode,
                    quantity: "1",
                    brand: cachedItem.brand,
                    notes: cachedItem.notes,
                    sustainabilityNotes: cachedItem.sustainabilityNotes,
                    userId: await currentUserId
                )

                try await supabase.insertItem(newItem)

                await MainActor.run {
                    items.append(newItem)
                    isAnalyzing = false
                    isPresentingScannerSheet = false
                }
                return
            }

            // Barcode not cached, fetch from Edamam API
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
                barcode: barcode,
                quantity: "1",
                brand: result.brand,
                notes: result.notes,
                sustainabilityNotes: result.sustainabilityNotes,
                genericName: result.genericName,
                userId: await currentUserId
            )

            // Save to Supabase
            try await supabase.insertItem(newItem)

            await MainActor.run {
                items.append(newItem)
                isAnalyzing = false
                isPresentingScannerSheet = false
                onItemAdded?(items)
            }
        } catch {
            // Check if error is "no results" or 404 - if so, open manual entry with barcode pre-filled
            let shouldOpenManualEntry: Bool
            if let serviceError = error as? FoodExpirationService.ServiceError {
                switch serviceError {
                case .noResults:
                    shouldOpenManualEntry = true
                case .apiError(let message) where message.contains("404"):
                    shouldOpenManualEntry = true
                default:
                    shouldOpenManualEntry = false
                }
            } else {
                shouldOpenManualEntry = false
            }

            if shouldOpenManualEntry {
                print("⚠️ Barcode \(barcode) not found - opening manual entry")
                await MainActor.run {
                    isAnalyzing = false
                    isPresentingScannerSheet = false
                    print("📱 Scanner sheet dismissed, setting barcode: \(barcode)")
                    barcodeForManualEntry = barcode
                }

                // Longer delay to ensure scanner sheet is fully dismissed
                try? await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds

                await MainActor.run {
                    print("📱 Opening add sheet with barcode: \(barcodeForManualEntry ?? "nil")")
                    isPresentingAddSheet = true
                }
            } else {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isAnalyzing = false
                    print("❌ Error adding item from barcode: \(error.localizedDescription)")
                }
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
                notes: result.notes,
                sustainabilityNotes: result.sustainabilityNotes,
                genericName: result.genericName,
                userId: await currentUserId
            )

            // Save to Supabase
            try await supabase.insertItem(newItem)

            await MainActor.run {
                items.append(newItem)
                isAnalyzing = false
                isPresentingScannerSheet = false
                onItemAdded?(items)
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isAnalyzing = false
                print("❌ Error adding item from image: \(error.localizedDescription)")
            }
        }
    }

    /// Add item from manual entry with AI analysis
    func addFromManualEntry(name: String, additionalContext: String, barcode: String?, imageURL: String?) async {
        await MainActor.run {
            isAnalyzing = true
            errorMessage = nil
        }

        do {
            // Combine name and context for AI analysis
            let fullDescription = additionalContext.isEmpty ? name : "\(name) - \(additionalContext)"

            let result = try await foodService.analyzeFoodFromImage(foodName: fullDescription)

            // Use provided image or result image, or fetch generic if needed
            var finalImageURL = imageURL ?? result.imageURL
            if finalImageURL == nil {
                // Try to get generic image
                let genericName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                finalImageURL = await foodService.fetchGenericFoodImage(genericName: genericName)
            }

            let newItem = PantryItem(
                name: result.name,
                storageLocation: result.recommendedStorage,
                scanDate: Date(),
                currentExpirationDate: result.expirationDate,
                shelfLifeEstimates: result.shelfLifeEstimates,
                edamamFoodId: result.edamamFoodId,
                imageURL: finalImageURL,
                category: result.category,
                barcode: barcode,
                quantity: "1",
                brand: result.brand,
                notes: result.notes,
                sustainabilityNotes: result.sustainabilityNotes,
                userId: await currentUserId
            )

            // Save to Supabase
            try await supabase.insertItem(newItem)

            await MainActor.run {
                items.append(newItem)
                isAnalyzing = false
                isPresentingAddSheet = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isAnalyzing = false
                print("❌ Error adding item from manual entry: \(error.localizedDescription)")
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
        // Notify listeners about the removal (pass remaining items)
        onItemsRemoved?(items)
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

    func updateItemAmount(_ item: PantryItem, newAmount: Double) {
        // Optimistic update
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].amountRemaining = newAmount

            // Update in Supabase
            let updatedItem = items[index]
            Task {
                do {
                    try await supabase.updateItem(updatedItem)
                } catch {
                    await MainActor.run {
                        errorMessage = "Failed to update amount: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func disposeItem(_ item: PantryItem, method: DisposalMethod) {
        print("📊 Item disposed: \(item.name) - Method: \(method.rawValue)")

        // Award sustainability points based on disposal method
        let currentPoints = UserDefaults.standard.integer(forKey: "sustainabilityPoints")
        var pointsChange = 0

        switch method {
        case .usedFully:
            pointsChange = 10
        case .usedPartially:
            pointsChange = 5
        case .thrownAway:
            pointsChange = -5
        }

        let newPoints = max(0, min(100, currentPoints + pointsChange))  // Clamp between 0-100
        UserDefaults.standard.set(newPoints, forKey: "sustainabilityPoints")

        // Update tree level based on points (level = points / 10)
        let newLevel = newPoints / 10
        UserDefaults.standard.set(newLevel, forKey: "treeLevel")

        print("🌱 Sustainability points: \(currentPoints) → \(newPoints) (\(pointsChange >= 0 ? "+" : "")\(pointsChange)) | Level: \(newLevel)")

        // Optimistic removal from local array
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
            // Notify listeners after optimistic removal
            onItemsRemoved?(items)
        }

        // Delete from Supabase
        Task {
            do {
                try await supabase.deleteItem(id: item.id)
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to dispose item: \(error.localizedDescription)"
                }
            }
        }
    }
}
