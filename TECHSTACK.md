# FreshTrack - Technical Stack & Implementation Guide

---

## Technology Stack

### iOS Application

**Framework:** SwiftUI  
**Minimum iOS Version:** iOS 16.0+  
**Language:** Swift 5.9+  
**Key iOS Frameworks:**
- **VisionKit:** For on-device text recognition (receipt scanning)
- **Vision:** For image analysis
- **UserNotifications:** For expiration alerts

**Why VisionKit?**
- ✅ **Free:** No API costs for OCR
- ✅ **Fast:** On-device processing, instant results
- ✅ **Private:** Receipt data never leaves the device during OCR
- ✅ **Accurate:** Apple's ML models trained on real-world text
- ✅ **Easy:** DataScannerViewController provides ready-to-use camera UI
- ✅ **Offline:** Works without internet connection

**Why SwiftUI?**
- Faster development for 24-hour timeline
- Modern declarative syntax
- Built-in animations and transitions
- Better for rapid prototyping

---

## Backend & Services

### Backend-as-a-Service: **Supabase** (Recommended)

**Why Supabase?**
- Free tier with generous limits
- Real-time database (PostgreSQL)
- Built-in authentication
- Storage for receipt images
- Easy iOS SDK integration
- RESTful API + real-time subscriptions

**Alternative:** Firebase (similar features, larger ecosystem)

### Database Schema

```
users
- id (uuid, primary key)
- created_at (timestamp)
- notification_settings (jsonb)

pantry_items
- id (uuid, primary key)
- user_id (uuid, foreign key)
- name (text)
- category (text)
- quantity (decimal)
- unit (text)
- purchase_date (date)
- expiration_date (date)
- image_url (text, optional)
- is_consumed (boolean)
- consumed_at (timestamp, nullable)
- created_at (timestamp)

recipes_cooked
- id (uuid, primary key)
- user_id (uuid, foreign key)
- recipe_name (text)
- ingredients_used (jsonb)
- cooked_at (timestamp)

environmental_stats
- id (uuid, primary key)
- user_id (uuid, foreign key)
- food_saved_lbs (decimal)
- co2_saved_lbs (decimal)
- money_saved (decimal)
- current_streak (integer)
- longest_streak (integer)
- badges_earned (jsonb)

receipts
- id (uuid, primary key)
- user_id (uuid, foreign key)
- image_url (text)
- processed_at (timestamp)
- extracted_data (jsonb)
```

---

## Receipt Processing Architecture

### The Two-Step Approach: VisionKit → AI Parser

**Step 1: Text Recognition (VisionKit)**
- Use Apple's VisionKit framework to extract raw text from receipt
- Fast, free, on-device processing
- No API calls, works offline
- Returns unstructured text

**Step 2: Intelligent Parsing (AI API)**
- Send extracted text to Claude/GPT-4
- AI understands receipt structure and extracts structured data
- Returns JSON with items, quantities, prices, categories
- Handles various receipt formats intelligently

### Why This Hybrid Approach?

| Approach | VisionKit Only | Third-Party OCR API | VisionKit + AI (Recommended) |
|----------|----------------|---------------------|------------------------------|
| **Cost** | Free | $0.01-0.05/receipt | ~$0.01/receipt |
| **Speed** | Very Fast (1-2s) | Medium (3-5s) | Fast (2-3s total) |
| **Privacy** | Excellent | Poor (data uploaded) | Good (only text uploaded) |
| **Parsing Quality** | Manual logic needed | Built-in | Excellent (AI understands context) |
| **Offline** | ✅ Yes (partial) | ❌ No | ⚠️ Text extraction yes, parsing no |
| **Setup Time** | Quick | Medium | Quick |

### Implementation Details

#### VisionKit Setup (iOS 16+)

```swift
import VisionKit

// Check if device supports text recognition
guard DataScannerViewController.isSupported,
      DataScannerViewController.isAvailable else {
    // Fallback to manual entry
    return
}

// Configure scanner for text recognition
let scanner = DataScannerViewController(
    recognizedDataTypes: [.text()],
    qualityLevel: .balanced,
    recognizesMultipleItems: true,
    isHighFrameRateTrackingEnabled: false,
    isHighlightingEnabled: true
)

scanner.delegate = self

// Present scanner
present(scanner, animated: true) {
    try? scanner.startScanning()
}
```

