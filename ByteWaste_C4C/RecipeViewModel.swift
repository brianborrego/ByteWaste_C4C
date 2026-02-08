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

    private let recipeService = RecipeService()
    private let supabase = SupabaseService.shared

    // MARK: - Load recipes from Supabase on view appear
    func loadRecipes() async {
        print("📥 Loading recipes from Supabase...")
        await MainActor.run { isLoading = true }

        do {
            let fetched = try await supabase.fetchRecipes()
            print("✅ Fetched \(fetched.count) recipes from Supabase")

            await MainActor.run {
                recipes = fetched
                isLoading = false

                // Rebuild dedup set from existing recipes' generatedFrom field
                if let lastRecipe = recipes.first {
                    lastGeneratedPantryNames = Set(
                        lastRecipe.generatedFrom.map { $0.lowercased() }
                    )
                }
            }
        } catch {
            print("❌ Failed to load recipes: \(error)")
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Generate recipes if new ingredient added (dedup logic)
    func generateRecipesIfNeeded(pantryItems: [PantryItem]) async {
        // Require at least 2 items
        guard pantryItems.count >= 2 else {
            print("⚠️ Need at least 2 pantry items to generate recipes (current: \(pantryItems.count))")
            return
        }

        // Build set of current generic names (use genericName if available, fall back to name)
        var currentIngredients: [String] = []
        for item in pantryItems {
            let searchTerm = item.genericName ?? item.name
            currentIngredients.append(searchTerm.lowercased())
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

            // Save to Supabase
            try await supabase.insertRecipes(newRecipes)
            print("💾 Saved \(newRecipes.count) recipes to Supabase")

            // Update UI: prepend new recipes to list (newest at top)
            await MainActor.run {
                recipes = newRecipes + recipes
                isGenerating = false

                // Update dedup tracker
                lastGeneratedPantryNames = currentSet
            }
        } catch {
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
}
