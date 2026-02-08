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
        try await client
            .from("pantry_items")
            .select()
            .order("current_expiration_date")
            .execute()
            .value
    }

    func insertItem(_ item: PantryItem) async throws {
        try await client
            .from("pantry_items")
            .insert(item)
            .execute()
    }

    func deleteItem(id: UUID) async throws {
        try await client
            .from("pantry_items")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    func updateItem(_ item: PantryItem) async throws {
        try await client
            .from("pantry_items")
            .update(item)
            .eq("id", value: item.id.uuidString)
            .execute()
    }
}
