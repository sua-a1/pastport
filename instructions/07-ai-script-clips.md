# AI Script to Video Generation Implementation Plan

## Overview
Implementation of the scene-by-scene video generation flow using Luma AI's Ray 2 model, with proper UI feedback, video management, and eventual scene concatenation.

## 1. UI Components & Navigation

### Script Diagram View Updates
- [x] Add "Create Video from Keyframes" button (enabled only when all keyframes are generated)
- [ ] Add loading state and progress indicators
- [x] Implement navigation to video generation view

### Video Generation View
- [x] Create `SceneVideoGenerationView`
  - Reuse diagram layout from `ScriptDiagramView`
  - Add video generation buttons for each scene
  - Display generation progress
  - Show video preview after generation
- [x] Create `VideoPreviewSheet`
  - Video player with controls
  - Dismiss button
  - Save/delete options

## 2. Models & ViewModels

### Data Models
- [ ] Update `AIScript` model
```swift
extension AIScript {
    enum VideoGenerationStatus {
        case notStarted
        case inProgress(sceneIndex: Int)
        case completed
        case failed(Error)
    }
    
    struct SceneVideo {
        let sceneIndex: Int
        let videoUrl: String
        let duration: TimeInterval
        let status: VideoGenerationStatus
        let metadata: [String: Any]
    }
}
```

### ViewModels
- [ ] Create `SceneVideoGenerationViewModel`
```swift
@Observable final class SceneVideoGenerationViewModel {
    let script: AIScript
    private(set) var generationStatus: VideoGenerationStatus
    private(set) var sceneVideos: [SceneVideo]
    private let lumaService: LumaAIService
    private let storageService: StorageService
    
    func generateVideoForScene(_ index: Int) async throws
    func saveGeneratedVideo(_ video: SceneVideo) async throws
    func deleteGeneratedVideo(_ video: SceneVideo) async throws
}
```

## 3. Services & Utilities

### Luma AI Integration
- [ ] Enhance `LumaAIService` for scene-based video generation
```swift
extension LumaAIService {
    func generateSceneVideo(
        scene: StoryScene,
        startKeyframe: String,
        endKeyframe: String,
        visualDescription: String,
        characterReferences: [String]?
    ) async throws -> URL
}
```

### Storage Service Updates
- [ ] Add paths and methods for scene videos
```swift
// Storage paths
videos/
  ├── scripts/
  │   └── {scriptId}/
  │       ├── scenes/
  │       │   ├── {sceneIndex}.mp4
  │       │   └── ...
  │       └── final.mp4
```

### Video Processing
- [ ] Create `VideoProcessingService`
```swift
final class VideoProcessingService {
    func compressVideo(url: URL, quality: VideoQuality) async throws -> URL
    func concatenateVideos(urls: [URL]) async throws -> URL
    func generateTransition(from: URL, to: URL) async throws -> URL
}
```

## 4. Firebase Updates

### Storage Rules
```javascript
match /videos/scripts/{scriptId}/scenes/{filename} {
    allow read: if isAuthenticated();
    allow write: if isAuthenticated() 
                 && isValidVideo()
                 && filename.matches('[0-9]+\\.mp4');
    allow delete: if isAuthenticated() 
                 && resource.metadata.userId == request.auth.uid;
}
```

### Firestore Schema
```javascript
scripts/{scriptId} {
    scenes: [{
        videoUrl: string?,
        videoStatus: string,
        videoMetadata: {
            duration: number,
            resolution: string,
            size: number,
            timestamp: timestamp
        }
    }]
}
```

## 5. Implementation Phases

### Phase 1: Basic Video Generation
- [ ] Implement `SceneVideoGenerationView` UI
- [ ] Add video generation button to script diagram
- [ ] Basic Luma integration for single scene
- [ ] Simple video preview
- [ ] Basic storage integration

### Phase 2: Enhanced Generation & Preview
- [ ] Full scene-by-scene generation flow
- [ ] Progress tracking and status updates
- [ ] Enhanced video preview with controls
- [ ] Proper error handling and retries
- [ ] Storage optimization and caching

### Phase 3: Video Management
- [ ] Video deletion and cleanup
- [ ] Compression and optimization
- [ ] Metadata management
- [ ] Analytics integration

### Phase 4: Scene Transitions (Future)
- [ ] Generate transition videos
- [ ] Video concatenation
- [ ] Final video export

## 6. Technical Considerations

### Video Generation
- Use Ray 2 model with 5-second duration
- 720p resolution, 30fps
- Maintain style consistency between scenes
- Proper prompt engineering for smooth transitions

### Storage & Caching
- Implement two-level caching (memory/disk)
- Proper cleanup of temporary files
- Efficient video compression
- Handle network interruptions

### Security & Performance
- Validate file sizes and formats
- Implement rate limiting
- Secure API key handling
- Optimize memory usage during generation

### Error Handling
- Proper retry mechanisms
- User-friendly error messages
- Graceful degradation
- State recovery after failures

## 7. Testing Checklist

### Functionality
- [ ] Video generation for single scene
- [ ] Multiple scene generation
- [ ] Preview and playback
- [ ] Save and delete operations
- [ ] Error scenarios

### Performance
- [ ] Memory usage during generation
- [ ] Storage space management
- [ ] Network bandwidth usage
- [ ] UI responsiveness

### Security
- [ ] API key protection
- [ ] File access permissions
- [ ] Input validation
- [ ] Error message safety

## 8. Future Enhancements

### Phase 5: Advanced Features
- Scene transition effects
- Custom video duration
- Style transfer between scenes
- Background music integration

### Phase 6: Optimization
- Parallel video generation
- Smart caching strategies
- Bandwidth optimization
- Advanced compression

## Notes
- Reuse existing video player components
- Follow established error handling patterns
- Maintain consistent UI/UX with current implementation
- Ensure proper cleanup of temporary files
- Add comprehensive logging for debugging
