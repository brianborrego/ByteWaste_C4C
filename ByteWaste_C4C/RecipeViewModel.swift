//
//  RecipeViewModel.swift
//  ByteWaste_C4C
//
//  Recipe state management & API integration
//

import SwiftUI
import Combine

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

            await MainActor.run {
                recipes = fetched
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
            // Query Edamam API
            let newRecipes = try await recipeService.searchRecipes(ingredients: currentIngredients)
            print("🍳 Edamam returned \(newRecipes.count) recipes")

            // Save to Supabase, but avoid inserting recipes that already exist
            // Fetch current recipes from DB and filter duplicates by label+sourceUrl
            let existing = try await supabase.fetchRecipes()
            let toInsert = newRecipes.filter { candidate in
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

            await MainActor.run {
                recipes = refreshed
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
