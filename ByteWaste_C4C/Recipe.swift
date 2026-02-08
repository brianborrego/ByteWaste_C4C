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
    var generatedFrom: [String]
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, label, image, yield
        case sourceUrl = "source_url"
        case sourcePublisher = "source_publisher"
        case totalTime = "total_time"
        case ingredientLines = "ingredient_lines"
        case cuisineType = "cuisine_type"
        case mealType = "meal_type"
        case pantryItemsUsed = "pantry_items_used"
        case generatedFrom = "generated_from"
        case createdAt = "created_at"
    }

    // Custom decoder to handle database nulls
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
        generatedFrom = (try? container.decode([String].self, forKey: .generatedFrom)) ?? []
        createdAt = try? container.decode(Date.self, forKey: .createdAt)
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
        generatedFrom: [String],
        createdAt: Date? = nil
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
        self.generatedFrom = generatedFrom
        self.createdAt = createdAt
    }

    // Helper: convert time in minutes to readable format (e.g., "30m" or "1h 30m")
    var formattedTime: String {
        guard let minutes = totalTime else { return "Unknown" }
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }

    // Helper: recipe snippet for list display
    var subtitle: String {
        var parts: [String] = []
        if let yield = yield {
            parts.append("Serves \(yield)")
        }
        if !ingredientLines.isEmpty {
            parts.append("\(ingredientLines.count) ingredients")
        }
        return parts.joined(separator: " • ")
    }
}
