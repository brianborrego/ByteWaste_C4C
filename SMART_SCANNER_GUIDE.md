# Smart Scanner Implementation Guide

## Overview
The Smart Scanner now supports two scanning modes:
1. **Barcode Mode** - For packaged foods with barcodes
2. **Image Mode** - For produce and non-barcoded items using AI image recognition

## What Was Added

### New Files
1. **ImageClassificationService.swift** - Uses Apple's Vision framework to classify food from photos
2. **SmartScannerView.swift** - Main scanner UI with mode toggle and image picker

### How It Works

#### Barcode Mode (Existing Workflow)
1. User taps "Start Barcode Scanner"
2. Camera opens with barcode detection
3. When barcode detected, calls `FoodExpirationService.analyzeFood(barcode:)`
4. Product is analyzed and added to pantry

#### Image Mode (New Workflow)
1. User selects "Image" tab
2. User can either:
   - Take a photo with camera
   - Choose existing photo from library
3. Image is analyzed using Vision framework
4. AI identifies potential food items with confidence scores
5. User selects the correct food item
6. Calls `FoodExpirationService.analyzeFoodFromImage(foodName:)`
7. Product is analyzed and added to pantry

## Setup Required

### 1. Camera & Photo Library Permissions
Add to your project's Info.plist (or update build settings):

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to scan barcodes and identify food items for your pantry.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access allows you to identify food items from existing photos.</string>
```

**Via Xcode Build Settings:**
- Target → Info → Custom iOS Target Properties
- Add `NSPhotoLibraryUsageDescription` with value: "Photo library access allows you to identify food items from existing photos."

### 2. Verify Files Are Included
The following files should be in your project:
- ✅ SmartScannerView.swift
- ✅ ImageClassificationService.swift

Since the project uses `PBXFileSystemSynchronizedRootGroup`, these should be automatically included.

### 3. Build the Project
1. Open project in Xcode
2. Clean build folder: `Product → Clean Build Folder` (⇧⌘K)
3. Build project: `Product → Build` (⌘B)

## Testing the Feature

### Test Barcode Mode
1. Run app on physical device (simulator may not have camera)
2. Navigate to Pantry
3. Tap scan button (barcode icon)
4. Select "Barcode" tab
5. Tap "Start Barcode Scanner"
6. Point at any product barcode
7. Verify product is analyzed and added

### Test Image Mode
1. Navigate to Pantry
2. Tap scan button
3. Select "Image" tab
4. **Option A - Take Photo:**
   - Tap "Take Photo"
   - Grant camera permission if prompted
   - Photograph a food item (apple, banana, etc.)
   - Select food from classification results
   - Verify product is analyzed and added

5. **Option B - Choose from Library:**
   - Tap "Choose from Library"
   - Grant photo permission if prompted
   - Select a food photo
   - Select food from classification results
   - Verify product is analyzed and added

## Known Limitations

### Vision Framework Classification
- Apple's Vision framework classifies general objects, not just food
- Works best with common, whole food items (fruits, vegetables, etc.)
- May not work well with:
  - Packaged foods (use barcode mode instead)
  - Processed foods
  - Mixed dishes
  - Obscured or poorly lit items

### Recommendations
- **Use barcode mode for**: Packaged goods with barcodes
- **Use image mode for**: Fresh produce, bulk items, non-barcoded goods
- Take clear, well-lit photos centered on the food item
- Ensure food item fills most of the frame

## Troubleshooting

### "No food detected" Error
- Take a clearer photo with better lighting
- Center the food item in frame
- Try a different angle
- Use barcode mode if item has a barcode

### Classification Shows Wrong Items
- The top result (highest confidence) is usually most accurate
- Scroll through all results to find correct item
- Vision framework sometimes needs context clues

### Camera/Photo Permissions Denied
- Go to Settings → ByteWaste → Photos/Camera
- Enable permissions
- Restart app

### Files Not Building
- Clean build folder (⇧⌘K)
- Verify files are in ByteWaste_C4C folder
- Check for import errors in Xcode

## Code Structure

### SmartScannerView.swift
- `ScanMode` enum - Defines barcode vs image modes
- `SmartScannerSheetView` - Main UI with mode picker
- `ImagePicker` - UIKit wrapper for camera/photo library
- Integrates with existing `PantryViewModel`

### ImageClassificationService.swift
- `classifyFood(from:)` - Uses Vision framework to classify images
- `cleanFoodName(_:)` - Cleans up technical classification names
- Returns array of `FoodClassification` objects with confidence scores

### Integration Points
- `PantryView.swift` line 36: Uses `SmartScannerSheetView`
- `PantryViewModel.swift`:
  - `addFromBarcode(barcode:)` - For barcode workflow
  - `addFromImageClassification(foodName:)` - For image workflow
- `FoodExpirationService.swift`:
  - `analyzeFood(barcode:)` - Existing barcode analysis
  - `analyzeFoodFromImage(foodName:)` - New image analysis

## Future Enhancements

### Potential Improvements
1. **Custom ML Model**: Train a food-specific CoreML model for better accuracy
2. **Edamam Vision API**: Integrate Edamam's Vision API for more accurate food identification
3. **Batch Scanning**: Allow multiple items to be scanned in sequence
4. **Confirmation Screen**: Show detected food info before adding to pantry
5. **Manual Override**: Allow user to type food name if classification fails
6. **History**: Remember recently scanned items for faster re-adding

### API Integration Option
The `FoodExpirationService` already has the structure to support Edamam Vision API. To upgrade from Vision framework to Edamam Vision:

1. Add Vision API credentials to environment variables
2. Implement `uploadImageToVision(image:)` method
3. Call Edamam Vision API endpoint with image
4. Parse response and use existing `analyzeFoodFromImage` flow

See CLAUDE.md for Edamam Vision API details.

## Summary

The Smart Scanner now provides a complete food input system:
- **Barcode mode** for packaged goods → Fast, accurate product data
- **Image mode** for produce → AI-powered food identification

Both workflows converge at the same AI shelf-life analysis, ensuring consistent expiration tracking regardless of input method.