#### Text Extraction

```swift
func dataScanner(_ dataScanner: DataScannerViewController, 
                 didAdd addedItems: [RecognizedItem], 
                 allItems: [RecognizedItem]) {
    
    // Extract all recognized text
    let extractedText = allItems.compactMap { item -> String? in
        switch item {
        case .text(let text):
            return text.transcript
        default:
            return nil
        }
    }.joined(separator: "\n")
    
    // Send to AI for parsing
    parseReceiptWithAI(extractedText)
}
```

#### AI Parsing Prompt

```swift
let prompt = """
You are a receipt parser. Extract grocery items from this receipt text.

Receipt text:
\(extractedText)

Return ONLY valid JSON in this exact format:
{
  "items": [
    {
      "name": "Organic Bananas",
      "quantity": 2.5,
      "unit": "lb",
      "price": 3.47,
      "category": "produce"
    }
  ],
  "store": "Whole Foods",
  "date": "2026-02-06",
  "total": 45.32
}

Rules:
- Only include food/grocery items (skip household, pharmacy, etc.)
- Standardize item names (e.g., "ORG BANANA" → "Organic Bananas")
- Infer category: produce, dairy, meat, bakery, pantry, frozen, beverages
- If quantity unclear, use 1 as default
- Use common units: lb, oz, count, gallon, etc.
"""
```

### AI Service for Receipt Parsing: **Anthropic Claude API**

**Recommended Model:** Claude 3.5 Sonnet  
**Why Claude over GPT-4?**
- Faster response times (1-2s vs 3-5s)
- Better at following structured output instructions
- More cost-effective ($0.003 vs $0.01 per request)
- Excellent at understanding messy/ambiguous text

**Alternative:** OpenAI GPT-4o-mini (cheaper but slightly less accurate)

### Receipt Parsing Service Implementation

```swift
import Foundation

class ReceiptParsingService {
    private let apiKey = "your_claude_api_key"
    
    struct ParsedReceipt: Codable {
        let items: [ReceiptItem]
        let store: String?
        let date: String?
        let total: Double?
    }
    
    struct ReceiptItem: Codable {
        let name: String
        let quantity: Double
        let unit: String
        let price: Double?
        let category: String
    }
    
    func parseReceipt(_ rawText: String) async throws -> ParsedReceipt {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let body: [String: Any] = [
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 2000,
            "messages": [
                [
                    "role": "user",
                    "content": buildPrompt(rawText)
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        
        // Extract JSON from response
        guard let textContent = response.content.first?.text else {
            throw ReceiptParsingError.noContent
        }
        
        // Parse the JSON response
        let jsonData = textContent.data(using: .utf8)!
        return try JSONDecoder().decode(ParsedReceipt.self, from: jsonData)
    }
    
    private func buildPrompt(_ text: String) -> String {
        // Use the prompt template from above
    }
}

struct ClaudeResponse: Codable {
    let content: [Content]
    
    struct Content: Codable {
        let text: String?
    }
}
```

### Grocery Photo Recognition: **Claude/GPT-4 Vision API**

**Use Case:** Grocery photo recognition  
**Cost:** ~$0.01 per image  
**Implementation:**
```
"Identify all grocery items in this image and return as JSON: 
[{name, category, estimated_quantity}]"
```

**Alternative:** Google Cloud Vision API + custom classification

### Recipe Generation: **Anthropic Claude API** or **OpenAI GPT-4**

**Recommended:** Claude 3.5 Sonnet (faster, cost-effective)  
**Use Case:** Generate recipes from ingredient list  
**Cost:** ~$0.003 per recipe generation

**Prompt Template:**
```
Create a recipe using these ingredients that will expire soon: [list].
Prioritize: [expiring items]. Format as JSON with: name, 
prep_time, cook_time, servings, ingredients, instructions, 
difficulty_level.
```

### Recipe Database: **Spoonacular API**

**Free Tier:** 150 requests/day  
**Features:**
- Search by ingredients
- Recipe details and instructions
- Nutrition information
- Ingredient matching

**Alternative:** Edamam Recipe API

---

## Push Notifications

**Service:** Apple Push Notification Service (APNs)  
**Implementation:** Native iOS UserNotifications framework  
**Scheduling:** Local notifications (no server required for MVP)

