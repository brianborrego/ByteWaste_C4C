# ByteWaste - AI Development Guide

## Project Overview

**ByteWaste** is an iOS app (iOS 17+) built with SwiftUI that prevents household food waste through:
- **Effortless food tracking** (barcode scan, photo recognition, manual search)
- **Intelligent storage management** (fridge/freezer/shelf with AI-powered expiration estimates)
- **Smart recipe suggestions** (prioritizing expiring items)
- **Integrated shopping lists** (from recipe missing ingredients)

**Core Philosophy:** Simple, minimal, human-readable code. No over-engineering.

---

## Current State

**What's Working:**
- Barebones Swift project structure
- Basic barcode scanning functionality
- Default Apple UI components

**What Needs Building:**
- Complete Pantry management system (3 storage sections)
- Photo recognition integration
- Manual entry with Edamam search
- Expiration tracking and recalculation logic
- Recipe matching system (2 tabs)
- Shopping list functionality
- Data persistence layer
- AI integration for shelf life estimation

---

## Tech Stack Summary

| Component | Technology |
|-----------|-----------|
| Language | Swift |
| UI Framework | SwiftUI (declarative, iOS 17+) |
| Architecture | MVVM (Model-View-ViewModel) |
| Storage | UserDefaults with JSON encoding |
| Camera | AVFoundation (already working for barcode) |
| Photo Picker | PhotosPicker |
| APIs | Edamam Food DB, Vision, Recipe Search + School's AI |

---

## Application Structure

### Navigation Pattern
Bottom tab bar with 3 main pages:
1. **Pantry** → Food inventory across 3 storage sections
2. **Recipes** → 2 sub-tabs: "My Pantry" (expiring-focused) + "All Recipes" (general search)
3. **Shopping List** → Simple checklist with add/delete/complete

---

## Critical Data Models

### PantryItem
```swift
struct PantryItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var storageLocation: StorageLocation  // enum: fridge/freezer/shelf
    let scanDate: Date  // NEVER changes - original add date
    var currentExpirationDate: Date
    var shelfLifeEstimates: ShelfLifeEstimates  // AI estimates for all 3 storage types
    var edamamFoodId: String?
    var imageURL: String?
    var category: String?

    // Optional
    var quantity: String?
    var brand: String?
    var notes: String?

    // Computed properties
    var daysUntilExpiration: Int { /* calculate from currentExpirationDate */ }
    var isExpired: Bool { /* currentExpirationDate < Date() */ }
    var urgencyColor: Color {
        // ≤3 days: red, 4-7 days: orange, >7 days: green
    }
}

struct ShelfLifeEstimates: Codable {
    let fridgeDays: Int
    let freezerDays: Int
    let shelfDays: Int
}

enum StorageLocation: String, Codable {
    case fridge, freezer, shelf
}
```

### Recipe (from Edamam)
```swift
struct Recipe: Identifiable, Codable {
    let id: String  // URI from Edamam
    let title: String
    let imageURL: String
    let sourcePublisher: String?
    let sourceURL: String?
    let ingredients: [RecipeIngredient]
    let instructions: [String]?
    let prepTime: Int?
    let cookTime: Int?
    let totalTime: Int?
    let servings: Int?
    let cuisineType: [String]?
    let mealType: [String]?
}

struct RecipeIngredient: Codable {
    let text: String  // "1 cup rice"
    let foodName: String  // "rice"
    let quantity: Double?
    let weight: Double?
}
```

### ScoredRecipe (for "My Pantry" tab)
```swift
struct ScoredRecipe: Identifiable {
    let recipe: Recipe
    let matchScore: Double  // 0-150+, used for sorting
    let availableIngredientsCount: Int
    let totalIngredientsCount: Int
    let missingIngredientsCount: Int
    let missingIngredientsList: [String]
    let expiringItemsUsed: [PantryItem]  // Items ≤3 days that recipe uses
    let matchPercentage: Double  // 0.0-1.0

    var id: String { recipe.id }
}
```

