//
//  FoodExpirationService.swift
//  ByteWaste_C4C
//
//  AI-powered food expiration estimation service
//

import Foundation

// MARK: - Configuration (internal to this file)
fileprivate struct APIConfig {
    // Edamam Food Database API
    static let EDAMAM_BASE_URL = "https://api.edamam.com"
    static let FOOD_APP_ID = "8ed2ee10"
    static let FOOD_APP_KEY = "1d7a4ef39b5d91968f1104e81b1848c0"
    
    // Navigator AI API
    static let NAVIGATOR_API_ENDPOINT = "https://api.ai.it.ufl.edu/v1"
    static let NAVIGATOR_API_KEY = "sk-2blAQakgnP15ORa_s0z1hw"
}

// MARK: - Models
public enum StorageLocation: String, Codable, CaseIterable {
    case fridge = "fridge"
    case freezer = "freezer"
    case shelf = "shelf"
    
    public var displayName: String {
        switch self {
        case .fridge: return "Refrigerator"
        case .freezer: return "Freezer"
        case .shelf: return "Pantry/Shelf"
        }
    }
    
    public var icon: String {
        switch self {
        case .fridge: return "🧊"
        case .freezer: return "❄️"
        case .shelf: return "🏠"
        }
    }
}

public struct ShelfLifeEstimates: Codable, Equatable {
    public let fridge: Int       // days
    public let freezer: Int      // days
    public let shelf: Int        // days
    
    public init(fridge: Int, freezer: Int, shelf: Int) {
        self.fridge = fridge
        self.freezer = freezer
        self.shelf = shelf
    }
}

// MARK: - Edamam Response Models
fileprivate struct EdamamResponse: Codable {
    let text: String?
    let parsed: [ParsedItem]?
    let hints: [Hint]?
}

fileprivate struct ParsedItem: Codable {
    let food: EdamamFood
}

fileprivate struct Hint: Codable {
    let food: EdamamFood
    let measures: [Measure]?
}

fileprivate struct EdamamFood: Codable {
    let foodId: String
    let label: String
    let brand: String?
    let category: String?
    let categoryLabel: String?
    let image: String?
    let nutrients: Nutrients?
}

fileprivate struct Nutrients: Codable {
    let ENERC_KCAL: Double?  // Energy (kcal)
    let PROCNT: Double?      // Protein
    let FAT: Double?         // Fat
    let CHOCDF: Double?      // Carbs
    let FIBTG: Double?       // Fiber
}

fileprivate struct Measure: Codable {
    let uri: String
    let label: String
}

// MARK: - Navigator AI Models
fileprivate struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let max_tokens: Int
}

fileprivate struct ChatMessage: Codable {
    let role: String
    let content: String
}

fileprivate struct ChatCompletionResponse: Codable {
    let choices: [Choice]
}

fileprivate struct Choice: Codable {
    let message: ChatMessage
}

fileprivate struct ShelfLifeAIResponse: Codable {
    let fridge_days: Int
    let freezer_days: Int
    let shelf_days: Int
    let recommended_storage: String
    let notes: String?
}

// MARK: - Public Result Model
public struct FoodAnalysisResult {
    public let name: String
    public let brand: String?
    public let category: String?
    public let imageURL: String?
    public let edamamFoodId: String
    public let shelfLifeEstimates: ShelfLifeEstimates
    public let recommendedStorage: StorageLocation
    public let notes: String?
    public let expirationDate: Date
}

// MARK: - Service
public class FoodExpirationService {
    
    public init() {}
    
    // MARK: - API Fetch Methods
    
    /// Fetch food data from Edamam API using barcode
    private func fetchFoodData(barcode: String) async throws -> EdamamFood {
        var components = URLComponents(string: "\(APIConfig.EDAMAM_BASE_URL)/api/food-database/v2/parser")
        
        components?.queryItems = [
            URLQueryItem(name: "app_id", value: APIConfig.FOOD_APP_ID),
            URLQueryItem(name: "app_key", value: APIConfig.FOOD_APP_KEY),
            URLQueryItem(name: "upc", value: barcode),
            URLQueryItem(name: "nutrition-type", value: "logging")
        ]
        
        guard let url = components?.url else {
            throw ServiceError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ServiceError.apiError("Edamam API returned error")
        }
        
        let decoder = JSONDecoder()
        let edamamResponse = try decoder.decode(EdamamResponse.self, from: data)
        
        guard let food = edamamResponse.hints?.first?.food else {
            throw ServiceError.noResults
        }
        
        return food
    }
    