---

## Key iOS Libraries & Dependencies

```swift
// Package.swift dependencies

dependencies: [
    // Supabase iOS client
    .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0"),
    
    // Image caching and processing
    .package(url: "https://github.com/onevcat/Kingfisher", from: "7.0.0"),
    
    // Date handling
    .package(url: "https://github.com/malcommac/SwiftDate", from: "7.0.0"),
]

// Native iOS Frameworks (no SPM needed)
import VisionKit          // Receipt text scanning
import Vision             // Image analysis
import UserNotifications  // Push notifications
import SwiftUI            // UI framework
```

**Note:** VisionKit is built into iOS 16+, no external dependencies needed!

---

## Project Structure

```
FreshTrack/
├── App/
│   ├── FreshTrackApp.swift          # App entry point
│   └── AppDelegate.swift            # Push notification setup
├── Models/
│   ├── PantryItem.swift             # Core data model
│   ├── Recipe.swift
│   ├── EnvironmentalStats.swift
│   └── Badge.swift
├── ViewModels/
│   ├── PantryViewModel.swift        # Pantry state management
│   ├── ReceiptScanViewModel.swift   # OCR processing
│   ├── RecipeViewModel.swift        # Recipe generation
│   └── ImpactViewModel.swift        # Environmental tracking
├── Views/
│   ├── Onboarding/
│   │   └── OnboardingView.swift
│   ├── Pantry/
│   │   ├── PantryListView.swift
│   │   ├── PantryItemRow.swift
│   │   └── AddItemView.swift
│   ├── Scanner/
│   │   ├── ReceiptScannerView.swift
│   │   ├── GroceryPhotoView.swift
│   │   └── ReviewItemsView.swift
│   ├── Recipes/
│   │   ├── RecipeGeneratorView.swift
│   │   ├── RecipeDetailView.swift
│   │   └── RecipeListView.swift
│   ├── Impact/
│   │   ├── ImpactDashboardView.swift
│   │   ├── BadgesView.swift
│   │   └── StatsCardView.swift
│   └── Settings/
│       └── SettingsView.swift
├── Services/
│   ├── SupabaseService.swift        # Database operations
│   ├── VisionKitService.swift        # VisionKit text recognition
│   ├── ReceiptParsingService.swift   # AI-powered receipt parsing
│   ├── ImageRecognitionService.swift # Grocery photos (Vision API)
│   ├── RecipeService.swift           # AI + database recipes
│   ├── NotificationService.swift     # Push notifications
│   └── ExpirationService.swift       # Date calculations
├── Utilities/
│   ├── Extensions/
│   │   ├── Date+Extensions.swift
│   │   └── Color+Extensions.swift
│   ├── Constants.swift
│   └── Helpers.swift
├── Resources/
│   ├── Assets.xcassets              # Images, colors
│   └── FoodExpirationData.json      # Common food shelf lives
└── Tests/
    └── FreshTrackTests/
```

---

---

## Complete Receipt Scanning Workflow

### Architecture Overview

```
User Scans Receipt
       ↓
VisionKit (on-device)
  - Extracts raw text
  - Returns in 1-2 seconds
  - Works offline
       ↓
Raw Receipt Text
  "WHOLE FOODS MARKET
   ORG BANANA 2.5 lb $3.47
   MILK ORGANIC GAL $5.99
   CHICKEN BREAST 1.2 lb $8.99
   TOTAL: $18.45"
       ↓
Claude API (cloud)
  - Understands structure
  - Parses line items
  - Categorizes foods
  - Returns JSON
       ↓
Structured Data
  [{name: "Organic Bananas", quantity: 2.5, unit: "lb", category: "produce", price: 3.47},
   {name: "Organic Milk", quantity: 1, unit: "gallon", category: "dairy", price: 5.99},
   {name: "Chicken Breast", quantity: 1.2, unit: "lb", category: "meat", price: 8.99}]
       ↓
Review UI
  - User confirms/edits
  - Adjusts expiration dates
  - Removes non-food items
       ↓
Save to Supabase
  - Store in pantry_items table
  - Calculate expiration dates
  - Update environmental stats
```

### Step-by-Step Implementation

#### 1. VisionKit Service