### ShoppingListItem
```swift
struct ShoppingListItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var isCompleted: Bool
    let dateAdded: Date
    var sourceRecipeId: String?
    var sourceRecipeName: String?
}
```

---

## Critical Algorithms

### 1. Expiration Recalculation (MOST IMPORTANT)

**When:** User moves item between storage locations (drag-and-drop or edit)

**Key Insight:** Each item stores `scanDate` (never changes) + `shelfLifeEstimates` (all 3 values from AI)

**Logic:**
```swift
func recalculateExpiration(item: PantryItem, newStorage: StorageLocation) -> Date {
    let currentDate = Date()
    let daysElapsed = Calendar.current.dateComponents([.day],
                                                       from: item.scanDate,
                                                       to: currentDate).day ?? 0

    // Rule 1: Moving TO Freezer → Full freezer estimate (freezing preserves)
    if newStorage == .freezer {
        return currentDate.addingDays(item.shelfLifeEstimates.freezerDays)
    }

    // Rule 2: Moving FROM Freezer → Full new storage estimate (thawing resets)
    if item.storageLocation == .freezer {
        let newDays = newStorage == .fridge ?
            item.shelfLifeEstimates.fridgeDays :
            item.shelfLifeEstimates.shelfDays
        return currentDate.addingDays(newDays)
    }

    // Rule 3: Moving between Fridge ↔ Shelf → Adjust for elapsed time
    let newEstimate = newStorage == .fridge ?
        item.shelfLifeEstimates.fridgeDays :
        item.shelfLifeEstimates.shelfDays
    let remainingDays = max(1, newEstimate - daysElapsed)  // Min 1 day
    return currentDate.addingDays(remainingDays)
}
```

**Examples:**
- **Chicken: Fridge → Freezer** (scanned 2 days ago, fridge estimate 2d, freezer 90d)
  - New expiration: Today + 90 days (full freezer life)
- **Chicken: Freezer → Fridge** (frozen 30 days ago)
  - New expiration: Today + 2 days (thawing resets clock)
- **Bread: Shelf → Fridge** (on shelf 2 days, shelf estimate 5d, fridge 7d)
  - New expiration: Today + (7 - 2) = 5 days

### 2. Recipe Matching Algorithm

**Goal:** Find recipes using expiring items (≤3 days), allow up to 3 missing ingredients

**Steps:**
1. **Identify expiring items** (≤3 days until expiration)
2. **Generate search queries:**
   - Individual items: "chicken recipes"
   - Pairs: "chicken tomato recipes"
   - Triples: "chicken tomato rice"
3. **Query Edamam Recipe API** multiple times
4. **For each recipe returned:**
   - Compare ingredients to pantry (fuzzy string matching)
   - Count: available, missing, expiring items used
   - Calculate match percentage: `available / total`
5. **Score each recipe:**
   - Base: `matchPercentage × 100`
   - Bonus: `+25 points per expiring item used`
   - Penalty: `-5 points per missing ingredient`
6. **Filter:** Keep only recipes with ≤3 missing ingredients
7. **Sort:** By score descending
8. **Return:** Top 15-20 recipes

**String Matching:**
- Case-insensitive
- Partial match OK
- "chicken breast" matches "Organic Chicken Breast"
- Use `String.localizedCaseInsensitiveContains()` or fuzzy matching library

---

## API Integration Details

### Edamam Food Database API
**Base URL:** Check `food_database_apidoc.yaml`

**Key Endpoints:**
- **Barcode lookup:** Query with UPC/EAN code
  - Returns: Product name, brand, category, image URL, nutrition
- **Text search:** Query with food name (for manual entry dropdown)
  - Use for autocomplete as user types (debounce 300ms)
  - Returns: Array of food items matching query

### Edamam Vision API
**Purpose:** Identify food from photos

**Flow:**
1. User takes photo or selects from library
2. Upload image to Vision API
3. API returns: Identified food name + confidence score
4. Use food name to query Food Database for full details

### Edamam Recipe Search API
**Purpose:** Find recipes by ingredients or search terms

