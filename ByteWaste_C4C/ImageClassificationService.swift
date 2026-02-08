//
//  ImageClassificationService.swift
//  ByteWaste_C4C
//
//  Image-based food classification using Vision framework
//

import Foundation
import Vision
import CoreML
import UIKit

public class ImageClassificationService {

    public init() {}

    /// Classify food from an image using Vision framework
    public func classifyFood(from image: UIImage) async throws -> [FoodClassification] {
        guard let ciImage = CIImage(image: image) else {
            throw ClassificationError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            // Create a request handler
            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])

            // Create classification request
            let request = VNClassifyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(throwing: ClassificationError.noResults)
                    return
                }

                // Filter food-related classifications
                let foodClassifications = observations
                    .filter { $0.confidence > 0.1 } // Only keep confident results
                    .prefix(5) // Top 5 results
                    .map { observation in
                        FoodClassification(
                            identifier: observation.identifier,
                            confidence: observation.confidence
                        )
                    }

                if foodClassifications.isEmpty {
                    continuation.resume(throwing: ClassificationError.noFoodDetected)
                } else {
                    continuation.resume(returning: Array(foodClassifications))
                }
            }

            // Perform the request
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Clean up classification identifier to make it more user-friendly
    public func cleanFoodName(_ identifier: String) -> String {
        // Remove technical classification terms and clean up the name
        var cleaned = identifier
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        // Take first part before comma if there are multiple classifications
        if let commaIndex = cleaned.firstIndex(of: ",") {
            cleaned = String(cleaned[..<commaIndex])
        }

        // Capitalize first letter of each word
        cleaned = cleaned.capitalized

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Models

public struct FoodClassification {
    public let identifier: String
    public let confidence: Float

    public var displayName: String {
        // Clean up the identifier for display
        identifier
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    public var confidencePercentage: Int {
        Int(confidence * 100)
    }
}

// MARK: - Errors

public enum ClassificationError: LocalizedError {
    case invalidImage
    case noResults
    case noFoodDetected
    case classificationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Unable to process the image. Please try another photo."
        case .noResults:
            return "No classification results returned."
        case .noFoodDetected:
            return "Could not detect food in the image. Please try a clearer photo of the food item."
        case .classificationFailed(let message):
            return "Classification failed: \(message)"
        }
    }
}