```swift
import VisionKit
import SwiftUI

@MainActor
class VisionKitService: NSObject, ObservableObject {
    @Published var recognizedText: String = ""
    @Published var isScanning = false
    
    func startScanning() -> DataScannerViewController? {
        // Check device capability
        guard DataScannerViewController.isSupported,
              DataScannerViewController.isAvailable else {
            return nil
        }
        
        // Configure scanner
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        
        scanner.delegate = self
        isScanning = true
        
        return scanner
    }
}

extension VisionKitService: DataScannerViewControllerDelegate {
    func dataScanner(_ dataScanner: DataScannerViewController,
                     didTapOn item: RecognizedItem) {
        // Handle tapped text (optional)
    }
    
    func dataScanner(_ dataScanner: DataScannerViewController,
                     didAdd addedItems: [RecognizedItem],
                     allItems: [RecognizedItem]) {
        // Extract all text
        let texts = allItems.compactMap { item -> String? in
            guard case .text(let text) = item else { return nil }
            return text.transcript
        }
        
        // Combine into single string
        recognizedText = texts.joined(separator: "\n")
    }
}
```

#### 2. Receipt Parser with Claude

```swift
import Foundation

struct ReceiptParsingService {
    
    struct ParsedReceipt: Codable {
        let items: [ParsedItem]
        let store: String?
        let purchaseDate: String?
        let total: Double?
    }
    
    struct ParsedItem: Codable {
        let name: String
        let quantity: Double
        let unit: String
        let price: Double?
        let category: FoodCategory
    }
    
    enum FoodCategory: String, Codable {
        case produce, dairy, meat, bakery, pantry, frozen, beverages
    }
    
    func parseReceiptText(_ rawText: String) async throws -> ParsedReceipt {
        let prompt = """
        You are a receipt parser. Extract grocery items from this receipt text.
        
        Receipt text:
        \(rawText)
        
        Return ONLY valid JSON (no markdown, no explanation):
        {
          "items": [
            {
              "name": "Organic Bananas",
              "quantity": 2.5,
              "unit": "lb",
              "price": 3.47,
              "category": "produce"
            }
          ],
          "store": "Whole Foods",
          "purchaseDate": "2026-02-06",
          "total": 18.45
        }
        
        Rules:
        - Only food/grocery items (skip cleaning supplies, toiletries)
        - Standardize names: "ORG BANANA" → "Organic Bananas"
        - Categories: produce, dairy, meat, bakery, pantry, frozen, beverages
        - Default quantity to 1 if unclear
        - Common units: lb, oz, kg, g, count, gallon, liter, each
        - If item has no clear quantity (like "EGGS"), use 1 count
        """
        
        // Call Claude API
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.claudeAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let body: [String: Any] = [
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 2048,
            "messages": [[
                "role": "user",
                "content": prompt
            ]]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ParsingError.apiError
        }
        
        // Parse Claude response
        let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        
        guard let content = claudeResponse.content.first?.text else {
            throw ParsingError.noContent
        }
        
        // Extract JSON from response
        let jsonData = content.data(using: .utf8)!
        let parsed = try JSONDecoder().decode(ParsedReceipt.self, from: jsonData)
        
        return parsed
    }
    
    private struct ClaudeResponse: Codable {
        let content: [Content]
        struct Content: Codable {
            let text: String?
            let type: String
        }
    }
    
    enum ParsingError: Error {
        case apiError
        case noContent
        case invalidJSON
    }
}
```

#### 3. Receipt Scanner View (SwiftUI)

