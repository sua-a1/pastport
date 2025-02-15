import Foundation
import SwiftUI
import FirebaseStorage

// Import our models
import class pastport.AIScript
import class pastport.StoryScene
import class pastport.LumaAIService
import class pastport.StorageService
import class pastport.VideoPlayerManager
import class pastport.VideoCompressionService
import class pastport.VideoStitchingService
import enum pastport.CloudinaryConfig

/// ViewModel for managing scene-by-scene video generation
@Observable final class SceneVideoGenerationViewModel {
    // MARK: - Properties
    
    private(set) var script: AIScript
    private(set) var sceneVideos: [AIScript.SceneVideo?]
    private(set) var progress: Double = 0.0
    private(set) var errorMessage: String?
    private(set) var generationStatus: AIScript.VideoGenerationStatus = .notStarted
    
    // MARK: - Private Properties
    private let lumaService: LumaAIService
    private let storageService: StorageService
    private let compressionService = VideoCompressionService.shared
    private let stitchingService: VideoStitchingService
    
    // MARK: - Initialization
    
    init(script: AIScript) throws {
        print("DEBUG: Initializing SceneVideoGenerationViewModel")
        print("DEBUG: Script ID: \(script.id ?? "nil")")
        print("DEBUG: Number of scenes: \(script.scenes.count)")
        
        self.script = script
        self.storageService = StorageService.shared
        self.lumaService = try LumaAIService()
        
        // Initialize VideoStitchingService with Cloudinary credentials
        guard let credentials = CloudinaryConfig.getCredentials() else {
            throw VideoGenerationError.cloudinaryConfigurationMissing
        }
        
        self.stitchingService = VideoStitchingService(
            cloudName: credentials.cloudName,
            apiKey: credentials.apiKey,
            apiSecret: credentials.apiSecret,
            transitionDuration: 1,  // 1 second fade transition
            clipDuration: 5         // 5 seconds per clip
        )
        
        // Initialize scene videos array with nil values for each scene
        self.sceneVideos = Array(repeating: nil, count: script.scenes.count)
        print("DEBUG: Initialized sceneVideos array with \(script.scenes.count) slots")
        
        // Load any existing videos
        Task {
            await loadExistingVideos()
        }
    }
    
    // MARK: - Public Methods
    
