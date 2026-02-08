//
//  Recipe.swift
//  ByteWaste_C4C
//

import Foundation

struct Recipe: Identifiable, Codable {
    let id: UUID
    var label: String
    var image: String?
    var sourceUrl: String?
    var sourcePublisher: String?
    var yield: Int?
    var totalTime: Int?
    var ingredientLines: [String]
    var cuisineType: [String]?
    var mealType: [String]?
    var pantryItemsUsed: [String]
    var expiringItemsUsed: [String]
    var generatedFrom: [String]
    var createdAt: Date?
    var userId: UUID?

    enum CodingKeys: String, CodingKey {
        case id, label, image, yield
        case sourceUrl = "source_url"
        case sourcePublisher = "source_publisher"
        case totalTime = "total_time"
        case ingredientLines = "ingredient_lines"
        case cuisineType = "cuisine_type"
        case mealType = "meal_type"
        case pantryItemsUsed = "pantry_items_used"
        case expiringItemsUsed = "expiring_items_used"
        case generatedFrom = "generated_from"
        case createdAt = "created_at"
        case userId = "user_id"
    }

    // Custom decoder to handle database NULLs for non-optional arrays
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)
        image = try? container.decode(String.self, forKey: .image)
        sourceUrl = try? container.decode(String.self, forKey: .sourceUrl)
        sourcePublisher = try? container.decode(String.self, forKey: .sourcePublisher)
        yield = try? container.decode(Int.self, forKey: .yield)
        totalTime = try? container.decode(Int.self, forKey: .totalTime)
        ingredientLines = (try? container.decode([String].self, forKey: .ingredientLines)) ?? []
        cuisineType = try? container.decode([String].self, forKey: .cuisineType)
        mealType = try? container.decode([String].self, forKey: .mealType)
        pantryItemsUsed = (try? container.decode([String].self, forKey: .pantryItemsUsed)) ?? []
        expiringItemsUsed = (try? container.decode([String].self, forKey: .expiringItemsUsed)) ?? []
        generatedFrom = (try? container.decode([String].self, forKey: .generatedFrom)) ?? []
        createdAt = try? container.decode(Date.self, forKey: .createdAt)
        userId = try? container.decode(UUID.self, forKey: .userId)
    }

    init(
        id: UUID = UUID(),
        label: String,
        image: String? = nil,
        sourceUrl: String? = nil,
        sourcePublisher: String? = nil,
        yield: Int? = nil,
        totalTime: Int? = nil,
        ingredientLines: [String],
        cuisineType: [String]? = nil,
        mealType: [String]? = nil,
        pantryItemsUsed: [String],
        expiringItemsUsed: [String] = [],
        generatedFrom: [String],
        createdAt: Date? = nil,
        userId: UUID? = nil
    ) {
        self.id = id
        self.label = label
        self.image = image
        self.sourceUrl = sourceUrl
        self.sourcePublisher = sourcePublisher
        self.yield = yield
        self.totalTime = totalTime
        self.ingredientLines = ingredientLines
        self.cuisineType = cuisineType
        self.mealType = mealType
        self.pantryItemsUsed = pantryItemsUsed
        self.expiringItemsUsed = expiringItemsUsed
        self.generatedFrom = generatedFrom
        self.createdAt = createdAt
        self.userId = userId
    }

    // Computed properties for UI and filtering
    var totalIngredients: Int {
        ingredientLines.count
    }

    var missingCount: Int {
        max(0, totalIngredients - pantryItemsUsed.count)
    }

    var subtitle: String {
        var parts: [String] = []
        parts.append("\(totalIngredients) ingredients")
        if let t = totalTime, t > 0 {
            parts.append("\(t)m")
        }
        return parts.joined(separator: " · ")
    }
}