```swift
import SwiftUI
import VisionKit

struct ReceiptScannerView: View {
    @StateObject private var visionService = VisionKitService()
    @State private var showScanner = false
    @State private var scannerVC: DataScannerViewController?
    @State private var isParsing = false
    @State private var parsedItems: [ParsedItem] = []
    @State private var showReviewSheet = false
    
    private let parsingService = ReceiptParsingService()
    
    var body: some View {
        VStack {
            if parsedItems.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    
                    Text("Scan Your Receipt")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Point your camera at a grocery receipt to automatically add items to your pantry")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    Button(action: startScanning) {
                        Label("Start Scanning", systemImage: "camera")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .sheet(isPresented: $showScanner) {
            if let scanner = scannerVC {
                ScannerViewControllerRepresentable(scanner: scanner, onComplete: handleScanComplete)
            }
        }
        .sheet(isPresented: $showReviewSheet) {
            ReviewItemsView(items: parsedItems)
        }
        .overlay {
            if isParsing {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Parsing receipt...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private func startScanning() {
        guard let scanner = visionService.startScanning() else {
            // Handle unsupported device
            return
        }
        scannerVC = scanner
        showScanner = true
        
        // Auto-dismiss after 3 seconds of capturing
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if showScanner {
                handleScanComplete()
            }
        }
    }
    
    private func handleScanComplete() {
        showScanner = false
        scannerVC?.stopScanning()
        
        let extractedText = visionService.recognizedText
        guard !extractedText.isEmpty else { return }
        
        // Parse with AI
        Task {
            isParsing = true
            
            do {
                let parsed = try await parsingService.parseReceiptText(extractedText)
                parsedItems = parsed.items
                showReviewSheet = true
            } catch {
                // Handle error
                print("Parsing failed: \(error)")
            }
            
            isParsing = false
        }
    }
}

// UIViewControllerRepresentable wrapper
struct ScannerViewControllerRepresentable: UIViewControllerRepresentable {
    let scanner: DataScannerViewController
    let onComplete: () -> Void
    
    func makeUIViewController(context: Context) -> DataScannerViewController {
        try? scanner.startScanning()
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}
}
```

### Handling Edge Cases

**What if VisionKit extracts poor text?**
- Show user the raw extracted text
- Allow manual correction before AI parsing
- Or skip AI and go straight to manual entry

**What if AI parsing fails?**
```swift
do {
    let parsed = try await parsingService.parseReceiptText(extractedText)
    parsedItems = parsed.items
} catch {
    // Fallback: show raw text and let user manually enter items
    showManualEntryWithSuggestedText(extractedText)
}
```

**What if user's device doesn't support VisionKit?**
```swift
if !DataScannerViewController.isSupported {
    // Fallback: manual item entry only
    showManualEntryView()
} else if !DataScannerViewController.isAvailable {
    // Camera permissions not granted
    requestCameraPermission()
}
```

### Why This Approach Wins

✅ **Free OCR:** No API costs for text extraction  
✅ **Fast:** VisionKit processes in real-time  
✅ **Private:** Receipt image never uploaded  
✅ **Smart:** AI understands messy receipt formats  
✅ **Reliable:** On-device processing can't fail due to network  
✅ **Offline-friendly:** Can extract text offline, queue AI parsing  

---

## Implementation Roadmap (24-Hour Sprint)

### Phase 1: Foundation (Hours 0-4)

**Setup & Infrastructure**
- [ ] Create Xcode project with SwiftUI
- [ ] Setup Supabase project and database schema
- [ ] Configure API keys (Claude API, Spoonacular)
- [ ] Implement basic navigation structure (TabView)
- [ ] Create data models (PantryItem, Recipe, etc.)
- [ ] Setup Supabase Swift client

**Core UI Components**
- [ ] Design color scheme and theming
- [ ] Create reusable components (buttons, cards, lists)
- [ ] Build main tab bar navigation
- [ ] Simple one-screen onboarding

---

### Phase 2: Pantry Management (Hours 4-8)

**Pantry Views**
- [ ] Build PantryListView with sorting by expiration
- [ ] Create PantryItemRow with color-coded expiration
- [ ] Implement swipe actions (delete, mark used)
- [ ] Build AddItemView for manual entry
- [ ] Add category filtering

**Data Layer**
- [ ] Implement SupabaseService CRUD operations
- [ ] Create PantryViewModel with @Published properties
- [ ] Handle item creation, update, deletion

**Expiration Logic**
- [ ] Create simple food shelf-life dictionary in code
- [ ] Calculate expiration dates based on category
- [ ] Color-code items: green (>7 days), yellow (3-7 days), red (<3 days)
- [ ] Sort items by expiration urgency

---

### Phase 3: VisionKit Receipt Scanning (Hours 8-12)

**VisionKit Integration**
- [ ] Add VisionKit and Vision framework imports
- [ ] Create VisionKitService wrapper
- [ ] Build ReceiptScannerView with DataScannerViewController
- [ ] Handle text recognition callbacks
- [ ] Extract all text from receipt into single string

