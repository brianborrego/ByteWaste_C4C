#!/usr/bin/env swift

import Foundation

// MARK: - Configuration
struct Config {
    static let EDAMAM_BASE_URL = "https://api.edamam.com"
    static let FOOD_APP_ID = "8ed2ee10"
    static let FOOD_APP_KEY = "d5e2c45aef522057bdd8dd80092eb950"
}

// MARK: - Barcode Type Detection
enum BarcodeType {
    case upc12  // 12 digits
    case ean13  // 13 digits
    case invalid

    static func detect(_ barcode: String) -> BarcodeType {
        let digits = barcode.filter { $0.isNumber }
        switch digits.count {
        case 12:
            return .upc12
        case 13:
            return .ean13
        default:
            return .invalid
        }
    }

    var description: String {
        switch self {
        case .upc12: return "UPC-12"
        case .ean13: return "EAN-13"
        case .invalid: return "Invalid"
        }
    }
}

// MARK: - Barcode Lookup Function
func lookupBarcode(_ barcode: String) {
    let cleanBarcode = barcode.filter { $0.isNumber }
    let barcodeType = BarcodeType.detect(cleanBarcode)

    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🔍 EDAMAM FOOD DATABASE API TESTER")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("📊 Barcode: \(cleanBarcode)")
    print("📋 Type: \(barcodeType.description) (\(cleanBarcode.count) digits)")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

    guard barcodeType != .invalid else {
        print("❌ ERROR: Invalid barcode format")
        print("   Expected: 12 digits (UPC) or 13 digits (EAN)")
        print("   Received: \(cleanBarcode.count) digits")
        exit(1)
    }

    // Build URL - Edamam uses 'upc' parameter for both UPC and EAN
    var components = URLComponents(string: "\(Config.EDAMAM_BASE_URL)/api/food-database/v2/parser")
    components?.queryItems = [
        URLQueryItem(name: "app_id", value: Config.FOOD_APP_ID),
        URLQueryItem(name: "app_key", value: Config.FOOD_APP_KEY),
        URLQueryItem(name: "upc", value: cleanBarcode)
    ]

    guard let url = components?.url else {
        print("❌ ERROR: Failed to construct URL")
        exit(1)
    }

    print("🌐 REQUEST URL:")
    print("   \(url.absoluteString)")
    print("\n⏳ Making API call...\n")

    let semaphore = DispatchSemaphore(value: 0)

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.timeoutInterval = 15

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }

        // Handle network error
        if let error = error {
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("❌ NETWORK ERROR")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("Error: \(error.localizedDescription)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
            return
        }

        // Handle HTTP response
        if let httpResponse = response as? HTTPURLResponse {
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("📡 HTTP RESPONSE")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("Status Code: \(httpResponse.statusCode)")

            let statusEmoji: String
            switch httpResponse.statusCode {
            case 200...299:
                statusEmoji = "✅"
            case 400...499:
                statusEmoji = "⚠️"
            case 500...599:
                statusEmoji = "❌"
            default:
                statusEmoji = "❓"
            }

            print("Status: \(statusEmoji) \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        }

        // Handle response data
        guard let data = data else {
            print("❌ No data received from server\n")
            return
        }

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📦 RAW JSON RESPONSE")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Pretty print JSON
        if let json = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            print(prettyString)
        } else if let rawString = String(data: data, encoding: .utf8) {
            print(rawString)
        } else {
            print("❌ Unable to decode response data")
        }

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

        // Parse and display key information
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            parseAndDisplayResults(json)
        }
    }

    task.resume()
    semaphore.wait()
}

// MARK: - Parse Results
func parseAndDisplayResults(_ json: [String: Any]) {
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("📋 PARSED RESULTS")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    if let text = json["text"] as? String {
        print("🔍 Search Query: \(text)")
    }

    if let hints = json["hints"] as? [[String: Any]] {
        print("📊 Results Found: \(hints.count)")

        if hints.isEmpty {
            print("\n⚠️  NO PRODUCTS FOUND")
            print("   This barcode is not in Edamam's database")
            print("   Possible reasons:")
            print("   • Product is too new/regional")
            print("   • Barcode is incorrect")
            print("   • Product not in their database")
        } else {
            for (index, hint) in hints.enumerated() {
                print("\n── Product #\(index + 1) ────────────────────────────────────────")

                if let food = hint["food"] as? [String: Any] {
                    if let label = food["label"] as? String {
                        print("   Name: \(label)")
                    }
                    if let brand = food["brand"] as? String {
                        print("   Brand: \(brand)")
                    }
                    if let category = food["category"] as? String {
                        print("   Category: \(category)")
                    }
                    if let foodId = food["foodId"] as? String {
                        print("   Food ID: \(foodId)")
                    }
                    if let image = food["image"] as? String {
                        print("   Image URL: \(image)")
                    }
                }
            }
        }
    }

    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
}

// MARK: - Main Execution
func printUsage() {
    print("""
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    📱 USAGE
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    swift food_db_tester.swift <barcode>

    Examples:
      swift food_db_tester.swift 041415001633    (UPC-12)
      swift food_db_tester.swift 0681131911955   (EAN-13)

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    """)
}

// Get barcode from command line arguments
let arguments = CommandLine.arguments

if arguments.count < 2 {
    print("❌ ERROR: No barcode provided\n")
    printUsage()
    exit(1)
}

let barcode = arguments[1]
lookupBarcode(barcode)