**Two use cases:**
1. **"My Pantry" tab:** Query with ingredient names from expiring items
   - Multiple queries for combinations
2. **"All Recipes" tab:** Query with user's search term
   - Single query based on text input

**Returns:** Array of recipes with images, ingredients, instructions

### School's AI System
**Purpose:** Estimate shelf life and recommend storage

**Input (JSON):**
```json
{
  "productName": "Organic Chicken Breast",
  "category": "meat",
  "brand": "Bell & Evans"
}
```

**Output (JSON):**
```json
{
  "fridgeDays": 2,
  "freezerDays": 90,
  "shelfDays": 0,
  "recommendedStorage": "fridge",
  "reasoning": "Raw poultry requires refrigeration for food safety"
}
```

**Error Handling:** If AI fails, use conservative defaults:
- Perishables: Fridge 3d, Freezer 60d, Shelf 0d
- Shelf-stable: Shelf 90d, Fridge 90d, Freezer 180d

---

## MVVM Architecture Pattern

### Views (SwiftUI)
- Responsible for UI presentation only
- Observe ViewModels via `@ObservedObject` or `@StateObject`
- No business logic
- Keep views small and composable

### ViewModels (ObservableObject)
- Hold UI state
- Contain business logic
- Interact with Models and Services
- Publish changes via `@Published` properties

### Models (Structs)
- Data structures (PantryItem, Recipe, etc.)
- Codable for JSON serialization
- No business logic

### Services (Separate classes)
- `EdamamService` - API calls to Edamam
- `AIService` - Calls to school's AI system
- `PersistenceService` - UserDefaults read/write
- `BarcodeService` - Camera barcode scanning (already exists)
- `PhotoRecognitionService` - Image processing + Vision API

**Example structure:**
```
Views/
  PantryView.swift
  RecipeListView.swift
  ShoppingListView.swift
ViewModels/
  PantryViewModel.swift
  RecipeViewModel.swift
  ShoppingListViewModel.swift
Models/
  PantryItem.swift
  Recipe.swift
  ShoppingListItem.swift
Services/
  EdamamService.swift
  AIService.swift
  PersistenceService.swift
  BarcodeService.swift
  PhotoRecognitionService.swift
```

---

## Key UI Components to Build

### Pantry Page
**Components:**
1. **StorageSectionView** - One section (Fridge/Freezer/Shelf)
   - Horizontal scroll or grid of food cards
   - Section header with icon
2. **FoodCardView** - Individual item card
   - Product image (from URL or placeholder)
   - Item name
   - Expiration badge (colored, shows days remaining)
   - Drag handle when in edit mode
3. **AddItemSheet** - Modal with 3 options (Barcode/Photo/Manual)
4. **ConfirmationSheet** - Review scanned items before adding
   - Allows storage changes (triggers expiration recalc)
   - Batch add to pantry
5. **EditItemSheet** - Form to edit item details

### Recipes Page
**Components:**
1. **RecipeTabView** - Container with 2 tabs
2. **MyPantryRecipesView** - Shows ScoredRecipe list
3. **AllRecipesView** - Search bar + results
4. **RecipeCardView** - List item showing recipe image, name, ingredient counts
5. **RecipeDetailView** - Full-screen recipe with:
   - Hero image
   - Missing ingredients (red) first
   - Available ingredients (green) with checkmarks
   - Expiring ingredient badges
   - Instructions
   - "Add to Shopping List" button

### Shopping List Page
**Components:**
1. **ShoppingListView** - Simple list
2. **ShoppingListItemRow** - Checkbox + name + delete button
3. **AddItemSheet** - Text input for manual add

---

## Color & Typography System

