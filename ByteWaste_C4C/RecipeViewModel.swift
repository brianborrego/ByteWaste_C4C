//
//  RecipeViewModel.swift
//  ByteWaste_C4C
//
//  Recipe state management & API integration
//

import SwiftUI
import Combine
import Supabase

class RecipeViewModel: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var isLoading = false
    @Published var isGenerating = false
    @Published var errorMessage: String?

    // Dedup tracker: set of lowercase generic names from last API call
    private var lastGeneratedPantryNames: Set<String> = []

    // Cache flag: only load recipes once from database on app start
    private(set) var hasInitializedRecipes = false

    // Closure to get current pantry items (set by ContentView)
    var pantryItemsProvider: (() -> [PantryItem])?

    private let recipeService = RecipeService()
    private let supabase = SupabaseService.shared

    // MARK: - Helper to get current user ID

    private var currentUserId: UUID? {
        get async {
            try? await supabase.client.auth.session.user.id
        }
    }

    // MARK: - Limit recipes per ingredient

    /// Limit recipes per ingredient to avoid overloading with one ingredient
    private func limitRecipesPerIngredient(_ recipes: [Recipe], maxPerIngredient: Int = 5) -> [Recipe] {
        let excludedStaples = Set(["water", "salt", "pepper", "sugar"])

        func getBaseIngredient(_ ingredient: String) -> String {
            let lower = ingredient.lowercased()
            let modifiers = ["fresh", "frozen", "canned", "dried", "cooked", "raw", "organic",
                           "plain", "greek", "whole", "skim", "low-fat", "fat-free", "unsweetened",
                           "sweetened", "vanilla", "strawberry", "chocolate", "extra", "virgin",
                           "light", "heavy", "sour", "sweet", "spicy", "mild"]
            var base = lower
            for modifier in modifiers {
                base = base.replacingOccurrences(of: "\(modifier) ", with: "")
                base = base.replacingOccurrences(of: " \(modifier)", with: "")
            }
            return base.trimmingCharacters(in: .whitespaces)
        }

        var baseIngredientGroups: [String: Set<String>] = [:]
        let allIngredients = Set(recipes.flatMap { $0.pantryItemsUsed })

        for ingredient in allIngredients where !excludedStaples.contains(ingredient.lowercased()) {
            let base = getBaseIngredient(ingredient)
            if baseIngredientGroups[base] == nil {
                baseIngredientGroups[base] = []
            }
            baseIngredientGroups[base]?.insert(ingredient)
        }

        var recipesToKeep = Set<UUID>()

        for (_, ingredientVariations) in baseIngredientGroups {
            let recipesUsingIngredient = recipes.filter { recipe in
                recipe.pantryItemsUsed.contains { pantryItem in
                    ingredientVariations.contains { variation in
                        pantryItem.lowercased() == variation.lowercased()
                    }
                }
            }

            let topRecipes = recipesUsingIngredient
                .sorted { a, b in
                    let aHasExpiring = !a.expiringItemsUsed.isEmpty
                    let bHasExpiring = !b.expiringItemsUsed.isEmpty
                    if aHasExpiring != bHasExpiring {
                        return aHasExpiring
                    }
                    return a.pantryItemsUsed.count > b.pantryItemsUsed.count
                }
                .prefix(maxPerIngredient)

            recipesToKeep.formUnion(topRecipes.map { $0.id })
        }

        return recipes.filter { recipesToKeep.contains($0.id) }
    }

    // MARK: - Recalculate expiring items for existing recipes

    /// Dynamically recalculates which pantry items are expiring for each recipe based on current pantry state
    private func recalculateExpiringItems(for recipes: [Recipe], using pantryItems: [PantryItem]) -> [Recipe] {
        // Get currently expiring items (≤3 days)
        let expiringItems = pantryItems.filter { $0.daysUntilExpiration <= 3 && !$0.isExpired }
        let expiringNames = Set(expiringItems.map { ($0.genericName ?? $0.name).lowercased() })

        return recipes.map { recipe in
            // Find which of this recipe's pantry items are currently expiring
            let currentlyExpiring = recipe.pantryItemsUsed.filter { expiringNames.contains($0.lowercased()) }

            // Return updated recipe with recalculated expiring items
            return Recipe(
                id: recipe.id,
                label: recipe.label,
                image: recipe.image,
                sourceUrl: recipe.sourceUrl,
                sourcePublisher: recipe.sourcePublisher,
                yield: recipe.yield,
                totalTime: recipe.totalTime,
                ingredientLines: recipe.ingredientLines,
                cuisineType: recipe.cuisineType,
                mealType: recipe.mealType,
                pantryItemsUsed: recipe.pantryItemsUsed,
                expiringItemsUsed: currentlyExpiring,
                generatedFrom: recipe.generatedFrom,
                createdAt: recipe.createdAt,
                userId: recipe.userId
            )
        }
    }

    // MARK: - Load recipes from Supabase (one-time cache)
    /// Only loads from database on first call; subsequent calls are no-ops unless recipes were generated/pruned.
    func loadRecipes() async {
        // Skip if already initialized (cached)
        if hasInitializedRecipes {
            print("⚡ Recipes already cached, skipping reload")
            return
        }
        print("📥 Loading recipes from Supabase...")
        await MainActor.run { isLoading = true }

        do {
            let fetched = try await supabase.fetchRecipes()
            print("✅ Fetched \(fetched.count) recipes from Supabase")

            // Recalculate expiring items based on current pantry state
            let currentPantryItems = pantryItemsProvider?() ?? []
            let updatedRecipes = recalculateExpiringItems(for: fetched, using: currentPantryItems)
            print("🔄 Recalculated expiring items for \(updatedRecipes.count) recipes")

            // Limit recipes per ingredient (clean up old recipes that violate limits)
            let limitedRecipes = limitRecipesPerIngredient(updatedRecipes, maxPerIngredient: 5)
            print("🎯 After limiting per ingredient: \(limitedRecipes.count) recipes")

            await MainActor.run {
                // Sort recipes: prioritize those with expiring items, then by pantry items used
                recipes = limitedRecipes.sorted { a, b in
                    let aHasExpiring = !a.expiringItemsUsed.isEmpty
                    let bHasExpiring = !b.expiringItemsUsed.isEmpty

                    // Recipes with expiring items always come first
                    if aHasExpiring != bHasExpiring {
                        return aHasExpiring
                    }

                    // Within same category, sort by most pantry items used
                    return a.pantryItemsUsed.count > b.pantryItemsUsed.count
                }
                isLoading = false
                hasInitializedRecipes = true // Mark as cached

                // Rebuild dedup set from existing recipes' generatedFrom field
                if let lastRecipe = recipes.first {
                    lastGeneratedPantryNames = Set(
                        lastRecipe.generatedFrom.map { $0.lowercased() }
                    )
                }
            }
        } catch {
            // Ignore task cancellation noise (URLSession / Swift concurrency cancellation)
            if (error is CancellationError) || ((error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorCancelled) {
                print("ℹ️ Load recipes request was cancelled")
                await MainActor.run { isLoading = false }
                return
            }

            print("❌ Failed to load recipes: \(error)")
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Force-refresh: reload from DB, then regenerate from current pantry items
    func refreshRecipes() async {
        hasInitializedRecipes = false
        lastGeneratedPantryNames = []
        await loadRecipes()

        // Regenerate recipes using current pantry items
        if let items = pantryItemsProvider?() {
            await generateRecipesIfNeeded(pantryItems: items)
        }
    }

    // MARK: - Generate recipes if new ingredient added (dedup logic)
    func generateRecipesIfNeeded(pantryItems: [PantryItem]) async {
        // Require at least 1 item
        guard !pantryItems.isEmpty else {
            print("⚠️ Need at least 1 pantry item to generate recipes")
            return
        }

        // Build ordered, deduplicated list of current generic names (use genericName if available)
        var seen = Set<String>()
        var currentIngredients: [String] = []
        for item in pantryItems {
            let searchTerm = (item.genericName ?? item.name).lowercased()
            if seen.insert(searchTerm).inserted {
                currentIngredients.append(searchTerm)
            }
        }

        let currentSet = Set(currentIngredients)

        // Dedup: if same ingredients, skip API call
        if currentSet == lastGeneratedPantryNames {
            print("⏭️ Skipping recipe API call (same ingredients as last time)")
            return
        }

        print("🆕 New ingredients detected, calling Edamam Recipe API")
        await MainActor.run { isGenerating = true }

        do {
            // Identify expiring items (≤3 days)
            let expiringItems = pantryItems.filter { $0.daysUntilExpiration <= 3 && !$0.isExpired }
            let expiringIngredients = expiringItems.map { ($0.genericName ?? $0.name).lowercased() }
            print("⚠️ Found \(expiringItems.count) expiring items: \(expiringIngredients)")

            // Query Edamam API
            let newRecipes = try await recipeService.searchRecipes(ingredients: currentIngredients, expiringIngredients: expiringIngredients)
            print("🍳 Edamam returned \(newRecipes.count) recipes")

            // Get current user ID
            let userId = await currentUserId

            // Add userId to all recipes
            let recipesWithUserId = newRecipes.map { recipe in
                Recipe(
                    id: recipe.id,
                    label: recipe.label,
                    image: recipe.image,
                    sourceUrl: recipe.sourceUrl,
                    sourcePublisher: recipe.sourcePublisher,
                    yield: recipe.yield,
                    totalTime: recipe.totalTime,
                    ingredientLines: recipe.ingredientLines,
                    cuisineType: recipe.cuisineType,
                    mealType: recipe.mealType,
                    pantryItemsUsed: recipe.pantryItemsUsed,
                    expiringItemsUsed: recipe.expiringItemsUsed,
                    generatedFrom: recipe.generatedFrom,
                    createdAt: recipe.createdAt,
                    userId: userId
                )
            }

            // Save to Supabase, but avoid inserting recipes that already exist
            // Fetch current recipes from DB and filter duplicates by label+sourceUrl
            let existing = try await supabase.fetchRecipes()
            let toInsert = recipesWithUserId.filter { candidate in
                !existing.contains { existing in
                    existing.label == candidate.label && (existing.sourceUrl ?? "") == (candidate.sourceUrl ?? "")
                }
            }

            if !toInsert.isEmpty {
                try await supabase.insertRecipes(toInsert)
                print("💾 Inserted \(toInsert.count) new recipes to Supabase")
            } else {
                print("ℹ️ No new recipes to insert (duplicates filtered)")
            }

            // Refresh authoritative list from Supabase to avoid local duplicates
            let refreshed = try await supabase.fetchRecipes()

            // Recalculate expiring items based on current pantry state
            let updatedRecipes = recalculateExpiringItems(for: refreshed, using: pantryItems)

            // Limit recipes per ingredient
            let limitedRecipes = limitRecipesPerIngredient(updatedRecipes, maxPerIngredient: 5)

            await MainActor.run {
                // Sort recipes: prioritize those with expiring items, then by pantry items used
                recipes = limitedRecipes.sorted { a, b in
                    let aHasExpiring = !a.expiringItemsUsed.isEmpty
                    let bHasExpiring = !b.expiringItemsUsed.isEmpty

                    // Recipes with expiring items always come first
                    if aHasExpiring != bHasExpiring {
                        return aHasExpiring
                    }

                    // Within same category, sort by most pantry items used
                    return a.pantryItemsUsed.count > b.pantryItemsUsed.count
                }
                isGenerating = false

                // Update dedup tracker
                lastGeneratedPantryNames = currentSet
            }
        } catch {
            // Ignore cancellation errors while generating (user may navigate away)
            if (error is CancellationError) || ((error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorCancelled) {
                print("ℹ️ Recipe generation request was cancelled")
                await MainActor.run { isGenerating = false }
                return
            }

            print("❌ Failed to generate recipes: \(error)")
            await MainActor.run {
                errorMessage = "Recipe generation failed: \(error.localizedDescription)"
                isGenerating = false
            }
        }
    }

    // MARK: - Delete recipe (optimistic + Supabase)
    func deleteRecipe(_ recipe: Recipe) {
        // Optimistic delete from local list
        recipes.removeAll { $0.id == recipe.id }

        Task {
            do {
                try await supabase.deleteRecipe(id: recipe.id)
                print("✅ Deleted recipe: \(recipe.label)")
            } catch {
                print("❌ Failed to delete recipe: \(error)")
                // Could add undo logic here if desired
                await MainActor.run {
                    errorMessage = "Failed to delete recipe: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Prune recipes when pantry items change
    /// Removes recipes where any pantryItemsUsed entry is no longer in the pantry, then regenerates.
    func pruneRecipesIfNeeded(remainingPantryItems: [PantryItem]) async {
        let remainingNames = Set(remainingPantryItems.map { ($0.genericName ?? $0.name).lowercased() })

        // Prune recipes where any used ingredient is no longer available
        var recipesToDelete: [Recipe] = []
        for recipe in recipes {
            let usedNames = Set(recipe.pantryItemsUsed.map { $0.lowercased() })
            // If any pantry item this recipe relied on was removed, prune it
            if !usedNames.isSubset(of: remainingNames) {
                recipesToDelete.append(recipe)
            }
        }

        guard !recipesToDelete.isEmpty else {
            return
        }

        // Optimistic local removal + clear dedup so regeneration can happen
        await MainActor.run {
            let idsToDelete = Set(recipesToDelete.map { $0.id })
            recipes.removeAll { idsToDelete.contains($0.id) }
            lastGeneratedPantryNames = []
        }

        // Delete from Supabase
        for recipe in recipesToDelete {
            do {
                try await supabase.deleteRecipe(id: recipe.id)
                print("🗑️ Pruned recipe: \(recipe.label)")
            } catch {
                print("❌ Failed to prune recipe: \(error)")
            }
        }

        // Regenerate recipes with remaining pantry items
        if !remainingPantryItems.isEmpty {
            await generateRecipesIfNeeded(pantryItems: remainingPantryItems)
        }
    }
}
