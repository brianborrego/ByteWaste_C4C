//
//  SupabaseService.swift
//  ByteWaste_C4C
//

import Foundation
import Supabase

class SupabaseService {
    static let shared = SupabaseService()

    // Expose client for AuthViewModel to access auth methods
    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: SupabaseConfig.url)!,
            supabaseKey: SupabaseConfig.anonKey
        )
    }

    // Synchronous user ID for keying local data per account
    var currentUserId: String? {
        client.auth.currentSession?.user.id.uuidString
    }

    // MARK: - Pantry Items CRUD

    func fetchItems() async throws -> [PantryItem] {
        print("📡 Fetching items from Supabase table: pantry_items")
        let result: [PantryItem] = try await client
            .from("pantry_items")
            .select()
            .order("current_expiration_date")
            .execute()
            .value
        print("📦 Fetched \(result.count) items from database")
        return result
    }

    func fetchItemByBarcode(_ barcode: String) async throws -> PantryItem? {
        print("🔍 Searching for barcode \(barcode) in Supabase")
        let result: [PantryItem] = try await client
            .from("pantry_items")
            .select()
            .eq("barcode", value: barcode)
            .limit(1)
            .execute()
            .value

        if let item = result.first {
            print("✅ Found item with barcode: \(item.name)")
            return item
        } else {
            print("❌ No item found with barcode: \(barcode)")
            return nil
        }
    }

    func insertItem(_ item: PantryItem) async throws {
        print("➕ Inserting item to Supabase: \(item.name)")
        try await client
            .from("pantry_items")
            .insert(item)
            .execute()
        print("✅ Successfully inserted item: \(item.name)")
    }

    func deleteItem(id: UUID) async throws {
        print("🗑️ Deleting item from Supabase: \(id)")
        try await client
            .from("pantry_items")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
        print("✅ Successfully deleted item: \(id)")
    }

    func updateItem(_ item: PantryItem) async throws {
        print("🔄 Updating item in Supabase: \(item.name)")
        try await client
            .from("pantry_items")
            .update(item)
            .eq("id", value: item.id.uuidString)
            .execute()
        print("✅ Successfully updated item: \(item.name)")
    }

    // MARK: - Recipes CRUD

    func fetchRecipes() async throws -> [Recipe] {
        print("📡 Fetching recipes from Supabase table: recipes")
        let result: [Recipe] = try await client
            .from("recipes")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        print("📦 Fetched \(result.count) recipes from database")
        return result
    }

    func insertRecipes(_ recipes: [Recipe]) async throws {
        print("➕ Inserting \(recipes.count) recipes to Supabase")
        try await client
            .from("recipes")
            .insert(recipes)
            .execute()
        print("✅ Successfully inserted \(recipes.count) recipes")
    }

    func deleteRecipe(id: UUID) async throws {
        print("🗑️ Deleting recipe from Supabase: \(id)")
        try await client
            .from("recipes")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
        print("✅ Successfully deleted recipe: \(id)")
    }

    func deleteAllRecipes() async throws {
        print("🗑️ Deleting all recipes from Supabase")
        try await client
            .from("recipes")
            .delete()
            .neq("id", value: "00000000-0000-0000-0000-000000000000")
            .execute()
        print("✅ Successfully deleted all recipes")
    }

    // MARK: - Shopping List CRUD

    func fetchShoppingListItems() async throws -> [ShoppingListItem] {
        print("🛒 Fetching shopping list items from Supabase")
        let result: [ShoppingListItem] = try await client
            .from("shopping_list_items")
            .select()
            .order("date_added", ascending: false)
            .execute()
            .value
        print("✅ Fetched \(result.count) shopping list items")
        return result
    }

    func insertShoppingListItem(_ item: ShoppingListItem) async throws {
        print("➕ Inserting shopping list item: \(item.name)")
        try await client
            .from("shopping_list_items")
            .insert(item)
            .execute()
        print("✅ Successfully inserted shopping list item: \(item.name)")
    }

    func updateShoppingListItem(_ item: ShoppingListItem) async throws {
        print("🔄 Updating shopping list item: \(item.name)")
        try await client
            .from("shopping_list_items")
            .update(item)
            .eq("id", value: item.id.uuidString)
            .execute()
        print("✅ Successfully updated shopping list item: \(item.name)")
    }

    func deleteShoppingListItem(id: UUID) async throws {
        print("🗑️ Deleting shopping list item: \(id)")
        try await client
            .from("shopping_list_items")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
        print("✅ Successfully deleted shopping list item: \(id)")
    }
}
