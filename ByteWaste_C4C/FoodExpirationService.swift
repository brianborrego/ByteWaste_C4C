//
//  FoodExpirationService.swift
//  ByteWaste_C4C
//
//  AI-powered food expiration estimation service
//

import Foundation

// MARK: - Configuration (uses Xcode Environment Variables)
fileprivate struct APIConfig {
    // Get value from Xcode Environment Variables only
    private static func value(for key: String) -> String {
        // Check Xcode environment variables
        if let env = ProcessInfo.processInfo.environment[key], !env.isEmpty {
            return env
        }
        // Fall back to Info.plist if needed
        if let plist = Bundle.main.object(forInfoDictionaryKey: key) as? String, !plist.isEmpty {
            return plist
        }
        return ""
    }

    // Edamam Food Database API
    static var EDAMAM_BASE_URL: String {
        value(for: "EDAMAM_BASE_URL")
    }
    static var FOOD_APP_ID: String {
        value(for: "FOOD_APP_ID")
    }
    static var FOOD_APP_KEY: String {
        value(for: "FOOD_APP_KEY")
    }

    // Navigator AI API
    static var NAVIGATOR_API_ENDPOINT: String {
        value(for: "NAVIGATOR_API_ENDPOINT")
    }
    static var NAVIGATOR_API_KEY: String {
        value(for: "NAVIGATOR_API_KEY")
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
    let sustainability_notes: String?
    let food_category: String?
    let generic_name: String?

    // Standard initializer for fallback values
    init(fridge_days: Int, freezer_days: Int, shelf_days: Int, recommended_storage: String, notes: String?, sustainability_notes: String?, food_category: String?, generic_name: String?) {
        self.fridge_days = fridge_days
        self.freezer_days = freezer_days
        self.shelf_days = shelf_days
        self.recommended_storage = recommended_storage
        self.notes = notes
        self.sustainability_notes = sustainability_notes
        self.food_category = food_category
        self.generic_name = generic_name
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

        // Decode optional sustainability_notes
        sustainability_notes = try? container.decode(String.self, forKey: .sustainability_notes)

        // Decode optional food_category
        food_category = try? container.decode(String.self, forKey: .food_category)

        // Decode optional generic_name
        generic_name = try? container.decode(String.self, forKey: .generic_name)
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
    public let sustainabilityNotes: String?
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

        print("\n🍎 Requesting AI shelf life estimates for:")
        print("   Product: \(food.label)")
        if let brand = food.brand {
            print("   Brand: \(brand)")
        }
        if let category = food.categoryLabel ?? food.category {
            print("   Category: \(category)")
        }
        print("")
        
        let systemPrompt = """
        You are a food safety expert specializing in shelf life estimation. Your ONLY job is to return JSON data.

        CRITICAL FORMAT RULES:
        1. Return ONLY raw JSON - no markdown, no code blocks, no explanations
        2. Do NOT include ```json or ``` markers
        3. Use integer numbers for all day values, never strings
        4. The "recommended_storage" must be exactly one of: "fridge", "freezer", or "shelf"

        STORAGE & EXPIRATION GUIDELINES:

        Be GENEROUS with expiration dates - modern food preservation means items last longer than you might think:
        - Regular (non-organic) eggs: 28-35 days in fridge (preservatives help them last)
        - Organic eggs: 14-21 days in fridge (no preservatives, expire faster)
        - Regular milk: 7-10 days in fridge
        - Organic milk: 5-7 days in fridge
        - Regular produce: Add 2-3 extra days compared to organic

        STORAGE LOCATION RULES:

        FREEZER (recommended_storage: "freezer"):
        - Raw meat (chicken, beef, pork): freezer 90-180 days, fridge 2-3 days, shelf 0
        - Raw fish/seafood: freezer 60-90 days, fridge 1-2 days, shelf 0
        - Frozen vegetables (e.g., "Frozen Peas"): freezer 180-365 days, fridge 2-3 days, shelf 0
        - Frozen meals/prepared foods: freezer 90-180 days, fridge 3-4 days, shelf 0

        FRIDGE (recommended_storage: "fridge"):
        - Dairy (milk, yogurt, cheese): fridge 7-21 days depending on type, freezer 30-60 days, shelf 0
        - Eggs: fridge 28-35 days (regular) or 14-21 days (organic), freezer 0, shelf 0
        - Fresh produce (lettuce, berries): fridge 5-14 days depending on type, freezer 60-90 days, shelf 0
        - Condiments that need refrigeration after opening (ketchup, mayo, mustard, salad dressing, BBQ sauce, hot sauce, soy sauce): fridge 60-180 days, freezer 0, shelf 0
        - Deli meats: fridge 5-7 days, freezer 60 days, shelf 0
        - Leftovers/prepared foods: fridge 3-5 days, freezer 60-90 days, shelf 0

        SHELF/PANTRY (recommended_storage: "shelf"):
        - Canned goods in METAL CANS (tuna, beans, soup, vegetables, fruit): shelf 365-730 days, fridge 365 days, freezer 0
        - Dry goods (pasta, rice, flour, cereal, oats): shelf 180-730 days, fridge 180-730 days, freezer 0
        - Bread/baked goods: shelf 5-7 days, fridge 10-14 days, freezer 90 days
        - Shelf-stable items (crackers, chips, cookies): shelf 60-180 days, fridge 60-180 days, freezer 0
        - Oils/vinegars: shelf 180-365 days, fridge 180-365 days, freezer 0
        - Unopened condiments: shelf 365 days, fridge 365 days, freezer 0

        SPECIAL CASES:
        - If the product name contains "organic" → reduce fridge/shelf days by 20-30%
        - If the product mentions "fresh" → prefer fridge storage
        - If the product mentions "frozen" → prefer freezer storage
        - If the product mentions "canned" or you see a brand known for canned goods → prefer shelf storage
        - Bananas: shelf 5-7 days, fridge 10-14 days (refrigeration slows ripening), freezer 90 days

        For shelf_days: use 0 if the item CANNOT safely be stored at room temperature (meat, dairy, fish, eggs, most produce).

        FOOD CATEGORIES:
        You MUST categorize the food into ONE of these categories:
        - "Fruits" (fresh fruit, dried fruit)
        - "Vegetables" (fresh vegetables, leafy greens)
        - "Meat" (beef, pork, lamb, processed meats)
        - "Poultry" (chicken, turkey, duck, eggs)
        - "Fish & Seafood" (fresh fish, shellfish)
        - "Dairy" (milk, cheese, yogurt, butter)
        - "Grains & Bread" (rice, pasta, bread, cereal, flour)
        - "Canned & Jarred Goods" (beans, soups, sauces, vegetables, tuna)
        - "Frozen Foods" (frozen meals, frozen vegetables, ice cream)
        - "Pantry Staples" (oils, vinegar, sugar, flour, baking ingredients)
        - "Snacks & Sweets" (chips, cookies, chocolate, candy)
        - "Condiments & Sauces" (ketchup, mayo, mustard, hot sauce, dressings)
        - "Beverages"
        - "Prepared / Ready-to-Eat"
        - "Other" (if it doesn't fit any category above)

        Required JSON structure (copy this EXACTLY):
        {
          "fridge_days": 7,
          "freezer_days": 30,
          "shelf_days": 0,
          "recommended_storage": "fridge",
          "notes": "Keep refrigerated",
          "sustainability_notes": "Compost the stem and leaves",
          "food_category": "Dairy",
          "generic_name": "milk"
        }

        GENERIC NAME:
        - Provide a simplified, generic version of the food name (lowercase, 1-2 words max)
        - Examples: "Grade A Whole Milk" → "milk", "Cage Free Large Eggs" → "eggs", "Organic Bananas" → "banana"
        - This helps find images for products without pictures
        - Remove brand names, qualifiers (organic, fresh, etc.), and specific varieties

        SUSTAINABILITY NOTES:
        - Include brief advice (1 sentence) on how to dispose of inedible parts sustainably
        - Examples: "Compost peels and cores", "Recycle the can after use", "Compost egg shells", "Recycle plastic packaging"
        - If no special disposal advice, you can omit this field or use an empty string
        """

        let userPrompt = """
        Provide realistic shelf life estimates in days for this food product:

        \(foodDescription)

        Analyze the product name, brand, and category to determine:
        - fridge_days: How many days in refrigerator (40°F/4°C)
        - freezer_days: How many days in freezer (0°F/-18°C)
        - shelf_days: How many days at room temperature (if unsafe, use 0)
        - recommended_storage: Best storage location ("fridge", "freezer", or "shelf")
        - notes: Brief storage instruction (1 sentence)
        - food_category: ONE of the categories listed in the system prompt
        - generic_name: Simplified food name (lowercase, 1-2 words, no brand/qualifiers)

        EXAMPLES:
        - "Chicken Breast" → {"fridge_days": 2, "freezer_days": 180, "shelf_days": 0, "recommended_storage": "freezer", "notes": "Store in freezer, thaw in fridge before use", "sustainability_notes": "Compost bones and scraps", "food_category": "Poultry", "generic_name": "chicken"}
        - "Organic Eggs" → {"fridge_days": 21, "freezer_days": 0, "shelf_days": 0, "recommended_storage": "fridge", "notes": "Keep refrigerated", "sustainability_notes": "Compost egg shells", "food_category": "Eggs", "generic_name": "eggs"}
        - "Regular Eggs" → {"fridge_days": 35, "freezer_days": 0, "shelf_days": 0, "recommended_storage": "fridge", "notes": "Keep refrigerated", "sustainability_notes": "Compost egg shells", "food_category": "Eggs", "generic_name": "eggs"}
        - "Heinz Ketchup" → {"fridge_days": 180, "freezer_days": 0, "shelf_days": 0, "recommended_storage": "fridge", "notes": "Refrigerate after opening", "sustainability_notes": "Recycle the plastic bottle", "food_category": "Condiments & Sauces", "generic_name": "ketchup"}
        - "Canned Tuna" → {"fridge_days": 730, "freezer_days": 0, "shelf_days": 730, "recommended_storage": "shelf", "notes": "Store in cool dry place", "sustainability_notes": "Recycle the metal can", "food_category": "Canned & Jarred Goods", "generic_name": "tuna"}
        - "Bananas" → {"fridge_days": 14, "freezer_days": 90, "shelf_days": 7, "recommended_storage": "shelf", "notes": "Refrigerate to slow ripening", "sustainability_notes": "Compost peels", "food_category": "Fruits", "generic_name": "banana"}
        - "Organic Milk" → {"fridge_days": 7, "freezer_days": 30, "shelf_days": 0, "recommended_storage": "fridge", "notes": "Keep refrigerated", "sustainability_notes": "Recycle the carton", "food_category": "Dairy", "generic_name": "milk"}
        - "Frozen Peas" → {"fridge_days": 3, "freezer_days": 365, "shelf_days": 0, "recommended_storage": "freezer", "notes": "Keep frozen until ready to cook", "sustainability_notes": "Recycle the plastic bag", "food_category": "Frozen Foods", "generic_name": "peas"}
        - "Pasta" → {"fridge_days": 730, "freezer_days": 0, "shelf_days": 730, "recommended_storage": "shelf", "notes": "Store in cool dry place", "sustainability_notes": "Recycle the cardboard box", "food_category": "Grains & Bread", "generic_name": "pasta"}

        Be GENEROUS with expiration dates - food with preservatives lasts longer than organic alternatives.
        Return ONLY the JSON object, nothing else.
        """
        
        let requestBody = ChatCompletionRequest(
            model: "llama-3.1-8b-instruct",
            messages: [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: userPrompt)
            ],
            temperature: 0.5,  // Increased from 0.3 to allow more varied responses
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

        print("📅 Expiration Calculation:")
        print("   Recommended storage: \(storageLocation.rawValue)")
        print("   Days to add: \(daysToAdd)")
        print("   Expiration date: \(expirationDate)")
        print("")

        // Step 6: Try to fetch generic image if barcode scan didn't provide one
        var finalImageURL = food.image
        if finalImageURL == nil, let genericName = aiResponse.generic_name, !genericName.isEmpty {
            print("🖼️ No image from barcode scan, searching for generic image: '\(genericName)'")
            finalImageURL = await fetchGenericFoodImage(genericName: genericName)
            if finalImageURL != nil {
                print("✅ Found generic image for '\(genericName)'")
            }
        }

        // Step 7: Return result
        return FoodAnalysisResult(
            name: food.label,
            brand: food.brand,
            category: aiResponse.food_category ?? "Other",  // Use AI category instead of Edamam
            imageURL: finalImageURL,
            edamamFoodId: food.foodId,
            shelfLifeEstimates: shelfLifeEstimates,
            recommendedStorage: storageLocation,
            notes: aiResponse.notes,
            sustainabilityNotes: aiResponse.sustainability_notes,
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

        print("📅 Expiration Calculation (from image):")
        print("   Recommended storage: \(storageLocation.rawValue)")
        print("   Days to add: \(daysToAdd)")
        print("   Expiration date: \(expirationDate)")
        print("")

        // Step 6: Return result
        return FoodAnalysisResult(
            name: food.label,
            brand: food.brand,
            category: aiResponse.food_category ?? "Other",  // Use AI category instead of Edamam
            imageURL: food.image,
            edamamFoodId: food.foodId,
            shelfLifeEstimates: shelfLifeEstimates,
            recommendedStorage: storageLocation,
            notes: aiResponse.notes,
            sustainabilityNotes: aiResponse.sustainability_notes,
            expirationDate: expirationDate
        )
    }
    
    /// Search for generic food image if barcode scan didn't return one
    private func fetchGenericFoodImage(genericName: String) async -> String? {
        do {
            let genericFood = try await searchFoodByName(name: genericName)
            return genericFood.image
        } catch {
            print("⚠️ Failed to fetch generic image for '\(genericName)': \(error.localizedDescription)")
            return nil
        }
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

