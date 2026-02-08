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

    /// Search Edamam Recipe API using multiple query combinations of pantry items.
    /// Generates individual, pair, and (if few items) triple queries, runs them
    /// in parallel, deduplicates, scores, filters, and returns top 15.
    func searchRecipes(ingredients: [String]) async throws -> [Recipe] {
        guard !ingredients.isEmpty else { return [] }

        // Generate query combinations, capped at 6 total API calls
        let queries = generateQueryCombinations(from: ingredients, maxQueries: 6)
        print("🍳 Generated \(queries.count) query combinations: \(queries)")

        // Run all queries in parallel
        let allHits: [(String, [Hit])] = try await withThrowingTaskGroup(
            of: (String, [Hit]).self,
            returning: [(String, [Hit])].self
        ) { group in
            for query in queries {
                group.addTask {
                    let hits = try await self.fetchEdamamRecipes(query: query)
                    return (query, hits)
                }
            }
            var results: [(String, [Hit])] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }

        // Flatten and deduplicate by label + sourceUrl
        let lowercasedIngredients = ingredients.map { $0.lowercased() }
        var seen = Set<String>()
        var allRecipes: [Recipe] = []

        for (_, hits) in allHits {
            for hit in hits {
                let edamamRecipe = hit.recipe
                let dedupKey = "\(edamamRecipe.label.lowercased())|\(edamamRecipe.url ?? "")"
                guard seen.insert(dedupKey).inserted else { continue }

                let ingredientLines = edamamRecipe.ingredientLines ?? []
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
                    generatedFrom: lowercasedIngredients
                )
                allRecipes.append(recipe)
            }
        }

        print("📦 Total unique recipes after dedup: \(allRecipes.count)")

        // Filter: keep recipes with <= 3 missing ingredients
        let filtered = allRecipes.filter { recipe in
            let total = recipe.ingredientLines.count
            let missing = max(0, total - recipe.pantryItemsUsed.count)
            return missing <= 3
        }

        // Sort by fewest missing ingredients first, then most pantry matches
        let sorted = filtered.sorted { a, b in
            let missingA = max(0, a.ingredientLines.count - a.pantryItemsUsed.count)
            let missingB = max(0, b.ingredientLines.count - b.pantryItemsUsed.count)
            if missingA != missingB { return missingA < missingB }
            return a.pantryItemsUsed.count > b.pantryItemsUsed.count
        }

        let topRecipes = Array(sorted.prefix(15))
        print("✅ Returning \(topRecipes.count) recipes (filtered by missing<=3, sorted)")
        return topRecipes
    }

    // MARK: - Query Generation

    /// Generate query combinations: individual items first, then pairs, then triples (if ≤4 items).
    /// Capped at maxQueries to respect Edamam rate limits.
    private func generateQueryCombinations(from ingredients: [String], maxQueries: Int) -> [String] {
        var queries: [String] = []

        // Priority 1: Individual items (ensures "eggs" returns scrambled eggs, etc.)
        for item in ingredients {
            queries.append(item)
        }

        // Priority 2: Pairs
        if ingredients.count >= 2 {
            for i in 0..<ingredients.count {
                for j in (i + 1)..<ingredients.count {
                    queries.append("\(ingredients[i]) \(ingredients[j])")
                }
            }
        }

        // Priority 3: Triples (only if 3-4 items to avoid combinatorial explosion)
        if ingredients.count >= 3 && ingredients.count <= 4 {
            for i in 0..<ingredients.count {
                for j in (i + 1)..<ingredients.count {
                    for k in (j + 1)..<ingredients.count {
                        queries.append("\(ingredients[i]) \(ingredients[j]) \(ingredients[k])")
                    }
                }
            }
        }

        return Array(queries.prefix(maxQueries))
    }

    // MARK: - Single API Call

    /// Fetch recipes from Edamam for a single query string.
    private func fetchEdamamRecipes(query: String) async throws -> [Hit] {
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
            throw RecipeServiceError.apiError("Invalid response for query: \(query)")
        }

        // Handle rate limiting gracefully — return empty instead of throwing
        if httpResponse.statusCode == 429 {
            print("⚠️ Rate limited on query: \(query), skipping")
            return []
        }

        guard httpResponse.statusCode == 200 else {
            print("❌ Edamam returned status \(httpResponse.statusCode) for query: \(query)")
            throw RecipeServiceError.apiError("Edamam returned status \(httpResponse.statusCode)")
        }

        let edamamResponse = try JSONDecoder().decode(EdamamRecipeResponse.self, from: data)
        print("  -> Query '\(query)' returned \(edamamResponse.hits.count) hits")
        return edamamResponse.hits
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
