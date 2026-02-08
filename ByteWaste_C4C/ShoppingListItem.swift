//
//  ShoppingListItem.swift
//  ByteWaste_C4C
//

import Foundation

struct ShoppingListItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var isCompleted: Bool
    let dateAdded: Date
    var sourceRecipeId: String?
    var sourceRecipeName: String?

    // Map Swift camelCase to DB snake_case columns
    enum CodingKeys: String, CodingKey {
        case id, name
        case isCompleted = "is_completed"
        case dateAdded = "date_added"
        case sourceRecipeId = "source_recipe_id"
        case sourceRecipeName = "source_recipe_name"
    }

    init(
        id: UUID = UUID(),
        name: String,
        isCompleted: Bool = false,
        dateAdded: Date = Date(),
        sourceRecipeId: String? = nil,
        sourceRecipeName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.isCompleted = isCompleted
        self.dateAdded = dateAdded
        self.sourceRecipeId = sourceRecipeId
        self.sourceRecipeName = sourceRecipeName
    }
}