**AI Receipt Parsing**
- [ ] Setup Claude API credentials
- [ ] Create ReceiptParsingService
- [ ] Build receipt parsing prompt
- [ ] Parse API response into PantryItem objects
- [ ] Handle errors gracefully (show raw text if parsing fails)

**Review & Confirmation**
- [ ] Build ReviewItemsView to display extracted items
- [ ] Allow editing of item details (name, quantity, expiration)
- [ ] Enable batch add to pantry
- [ ] Show loading state during AI processing

---

### Phase 4: Recipe Generation (Hours 12-16)

**Recipe Service**
- [ ] Implement RecipeService with Claude API
- [ ] Build prompt template for recipe generation
- [ ] Parse structured recipe response
- [ ] Integrate Spoonacular as fallback/supplement

**Recipe Views**
- [ ] Build RecipeGeneratorView with "What can I cook?" button
- [ ] Show loading animation during generation
- [ ] Display RecipeDetailView with ingredients and steps
- [ ] Highlight pantry items available vs. needed
- [ ] Add "Mark ingredients as used" button

**Recipe Logic**
- [ ] Filter pantry items expiring in next 3-5 days
- [ ] Prioritize items closest to expiration in prompt
- [ ] Save cooked recipes to database
- [ ] Update pantry when ingredients marked as used

---

### Phase 5: Environmental Impact & Badges (Hours 16-19)

**Impact Calculations**
- [ ] Calculate food saved: sum weight of items consumed before expiration
- [ ] Convert to CO2 saved (1 lb food = 3.3 lbs CO2)
- [ ] Calculate money saved (avg $1.50/lb)
- [ ] Track streak (consecutive days without expired items)

**Badge System**
- [ ] Define 4-5 badge criteria in code
- [ ] Create Badge model with unlock logic
- [ ] Design badge icons using SF Symbols
- [ ] Implement badge unlocking on milestones
- [ ] Show badge unlock animation

**Impact Dashboard**
- [ ] Build ImpactDashboardView with stats cards
- [ ] Display total impact metrics (food saved, CO2, money)
- [ ] Show current streak counter with fire emoji
- [ ] Create BadgesView grid layout
- [ ] Simple progress indicator to next badge

---

### Phase 6: Notifications (Hours 19-21)

**Push Notification Setup**
- [ ] Request notification permissions on first launch
- [ ] Configure APNs capabilities in Xcode
- [ ] Create NotificationService

**Notification Logic**
- [ ] Schedule local notifications for items expiring in 1-2 days
- [ ] Daily summary notification (8 AM)
- [ ] Include item names in notification body
- [ ] Handle notification taps to open pantry view
- [ ] Test on physical device

---

### Phase 7: Polish & Testing (Hours 21-23)

**UI/UX Polish**
- [ ] Add smooth transitions between views
- [ ] Implement haptic feedback for key actions
- [ ] Create loading states for all async operations
- [ ] Add empty states with helpful messages
- [ ] Consistent spacing, colors, and typography

**Testing**
- [ ] Test VisionKit with 3+ different receipt types
- [ ] Verify AI parsing accuracy
- [ ] Test recipe generation with various pantry states
- [ ] Validate expiration date calculations
- [ ] Test notifications fire correctly
- [ ] Verify badge unlocking logic

**Error Handling**
- [ ] Handle VisionKit unavailable gracefully
- [ ] Show user-friendly errors for API failures
- [ ] Add retry logic for failed AI requests

---

### Phase 8: Demo Preparation (Hours 23-24)

**Sample Data**
- [ ] Create realistic demo pantry with varied expiration dates
- [ ] Include some items expiring tomorrow
- [ ] Pre-unlock 1-2 badges for visual appeal
- [ ] Have sample receipt images ready

**Demo Script**
- [ ] Write 3-minute demo flow
- [ ] Practice complete user journey
- [ ] Prepare backup screenshots
- [ ] Test on judge's perspective

**Presentation**
- [ ] Create 3-5 slide deck
- [ ] Highlight environmental impact stats
- [ ] Prepare answers to likely questions
- [ ] Record backup demo video (just in case)

---

## API Configuration

### Environment Variables (.env or Config file)

