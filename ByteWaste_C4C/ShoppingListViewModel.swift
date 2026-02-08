//
//  ShoppingListViewModel.swift
//  ByteWaste_C4C
//

import SwiftUI
import Combine

class ShoppingListViewModel: ObservableObject {
    @Published var items: [ShoppingListItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingAddSheet = false

    private let supabase = SupabaseService.shared

    // MARK: - Load from Supabase

    func loadItems() async {
        print("🔄 Loading shopping list items from Supabase...")
        await MainActor.run { isLoading = true }

        do {
            let fetched = try await supabase.fetchShoppingListItems()
            print("✅ Successfully fetched \(fetched.count) shopping list items")
            await MainActor.run {
                items = fetched
                isLoading = false
            }
        } catch {
            print("❌ Failed to load shopping list items: \(error)")
            await MainActor.run {
                errorMessage = "Failed to load items: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    // MARK: - Add Item

    func addItem(name: String, sourceRecipeId: String? = nil, sourceRecipeName: String? = nil) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            // Fetch image URL from Edamam
            let imageURL = await FoodImageService.shared.fetchFoodImageURL(for: trimmedName)

            let newItem = ShoppingListItem(
                name: trimmedName,
                sourceRecipeId: sourceRecipeId,
                sourceRecipeName: sourceRecipeName,
                imageURL: imageURL
            )

            // Add to UI
            await MainActor.run {
                items.insert(newItem, at: 0)
            }

            // Insert to database
            do {
                try await supabase.insertShoppingListItem(newItem)
            } catch {
                await MainActor.run {
                    // Remove from local array on failure
                    items.removeAll { $0.id == newItem.id }
                    errorMessage = "Failed to add item: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Toggle Completion

    func toggleCompletion(for item: ShoppingListItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }

        // Optimistic update
        items[index].isCompleted.toggle()
        let updatedItem = items[index]

        Task {
            do {
                try await supabase.updateShoppingListItem(updatedItem)
            } catch {
                await MainActor.run {
                    // Revert on failure
                    if let revertIndex = items.firstIndex(where: { $0.id == item.id }) {
                        items[revertIndex].isCompleted.toggle()
                    }
                    errorMessage = "Failed to update item: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Delete Item

    func deleteItem(_ item: ShoppingListItem) {
        // Optimistic update
        items.removeAll { $0.id == item.id }

        Task {
            do {
                try await supabase.deleteShoppingListItem(id: item.id)
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete item: \(error.localizedDescription)"
                    // Re-add on failure
                    items.insert(item, at: 0)
                }
            }
        }
    }

    func deleteItems(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { items[$0] }
        items.remove(atOffsets: offsets)

        Task {
            for item in itemsToDelete {
                do {
                    try await supabase.deleteShoppingListItem(id: item.id)
                } catch {
                    await MainActor.run {
                        errorMessage = "Failed to delete item: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    // MARK: - Clear Completed

    func clearCompleted() {
        let completedItems = items.filter { $0.isCompleted }

        // Optimistic update
        items.removeAll { $0.isCompleted }

        Task {
            for item in completedItems {
                do {
                    try await supabase.deleteShoppingListItem(id: item.id)
                } catch {
                    print("❌ Failed to delete completed item: \(error)")
                }
            }
        }
    }

    // MARK: - Computed Properties

    var completedItems: [ShoppingListItem] {
        items.filter { $0.isCompleted }
    }

    var activeItems: [ShoppingListItem] {
        items.filter { !$0.isCompleted }
    }

    var hasCompletedItems: Bool {
        items.contains { $0.isCompleted }
    }
}