```swift
// Color Extensions
extension Color {
    static let urgentRed = Color(red: 1.0, green: 0.23, blue: 0.19)      // #FF3B30
    static let warningOrange = Color(red: 1.0, green: 0.58, blue: 0.0)   // #FF9500
    static let freshGreen = Color(red: 0.20, green: 0.78, blue: 0.35)    // #34C759
    static let actionBlue = Color(red: 0.0, green: 0.48, blue: 1.0)      // #007AFF
    static let secondaryGray = Color(red: 0.56, green: 0.56, blue: 0.58) // #8E8E93
}

// Typography
// Use native San Francisco font via .font() modifiers:
// .font(.largeTitle)    - 34pt bold - Page headers
// .font(.headline)      - 17pt semibold - Item names, section headers
// .font(.body)          - 17pt regular - Main content
// .font(.caption)       - 12pt regular - Metadata, timestamps
```

---

## Persistence Strategy

**Use UserDefaults** with JSON encoding (simple, no CoreData needed for hackathon)

```swift
class PersistenceService {
    private let pantryKey = "pantryItems"
    private let shoppingListKey = "shoppingListItems"

    func savePantryItems(_ items: [PantryItem]) {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: pantryKey)
        }
    }

    func loadPantryItems() -> [PantryItem] {
        guard let data = UserDefaults.standard.data(forKey: pantryKey),
              let items = try? JSONDecoder().decode([PantryItem].self, from: data) else {
            return []
        }
        return items
    }

    // Similar methods for shopping list
}
```

---

## Development Workflow Guidelines

### Code Style
- **Simple, minimal, human-readable** - top priority
- Use descriptive variable names: `expiringItems` not `ei`
- Keep functions short (< 30 lines ideally)
- Add comments only where logic isn't self-evident
- Use SwiftUI's declarative style (avoid imperative updates)

### File Organization
- One model per file
- One view per file
- ViewModels can be larger but keep focused
- Group related files in folders

### API Calls
- Always use `async/await` (keep UI responsive)
- Handle errors gracefully with try/catch
- Show loading states during API calls
- Cache responses where appropriate (15-min cache for EdamamService)

### Testing Strategy (Hackathon Context)
- Manual testing via Xcode simulator
- Test all 3 input methods (barcode, photo, manual)
- Test drag-and-drop with expiration recalculation
- Test recipe matching with various pantry states
- Test shopping list integration

### Edge Cases to Handle
1. **No expiring items:** "My Pantry" tab shows message "Add items to your pantry to get recipe suggestions"
2. **API failures:** Show error message, allow retry
3. **No camera access:** Show permission prompt
4. **Empty pantry:** Show onboarding message
5. **No internet:** Show cached data if available, warn user
6. **Barcode not found:** Suggest photo recognition or manual entry
7. **Photo recognition fails:** Suggest manual entry

---

## Demo Flow for Hackathon

**Recommended demo sequence:**
1. **Start with empty pantry** - Show clean state
2. **Barcode scan milk** - Demonstrates quickest input method
3. **Photo scan bananas** - Shows AI vision capability
4. **Manual entry chicken** - Shows search functionality
5. **Navigate to Pantry** - Show 3 storage sections organized
6. **Drag chicken to freezer** - Demonstrate expiration recalculation (2d → 90d)
7. **Wait or manually adjust date** - Make chicken "expire in 2 days"
8. **Open Recipes → My Pantry tab** - Show recipe suggestions featuring chicken
9. **Tap recipe** - Show detail with missing ingredients highlighted
10. **Add to shopping list** - Demonstrate integration
11. **Navigate to Shopping List** - Show added ingredients
12. **Check off items** - Show completion interaction

**Total demo time:** ~5 minutes

---

## Common Pitfalls to Avoid

1. **Over-engineering:** Don't build features not in spec (no meal planning, no social features, no notifications)
2. **Complex animations:** Keep transitions simple (native SwiftUI defaults)
3. **Premature optimization:** Focus on functionality first, performance second
4. **Ignoring expiration recalc:** This is the core feature - must work perfectly
5. **Poor error handling:** API failures will happen - handle gracefully
6. **Hardcoded data:** Use real APIs, not mock data (except for initial development)
7. **Forgetting edge cases:** Empty states, no results, API failures
8. **Complex state management:** UserDefaults + ViewModels is sufficient

