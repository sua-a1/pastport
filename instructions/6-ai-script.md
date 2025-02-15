# AI Script Generation Implementation Plan

## Phase 1: Data Models & Schema Updates

### 1.1 Firestore Schema Updates
- [x] Add `AIScript` collection with fields:
  ```typescript
  {
    id: string
    draftId: string
    userId: string
    scenes: [{
      id: string
      order: number
      content: string
      startKeyframe: {
        status: 'not_started' | 'generating' | 'completed' | 'failed'
        imageUrl: string?
        selectedImages: [{url: string, weight: number}]
        prompt: string
      }
      endKeyframe: {
        status: 'not_started' | 'generating' | 'completed' | 'failed'
        imageUrl: string?
        selectedImages: [{url: string, weight: number}]
        prompt: string
      }
    }]
    status: 'draft' | 'generating_script' | 'editing_keyframes' | 'generating_video' | 'completed' | 'failed'
    createdAt: timestamp
    updatedAt: timestamp
    selectedCharacterId?: string
    selectedCharacterImages?: string[]
    selectedReferenceImages?: string[]
    selectedReferenceTextIds?: string[]
  }
  ```

### 1.2 Storage Rules Updates
- [x] Add rules for AI-generated keyframe images:
  ```javascript
  match /ai_scripts/{scriptId}/keyframes/{keyframeId} {
    allow read: if isAuthenticated();
    allow write: if isAuthenticated() && isOwner(userId);
  }
  ```

### 1.3 Swift Models
- [x] Create `AIScript` model
- [x] Create `Scene` model
- [x] Create `Keyframe` model
- [x] Create `KeyframeGeneration` model for generation requests

## Phase 2: Core Services

### 2.1 OpenAI Service
- [x] Create `OpenAIService` class
- [x] Implement scene generation method using GPT-4
- [x] Define structured output format for scenes
- [x] Add error handling and retry logic
- [x] Add logging for debugging

### 2.2 Luma AI Service Updates
- [x] Add methods for keyframe generation
- [x] Implement image weight handling
- [x] Add start/end keyframe differentiation
- [x] Update error handling for keyframe-specific cases

### 2.3 Script Generation Service
- [x ] Create `AIScriptService` class
- [x ] Implement script state management
- [x ] Add methods for saving/loading progress
- [x ] Add cleanup methods

## Phase 3: ViewModels

### 3.1 Script Generation ViewModel
- [x] Create `ScriptGenerationViewModel` class
- [x] Implement character selection logic
- [x] Add reference image selection
- [x] Add reference text selection
- [x] Implement script generation flow
- [x] Add progress tracking
- [x] Implement save/load functionality

### 3.2 Keyframe Generation ViewModel
- [x] Create `KeyframeGenerationViewModel` class
- [x] Implement image selection logic
- [x] Add keyframe generation flow
- [x] Add regeneration functionality
- [x] Implement save/load functionality

## Phase 4: Views

### 4.1 Script Generation View
- [x] Create initial generation form
- [x] Add character selection UI
- [x] Add reference selection UI
- [x] Add generation progress UI
- [x] Implement navigation logic

### 4.2 Script Diagram View
- [x] Create scene diagram layout
- [x] Add keyframe generation buttons
- [x] Implement keyframe preview
- [x] Add editing capabilities
- [x] Add progress indicators

### 4.3 Keyframe Generation View
- [x] Create image selection UI
- [x] Add generation controls
- [x] Implement preview functionality
- [x] Add regeneration option
- [x] Add save/dismiss actions

## Phase 5: Integration & Navigation

### 5.1 Draft Detail Integration
- [x] Add generate script button
- [x] Implement navigation to script generation
- [x] Add progress restoration
- [x] Update draft status handling

### 5.2 Navigation Flow
- [x] Set up navigation between views
- [x] Add progress preservation
- [x] Implement back navigation
- [x] Add completion handling

## Phase 6: Testing & Refinement

### 6.1 Unit Tests
- [x] Test OpenAI service
- [x] Test Luma AI service
- [ ] Test script generation logic
- [ ] Test state management

### 6.2 Integration Tests
- [ ] Test full generation flow
- [ ] Test progress saving/loading
- [ ] Test error scenarios
- [ ] Test navigation paths

### 6.3 UI Testing
- [ ] Test user interactions
- [ ] Verify progress indicators
- [ ] Test image selection
- [ ] Verify keyframe generation

## Implementation Order
1. Start with Phase 1 to set up data models
2. Implement Phase 2 core services
3. Build Phase 3 ViewModels
4. Create Phase 4 Views
5. Complete Phase 5 Integration
6. Finish with Phase 6 Testing

## Notes
- Use `@Observable` for ViewModels
- Implement proper error handling at each step
- Add detailed logging for debugging
- Consider rate limiting for API calls
- Cache generated images efficiently
- Implement proper cleanup for failed generations
