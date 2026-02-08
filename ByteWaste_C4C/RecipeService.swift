//
//  RecipeService.swift
//  ByteWaste_C4C
//
//  Edamam Recipe Search API v2 integration
//

import Foundation

class RecipeService {

    // MARK: - Edamam Response Models (private)

    private struct EdamamRecipeResponse: Codable {
        let hits: [Hit]
    }

    private struct Hit: Codable {
        let recipe: EdamamRecipe
    }

    private struct EdamamRecipe: Codable {
        let uri: String
        let label: String
        let image: String?
        let source: String?
        let url: String?
        let yield: Double?
        let totalTime: Double?
        let ingredientLines: [String]?
        let ingredients: [EdamamIngredient]?
        let cuisineType: [String]?
        let mealType: [String]?
    }

    private struct EdamamIngredient: Codable {
        let text: String?
        let food: String?
        let quantity: Double?
        let weight: Double?
    }

    // MARK: - Search Recipes

    /// Search Edamam Recipe API using pantry item names as ingredients
    func searchRecipes(ingredients: [String]) async throws -> [Recipe] {
        guard !ingredients.isEmpty else { return [] }

        let query = ingredients.joined(separator: " ")
        print("🍳 Searching Edamam Recipe API for: \(query)")

        var components = URLComponents(string: "\(Config.EDAMAM_BASE_URL)/api/recipes/v2")
        components?.queryItems = [
            URLQueryItem(name: "type", value: "public"),
            URLQueryItem(name: "app_id", value: Config.RECIPE_APP_ID),
            URLQueryItem(name: "app_key", value: Config.RECIPE_APP_KEY),
            URLQueryItem(name: "q", value: query)
        ]

        guard let url = components?.url else {
            throw RecipeServiceError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RecipeServiceError.apiError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            print("❌ Edamam Recipe API returned status \(httpResponse.statusCode)")
            throw RecipeServiceError.apiError("Edamam Recipe API returned status \(httpResponse.statusCode)")
        }

        let decoder = JSONDecoder()
        let edamamResponse = try decoder.decode(EdamamRecipeResponse.self, from: data)

        print("📦 Edamam returned \(edamamResponse.hits.count) recipe hits")

        // Map Edamam recipes to our Recipe model
        let lowercasedIngredients = ingredients.map { $0.lowercased() }
        let pantrySnapshot = lowercasedIngredients

        var recipes: [Recipe] = []
        for hit in edamamResponse.hits {
            let edamamRecipe = hit.recipe
            let ingredientLines = edamamRecipe.ingredientLines ?? []

            // Determine which pantry items this recipe uses
            let pantryItemsUsed = matchPantryItems(
                pantryNames: lowercasedIngredients,
                recipeIngredients: edamamRecipe.ingredients ?? [],
                ingredientLines: ingredientLines
            )

            let recipe = Recipe(
                label: edamamRecipe.label,
                image: edamamRecipe.image,
                sourceUrl: edamamRecipe.url,
                sourcePublisher: edamamRecipe.source,
                yield: edamamRecipe.yield.map { Int($0) },
                totalTime: edamamRecipe.totalTime.map { Int($0) },
                ingredientLines: ingredientLines,
                cuisineType: edamamRecipe.cuisineType,
                mealType: edamamRecipe.mealType,
                pantryItemsUsed: pantryItemsUsed,
                generatedFrom: pantrySnapshot
            )
            recipes.append(recipe)
        }

        // Sort by number of pantry items used (most matches first)
        recipes.sort { $0.pantryItemsUsed.count > $1.pantryItemsUsed.count }

        // Return top 15
        let topRecipes = Array(recipes.prefix(15))
        print("✅ Returning \(topRecipes.count) recipes (sorted by pantry match)")
        return topRecipes
    }

    // MARK: - Ingredient Matching

    /// Match pantry item names against recipe ingredients (case-insensitive)
    private func matchPantryItems(
        pantryNames: [String],
        recipeIngredients: [EdamamIngredient],
        ingredientLines: [String]
    ) -> [String] {
        var matched: [String] = []

        for pantryName in pantryNames {
            // Check against structured ingredient "food" field first
            let foundInFood = recipeIngredients.contains { ingredient in
                guard let food = ingredient.food else { return false }
                return food.localizedCaseInsensitiveContains(pantryName)
                    || pantryName.localizedCaseInsensitiveContains(food)
            }

            if foundInFood {
                matched.append(pantryName)
                continue
            }

            // Fallback: check against ingredientLines text
            let foundInLines = ingredientLines.contains { line in
                line.localizedCaseInsensitiveContains(pantryName)
            }

            if foundInLines {
                matched.append(pantryName)
            }
        }

        return matched
    }
}

// MARK: - Errors

enum RecipeServiceError: LocalizedError {
    case invalidURL
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid recipe API URL"
        case .apiError(let message):
            return "Recipe API error: \(message)"
        }
    }
}