---

## API Keys & Configuration

**Store in a Config.swift file (NOT in version control):**
```swift
enum Config {
    static let edamamFoodDBAppID = "YOUR_APP_ID"
    static let edamamFoodDBAppKey = "YOUR_APP_KEY"
    static let edamamVisionAppID = "YOUR_APP_ID"
    static let edamamVisionAppKey = "YOUR_APP_KEY"
    static let edamamRecipeAppID = "YOUR_APP_ID"
    static let edamamRecipeAppKey = "YOUR_APP_KEY"
    static let schoolAIEndpoint = "YOUR_AI_ENDPOINT"
    static let schoolAIKey = "YOUR_AI_KEY"
}
```

**Add Config.swift to .gitignore**

---

## Quick Reference: File Paths

- **API Documentation:** `food_database_apidoc.yaml`
- **This guide:** `CLAUDE.md`
- **Project root:** `/Users/brianborrego/Documents/Projects/ByteWaste_C4C/`

---

## Development Priorities (In Order)

### Phase 1: Core Data Layer
1. Define all models (PantryItem, Recipe, ShoppingListItem)
2. Build PersistenceService
3. Test save/load cycles

### Phase 2: Pantry Functionality
1. Build StorageSectionView + FoodCardView
2. Implement expiration date display and color coding
3. Build AddItemSheet with 3 options
4. Integrate existing barcode scanner
5. Add Edamam Food DB API integration
6. Add AI service for shelf life estimates
7. Build ConfirmationSheet
8. Implement drag-and-drop between sections
9. **CRITICAL:** Implement expiration recalculation logic
10. Build EditItemSheet

### Phase 3: Photo Recognition
1. Build PhotoRecognitionService
2. Integrate Edamam Vision API
3. Test photo → food identification → pantry flow

### Phase 4: Manual Entry
1. Build searchable dropdown
2. Integrate Edamam Food DB text search
3. Build expiration input UI (calendar + "in X days")
4. Test manual entry → pantry flow

### Phase 5: Recipe System
1. Build EdamamRecipeService
2. Implement recipe matching algorithm
3. Build RecipeCardView + RecipeDetailView
4. Build "My Pantry" tab (expiring item prioritization)
5. Build "All Recipes" tab (search functionality)
6. Test ingredient matching logic

### Phase 6: Shopping List
1. Build ShoppingListView + item rows
2. Implement add/delete/complete
3. Integrate with recipe detail view
4. Test end-to-end flow: recipe → shopping list

### Phase 7: Polish & Testing
1. Add loading states
2. Add error handling
3. Refine UI spacing and colors
4. Test all workflows
5. Fix bugs
6. Prepare demo data

---

## Success Metrics

**Must work perfectly:**
- ✅ Expiration recalculation when moving items
- ✅ Recipe matching prioritizes expiring items
- ✅ Shopping list integration from recipes
- ✅ All 3 input methods (barcode, photo, manual)

**Should work well:**
- Smooth drag-and-drop
- Fast API responses
- Clean, professional UI
- No crashes during demo

**Nice to have:**
- Animations and transitions
- Cached API responses
- Optimized image loading
- Detailed error messages

---

## When in Doubt

**Guiding principles:**
1. **Simple over complex** - If there's a simpler way, use it
2. **Readable over clever** - Future developers (and AI) should understand the code easily
3. **Working over perfect** - Hackathon priority is functionality
4. **User experience over features** - Better to have 3 features that work great than 10 that are buggy

**Ask yourself:**
- "Is this the simplest solution that works?"
- "Would a junior developer understand this code?"
- "Does this directly support the core value proposition (preventing food waste)?"

If the answer to any is "no," reconsider the approach.

---

## Next Steps for Development

1. Review existing barcode scanning code
2. Set up Config.swift with API keys
3. Start with Phase 1 (Core Data Layer)
4. Build incrementally, testing each component
5. Keep commits small and focused
6. Reference this document frequently

Good luck building ByteWaste! 🚀
