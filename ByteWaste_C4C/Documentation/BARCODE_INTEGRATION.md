# Barcode Scanner Integration Guide

## Overview
Your app now integrates barcode scanning with AI-powered food expiration estimation! When you scan a barcode on your phone, the app will:

1. **Scan the barcode** using your device's camera
2. **Fetch product info** from Edamam Food Database API
3. **Analyze with AI** using Navigator AI to estimate shelf life
4. **Create a PantryItem** with full details
5. **Print JSON output** to the console for debugging

## How It Works

### Architecture

```
BarcodeScannerView (UI)
    ↓ (scans barcode)
PantryViewModel
    ↓ (calls async function)
FoodExpirationService
    ↓ (makes API calls)
Edamam API + Navigator AI
    ↓ (returns data)
PantryItem (created & added to list)
    ↓ (JSON printed to console)
```

### Files Modified/Created

1. **`FoodExpirationService.swift`** ✨ NEW
   - Service class handling API calls
   - Async/await pattern for clean code
   - Error handling for both APIs
   - Returns structured `FoodAnalysisResult`

2. **`PantryViewModel.swift`** 🔄 UPDATED
   - New `PantryItem` structure matching your requirements
   - `addFromBarcode()` now async and uses AI
   - Automatically prints JSON to console
   - Loading and error states

3. **`BarcodeScannerView.swift`** 🔄 UPDATED
   - Shows loading indicator during AI analysis
   - Error handling with retry option
   - Automatic flow (scan → analyze → add)

4. **`PantryView.swift`** 🔄 UPDATED
   - Displays new item structure
   - Shows expiration urgency with color coding
   - Product images from Edamam
   - Storage location icons

## PantryItem Structure

```swift
struct PantryItem: Identifiable, Codable {
    let id: UUID                              // Unique identifier
    var name: String                          // Product name from API
    var storageLocation: StorageLocation      // fridge/freezer/shelf
    let scanDate: Date                        // Never changes
    var currentExpirationDate: Date           // Based on storage location
    var shelfLifeEstimates: ShelfLifeEstimates // AI estimates for all 3 locations
    var edamamFoodId: String?                 // For future API calls
    var imageURL: String?                     // Product image
    var category: String?                     // Food category
    
    // Optional fields
    var quantity: String?
    var brand: String?
    var notes: String?                        // AI storage tips
    
    // Computed properties
    var daysUntilExpiration: Int              // Auto-calculated
    var isExpired: Bool                       // Auto-calculated
    var urgencyColor: Color                   // red/orange/green
}
```

## Storage Locations

```swift
enum StorageLocation {
    case fridge   // 🧊 Refrigerator
    case freezer  // ❄️  Freezer
    case shelf    // 🏠 Pantry/Shelf
}
```

## How to Use

### 1. Run the App on a Physical Device
(VisionKit barcode scanning requires a real device, not simulator)

### 2. Tap "Scan" Button
Opens the barcode scanner

### 3. Point Camera at Barcode
Automatically detects and scans

### 4. Watch the Magic! ✨
- Shows "Analyzing Product..." with loading indicator
- Calls Edamam API to get product info
- Calls Navigator AI to estimate shelf life
- Creates PantryItem with all data
- Adds to your pantry list
- **Prints JSON to Xcode console**

### 5. Check the Console
Look for output like this:

```
============================================================
PANTRY ITEM JSON:
============================================================
{
  "brand" : "Cheerios",
  "category" : "food",
  "currentExpirationDate" : "2026-08-06T20:33:56Z",
  "edamamFoodId" : "food_buqzkgib2gk5a3bkhwg1ta6ls5r9",
  "id" : "C4E14A90-D5E1-4047-8092-9C53553F05B8",
  "imageURL" : "https://www.edamam.com/food-img/6d5/...",
  "name" : "Honey Nut Cheerios...",
  "notes" : "Store in a cool, dry place...",
  "scanDate" : "2026-02-07T21:33:56Z",
  "shelfLifeEstimates" : {
    "freezer" : 365,
    "fridge" : 365,
    "shelf" : 180
  },
  "storageLocation" : "shelf"
}
============================================================
```

## Error Handling

The app handles:
- ❌ Invalid barcodes (not in database)
- ❌ Network errors
- ❌ API timeouts
- ❌ Rate limiting
- ❌ Invalid API responses

Users see friendly error messages with a "Try Again" button.

## Testing with the Command Line Script

You can still test the backend independently:

```bash
cd ByteWaste_C4C
swift testFoodExp.swift 016000141551
```

This will show the full analysis and JSON output without needing the app.

## API Keys Location

Both API keys are stored in `Config.swift`:
- Edamam Food Database API
- Navigator AI API

## What Happens Behind the Scenes

### Step 1: Fetch from Edamam
```
GET https://api.edamam.com/api/food-database/v2/parser?upc=016000141551
```
Returns: Product name, brand, category, image, nutrition, etc.

### Step 2: AI Analysis
```
POST https://api.ai.it.ufl.edu/v1/chat/completions
```
Sends product info, gets back:
```json
{
  "fridge_days": 365,
  "freezer_days": 365,
  "shelf_days": 180,
  "recommended_storage": "shelf",
  "notes": "Store in cool, dry place..."
}
```

### Step 3: Create PantryItem
Combines all data into structured model

### Step 4: Print JSON
Outputs to Xcode console for debugging

## Next Steps

You can now:
1. ✅ Scan barcodes on your phone
2. ✅ Get AI-powered expiration estimates
3. ✅ See JSON output in console
4. ✅ View items in your pantry with color-coded urgency
5. 📱 Use this data for notifications, recipes, etc.

## Example Barcodes to Test

- `016000141551` - Cheerios
- `041331024198` - Works (you tested this!)
- `689544083016` - Another product
- `028400064057` - Lay's Chips

---

**Built with:**
- SwiftUI
- VisionKit (barcode scanning)
- URLSession (async/await)
- Edamam Food Database API
- Navigator AI (OpenAI-compatible)
