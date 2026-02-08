//
//  FoodImageService.swift
//  ByteWaste_C4C
//
//  Service to fetch food images from Edamam Food Database API 
// Used by grocery list page
//

import Foundation

class FoodImageService {
    static let shared = FoodImageService()

    private init() {}

    // MARK: - Fetch Food Image URL

    func fetchFoodImageURL(for foodName: String) async -> String? {
        guard !foodName.isEmpty else { return nil }

        // Build the URL for Edamam Food Database API
        let baseURL = Config.EDAMAM_BASE_URL
        let endpoint = Config.EDAMAM_FOOD_PARSER_ENDPOINT

        var components = URLComponents(string: baseURL + endpoint)
        components?.queryItems = [
            URLQueryItem(name: "app_id", value: Config.FOOD_APP_ID),
            URLQueryItem(name: "app_key", value: Config.FOOD_APP_KEY),
            URLQueryItem(name: "ingr", value: foodName)
        ]

        guard let url = components?.url else {
            print("❌ Invalid URL for food image search")
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ Failed to fetch food image: Invalid response")
                return nil
            }

            // Parse the response
            let decoder = JSONDecoder()
            let result = try decoder.decode(EdamamFoodResponse.self, from: data)

            // Return the first food item's image URL
            if let firstFood = result.hints.first?.food.image {
                print("✅ Found image URL for \(foodName): \(firstFood)")
                return firstFood
            }

            print("⚠️ No image found for \(foodName)")
            return nil

        } catch {
            print("❌ Error fetching food image: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Edamam API Response Models

private struct EdamamFoodResponse: Codable {
    let hints: [FoodHint]
}

private struct FoodHint: Codable {
    let food: FoodItem
}

private struct FoodItem: Codable {
    let image: String?
}
