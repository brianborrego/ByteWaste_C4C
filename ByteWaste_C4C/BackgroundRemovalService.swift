//
//  BackgroundRemovalService.swift
//  ByteWaste_C4C
//
//  Background removal service using Replicate API
//

import Foundation

class BackgroundRemovalService {

    private let apiToken: String

    init() {
        self.apiToken = Config.REPLICATE_API_TOKEN
    }

    /// Remove background from image URL using Replicate API
    /// Returns the URL to the background-removed image
    func removeBackground(from imageURL: String) async throws -> String {
        print("🖼️ Removing background from image: \(imageURL)")

        guard let url = URL(string: "https://api.replicate.com/v1/predictions") else {
            throw BackgroundRemovalError.invalidURL
        }

        // Prepare request body
        let requestBody: [String: Any] = [
            "version": "95fcc2a26d3899cd6c2691c900465aaeff466285a65c14638cc5f36f34befaf1",
            "input": [
                "image": imageURL
            ]
        ]

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("wait", forHTTPHeaderField: "Prefer") // Wait for completion
        request.timeoutInterval = 60 // 60 second timeout
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid HTTP response from Replicate")
            throw BackgroundRemovalError.invalidResponse
        }

        print("✅ Replicate API Status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ Replicate error response: \(errorString)")
            }
            throw BackgroundRemovalError.apiError("API returned status \(httpResponse.statusCode)")
        }

        // Debug: Print raw response
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 Raw Replicate response:")
            print(responseString)
        }

        // Parse response
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let predictionResponse = try decoder.decode(PredictionResponse.self, from: data)

        // Check status
        guard predictionResponse.status == "succeeded" else {
            throw BackgroundRemovalError.processingFailed("Prediction status: \(predictionResponse.status)")
        }

        // Get output URL (it's a string, not an array)
        guard let outputURL = predictionResponse.output, !outputURL.isEmpty else {
            throw BackgroundRemovalError.noOutput
        }

        print("✅ Background removed successfully: \(outputURL)")
        return outputURL
    }

    // MARK: - Response Model
    private struct PredictionResponse: Codable {
        let id: String
        let status: String
        let output: String?  // Output is a string URL, not an array
    }

    // MARK: - Error Types
    enum BackgroundRemovalError: LocalizedError {
        case invalidURL
        case invalidResponse
        case apiError(String)
        case processingFailed(String)
        case noOutput

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid API URL"
            case .invalidResponse:
                return "Invalid response from Replicate API"
            case .apiError(let message):
                return message
            case .processingFailed(let message):
                return "Background removal failed: \(message)"
            case .noOutput:
                return "No output URL in response"
            }
        }
    }
}
