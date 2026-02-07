/*#!/usr/bin/env swift

import Foundation

struct Config {
    static let EDAMAM_BASE_URL = "https://api.edamam.com"
    static let FOOD_APP_ID = "8ed2ee10"
    static let FOOD_APP_KEY = "1d7a4ef39b5d91968f1104e81b1848c0"
}

// MARK: - Response Models
struct EdamamResponse: Codable {
    let text: String
    let parsed: [ParsedItem]
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
    
    enum CodingKeys: String, CodingKey {
        case foodId, label, brand, category, categoryLabel, image, nutrients
    }
}

struct Nutrients: Codable {
    let ENERC_KCAL: Double?  // Energy (kcal)
    let PROCNT: Double?      // Protein
    let FAT: Double?         // Fat
    let CHOCDF: Double?      // Carbs
    let FIBTG: Double?       // Fiber
    
    enum CodingKeys: String, CodingKey {
        case ENERC_KCAL, PROCNT, FAT, CHOCDF, FIBTG
    }
}

struct Measure: Codable {
    let uri: String
    let label: String
}

// MARK: - Barcode Search Function
func searchFoodByBarcode(_ barcode: String, completion: @escaping (Bool) -> Void) {
    var components = URLComponents(
        string: "\(Config.EDAMAM_BASE_URL)/api/food-database/v2/parser"
    )

    components?.queryItems = [
        URLQueryItem(name: "app_id", value: Config.FOOD_APP_ID),
        URLQueryItem(name: "app_key", value: Config.FOOD_APP_KEY),
        URLQueryItem(name: "upc", value: barcode),
        URLQueryItem(name: "nutrition-type", value: "logging")
    ]

    guard let url = components?.url else {
        print("❌ Invalid URL")
        completion(false)
        return
    }

    print("\n🔍 Searching for barcode: \(barcode)")
    print("📡 Request URL: \(url.absoluteString)\n")

    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        // Handle errors
        if let error = error {
            print("❌ Network error: \(error.localizedDescription)")
            completion(false)
            return
        }

        // Check HTTP response
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 HTTP Status Code: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                print("❌ API returned error status code: \(httpResponse.statusCode)")
            }
        }

        guard let data = data else {
            print("❌ No data returned")
            completion(false)
            return
        }

        // Print raw JSON response
        print("\n📄 Raw JSON Response:")
        print("═══════════════════════════════════════════════════════════")
        if let jsonString = String(data: data, encoding: .utf8) {
            if let jsonData = jsonString.data(using: .utf8),
               let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
               let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                print(prettyString)
            } else {
                print(jsonString)
            }
        }
        print("═══════════════════════════════════════════════════════════\n")

        // Parse and display structured information
        do {
            let decoder = JSONDecoder()
            let response = try decoder.decode(EdamamResponse.self, from: data)
            
            if response.hints.isEmpty {
                print("⚠️  No products found for this barcode")
                print("💡 Tips:")
                print("   • Verify the barcode is correct")
                print("   • Try a different barcode")
                print("   • Some products may not be in the Edamam database")
                completion(false)
                return
            }
            
            print("✅ SUCCESS! Product(s) Found:\n")
            
            // Display all hints (usually just one for barcode search)
            for (index, hint) in response.hints.enumerated() {
                let food = hint.food
                print("┌─ Product \(index + 1) ─────────────────────────────────────")
                print("│")
                print("│ 🏷️  Name:     \(food.label)")
                
                if let brand = food.brand {
                    print("│ 🏢 Brand:    \(brand)")
                }
                
                if let category = food.categoryLabel {
                    print("│ 📦 Category: \(category)")
                } else if let category = food.category {
                    print("│ 📦 Category: \(category)")
                }
                
                if let image = food.image {
                    print("│ 🖼️  Image:    \(image)")
                }
                
                print("│ 🆔 Food ID:  \(food.foodId)")
                
                // Nutrition information
                if let nutrients = food.nutrients {
                    print("│")
                    print("│ 📊 Nutrition (per 100g):")
                    if let calories = nutrients.ENERC_KCAL {
                        print("│    • Calories: \(String(format: "%.1f", calories)) kcal")
                    }
                    if let protein = nutrients.PROCNT {
                        print("│    • Protein:  \(String(format: "%.1f", protein))g")
                    }
                    if let fat = nutrients.FAT {
                        print("│    • Fat:      \(String(format: "%.1f", fat))g")
                    }
                    if let carbs = nutrients.CHOCDF {
                        print("│    • Carbs:    \(String(format: "%.1f", carbs))g")
                    }
                    if let fiber = nutrients.FIBTG {
                        print("│    • Fiber:    \(String(format: "%.1f", fiber))g")
                    }
                }
                
                // Available measures
                if let measures = hint.measures, !measures.isEmpty {
                    print("│")
                    print("│ 📏 Available Measures:")
                    for measure in measures.prefix(5) {
                        print("│    • \(measure.label)")
                    }
                    if measures.count > 5 {
                        print("│    ... and \(measures.count - 5) more")
                    }
                }
                
                print("│")
                print("└─────────────────────────────────────────────────────────\n")
            }
            
            completion(true)
        } catch {
            print("❌ Failed to parse response: \(error)")
            print("💡 The API returned data but in an unexpected format")
            completion(false)
        }
    }

    task.resume()
}

// MARK: - Main Program
print("╔═══════════════════════════════════════════════════════════╗")
print("║          Edamam Barcode Scanner Test                      ║")
print("╚═══════════════════════════════════════════════════════════╝")

// Check if barcode was provided as command line argument
let barcode: String
if CommandLine.arguments.count > 1 {
    barcode = CommandLine.arguments[1]
} else {
    // Default test barcode (you can change this)
    barcode = "689544083016"
    print("\n💡 No barcode provided. Using default: \(barcode)")
    print("💡 To test with a custom barcode, run:")
    print("   swift testMCP.swift YOUR_BARCODE_HERE\n")
}

// Search for the product
searchFoodByBarcode(barcode) { success in
    if success {
        print("✅ Test completed successfully!")
    } else {
        print("❌ Test failed or no results found")
    }
    exit(success ? 0 : 1)
}

// Keep the script running until the async request completes
RunLoop.main.run()


*/