```swift
// Config.swift - Store API keys securely

enum Config {
    // Supabase
    static let supabaseURL = "your_project_url"
    static let supabaseAnonKey = "your_anon_key"
    
    // Claude API for receipt parsing & recipes
    static let claudeAPIKey = "your_anthropic_key"
    
    // Spoonacular for recipe database (optional)
    static let spoonacularAPIKey = "your_spoonacular_key"
}
```

**No OCR API Key Needed!** VisionKit is built into iOS - completely free.

**Security Note:** Never commit API keys to git. Add `Config.swift` to `.gitignore` and use a `Config.example.swift` template for team members.

---

## Development Best Practices

### Version Control
```bash
# .gitignore
.env
*.xcuserstate
xcuserdata/
.DS_Store
Config.plist
```

### Code Organization
- Use MVVM architecture
- Keep ViewModels testable (no UI code)
- Create reusable view components
- Document complex logic with comments
- Use Swift's type safety to prevent errors

### Performance Tips
- Lazy load images with Kingfisher
- Debounce search inputs
- Cache API responses for 24 hours
- Use background threads for image processing
- Optimize database queries with indexes

---

## Testing Strategy

### Unit Tests
- ExpirationService date calculations
- Badge unlock logic
- Environmental impact calculations
- Data model validation

### Integration Tests
- Supabase CRUD operations
- API service calls with mock data
- Recipe generation flow

### Manual Testing Checklist
- [ ] Scan receipt with VisionKit → text extracted
- [ ] AI parses receipt text → items appear in pantry with correct details
- [ ] Photo of groceries → items detected
- [ ] Mark item as used → stats update, streak increments
- [ ] Item expires → notification fires (test on device, not simulator)
- [ ] Generate recipe → uses expiring items
- [ ] Unlock badge → animation shows
- [ ] Offline mode → VisionKit still works, AI calls queue for later
- [ ] Test with blurry receipt → should still extract most text
- [ ] Test with various receipt formats (Walmart, Whole Foods, local stores)

---

## Cost Estimation (24-Hour Hackathon)

| Service | Free Tier / Pricing | Expected Usage | Cost |
|---------|-----------|----------------|------|
| **VisionKit** | Free (built into iOS) | Unlimited receipt scans | **$0** |
| Supabase | 500MB database, 1GB storage | 50 users, 5K items | $0 |
| Claude API (receipt parsing) | Pay-per-use | ~30 receipts × $0.003 | ~$0.09 |
| Claude API (recipes) | Pay-per-use | ~50 recipes × $0.003 | ~$0.15 |
| Claude Vision (grocery photos) | Pay-per-use | ~10 photos × $0.01 | ~$0.10 |
| Spoonacular | 150 calls/day free | ~30 searches | $0 |
| **Total** | | | **~$0.34** |

**Huge Cost Savings with VisionKit:**
- Third-party OCR APIs: $0.01-0.05 per receipt = $0.30-1.50 for 30 receipts
- VisionKit approach: $0 for OCR + ~$0.09 for AI parsing
- **Saves ~70-90% vs traditional OCR APIs**

**For the hackathon, you'll spend less than $1 total!**

---

## Deployment Checklist

### Pre-Demo
- [ ] Test on physical iPhone device
- [ ] Verify all API keys are working
- [ ] Clear and reseed demo data
- [ ] Disable debug logging
- [ ] Check app icon and launch screen
- [ ] Test in airplane mode (offline features)

### TestFlight (Optional)
- [ ] Archive app in Xcode
- [ ] Upload to App Store Connect
- [ ] Send TestFlight invites to judges
- [ ] Include demo account credentials

---

## Troubleshooting Guide

### Common Issues

**VisionKit Not Available**
- Check device compatibility (iPhone XS or newer for best results)
- Ensure iOS 16+ is installed
- Fallback to manual entry if `DataScannerViewController.isSupported` is false

**VisionKit Text Recognition Poor Quality**
- Ensure good lighting when scanning
- Hold phone steady, avoid blur
- Try flattening crumpled receipts
- Use flash for faded thermal receipts

**AI Parsing Returns Wrong Items**
- Check that VisionKit extracted text correctly (log it)
- Improve prompt with more examples
- Add validation rules (e.g., reject items with prices > $100)
- Allow user to re-scan or edit