    /// Generate video for a specific scene
    @MainActor
    func generateVideoForScene(_ scene: StoryScene) async throws {
        guard let sceneIndex = script.scenes.firstIndex(where: { $0.id == scene.id }) else {
            throw VideoGenerationError.sceneNotFound
        }
        
        print("DEBUG: Starting video generation for scene \(sceneIndex)")
        print("DEBUG: Current sceneVideos array: \(sceneVideos)")
        
        generationStatus = .inProgress(sceneIndex: sceneIndex)
        
        do {
            // Build enhanced prompt for video generation
            let enhancedPrompt = """
            Scene: \(scene.content)
            Style: Clear, photorealistic, minimal artifacts
            Transition: Simple, static-focused with minimal movement
            Start: \(scene.startKeyframe.prompt ?? "")
            End: \(scene.endKeyframe.prompt ?? "")
            
            Requirements:
            - Maintain exact character appearance
            - Static composition with minimal motion
            - Simple, uncluttered background
            - Maximum 1-2 characters
            - Essential elements only
            - No camera movement
            - Consistent lighting
            """
            
            // Validate keyframe URLs
            guard let startKeyframeUrl = scene.startKeyframe.imageUrl,
                  let endKeyframeUrl = scene.endKeyframe.imageUrl else {
                throw VideoGenerationError.invalidKeyframes
            }
            
            // Create keyframes dictionary
            let keyframes: [String: LumaAIService.Keyframe] = [
                "frame0": .init(
                    type: "image",
                    url: startKeyframeUrl
                ),
                "frame1": .init(
                    type: "image",
                    url: endKeyframeUrl
                )
            ]
            
            // Generate video using Luma API
            let lumaVideoUrl = try await lumaService.generateVideo(
                prompt: enhancedPrompt,
                keyframes: keyframes
            )
            
            // Extract generation ID from Luma video URL
            let generationId = try await lumaService.getGenerationIdFromUrl(lumaVideoUrl)
            print("DEBUG: Got Luma generation ID: \(generationId)")
            
            // Download the video to a local temporary URL
            let (tempUrl, _) = try await URLSession.shared.download(from: lumaVideoUrl)
            
            // Move to a new temporary location that we control
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp4")
            
            try FileManager.default.moveItem(at: tempUrl, to: tempURL)
            
            print("DEBUG: Original video downloaded to: \(tempURL)")
            let originalSize = try Data(contentsOf: tempURL).count
            print("DEBUG: Original video size: \(originalSize / 1024 / 1024)MB")
            
            // Compress video
            let compressedURL = try await compressionService.compressVideo(
                at: tempURL,
                maxWidth: 1080,
                targetSize: 5 * 1024 * 1024 // 5MB target size
            )
            
            // Create metadata dictionary with generation ID
            let metadata: [String: String] = [
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "sceneId": scene.id,
                "scriptId": script.id ?? "",
                "userId": script.userId,
                "sceneIndex": String(sceneIndex),
                "model": "ray-2",
                "fileSize": String(try Data(contentsOf: compressedURL).count),
                "generatedAt": ISO8601DateFormatter().string(from: Date()),
                "contentType": "video/mp4",
                "lumaGenerationId": generationId // Ensure generation ID is included
            ]
            
            print("DEBUG: Adding custom metadata: \(metadata)")
            print("DEBUG: Luma generation ID in metadata: \(generationId)")
            
            // Upload compressed video with retry logic
            let maxRetries = 3
            var lastError: Error?
            var uploadedUrl: String?
            
            for attempt in 1...maxRetries {
                do {
                    // Generate a unique filename for each attempt
                    let uniqueId = UUID().uuidString
                    let path = "videos/scripts/\(script.id ?? "")/scenes/\(sceneIndex)_\(uniqueId).mp4"
                    print("DEBUG: Attempting upload (attempt \(attempt)/\(maxRetries)) to path: \(path)")
                    
                    // Try to delete any existing file at this path
                    try? await storageService.deleteVideo(at: URL(string: path)!)
                    
                    // Upload the video
                    let url = try await storageService.uploadVideo(
                        url: compressedURL,
                        to: path,
                        metadata: metadata
                    )
                    
                    uploadedUrl = url
                    print("DEBUG: Successfully uploaded to Firebase. Storage URL: \(url)")
                    break
                } catch {
                    lastError = error
                    print("DEBUG: Upload attempt \(attempt) failed: \(error.localizedDescription)")
                    
                    if attempt == maxRetries {
                        throw error
                    }
                    
                    // Wait before retrying
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt))) * 1_000_000_000)
                }
            }
            
            guard let url = uploadedUrl else {
                throw lastError ?? VideoGenerationError.uploadFailed
            }
            
            // Update scene videos array with metadata including generation ID
            await MainActor.run {
                let sceneVideo = AIScript.SceneVideo(
                    sceneIndex: sceneIndex,
                    videoUrl: url,
                    duration: 5.0,
                    status: .completed,
                    metadata: [
                        "sceneId": scene.id,
                        "generatedAt": ISO8601DateFormatter().string(from: Date()),
                        "fileSize": String(try! Data(contentsOf: compressedURL).count),
                        "model": "ray-2",
                        "lumaGenerationId": generationId // Ensure generation ID is included in SceneVideo metadata
                    ]
                )
                
                print("DEBUG: Created scene video object: \(sceneVideo)")
                print("DEBUG: Metadata for scene \(sceneIndex): \(sceneVideo.metadata)")
                print("DEBUG: Generation ID in scene video metadata: \(generationId)")
                print("DEBUG: Updating sceneVideos array at index \(sceneIndex)")
                
                updateSceneVideo(sceneVideo, at: sceneIndex)
                print("DEBUG: Full sceneVideos array after update: \(sceneVideos)")
            }
            
            // Update progress
            updateProgress()
            
            // Clean up temporary files
            try? FileManager.default.removeItem(at: tempURL)
            try? FileManager.default.removeItem(at: compressedURL)
            
            print("DEBUG: Successfully generated and stored video for scene \(sceneIndex)")
            
            // Ensure we have a valid URL before setting up the player
            guard let url = URL(string: url) else {
                print("DEBUG: Invalid storage URL: \(url)")
                throw VideoGenerationError.invalidStorageUrl
            }
            
            print("DEBUG: Setting up video player with URL: \(url)")
            await VideoPlayerManager.shared.cleanup() // Clean up any existing player
            await VideoPlayerManager.shared.setupPlayer(with: url, postId: scene.id)
            VideoPlayerManager.shared.play()
            print("DEBUG: Video player setup completed")
            
        } catch {
            print("DEBUG: Failed to generate video: \(error)")
            self.errorMessage = error.localizedDescription
            generationStatus = .failed(errorMessage: error.localizedDescription)
            // Clean up player
            await VideoPlayerManager.shared.cleanup()
            throw error
        }
    }
    
    /// Save a generated video to Photos library
    @MainActor
    func saveGeneratedVideo(_ video: AIScript.SceneVideo) async throws {
        print("DEBUG: Saving video to Photos library")
        guard let url = URL(string: video.videoUrl) else {
            throw NSError(domain: "SceneVideoGeneration", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid video URL"])
        }
        
        try await storageService.saveVideoToPhotos(from: url)
        print("DEBUG: Successfully saved video to Photos library")
    }
    
    /// Delete a generated video
    @MainActor
    func deleteGeneratedVideo(_ video: AIScript.SceneVideo) async throws {
        print("DEBUG: Deleting video")
        guard let url = URL(string: video.videoUrl) else {
            throw NSError(domain: "SceneVideoGeneration", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid video URL"])
        }
        
        // Delete from storage
        try await storageService.deleteVideo(at: url)
        
        // Update local state
        if let index = sceneVideos.firstIndex(where: { $0?.id == video.id }) {
            sceneVideos[index] = nil
            updateProgress()
        }
        
        print("DEBUG: Successfully deleted video")
    }
    
    /// Clear the current error message
    func clearError() {
        errorMessage = nil
    }
    
    /// Regenerate video for a specific scene
    @MainActor
    func regenerateVideo(for scene: StoryScene) async throws {
        guard let sceneIndex = script.scenes.firstIndex(where: { $0.id == scene.id }) else {
            throw VideoGenerationError.sceneNotFound
        }
        
        guard let existingVideo = sceneVideos[sceneIndex] else {
            throw VideoGenerationError.videoNotFound
        }
        
        print("DEBUG: Regenerating video for scene \(sceneIndex)")
        generationStatus = .inProgress(sceneIndex: sceneIndex)
        
        do {
            // Generate video
            let videoUrl = try await generateVideo(
                scene: scene,
                characterReferences: script.selectedCharacterImages ?? []
            )
            
            // Save video to storage
            let storagePath = "videos/scripts/\(script.id)/scenes/\(sceneIndex).mp4"
            let storageUrl = try await storageService.uploadVideo(
                url: videoUrl,
                to: storagePath,
                metadata: [
                    "scriptId": script.id ?? "",
                    "sceneIndex": String(sceneIndex),
                    "timestamp": Date().ISO8601Format()
                ]
            )
            
            // Create updated scene video
            let updatedSceneVideo = AIScript.SceneVideo(
                sceneIndex: sceneIndex,
                videoUrl: storageUrl,
                duration: 5.0,
                status: .completed,
                metadata: [
                    "generatedAt": Date().ISO8601Format(),
                    "model": "ray-2",
                    "sceneId": scene.id
                ]
            )
            
            // Update scene video in array
            sceneVideos[sceneIndex] = updatedSceneVideo
            
            // Update progress
            updateProgress()
            
            // Update generation status
            if areAllScenesComplete() {
                generationStatus = .completed
            }
            
            print("DEBUG: Successfully regenerated video for scene \(sceneIndex)")
        } catch {
            print("DEBUG: Failed to regenerate video for scene \(sceneIndex): \(error.localizedDescription)")
            generationStatus = .failed(errorMessage: error.localizedDescription)
            throw error
        }
    }
    
    /// Generate a complete video by stitching all scene videos together
    @MainActor
    func generateCompleteVideo() async throws -> URL {
        print("DEBUG: Starting complete video generation")
        print("DEBUG: Current sceneVideos array state:")
        for (index, video) in sceneVideos.enumerated() {
            if let video = video {
                print("DEBUG: Scene \(index): URL = \(video.videoUrl)")
            } else {
                print("DEBUG: Scene \(index): No video")
            }
        }
        
        // Get available videos
        let availableVideos = sceneVideos.compactMap { $0 }
        print("DEBUG: Found \(availableVideos.count) videos to stitch")
        
        guard !availableVideos.isEmpty else {
            print("ERROR: No videos available to stitch")
            throw VideoGenerationError.noVideosAvailable
        }
        
        // Sort videos by scene index to ensure correct order
        let sortedVideos = availableVideos.sorted { $0.sceneIndex < $1.sceneIndex }
        print("DEBUG: Videos sorted by scene index")
        
        // Get video URLs
        let videoUrls = sortedVideos.map { $0.videoUrl }
        print("DEBUG: Video URLs to stitch:")
        videoUrls.forEach { print("DEBUG: URL: \($0)") }
        
        // Build prompt for video stitching
        let stitchingPrompt = """
        Complete story sequence with smooth transitions.
        Title: \(script.title ?? "Untitled Story")
        Story Overview: \(script.scriptOverview ?? "A sequence of historical/mythological scenes")
        Style: Cinematic, high quality, detailed, photorealistic
        Transitions: Create smooth, natural transitions between scenes while maintaining visual consistency and character appearance.
        Scene Count: \(sortedVideos.count) scenes
        Scene Flow: \(script.scenes.map { $0.content }.joined(separator: " → "))
        """
        
        print("DEBUG: Starting video stitching with prompt: \(stitchingPrompt)")
        print("DEBUG: Number of videos to stitch: \(videoUrls.count)")
        
        do {
            // Stitch videos together using Cloudinary
            let cloudinaryUrl = try await stitchingService.stitchVideos(
                videoUrls: videoUrls,
                prompt: stitchingPrompt
            )
            
            print("DEBUG: Video stitching completed successfully")
            print("DEBUG: Cloudinary URL: \(cloudinaryUrl)")
            
            // Download the stitched video
            print("DEBUG: Downloading stitched video")
            let (tempUrl, _) = try await URLSession.shared.download(from: cloudinaryUrl)
            
            // Move to a new temporary location that we control
            let finalTempUrl = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp4")
            
            try FileManager.default.moveItem(at: tempUrl, to: finalTempUrl)
            
            print("DEBUG: Final video saved to temporary location: \(finalTempUrl)")
            return finalTempUrl
            
        } catch {
            print("ERROR: Video stitching failed: \(error)")
            throw error
        }
    }
    
    /// Check if all scenes have completed videos
    func areAllScenesComplete() -> Bool {
        return sceneVideos.count == script.scenes.count &&
            !sceneVideos.contains(where: { $0 == nil }) &&
            sceneVideos.compactMap({ $0 }).allSatisfy { $0.status == .completed }
    }
    
    // MARK: - Private Methods
    
    /// Load any existing videos for the scenes
    @MainActor
    private func loadExistingVideos() async {
        print("DEBUG: Loading existing videos")
        print("DEBUG: Script ID: \(script.id ?? "nil")")
        print("DEBUG: Number of scenes: \(script.scenes.count)")
        
        do {
            // Reset scene videos array
            sceneVideos = Array(repeating: nil, count: script.scenes.count)
            
            // Load videos for each scene
            for index in 0..<script.scenes.count {
                print("DEBUG: Checking for video at scene index \(index)")
                
                // Try to get video URL and metadata for this scene
                do {
                    let (videoUrl, metadata) = try await storageService.getSceneVideoURLAndMetadata(
                        scriptId: script.id ?? "",
                        sceneIndex: index
                    )
                    print("DEBUG: Found video for scene \(index): \(videoUrl)")
                    print("DEBUG: Retrieved metadata: \(metadata)")
                    
                    // Verify we have the generation ID
                    guard let generationId = metadata["lumaGenerationId"] else {
                        print("DEBUG: No Luma generation ID found in metadata for scene \(index)")
                        continue
                    }
                    print("DEBUG: Found Luma generation ID: \(generationId) for scene \(index)")
                    
                    // Create scene video object with complete metadata
                    let sceneVideo = AIScript.SceneVideo(
                        sceneIndex: index,
                        videoUrl: videoUrl,
                        duration: 5.0,
                        status: .completed,
                        metadata: [
                            "generatedAt": metadata["generatedAt"] ?? Date().ISO8601Format(),
                            "model": metadata["model"] ?? "ray-2",
                            "sceneId": script.scenes[index].id,
                            "lumaGenerationId": generationId // Include the generation ID
                        ]
                    )
                    
                    // Update scene videos array
                    sceneVideos[index] = sceneVideo
                    print("DEBUG: Added video to sceneVideos array at index \(index)")
                    print("DEBUG: Scene video metadata: \(sceneVideo.metadata)")
                } catch {
                    print("DEBUG: No video found for scene \(index): \(error.localizedDescription)")
                }
            }
            
            // Log final state
            print("DEBUG: Final sceneVideos array state:")
            for (index, video) in sceneVideos.enumerated() {
                if let video = video {
                    print("DEBUG: Scene \(index): URL = \(video.videoUrl)")
                    print("DEBUG: Scene \(index) metadata: \(video.metadata)")
                } else {
                    print("DEBUG: Scene \(index): No video")
                }
            }
            
            // Update progress and status
            updateProgress()
            if areAllScenesComplete() {
                generationStatus = .completed
                print("DEBUG: All scenes are complete")
            } else {
                print("DEBUG: Not all scenes are complete. Found \(sceneVideos.compactMap { $0 }.count) videos out of \(script.scenes.count) scenes")
            }
            
        } catch {
            print("ERROR: Failed to load existing videos: \(error)")
            errorMessage = "Failed to load existing videos: \(error.localizedDescription)"
        }
    }
    
    /// Update the overall progress based on generated videos
    private func updateProgress() {
        let completedVideos = Double(sceneVideos.compactMap { $0 }.count)
        progress = completedVideos / Double(script.scenes.count)
    }
    
    /// Generate video using Luma AI
    private func generateVideo(scene: StoryScene, characterReferences: [String]) async throws -> URL {
        print("DEBUG: Starting Luma AI video generation")
        
        // Build enhanced prompt for video generation
        let enhancedPrompt = """
        Scene: \(scene.content)
        Style: Clear, photorealistic, minimal artifacts
        Transition: Simple, static-focused with minimal movement
        Start: \(scene.startKeyframe.prompt ?? "")
        End: \(scene.endKeyframe.prompt ?? "")
        
        Requirements:
        - Maintain exact character appearance
        - Static composition with minimal motion
        - Simple, uncluttered background
        - Maximum 1-2 characters
        - Essential elements only
        - No camera movement
        - Consistent lighting
        """
        print("DEBUG: Prompt: \(enhancedPrompt)")
        
        // Validate keyframe URLs
        guard let startKeyframeUrl = scene.startKeyframe.imageUrl,
              let endKeyframeUrl = scene.endKeyframe.imageUrl else {
            throw VideoGenerationError.invalidKeyframes
        }
        
        // Create keyframes dictionary
        let keyframes: [String: LumaAIService.Keyframe] = [
            "frame0": .init(
                type: "image",
                url: startKeyframeUrl
            ),
            "frame1": .init(
                type: "image",
                url: endKeyframeUrl
            )
        ]
        
        // Generate the video
        let lumaVideoUrl = try await lumaService.generateVideo(
            prompt: enhancedPrompt,
            keyframes: keyframes
        )
        
        // Download the video to a local temporary URL
        let (tempUrl, _) = try await URLSession.shared.download(from: lumaVideoUrl)
        
        // Move to a new temporary location that we control
        let newTempUrl = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        try FileManager.default.moveItem(at: tempUrl, to: newTempUrl)
        print("DEBUG: Video downloaded to temporary URL: \(newTempUrl)")
        
        return newTempUrl
    }
    
    @MainActor
    private func updateSceneVideo(_ video: AIScript.SceneVideo, at index: Int) {
        print("DEBUG: Updating scene video at index \(index)")
        print("DEBUG: Before update - sceneVideos count: \(sceneVideos.count)")
        
        // Ensure array is properly sized
        while sceneVideos.count <= index {
            sceneVideos.append(nil)
        }
        
        // Create a new array to force a state update
        var newSceneVideos = sceneVideos
        newSceneVideos[index] = video
        sceneVideos = newSceneVideos
        
        print("DEBUG: After update - sceneVideos count: \(sceneVideos.count)")
        print("DEBUG: Video at index \(index): \(String(describing: sceneVideos[index]))")
    }
    
    /// Video generation errors
    enum VideoGenerationError: LocalizedError {
        case sceneNotFound
        case invalidKeyframes
        case uploadFailed
        case videoNotFound
        case videoNotAccessible
        case invalidStorageUrl
        case invalidScriptId
        case incompleteScenes
        case noVideosAvailable
        case missingGenerationId
        case cloudinaryConfigurationMissing
        
        var errorDescription: String? {
            switch self {
            case .sceneNotFound:
                return "Scene not found in script"
            case .invalidKeyframes:
                return "Invalid or missing keyframe URLs"
            case .uploadFailed:
                return "Failed to upload video to storage"
            case .videoNotFound:
                return "Generated video file not found"
            case .videoNotAccessible:
                return "Generated video is not accessible"
            case .invalidStorageUrl:
                return "Invalid storage URL returned"
            case .invalidScriptId:
                return "Script ID is missing or invalid"
            case .incompleteScenes:
                return "Cannot generate complete video: some scenes are missing videos"
            case .noVideosAvailable:
                return "No videos available to stitch together"
            case .missingGenerationId:
                return "Missing Luma AI generation ID in video metadata"
            case .cloudinaryConfigurationMissing:
                return "Cloudinary configuration is missing. Please check environment variables."
            }
        }
    }
} 