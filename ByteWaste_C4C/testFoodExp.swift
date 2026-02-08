/*#!/usr/bin/env swift

import Foundation

// MARK: - Configuration
struct Config {
    // Edamam Food Database API
    static let EDAMAM_BASE_URL = "https://api.edamam.com"
    static let FOOD_APP_ID = "8ed2ee10"
    static let FOOD_APP_KEY = "1d7a4ef39b5d91968f1104e81b1848c0"
    
    // Navigator AI API
    static let NAVIGATOR_API_ENDPOINT = "https://api.ai.it.ufl.edu/v1"
    static let NAVIGATOR_API_KEY = "sk-2blAQakgnP15ORa_s0z1hw"
}

// MARK: - Edamam Response Models
struct EdamamResponse: Codable {
    let text: String?
    let parsed: [ParsedItem]?
    let hints: [Hint]
}

struct ParsedItem: Codable {
    let food: Food
}

struct Hint: Codable {
    let food: Food
    let measures: [Measure]?
}

struct Food: Codable {
    let foodId: String
    let label: String
    let brand: String?
    let category: String?
    let categoryLabel: String?
    let image: String?
    let nutrients: Nutrients?
}

struct Nutrients: Codable {
    let ENERC_KCAL: Double?  // Energy (kcal)
    let PROCNT: Double?      // Protein
    let FAT: Double?         // Fat
    let CHOCDF: Double?      // Carbs
    let FIBTG: Double?       // Fiber
}

struct Measure: Codable {
    let uri: String
    let label: String
}

// MARK: - PantryItem Models
enum StorageLocation: String, Codable {
    case fridge = "fridge"
    case freezer = "freezer"
    case shelf = "shelf"
}

struct ShelfLifeEstimates: Codable {
    let fridge: Int       // days
    let freezer: Int      // days
    let shelf: Int        // days
}

struct PantryItem: Codable {
    let id: String
    var name: String
    var storageLocation: StorageLocation
    let scanDate: String  // ISO8601 format
    var currentExpirationDate: String  // ISO8601 format
    var shelfLifeEstimates: ShelfLifeEstimates
    var edamamFoodId: String?
    var imageURL: String?
    var category: String?
    
    // Optional
    var quantity: String?
    var brand: String?
    var notes: String?
    
    // Computed properties (displayed separately)
    var daysUntilExpiration: Int {
        let formatter = ISO8601DateFormatter()
        guard let expirationDate = formatter.date(from: currentExpirationDate) else { return 0 }
        return Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
    }
    
    var isExpired: Bool {
        return daysUntilExpiration < 0
    }
    
    var urgencyColor: String {
        let days = daysUntilExpiration
        if days <= 3 { return "red" }
        else if days <= 7 { return "orange" }
        else { return "green" }
    }
}

// MARK: - Navigator AI Models
struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let max_tokens: Int
}

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatCompletionResponse: Codable {
    let id: String?
    let object: String?
    let created: Int?
    let model: String?
    let choices: [Choice]
}

struct Choice: Codable {
    let index: Int
    let message: ChatMessage
    let finish_reason: String?
}

// AI Response for shelf life
struct ShelfLifeAIResponse: Codable {
    let fridge_days: Int
    let freezer_days: Int
    let shelf_days: Int
    let recommended_storage: String
    let notes: String?
}

// MARK: - Food Expiration Estimator
class FoodExpirationEstimator {
    
    // Step 1: Fetch food data from Edamam
    func fetchFoodData(barcode: String, completion: @escaping (Food?) -> Void) {
        var components = URLComponents(string: "\(Config.EDAMAM_BASE_URL)/api/food-database/v2/parser")
        
        components?.queryItems = [
            URLQueryItem(name: "app_id", value: Config.FOOD_APP_ID),
            URLQueryItem(name: "app_key", value: Config.FOOD_APP_KEY),
            URLQueryItem(name: "upc", value: barcode),
            URLQueryItem(name: "nutrition-type", value: "logging")
        ]
        
        guard let url = components?.url else {
            print("❌ Invalid Edamam URL")
            completion(nil)
            return
        }
        
        print("🔍 Fetching food data for barcode: \(barcode)...")
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Edamam API error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("❌ No data from Edamam API")
                completion(nil)
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(EdamamResponse.self, from: data)
                
                if let firstFood = response.hints.first?.food {
                    print("✅ Food found: \(firstFood.label)")
                    if let brand = firstFood.brand {
                        print("   Brand: \(brand)")
                    }
                    if let category = firstFood.categoryLabel ?? firstFood.category {
                        print("   Category: \(category)")
                    }
                    completion(firstFood)
                } else {
                    print("⚠️  No food found for barcode: \(barcode)")
                    completion(nil)
                }
            } catch {
                print("❌ Failed to parse Edamam response: \(error)")
                completion(nil)
            }
        }
        
        task.resume()
    }
    
    // Step 2: Estimate expiration using Navigator AI
    func estimateExpiration(food: Food, completion: @escaping (ShelfLifeAIResponse?) -> Void) {
        guard let url = URL(string: "\(Config.NAVIGATOR_API_ENDPOINT)/chat/completions") else {
            print("❌ Invalid Navigator AI URL")
            completion(nil)
            return
        }
        
        // Build the food description
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
        """.trim()
        
        let userPrompt = """
        Estimate shelf life in days for this food product in three storage conditions:
        1. Refrigerator (fridge_days)
        2. Freezer (freezer_days)
        3. Room temperature pantry/shelf (shelf_days)

        Also indicate the recommended_storage location (fridge, freezer, or shelf).

        Food Product:
        \(foodDescription)

        Return ONLY the JSON object, no markdown, no explanations.
        """.trim()
        
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
        request.setValue("Bearer \(Config.NAVIGATOR_API_KEY)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120
        
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(requestBody)
        } catch {
            print("❌ Failed to encode request: \(error)")
            completion(nil)
            return
        }
        
        print("🤖 Analyzing food with Navigator AI...")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                let nsError = error as NSError
                if nsError.code == NSURLErrorTimedOut {
                    print("❌ Navigator AI request timed out. Please try again.")
                } else if nsError.code == NSURLErrorNotConnectedToInternet {
                    print("❌ No internet connection. Please check your network.")
                } else {
                    print("❌ Navigator AI error: \(error.localizedDescription)")
                }
                completion(nil)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response from Navigator AI")
                completion(nil)
                return
            }
            
            if httpResponse.statusCode != 200 {
                print("❌ Navigator AI returned status code: \(httpResponse.statusCode)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("❌ No data from Navigator AI")
                completion(nil)
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let chatResponse = try decoder.decode(ChatCompletionResponse.self, from: data)
                
                guard let messageContent = chatResponse.choices.first?.message.content else {
                    print("❌ No message in AI response")
                    completion(nil)
                    return
                }
                
                print("✅ AI analysis complete!")
                
                // Extract JSON from response (might have markdown code blocks)
                var jsonString = messageContent.trim()
                
                // Remove markdown code blocks if present
                if jsonString.hasPrefix("```json") {
                    jsonString = jsonString.replacingOccurrences(of: "```json", with: "")
                }
                if jsonString.hasPrefix("```") {
                    jsonString = jsonString.replacingOccurrences(of: "```", with: "")
                }
                jsonString = jsonString.trim()
                
                // Parse the JSON response
                guard let jsonData = jsonString.data(using: .utf8) else {
                    print("❌ Could not convert response to data")
                    print("Response: \(messageContent)")
                    completion(nil)
                    return
                }
                
                let shelfLifeResponse = try decoder.decode(ShelfLifeAIResponse.self, from: jsonData)
                completion(shelfLifeResponse)
                
            } catch {
                print("❌ Failed to parse AI response: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("   Raw response preview: \(jsonString.prefix(300))...")
                }
                completion(nil)
            }
        }
        
        task.resume()
    }
    
    // Complete workflow: Fetch food data and estimate expiration
    func analyzeFood(barcode: String, completion: @escaping (PantryItem?) -> Void) {
        fetchFoodData(barcode: barcode) { food in
            guard let food = food else {
                print("\n❌ Failed to fetch food data")
                completion(nil)
                return
            }
            
            self.estimateExpiration(food: food) { aiResponse in
                guard let aiResponse = aiResponse else {
                    print("\n❌ Failed to get AI analysis")
                    completion(nil)
                    return
                }
                
                // Determine storage location from AI recommendation
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
                
                // Create shelf life estimates
                let shelfLifeEstimates = ShelfLifeEstimates(
                    fridge: aiResponse.fridge_days,
                    freezer: aiResponse.freezer_days,
                    shelf: aiResponse.shelf_days
                )
                
                // Calculate expiration date based on recommended storage
                let scanDate = Date()
                let daysToAdd: Int
                switch storageLocation {
                case .fridge:
                    daysToAdd = aiResponse.fridge_days
                case .freezer:
                    daysToAdd = aiResponse.freezer_days
                case .shelf:
                    daysToAdd = aiResponse.shelf_days
                }
                
                let expirationDate = Calendar.current.date(byAdding: .day, value: daysToAdd, to: scanDate) ?? scanDate
                
                // Format dates to ISO8601
                let formatter = ISO8601DateFormatter()
                
                // Create PantryItem
                let pantryItem = PantryItem(
                    id: UUID().uuidString,
                    name: food.label,
                    storageLocation: storageLocation,
                    scanDate: formatter.string(from: scanDate),
                    currentExpirationDate: formatter.string(from: expirationDate),
                    shelfLifeEstimates: shelfLifeEstimates,
                    edamamFoodId: food.foodId,
                    imageURL: food.image,
                    category: food.categoryLabel ?? food.category,
                    quantity: nil,
                    brand: food.brand,
                    notes: aiResponse.notes
                )
                
                completion(pantryItem)
            }
        }
    }
}

// MARK: - String Extension Helper
extension String {
    func trim() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// Repeat string operator
func *(left: String, right: Int) -> String {
    return String(repeating: left, count: right)
}

// MARK: - Main Program
print("╔═══════════════════════════════════════════════════════════╗")
print("║         Food Expiration Estimator with AI                ║")
print("╚═══════════════════════════════════════════════════════════╝")

// Get barcode from command line or use default
let barcode: String
if CommandLine.arguments.count > 1 {
    barcode = CommandLine.arguments[1]
} else {
    // Default test barcode
    barcode = "016000141551"
    print("\n💡 No barcode provided. Using default: \(barcode)")
    print("💡 To test with a custom barcode, run:")
    print("   swift testFoodExp.swift YOUR_BARCODE_HERE\n")
}

let estimator = FoodExpirationEstimator()
estimator.analyzeFood(barcode: barcode) { pantryItem in
    guard let item = pantryItem else {
        print("❌ Analysis failed")
        exit(1)
    }
    
    // Display structured output
    print("\n╔═══════════════════════════════════════════════════════════╗")
    print("║                  PANTRY ITEM CREATED                      ║")
    print("╚═══════════════════════════════════════════════════════════╝\n")
    
    print("📦 BASIC INFO:")
    print("   ID: \(item.id)")
    print("   Name: \(item.name)")
    if let brand = item.brand {
        print("   Brand: \(brand)")
    }
    if let category = item.category {
        print("   Category: \(category)")
    }
    
    print("\n📍 STORAGE:")
    print("   Location: \(item.storageLocation.rawValue)")
    print("   Scan Date: \(item.scanDate)")
    print("   Expiration: \(item.currentExpirationDate)")
    
    print("\n⏱️  SHELF LIFE ESTIMATES:")
    print("   🧊 Fridge:  \(item.shelfLifeEstimates.fridge) days")
    print("   ❄️  Freezer: \(item.shelfLifeEstimates.freezer) days")
    print("   🏠 Shelf:   \(item.shelfLifeEstimates.shelf) days")
    
    print("\n📊 STATUS:")
    print("   Days Until Expiration: \(item.daysUntilExpiration)")
    print("   Is Expired: \(item.isExpired ? "Yes ⚠️" : "No ✅")")
    print("   Urgency Level: \(item.urgencyColor) \(item.urgencyColor == "red" ? "🔴" : item.urgencyColor == "orange" ? "🟠" : "🟢")")
    
    if let notes = item.notes {
        print("\n📝 NOTES:")
        print("   \(notes)")
    }
    
    if let imageURL = item.imageURL {
        print("\n🖼️  Image URL: \(imageURL)")
    }
    
    if let foodId = item.edamamFoodId {
        print("\n🆔 Edamam Food ID: \(foodId)")
    }
    
    // Output JSON representation
    print("\n" + "═" * 60)
    print("JSON OUTPUT (for API integration):")
    print("═" * 60 + "\n")
    
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    
    if let jsonData = try? encoder.encode(item),
       let jsonString = String(data: jsonData, encoding: .utf8) {
        print(jsonString)
    } else {
        print("❌ Failed to encode JSON")
    }
    
    print("\n" + "═" * 60)
    print("\n✅ Analysis completed successfully!")
    exit(0)
}

// Keep the script running until async operations complete
RunLoop.main.run()

*/