**Recipe Generation Fails**
- Check API key validity and quota
- Verify internet connection
- Implement fallback to Spoonacular database
- Show cached recipes if available

**Notifications Don't Fire**
- Confirm permissions granted
- Test on physical device (simulator has limitations)
- Check notification scheduling logic
- Verify app is not in Low Power Mode

**Supabase Connection Errors**
- Verify API keys in Config.swift
- Check database rules (RLS policies)
- Ensure network connectivity
- Test with Supabase dashboard directly

---

## Post-Hackathon Roadmap

### Week 1-2
- Implement barcode scanning
- Add nutrition information
- Improve OCR accuracy with custom training

### Month 1
- Launch TestFlight beta
- Gather user feedback
- Optimize performance

### Month 2-3
- Add social features
- Implement meal planning
- Partner with local food banks

### Long-term
- Machine learning for personalized recipes
- Integration with smart home devices
- Expansion to Android platform

---

## Resources & Documentation

**SwiftUI:**
- Apple Developer Documentation: https://developer.apple.com/documentation/swiftui
- Hacking with Swift: https://www.hackingwithswift.com

**Supabase:**
- iOS Client: https://github.com/supabase/supabase-swift
- Documentation: https://supabase.com/docs

**APIs:**
- Veryfi: https://docs.veryfi.com
- Claude: https://docs.anthropic.com
- Spoonacular: https://spoonacular.com/food-api/docs

**Design Inspiration:**
- Apple HIG: https://developer.apple.com/design/human-interface-guidelines
- Food waste stats: https://www.usda.gov/foodwaste

---

## Success Criteria

✅ **Must Have (Demo Day):**
- Scan receipt and extract items
- Photo recognition of groceries
- View pantry sorted by expiration
- Generate AI recipe from expiring items
- Track environmental impact
- Show earned badges

✅ **Should Have:**
- Push notifications
- Mark items as used
- Edit expiration dates
- Smooth animations

✅ **Nice to Have:**
- Multiple receipt format support
- Recipe database search
- Shareable impact cards

---

## Team Roles Suggestion

**If working in a team:**

- **iOS Developer 1:** UI/UX, SwiftUI views, animations
- **iOS Developer 2:** ViewModels, business logic, data models
- **Backend/Integration:** Supabase setup, API integrations
- **Designer:** UI mockups, badge designs, color schemes
- **PM/Presenter:** PRD, demo script, pitch deck

**Solo developer:** Follow the phase-by-phase implementation guide, prioritizing MVP features first.

---

## Final Tips for 24-Hour Hackathon Success

1. **Start with VisionKit early** - Test it on real receipts in first 2 hours to validate approach
2. **Use mock data initially** - Don't let API setup block UI development
3. **Test AI parsing thoroughly** - Receipts vary wildly; test Walmart, Whole Foods, local stores
4. **Have a manual entry fallback** - If scanning fails, users need a backup
5. **Demo over perfection** - A working 80% solution beats a perfect 20%
6. **Tell the environmental story** - Lead with impact metrics in your pitch
7. **Show, don't tell** - Live demo is more compelling than slides
8. **Record a backup video** - In case VisionKit acts up during demo
9. **Highlight the hybrid approach** - "Free on-device OCR + smart AI parsing" is your differentiator
10. **Prepare for questions:**
    - "Why not use a third-party OCR API?" → Cost, privacy, speed
    - "What if VisionKit fails?" → Manual entry fallback
    - "How accurate is the AI parsing?" → Show confidence scores, user review step

### Pre-Demo Checklist
- [ ] Test on actual iPhone (VisionKit doesn't work in simulator!)
- [ ] Have 3-4 real receipts ready to scan
- [ ] Clear demo data and reseed with realistic pantry
- [ ] Practice 3-minute pitch: Problem → Solution → Demo → Impact
- [ ] Charge your phone fully
- [ ] Disable "Do Not Disturb" to show notifications
- [ ] Test in good lighting conditions

### If Things Go Wrong
- **VisionKit fails:** Switch to manual entry, still show the pantry + recipe features
- **AI API is down:** Have pre-parsed sample data ready to load
- **Database crashes:** Use local-only mode (UserDefaults) for demo
- **Phone dies:** Have screenshots/video backup ready

Good luck! 🚀🌱 You've got this!