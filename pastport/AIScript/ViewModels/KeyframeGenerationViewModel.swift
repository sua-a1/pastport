import Foundation
import SwiftUI
import FirebaseFirestore
import Observation

// Import our models
import struct pastport.ReferenceImage
import struct pastport.Keyframe
import class pastport.StoryScene

/// ViewModel for managing keyframe generation and editing
@Observable final class KeyframeGenerationViewModel {
    // MARK: - Types
    
    /// States for the keyframe generation process
    enum GenerationState: Equatable {
        case initial
        case selectingImages
        case generating
        case preview
        case completed
        case failed(Error)
        
        static func == (lhs: GenerationState, rhs: GenerationState) -> Bool {
            switch (lhs, rhs) {
            case (.initial, .initial),
                 (.selectingImages, .selectingImages),
                 (.generating, .generating),
                 (.preview, .preview),
                 (.completed, .completed):
                return true
            case (.failed(let lhsError), .failed(let rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }
        }
    }
    
    enum KeyframeGenerationError: LocalizedError {
        case invalidState(String)
        case generationFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidState(let message):
                return "Invalid state: \(message)"
            case .generationFailed(let message):
                return "Generation failed: \(message)"
            }
        }
    }
    
    // MARK: - Properties
    
    /// The script being edited
    private(set) var script: AIScript
    
    /// Index of the current scene
    let sceneIndex: Int
    
    /// Current state of the view model
    private(set) var state: GenerationState = .initial
    
    /// Selected reference images with weights
    private(set) var selectedImages: [ReferenceImage] = []
    
    /// Whether keyframes are currently generating
    var isGenerating: Bool {
        state == .generating
    }
    
    /// Error message if any
    private(set) var errorMessage: String?
    
    /// Start keyframe prompt
    var startKeyframePrompt: String {
        get { script.scenes[sceneIndex].startKeyframe.prompt ?? "" }
        set {
            var updatedScript = script
            updatedScript.scenes[sceneIndex].startKeyframe.prompt = newValue
            // Use Task to handle async operation
            Task {
                do {
                    try await scriptService.saveScript(updatedScript)
                    self.script = updatedScript
                } catch {
                    print("ERROR: Failed to save start keyframe prompt: \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// End keyframe prompt
    var endKeyframePrompt: String {
        get { script.scenes[sceneIndex].endKeyframe.prompt ?? "" }
        set {
            var updatedScript = script
            updatedScript.scenes[sceneIndex].endKeyframe.prompt = newValue
            // Use Task to handle async operation
            Task {
                do {
                    try await scriptService.saveScript(updatedScript)
                    self.script = updatedScript
                } catch {
                    print("ERROR: Failed to save end keyframe prompt: \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    var availableImages: [ReferenceImage] {
        // Combine character and reference images
        var images: [ReferenceImage] = []
        
        if let characterImages = script.selectedCharacterImages {
            images += characterImages.map { url in
                ReferenceImage(
                    url: url,
                    type: .character,
                    weight: 0.5
                )
            }
        }
        
        if let referenceImages = script.selectedReferenceImages {
            images += referenceImages.map { url in
                ReferenceImage(
                    url: url,
                    type: .reference,
                    weight: 0.5
                )
            }
        }
        
        return images
    }
    
    // MARK: - Private Properties
    
    private var currentScene: StoryScene {
        script.scenes[sceneIndex]
    }
    
    private let scriptService: AIScriptService
    
    // MARK: - Initialization
    
    init(script: AIScript, scene: StoryScene, sceneIndex: Int) throws {
        self.scriptService = try AIScriptService()
        self.script = script
        self.sceneIndex = sceneIndex
        print("DEBUG: Initialized KeyframeGenerationViewModel for scene \(sceneIndex)")
    }
    
    // MARK: - Public Methods
    
    /// Add a reference image
    /// - Parameters:
    ///   - url: URL of the image
    ///   - weight: Weight of the image in generation (0.0 - 1.0)
    func addReferenceImage(url: String, weight: Double = 0.5) {
        print("DEBUG: Adding reference image: \(url) with weight: \(weight)")
        let image = ReferenceImage(url: url, weight: weight)
        selectedImages.append(image)
        state = .selectingImages
    }
    
    /// Remove a reference image
    /// - Parameter url: URL of the image to remove
    func removeReferenceImage(url: String) {
        print("DEBUG: Removing reference image: \(url)")
        selectedImages.removeAll { $0.url == url }
    }
    
    /// Update the weight of a reference image
    /// - Parameters:
    ///   - url: URL of the image
    ///   - weight: New weight value
    func updateImageWeight(url: String, weight: Double) {
        print("DEBUG: Updating weight for image \(url) to \(weight)")
        guard let index = selectedImages.firstIndex(where: { $0.url == url }) else { return }
        selectedImages[index] = ReferenceImage(url: url, weight: weight)
    }
    
    /// Generate keyframes with current settings
    func generateKeyframes() async {
        print("DEBUG: Starting keyframe generation")
        state = .generating
        errorMessage = nil
        
        do {
            // Update prompts in script
            var updatedScript = script
            
            // Convert ReferenceImage to Keyframe.SelectedImage
            let selectedKeyframeImages = selectedImages.map { refImage in
                Keyframe.SelectedImage(url: refImage.url, weight: refImage.weight)
            }
            
            // Update both keyframes with selected images
            updatedScript.scenes[sceneIndex].startKeyframe.selectedImages = selectedKeyframeImages
            updatedScript.scenes[sceneIndex].endKeyframe.selectedImages = selectedKeyframeImages
            
            // Generate keyframes
            let result = try await scriptService.generateKeyframes(updatedScript, forSceneIndex: sceneIndex)
            
            // Update state based on result
            if result.scenes[sceneIndex].startKeyframe.status == .completed &&
               result.scenes[sceneIndex].endKeyframe.status == .completed {
                state = .completed
                print("DEBUG: Keyframe generation completed successfully")
            } else {
                throw KeyframeGenerationError.generationFailed("Generation did not complete")
            }
            
        } catch {
            print("ERROR: Keyframe generation failed: \(error.localizedDescription)")
            handleError(error)
        }
    }
    
    /// Regenerate keyframes
    func regenerateKeyframes() async {
        print("DEBUG: Regenerating keyframes")
        await generateKeyframes()
    }
    
    /// Reset the generation process
    func reset() {
        print("DEBUG: Resetting keyframe generation")
        state = .initial
        errorMessage = nil
        selectedImages = []
    }
    
    // MARK: - Private Methods
    
    private func handleError(_ error: Error) {
        print("DEBUG: Handling error: \(error.localizedDescription)")
        state = .failed(error)
        errorMessage = error.localizedDescription
    }
} 