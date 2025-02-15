import Foundation
import SwiftUI
import FirebaseFirestore

/// ViewModel for managing the script generation flow
@Observable final class ScriptGenerationViewModel {
    // MARK: - Types
    
    /// States for the generation process
    enum GenerationState {
        case initial
        case selectingCharacter
        case selectingReferences
        case generatingScenes
        case editingKeyframes(sceneIndex: Int)
        case completed
        case failed(Error)
    }
    
    /// Errors that can occur during script generation
    enum AIScriptError: LocalizedError {
        case invalidState(String)
        case scriptGenerationFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidState(let message):
                return "Invalid state: \(message)"
            case .scriptGenerationFailed(let message):
                return "Script generation failed: \(message)"
            }
        }
    }
    
    /// Errors that can occur during keyframe generation
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
    
    /// Current state of the view model
    private(set) var state: GenerationState = .initial
    
    // MARK: - Properties
    
    /// The draft to generate script from
    let draftId: String
    
    /// The user ID
    let userId: String
    
    /// Currently selected character ID
    private(set) var selectedCharacterId: String?
    
    /// Available character images
    private(set) var characterImages: [ReferenceImage] = []
    
    /// Available reference images
    private(set) var referenceImages: [ReferenceImage] = []
    
    /// Selected character reference images
    private(set) var selectedCharacterImages: [ReferenceImage] = []
    
    /// Selected reference images
    private(set) var selectedReferenceImages: [ReferenceImage] = []
    
    /// Selected reference text IDs
    private(set) var selectedReferenceTextIds: [String] = []
    
    /// Available reference texts
    private(set) var referenceTexts: [ReferenceText] = []
    
    /// The current script being generated
    private(set) var script: AIScript?
    
    /// Generation progress (0.0 - 1.0)
    private(set) var progress: Double = 0.0
    
    /// Error message if any
    private(set) var errorMessage: String?
    
    /// Loading state
    var isLoading = false
    
    /// Error state
    var error: Error?
    
    /// The current draft being edited
    private(set) var draft: Draft?
    
    // MARK: - Services
    
    private let scriptService: AIScriptService
    private let referenceImageService: ReferenceImageService
    
    // MARK: - Computed Properties
    
    /// Get available character images
    var availableCharacterImages: [ReferenceImage] {
        // Filter and validate character images
        characterImages.filter { image in
            // Only include images that pass validation
            referenceImageService.validateCharacterSelection(image.id, images: [image]) == nil
        }
    }
    
    /// Get available reference images
    var availableReferenceImages: [ReferenceImage] {
        referenceImages
    }
    
    // MARK: - Initialization
    
    init(draftId: String, userId: String) throws {
        print("DEBUG: Initializing ScriptGenerationViewModel for draft \(draftId)")
        self.draftId = draftId
        self.userId = userId
        
        do {
            self.scriptService = try AIScriptService()
            self.referenceImageService = ReferenceImageService(draftId: draftId)
        } catch {
            print("ERROR: Failed to initialize services: \(error.localizedDescription)")
            self.state = .failed(error)
            // Force try since we're in a failing state anyway
            self.scriptService = try! AIScriptService()
            self.referenceImageService = ReferenceImageService(draftId: draftId)
        }
    }
    
    // MARK: - Public Methods
    
    /// Load saved script if it exists
    @MainActor
    func loadSavedScript() async {
        print("DEBUG: Loading saved script for draft \(draftId)")
        do {
            if let savedScript = try await scriptService.loadScript(draftId: draftId, userId: userId) {
                self.script = savedScript
                
                // Restore state based on script status
                switch savedScript.status {
                case .draft:
                    state = .selectingCharacter
                case .generatingScript:
                    state = .generatingScenes
                case .editingKeyframes:
                    if let firstIncompleteScene = savedScript.scenes.firstIndex(where: { !isSceneComplete($0) }) {
                        state = .editingKeyframes(sceneIndex: firstIncompleteScene)
                    } else {
                        state = .editingKeyframes(sceneIndex: 0)
                    }
                case .completed:
                    state = .completed
                case .failed:
                    state = .failed(AIScriptError.invalidState("Script generation failed"))
                case .generatingVideo:
                    state = .completed // Treat as completed for script generation view
                }
                
                // Restore selected images and references
                if let characterImages = savedScript.selectedCharacterImages {
                    self.selectedCharacterImages = characterImages.compactMap { url in
                        self.characterImages.first { $0.url == url }
                    }
                }
                if let referenceImages = savedScript.selectedReferenceImages {
                    self.selectedReferenceImages = referenceImages.compactMap { url in
                        self.referenceImages.first { $0.url == url }
                    }
                }
                self.selectedReferenceTextIds = savedScript.selectedReferenceTextIds ?? []
                
                print("DEBUG: Successfully loaded saved script with status: \(savedScript.status)")
            } else {
                print("DEBUG: No saved script found for draft \(draftId)")
                state = .selectingCharacter
            }
        } catch {
            print("ERROR: Failed to load saved script: \(error.localizedDescription)")
            handleError(error)
        }
    }
    
    /// Start the generation process
    func startGeneration() async {
        print("DEBUG: Starting generation process")
        await loadSavedScript() // Load any existing script first
        errorMessage = nil
    }
    
    /// Select a character for the script
    /// - Parameters:
    ///   - characterId: The character ID
    ///   - images: Character reference images
    func selectCharacter(id characterId: String, images: [ReferenceImage]) {
        print("DEBUG: Selecting character \(characterId) with \(images.count) images")
        
        // Validate character selection
        if let error = referenceImageService.validateCharacterSelection(characterId, images: images) {
            print("ERROR: Invalid character selection: \(error.localizedDescription)")
            handleError(error)
            return
        }
        
        // Ensure all images are properly weighted
        let weightedImages = images.map { image in
            var newImage = image
            newImage.weight = min(max(image.weight, 0.0), 1.0)
            return newImage
        }
        
        print("DEBUG: Successfully selected character \(characterId)")
        self.selectedCharacterId = characterId
        self.selectedCharacterImages = weightedImages
        state = .selectingReferences
        progress = 0.2
    }
    
    /// Skip character selection
    func skipCharacterSelection() {
        print("DEBUG: Skipping character selection")
        self.selectedCharacterId = nil
        self.selectedCharacterImages = []
        state = .selectingReferences
        progress = 0.2
    }
    
    /// Select reference materials
    /// - Parameters:
    ///   - referenceImages: Reference images
    ///   - characterImages: Character images
    ///   - textIds: Reference text IDs
    func selectReferences(
        referenceImages: [ReferenceImage],
        characterImages: [ReferenceImage],
        textIds: [String]
    ) {
        print("DEBUG: Selected \(referenceImages.count) reference images, \(characterImages.count) character images, and \(textIds.count) reference texts")
        self.selectedReferenceImages = referenceImages
        self.selectedCharacterImages = characterImages
        self.selectedReferenceTextIds = textIds
        progress = 0.4
    }
    
    /// Generate scenes after reference selection
    func generateScenes() async {
        print("DEBUG: Starting scene generation")
        state = .generatingScenes
        progress = 0.5
        isLoading = true // Set loading state at start
        
        do {
            // Start script generation
            let script = try await scriptService.startScriptGeneration(
                draftId: draftId,
                userId: userId,
                characterId: selectedCharacterId,
                characterImages: selectedCharacterImages.map { $0.url },
                referenceImages: selectedReferenceImages.map { $0.url },
                referenceTextIds: selectedReferenceTextIds
            )
            self.script = script
            
            // Generate scenes
            let updatedScript = try await scriptService.generateScenes(script)
            self.script = updatedScript
            
            // Move to keyframe editing for first scene
            state = .editingKeyframes(sceneIndex: 0)
            progress = 0.7
            print("DEBUG: Successfully generated scenes")
            isLoading = false // Set loading state to false on success
            
        } catch {
            print("ERROR: Scene generation failed: \(error.localizedDescription)")
            handleError(error)
            isLoading = false // Set loading state to false on error
        }
    }
    
    /// Generate keyframes for a scene
    /// - Parameter sceneIndex: Index of the scene
    func generateKeyframes(forSceneIndex sceneIndex: Int) async {
        guard let script = script else {
            print("ERROR: No script available for keyframe generation")
            handleError(KeyframeGenerationError.invalidState("No script available"))
            return
        }
        
        print("DEBUG: Generating keyframes for scene \(sceneIndex)")
        
        do {
            let updatedScript = try await scriptService.generateKeyframes(script, forSceneIndex: sceneIndex)
            self.script = updatedScript
            
            // Update progress
            let progressPerScene = 0.3 / Double(script.scenes.count)
            progress = 0.7 + (Double(sceneIndex + 1) * progressPerScene)
            
            // Move to next scene or complete
            if sceneIndex < script.scenes.count - 1 {
                state = .editingKeyframes(sceneIndex: sceneIndex + 1)
            } else {
                state = .completed
                progress = 1.0
            }
            
            print("DEBUG: Successfully generated keyframes for scene \(sceneIndex)")
            
        } catch {
            print("ERROR: Keyframe generation failed: \(error.localizedDescription)")
            handleError(error)
        }
    }
    
    /// Regenerate keyframes for a scene
    /// - Parameter sceneIndex: Index of the scene
    func regenerateKeyframes(forSceneIndex sceneIndex: Int) async {
        print("DEBUG: Regenerating keyframes for scene \(sceneIndex)")
        await generateKeyframes(forSceneIndex: sceneIndex)
    }
    
    /// Reset the generation process
    func reset() {
        print("DEBUG: Resetting generation process")
        state = .initial
        progress = 0.0
        errorMessage = nil
        selectedCharacterId = nil
        selectedCharacterImages = []
        selectedReferenceImages = []
        selectedReferenceTextIds = []
        script = nil
    }
    
    /// Prepare for video generation by updating script status
    func prepareForVideoGeneration() async {
        guard let script = script else {
            print("ERROR: No script available for video generation")
            handleError(AIScriptError.invalidState("No script available"))
            return
        }
        
        do {
            // Update script status to generating video
            var updatedScript = script
            updatedScript.status = .generatingVideo
            self.script = try await scriptService.saveScript(updatedScript)
            print("DEBUG: Script status updated to generating video")
        } catch {
            print("ERROR: Failed to prepare for video generation: \(error.localizedDescription)")
            handleError(error)
        }
    }
    
    /// Delete the current script and its resources
    func deleteScript() async {
        print("DEBUG: Deleting script")
        if let script = script {
            do {
                try await scriptService.deleteScript(script)
                reset() // Reset local state
                print("DEBUG: Successfully deleted script")
            } catch {
                print("ERROR: Failed to delete script: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Load available reference images
    @MainActor
    func loadReferenceImages() async {
        print("DEBUG: Starting to load reference images for draft: \(draftId)")
        isLoading = true
        errorMessage = nil
        
        do {
            // Load images
            try await referenceImageService.loadAvailableImages(for: userId)
            
            // Get the loaded images
            let loadedCharacterImages = referenceImageService.characterImages
            let loadedReferenceImages = referenceImageService.referenceImages
            
            print("DEBUG: Loaded \(loadedCharacterImages.count) character images")
            print("DEBUG: Character image URLs:")
            loadedCharacterImages.forEach { image in
                print("- \(image.url)")
            }
            
            print("DEBUG: Loaded \(loadedReferenceImages.count) reference images")
            print("DEBUG: Reference image URLs:")
            loadedReferenceImages.forEach { image in
                print("- \(image.url)")
            }
            
            // Update the view model's properties
            self.characterImages = loadedCharacterImages
            self.referenceImages = loadedReferenceImages
            
            // Load reference texts after images are loaded
            await loadReferenceTexts()
            
        } catch {
            print("ERROR: Failed to load reference images: \(error.localizedDescription)")
            print("ERROR: Detailed error: \(error)")
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Toggle character selection
    func toggleCharacterSelection(_ character: ReferenceImage) {
        if selectedCharacterImages.contains(where: { $0.id == character.id }) {
            selectedCharacterImages.removeAll { $0.id == character.id }
        } else {
            selectedCharacterImages.append(character)
        }
    }
    
    /// Toggle reference image selection
    func toggleReferenceSelection(_ reference: ReferenceImage) {
        if selectedReferenceImages.contains(where: { $0.id == reference.id }) {
            selectedReferenceImages.removeAll { $0.id == reference.id }
        } else {
            selectedReferenceImages.append(reference)
        }
    }
    
    /// Generate script based on selected images
    @MainActor
    func generateScript() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // TODO: Implement script generation
            // This will be implemented once we have the AIScriptService
            isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    /// Generate keyframe for a scene
    @MainActor
    func generateKeyframe(for scene: StoryScene, isStart: Bool) async {
        guard let sceneIndex = script?.scenes.firstIndex(where: { $0.id == scene.id }) else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // TODO: Implement keyframe generation
            // This will be implemented once we have the AIScriptService
            isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    /// Clear the current error message
    func clearError() {
        errorMessage = nil
    }
    
    /// Load the draft data
    @MainActor
    func loadDraft() async {
        print("DEBUG: Loading draft data for ID: \(draftId)")
        do {
            let db = Firestore.firestore()
            let draftDoc = try await db.collection("users")
                .document(userId)
                .collection("drafts")
                .document(draftId)
                .getDocument()
            
            if let data = draftDoc.data(),
               let draft = Draft.fromFirestore(data, id: draftDoc.documentID) {
                print("DEBUG: Successfully loaded draft: \(draft.title)")
                self.draft = draft
            } else {
                print("ERROR: Failed to parse draft data")
                handleError(KeyframeGenerationError.invalidState("Failed to load draft data"))
            }
        } catch {
            print("ERROR: Failed to load draft: \(error.localizedDescription)")
            handleError(error)
        }
    }
    
    /// Update the draft content
    @MainActor
    func updateDraftContent(_ newContent: String) async {
        print("DEBUG: Updating draft content")
        do {
            let db = Firestore.firestore()
            try await db.collection("users")
                .document(userId)
                .collection("drafts")
                .document(draftId)
                .updateData([
                    "content": newContent,
                    "updatedAt": Date()
                ])
            
            // Update local draft
            var updatedDraft = draft
            updatedDraft?.content = newContent
            updatedDraft?.updatedAt = Date()
            self.draft = updatedDraft
            
            print("DEBUG: Successfully updated draft content")
        } catch {
            print("ERROR: Failed to update draft content: \(error.localizedDescription)")
            handleError(error)
        }
    }
    
    /// Load reference texts for the draft
    @MainActor
    func loadReferenceTexts() async {
        print("DEBUG: Loading reference texts for draft \(draftId)")
        do {
            let db = Firestore.firestore()
            referenceTexts = []
            
            guard let draft = draft else {
                print("DEBUG: No draft available, skipping reference text loading")
                return
            }
            
            for id in draft.referenceTextIds {
                print("DEBUG: Fetching reference with ID: \(id)")
                let docRef = db.collection("users")
                    .document(userId)
                    .collection("referenceTexts")
                    .document(id)
                
                let doc = try await docRef.getDocument()
                print("DEBUG: Got document for reference \(id). Exists: \(doc.exists)")
                
                if doc.exists {
                    print("DEBUG: Document data: \(doc.data() ?? [:])")
                    if let reference = ReferenceText.fromFirestore(doc.data() ?? [:], id: doc.documentID) {
                        print("DEBUG: Successfully parsed reference: \(reference.title)")
                        referenceTexts.append(reference)
                    } else {
                        print("DEBUG: Failed to parse reference from data")
                    }
                }
            }
            
            print("DEBUG: Finished loading reference texts. Found: \(referenceTexts.count)")
        } catch {
            print("ERROR: Failed to load reference texts: \(error.localizedDescription)")
            handleError(error)
        }
    }
    
    // MARK: - Private Methods
    
    private func handleError(_ error: Error) {
        print("ERROR: Handling error: \(error.localizedDescription)")
        state = .failed(error)
        errorMessage = error.localizedDescription
    }
    
    /// Check if a scene is complete
    private func isSceneComplete(_ scene: StoryScene) -> Bool {
        return scene.startKeyframe.status == .completed && scene.endKeyframe.status == .completed
    }
    
    /// Check if all scenes are complete
    private func areAllScenesComplete() -> Bool {
        guard let script = script, !script.scenes.isEmpty else { return false }
        return script.scenes.allSatisfy { isSceneComplete($0) }
    }
} 