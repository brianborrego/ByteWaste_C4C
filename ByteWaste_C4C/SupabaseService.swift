//
//  SupabaseService.swift
//  ByteWaste_C4C
//

import Foundation
import Supabase

class SupabaseService {
    static let shared = SupabaseService()

    private let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: SupabaseConfig.url)!,
            supabaseKey: SupabaseConfig.anonKey
        )
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
}
