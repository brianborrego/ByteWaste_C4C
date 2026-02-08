//
//  FoodExpirationService.swift
//  ByteWaste_C4C
//
//  AI-powered food expiration estimation service
//

import Foundation

// MARK: - Configuration (uses Xcode Environment Variables)
fileprivate struct APIConfig {
    // Get value from Xcode Environment Variables, with Config.swift as fallback
    private static func value(envKey: String, fallback: String) -> String {
        // First, check Xcode environment variables
        if let env = ProcessInfo.processInfo.environment[envKey], !env.isEmpty {
            return env
        }
        // Fall back to Config.swift if environment variable not set
        if !fallback.isEmpty {
            return fallback
        }
        // Last resort: check Info.plist
        if let plist = Bundle.main.object(forInfoDictionaryKey: envKey) as? String, !plist.isEmpty {
            return plist
        }
        return ""
    }

    // Edamam Food Database API
    static var EDAMAM_BASE_URL: String { 
        value(envKey: "EDAMAM_BASE_URL", fallback: Config.EDAMAM_BASE_URL)
    }
    static var FOOD_APP_ID: String { 
        value(envKey: "FOOD_APP_ID", fallback: Config.FOOD_APP_ID)
    }
    static var FOOD_APP_KEY: String { 
        value(envKey: "FOOD_APP_KEY", fallback: Config.FOOD_APP_KEY)
    }

    // Navigator AI API
    static var NAVIGATOR_API_ENDPOINT: String { 
        value(envKey: "NAVIGATOR_API_ENDPOINT", fallback: Config.navigatorAPIEndpoint)
    }
    static var NAVIGATOR_API_KEY: String { 
        value(envKey: "NAVIGATOR_API_KEY", fallback: Config.navigatorAPIKey)
    }
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

    // Standard initializer for fallback values
    init(fridge_days: Int, freezer_days: Int, shelf_days: Int, recommended_storage: String, notes: String?) {
        self.fridge_days = fridge_days
        self.freezer_days = freezer_days
        self.shelf_days = shelf_days
        self.recommended_storage = recommended_storage
        self.notes = notes
    }

    // Custom decoding to handle flexible AI responses
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Try to decode fridge_days - handle both Int and String
        if let fridgeInt = try? container.decode(Int.self, forKey: .fridge_days) {
            fridge_days = fridgeInt
        } else if let fridgeString = try? container.decode(String.self, forKey: .fridge_days),
                  let fridgeInt = Int(fridgeString) {
            fridge_days = fridgeInt
        } else {
            throw DecodingError.dataCorruptedError(forKey: .fridge_days, in: container, debugDescription: "fridge_days must be Int or String convertible to Int")
        }

        // Try to decode freezer_days - handle both Int and String
        if let freezerInt = try? container.decode(Int.self, forKey: .freezer_days) {
            freezer_days = freezerInt
        } else if let freezerString = try? container.decode(String.self, forKey: .freezer_days),
                  let freezerInt = Int(freezerString) {
            freezer_days = freezerInt
        } else {
            throw DecodingError.dataCorruptedError(forKey: .freezer_days, in: container, debugDescription: "freezer_days must be Int or String convertible to Int")
        }

        // Try to decode shelf_days - handle both Int and String
        if let shelfInt = try? container.decode(Int.self, forKey: .shelf_days) {
            shelf_days = shelfInt
        } else if let shelfString = try? container.decode(String.self, forKey: .shelf_days),
                  let shelfInt = Int(shelfString) {
            shelf_days = shelfInt
        } else {
            throw DecodingError.dataCorruptedError(forKey: .shelf_days, in: container, debugDescription: "shelf_days must be Int or String convertible to Int")
        }

        // Decode recommended_storage
        recommended_storage = try container.decode(String.self, forKey: .recommended_storage)

        // Decode optional notes
        notes = try? container.decode(String.self, forKey: .notes)
    }
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
        // Validate configuration from environment/schema
        guard !APIConfig.EDAMAM_BASE_URL.isEmpty,
              !APIConfig.FOOD_APP_ID.isEmpty,
              !APIConfig.FOOD_APP_KEY.isEmpty else {
            throw ServiceError.apiError("Missing Edamam configuration. Ensure EDAMAM_BASE_URL, FOOD_APP_ID, and FOOD_APP_KEY are set in the Scheme's Environment Variables or Info.plist.")
        }
        
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
        
        print("\n🔍 Fetching food data from Edamam for barcode: \(barcode)")
        print("   URL: \(url.absoluteString)")

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid HTTP response from Edamam")
            throw ServiceError.apiError("Invalid HTTP response")
        }

        print("✅ Edamam API Status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ Edamam error response: \(errorString)")
            }
            throw ServiceError.apiError("Edamam API returned status \(httpResponse.statusCode)")
        }

        let decoder = JSONDecoder()
        let edamamResponse = try decoder.decode(EdamamResponse.self, from: data)

        guard let food = edamamResponse.hints?.first?.food else {
            print("❌ No food found in Edamam response")
            throw ServiceError.noResults
        }

        print("✅ Found food: \(food.label)")
        if let brand = food.brand {
            print("   Brand: \(brand)")
        }
        print("")

        return food
    }
    
    /// Estimate shelf life using Navigator AI
    private func estimateShelfLife(food: EdamamFood) async throws -> ShelfLifeAIResponse {
        // Validate Navigator configuration
        guard !APIConfig.NAVIGATOR_API_ENDPOINT.isEmpty,
              !APIConfig.NAVIGATOR_API_KEY.isEmpty else {
            throw ServiceError.apiError("Missing Navigator AI configuration. Ensure NAVIGATOR_API_ENDPOINT and NAVIGATOR_API_KEY are set in the Scheme's Environment Variables or Info.plist.")
        }
        
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
        You are a food safety expert specializing in shelf life estimation. Your ONLY job is to return JSON data.

        CRITICAL RULES:
        1. Return ONLY raw JSON - no markdown, no code blocks, no explanations
        2. Do NOT include ```json or ``` markers
        3. Use integer numbers for all day values, never strings
        4. The "recommended_storage" must be exactly one of: "fridge", "freezer", or "shelf"
        5. For shelf_days: use 0 if the item CANNOT be stored at room temperature (e.g., dairy, meat, fish)
        6. Be realistic: milk lasts ~7 days in fridge, not 90 days

        Required JSON structure (copy this EXACTLY):
        {
          "fridge_days": 7,
          "freezer_days": 30,
          "shelf_days": 0,
          "recommended_storage": "fridge",
          "notes": "Keep refrigerated"
        }
        """

        let userPrompt = """
        Provide realistic shelf life estimates in days for this food product:

        \(foodDescription)

        Storage conditions:
        - fridge_days: How many days in refrigerator (40°F/4°C)
        - freezer_days: How many days in freezer (0°F/-18°C)
        - shelf_days: How many days at room temperature (if unsafe, use 0)
        - recommended_storage: Best storage location ("fridge", "freezer", or "shelf")
        - notes: Brief storage instruction (1 sentence)

        REMEMBER:
        - Perishables (meat, dairy, fish, eggs): fridge 2-7 days, shelf_days = 0
        - Produce: fridge 3-14 days depending on type
        - Shelf-stable (canned, dry goods): shelf 180-365 days
        - Return ONLY the JSON object, nothing else
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

        print("\n" + String(repeating: "=", count: 70))
        print("🤖 RAW AI RESPONSE:")
        print(String(repeating: "=", count: 70))
        print(jsonString)
        print(String(repeating: "=", count: 70))

        // Remove markdown code blocks
        if jsonString.hasPrefix("```json") {
            jsonString = jsonString.replacingOccurrences(of: "```json", with: "")
        }
        if jsonString.hasPrefix("```") {
            jsonString = jsonString.replacingOccurrences(of: "```", with: "")
        }
        if jsonString.hasSuffix("```") {
            jsonString = jsonString.replacingOccurrences(of: "```", with: "")
        }

        // Remove any leading/trailing whitespace again
        jsonString = jsonString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        print("\n" + String(repeating: "=", count: 70))
        print("🧹 CLEANED JSON STRING:")
        print(String(repeating: "=", count: 70))
        print(jsonString)
        print(String(repeating: "=", count: 70) + "\n")

        guard let jsonData = jsonString.data(using: String.Encoding.utf8) else {
            print("❌ Failed to convert cleaned string to Data")
            throw ServiceError.parseError
        }

        // Attempt to decode with detailed error handling
        do {
            let shelfLifeResponse = try decoder.decode(ShelfLifeAIResponse.self, from: jsonData)

            print("✅ Successfully decoded AI response:")
            print("   Fridge: \(shelfLifeResponse.fridge_days) days")
            print("   Freezer: \(shelfLifeResponse.freezer_days) days")
            print("   Shelf: \(shelfLifeResponse.shelf_days) days")
            print("   Recommended: \(shelfLifeResponse.recommended_storage)")
            if let notes = shelfLifeResponse.notes {
                print("   Notes: \(notes)")
            }
            print("")

            return shelfLifeResponse
        } catch let DecodingError.keyNotFound(key, context) {
            print("❌ DECODING ERROR: Missing required key '\(key.stringValue)'")
            print("   Expected keys: fridge_days, freezer_days, shelf_days, recommended_storage")
            print("   Context: \(context.debugDescription)")
            print("   Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            throw ServiceError.apiError("AI returned incomplete data - missing '\(key.stringValue)'")
        } catch let DecodingError.typeMismatch(type, context) {
            print("❌ DECODING ERROR: Type mismatch for type \(type)")
            print("   Expected: Int for day values, String for recommended_storage")
            print("   Context: \(context.debugDescription)")
            print("   Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            throw ServiceError.apiError("AI returned wrong data type - check the raw response above")
        } catch let DecodingError.valueNotFound(type, context) {
            print("❌ DECODING ERROR: Value not found for type \(type)")
            print("   Context: \(context.debugDescription)")
            throw ServiceError.apiError("AI returned null/missing value - check the raw response above")
        } catch let DecodingError.dataCorrupted(context) {
            print("❌ DECODING ERROR: Data corrupted")
            print("   Context: \(context.debugDescription)")
            throw ServiceError.apiError("AI returned invalid JSON format - check the raw response above")
        } catch {
            print("❌ UNKNOWN DECODING ERROR: \(error.localizedDescription)")
            throw ServiceError.apiError("Failed to parse AI response - check console logs above")
        }
    }
    
    // MARK: - Complete Analysis
    
    /// Complete analysis: Fetch food data and estimate expiration
    public func analyzeFood(barcode: String) async throws -> FoodAnalysisResult {
        // Step 1: Fetch food data
        let food = try await fetchFoodData(barcode: barcode)

        // Step 2: Get AI shelf life estimates (NO fallback - must work)
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
        // Note: imageURL can be nil - not all products have images in Edamam database
        return FoodAnalysisResult(
            name: food.label,
            brand: food.brand,
            category: food.categoryLabel ?? food.category,
            imageURL: food.image,  // Optional - may be nil
            edamamFoodId: food.foodId,
            shelfLifeEstimates: shelfLifeEstimates,
            recommendedStorage: storageLocation,
            notes: aiResponse.notes,
            expirationDate: expirationDate
        )
    }
    
    /// Analyze food from image classification (no barcode)
    public func analyzeFoodFromImage(foodName: String) async throws -> FoodAnalysisResult {
        // Step 1: Search Edamam for the food name
        let food = try await searchFoodByName(name: foodName)
        
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
    
    /// Search for food by name (for image classification results)
    private func searchFoodByName(name: String) async throws -> EdamamFood {
        // Validate configuration
        guard !APIConfig.EDAMAM_BASE_URL.isEmpty,
              !APIConfig.FOOD_APP_ID.isEmpty,
              !APIConfig.FOOD_APP_KEY.isEmpty else {
            throw ServiceError.apiError("Missing Edamam configuration")
        }
        
        var components = URLComponents(string: "\(APIConfig.EDAMAM_BASE_URL)/api/food-database/v2/parser")
        
        // Clean up the food name (remove technical classification terms)
        let cleanedName = name
            .replacingOccurrences(of: "_", with: " ")
            .components(separatedBy: ",").first ?? name
        
        components?.queryItems = [
            URLQueryItem(name: "app_id", value: APIConfig.FOOD_APP_ID),
            URLQueryItem(name: "app_key", value: APIConfig.FOOD_APP_KEY),
            URLQueryItem(name: "ingr", value: cleanedName),
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
        
        // Try parsed items first, then hints
        if let parsedFood = edamamResponse.parsed?.first?.food {
            return parsedFood
        } else if let hintFood = edamamResponse.hints?.first?.food {
            return hintFood
        } else {
            throw ServiceError.noResults
        }
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