    /// Estimate shelf life using Navigator AI
    private func estimateShelfLife(food: EdamamFood) async throws -> ShelfLifeAIResponse {
        guard let url = URL(string: "\(APIConfig.NAVIGATOR_API_ENDPOINT)/chat/completions") else {
            throw ServiceError.invalidURL
        }
        
        // Build food description
        var foodDescription = "Product: \(food.label)"
        if let brand = food.brand {
            foodDescription += "\nBrand: \(brand)"
        }
        if let category = food.categoryLabel ?? food.category {
            foodDescription += "\nCategory: \(category)"
        }
        
        let systemPrompt = """
        You are a food safety expert. Provide shelf life estimates in days for different storage locations.
        Return ONLY valid JSON matching this exact structure, no additional text:
        {
          "fridge_days": <number>,
          "freezer_days": <number>,
          "shelf_days": <number>,
          "recommended_storage": "<fridge|freezer|shelf>",
          "notes": "<brief storage tip>"
        }
        """
        
        let userPrompt = """
        Estimate shelf life in days for this food product in three storage conditions:
        1. Refrigerator (fridge_days)
        2. Freezer (freezer_days)
        3. Room temperature pantry/shelf (shelf_days)

        Also indicate the recommended_storage location (fridge, freezer, or shelf).

        Food Product:
        \(foodDescription)

        Return ONLY the JSON object, no markdown, no explanations.
        """
        
        let requestBody = ChatCompletionRequest(
            model: "llama-3.1-8b-instruct",
            messages: [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: userPrompt)
            ],
            temperature: 0.3,
            max_tokens: 500
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(APIConfig.NAVIGATOR_API_KEY)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ServiceError.apiError("Navigator AI returned error")
        }
        
        let decoder = JSONDecoder()
        let chatResponse = try decoder.decode(ChatCompletionResponse.self, from: data)
        
        guard let messageContent = chatResponse.choices.first?.message.content else {
            throw ServiceError.noResults
        }
        
        // Clean up response (remove markdown if present)
        var jsonString = messageContent.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if jsonString.hasPrefix("```json") {
            jsonString = jsonString.replacingOccurrences(of: "```json", with: "")
        }
        if jsonString.hasPrefix("```") {
            jsonString = jsonString.replacingOccurrences(of: "```", with: "")
        }
        jsonString = jsonString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        guard let jsonData = jsonString.data(using: String.Encoding.utf8) else {
            throw ServiceError.parseError
        }
        
        let shelfLifeResponse = try decoder.decode(ShelfLifeAIResponse.self, from: jsonData)
        return shelfLifeResponse
    }
    
    // MARK: - Complete Analysis
    
    /// Complete analysis: Fetch food data and estimate expiration
    public func analyzeFood(barcode: String) async throws -> FoodAnalysisResult {
        // Step 1: Fetch food data
        let food = try await fetchFoodData(barcode: barcode)
        
        // Step 2: Get AI shelf life estimates
        let aiResponse = try await estimateShelfLife(food: food)
        
        // Step 3: Determine storage location
        let storageLocation: StorageLocation
        switch aiResponse.recommended_storage.lowercased() {
        case "fridge":
            storageLocation = .fridge
        case "freezer":
            storageLocation = .freezer
        case "shelf":
            storageLocation = .shelf
        default:
            storageLocation = .shelf
        }
        
        // Step 4: Create shelf life estimates
        let shelfLifeEstimates = ShelfLifeEstimates(
            fridge: aiResponse.fridge_days,
            freezer: aiResponse.freezer_days,
            shelf: aiResponse.shelf_days
        )
        
        // Step 5: Calculate expiration date based on recommended storage
        let daysToAdd: Int
        switch storageLocation {
        case .fridge:
            daysToAdd = aiResponse.fridge_days
        case .freezer:
            daysToAdd = aiResponse.freezer_days
        case .shelf:
            daysToAdd = aiResponse.shelf_days
        }
        
        let expirationDate = Calendar.current.date(byAdding: .day, value: daysToAdd, to: Date()) ?? Date()
        
        // Step 6: Return result
        return FoodAnalysisResult(
            name: food.label,
            brand: food.brand,
            category: food.categoryLabel ?? food.category,
            imageURL: food.image,
            edamamFoodId: food.foodId,
            shelfLifeEstimates: shelfLifeEstimates,
            recommendedStorage: storageLocation,
            notes: aiResponse.notes,
            expirationDate: expirationDate
        )
    }
}

// MARK: - Errors
public enum ServiceError: LocalizedError {
    case invalidURL
    case apiError(String)
    case noResults
    case parseError
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .apiError(let message):
            return message
        case .noResults:
            return "No food found for this barcode"
        case .parseError:
            return "Failed to parse API response"
        }
    }
}
