# Character Creation Implementation Checklist

## Overview
This checklist outlines the implementation steps for the character creation functionality in Pastport. This feature allows users to create AI-generated characters using text prompts and reference images, which will be used across their stories for consistency.

## Implementation Steps

### 1. Models & Storage Setup
- [ ] Create Character model for SwiftData
  - Character name
  - Description/backstory
  - Generated image URLs
  - Reference image URLs with prompts and weights
  - Creation date
  - Last modified date
  - User ID reference
  - Status (generating/completed/failed)
- [] Create corresponding Firestore schema for characters
- [ ] Set up Firebase Storage structure for character images
  - Reference images folder
  - Generated images folder
- [ ] Implement Character-User relationship in SwiftData

### 2. Create Tab UI Updates
- [x] Add "Create Character" option to Create tab
- [x] Design and implement character creation form
  - Character name input
  - Description/backstory input
  - Style prompt input with helper text
  - Reference image section (max 4)
    - Image picker
    - Individual prompt field for each image
    - Weight slider (0-1) for each image
  - Preview/review section
- [x] Add loading and error states
- [x] Implement navigation to generation results view

### 3. Luma AI Integration
- [x] Create LumaAIService class
  - API key configuration
  - Error handling
  - Response parsing
- [x] Implement image upload functionality
  - Convert local images to URLs
  - Handle image compression
  - Upload to Firebase Storage
- [x] Implement prompt combination logic
  - Combine main prompt with reference prompts
  - Format request payload
- [x] Implement generation endpoints
  - Create generation
  - Check generation status
  - Fetch generated images
  - Handle errors and retries

### 4. Generation Results View
- [x] Create GenerationResultsView
  - Loading state with progress
  - Error state with retry option
  - Success state with generated images
  - Save/discard options
- [x] Implement image saving functionality
  - Download generated images
  - Upload to Firebase Storage
  - Update character model
- [ ] Add sharing options

### 5. Character Management
- [ ] Add Characters tab to Profile view
- [ ] Implement character list view
  - Show name, preview image, status
  - Add edit/delete options
- [ ] Create character detail view
  - Display all info and images
  - Show usage in stories
  - Edit functionality

### 6. Firebase Integration
- [ ] Set up character collection in Firestore
- [ ] Implement CRUD operations
  - Create new characters
  - Read character data
  - Update character info
  - Delete characters and associated media
- [ ] Set up proper security rules

### 7. Testing & Polish
- [ ] Test image upload limits
- [ ] Verify API integration
- [ ] Test error scenarios
- [ ] Add proper cleanup of unused media
- [ ] Implement proper loading states
- [ ] Add user feedback for long operations

## Technical Notes

### Luma AI API Integration
```swift
// Base URL and endpoints
let baseUrl = "https://api.lumalabs.ai/dream-machine/v1"
let endpoints = [
    "create": "/generations",
    "get": "/generations/{id}",
    "delete": "/generations/{id}"
]

// API key configuration
let apiKey = "luma-06baadf0-2cd5-4248-828b-4fe02a133104-cef3cdb8-b368-445c-81c6-fd6f877d332d"

// Request structure for character generation
struct GenerationRequest {
    let prompt: String
    let image_ref: [ImageReference]
    let model: String = "photon-1"
    let aspect_ratio: String = "1:1"
}

struct ImageReference {
    let url: String
    let weight: Double
    let prompt: String
}
```

### Firebase Storage Structure
```
/characters
    /{userId}
        /reference_images
            /{characterId}_{imageIndex}.jpg
        /generated_images
            /{characterId}_{timestamp}.jpg
```

### Firestore Schema
```typescript
interface Character {
    id: string;
    userId: string;
    name: string;
    description: string;
    stylePrompt: string;
    referenceImages: {
        url: string;
        prompt: string;
        weight: number;
    }[];
    generatedImages: string[];
    status: 'generating' | 'completed' | 'failed';
    createdAt: Timestamp;
    updatedAt: Timestamp;
}
``` 