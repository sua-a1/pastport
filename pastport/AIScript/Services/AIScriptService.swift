import Foundation
import FirebaseFirestore

/// Service for managing AI script generation flow
actor AIScriptService {
    // MARK: - Types
    
    enum AIScriptError: LocalizedError {
        case invalidDraft
        case scriptGenerationFailed(String)
        case keyframeGenerationFailed(String)
        case saveFailed(String)
        case notFound
        case invalidState(String)
        case invalidSceneIndex
        
        var errorDescription: String? {
            switch self {
            case .invalidDraft:
                return "Invalid draft data"
            case .scriptGenerationFailed(let message):
                return "Script generation failed: \(message)"
            case .keyframeGenerationFailed(let message):
                return "Keyframe generation failed: \(message)"
            case .saveFailed(let message):
                return "Failed to save script: \(message)"
            case .notFound:
                return "Script not found"
            case .invalidState(let message):
                return "Invalid state: \(message)"
            case .invalidSceneIndex:
                return "Invalid scene index"
            }
        }
    }
    
    // MARK: - Properties
    
    private let db: Firestore
    private let openAIService: OpenAIService
    private let lumaAIService: LumaAIService
    
    // MARK: - Initialization
    
    init(
        db: Firestore = Firestore.firestore(),
        openAIService: OpenAIService? = nil,
        lumaAIService: LumaAIService? = nil
    ) throws {
        self.db = db
        self.openAIService = try openAIService ?? OpenAIService()
        self.lumaAIService = try lumaAIService ?? LumaAIService()
    }
    
    // MARK: - Public Methods
    
    /// Start script generation from a draft
    /// - Parameters:
    ///   - draftId: ID of the draft to generate from
    ///   - userId: ID of the user
    ///   - characterId: Optional character ID to use
    ///   - characterImages: Optional character reference images
    ///   - referenceImages: Optional reference images
    ///   - referenceTextIds: Optional reference text IDs
    /// - Returns: The created AIScript object
    func startScriptGeneration(
        draftId: String,
        userId: String,
        characterId: String? = nil,
        characterImages: [String]? = nil,
        referenceImages: [String]? = nil,
        referenceTextIds: [String]? = nil
    ) async throws -> AIScript {
        print("DEBUG: Starting script generation for draft \(draftId)")
        
        // Create initial script document
        let script = AIScript(
            draftId: draftId,
            userId: userId,
            scenes: [],
            status: AIScript.Status.draft,
            createdAt: Date(),
            updatedAt: Date(),
            selectedCharacterId: characterId,
            selectedCharacterImages: characterImages,
            selectedReferenceImages: referenceImages,
            selectedReferenceTextIds: referenceTextIds
        )
        
        // Save initial state and get updated script with ID
        let savedScript = try await saveScript(script)
        print("DEBUG: Created initial script document with ID: \(savedScript.id ?? "unknown")")
        
        return savedScript
    }
    
    /// Generate scenes for a script
    /// - Parameter script: The script to generate scenes for
    /// - Returns: Updated script with generated scenes
    func generateScenes(_ script: AIScript) async throws -> AIScript {
        guard let scriptId = script.id else {
            print("ERROR: Script has no ID")
            throw AIScriptError.invalidDraft
        }
        
        print("DEBUG: Generating scenes for script \(scriptId)")
        
        // Update status
        var updatedScript = script
        updatedScript.status = AIScript.Status.generatingScript
        updatedScript = try await saveScript(updatedScript)
        
        do {
            print("DEBUG: Attempting to fetch draft content for draft \(script.draftId)")
            // Fetch draft content and reference texts
            let (content, referenceTexts) = try await fetchDraftContent(
                draftId: script.draftId,
                userId: script.userId,
                referenceTextIds: script.selectedReferenceTextIds
            )
            print("DEBUG: Successfully fetched draft content: \(content.prefix(100))...")
            print("DEBUG: Fetched \(referenceTexts?.count ?? 0) reference texts")
            
            // Generate scenes using OpenAI
            let generatedContent = try await openAIService.generateScenes(
                content: content,
                referenceTexts: referenceTexts,
                characterDescription: nil // TODO: Fetch character description if needed
            )
            print("DEBUG: Generated \(generatedContent.scenes.count) scenes")
            
            // Store script overview
            updatedScript.scriptOverview = generatedContent.scriptOverview
            print("DEBUG: Generated script overview: \(generatedContent.scriptOverview)")
            
            // Convert to Scene models
            updatedScript.scenes = generatedContent.scenes.enumerated().map { index, sceneContent in
                StoryScene(
                    order: index,
                    content: sceneContent.content,
                    startKeyframe: Keyframe(prompt: sceneContent.startKeyframePrompt),
                    endKeyframe: Keyframe(prompt: sceneContent.endKeyframePrompt)
                )
            }
            
            updatedScript.status = AIScript.Status.editingKeyframes
            updatedScript = try await saveScript(updatedScript)
            print("DEBUG: Saved generated scenes and script overview")
            
            return updatedScript
        } catch {
            // Handle failure
            updatedScript.status = AIScript.Status.failed
            _ = try await saveScript(updatedScript)
            print("ERROR: Scene generation failed: \(error.localizedDescription)")
            throw AIScriptError.scriptGenerationFailed(error.localizedDescription)
        }
    }
    
    /// Generate keyframes for a scene
    /// - Parameters:
    ///   - script: The script containing the scene
    ///   - sceneIndex: Index of the scene to generate keyframes for
    /// - Returns: Updated script with generated keyframes
    func generateKeyframes(_ script: AIScript, forSceneIndex sceneIndex: Int) async throws -> AIScript {
        guard let scriptId = script.id else {
            throw AIScriptError.invalidDraft
        }
        
        print("DEBUG: Generating keyframes for scene \(sceneIndex) in script \(scriptId)")
        
        // Validate scene index
        guard sceneIndex >= 0 && sceneIndex < script.scenes.count else {
            throw AIScriptError.invalidSceneIndex
        }
        
        var updatedScript = script
        var updatedScene = script.scenes[sceneIndex]
        
        // Update keyframe statuses
        updatedScene.startKeyframe.status = .generating
        updatedScene.endKeyframe.status = .generating
        updatedScript.scenes[sceneIndex] = updatedScene
        updatedScript = try await saveScript(updatedScript)
        
        do {
            // Convert reference images to ReferenceImage objects
            let references = script.selectedReferenceImages?.map { url in
                LumaAIService.ReferenceImage(url: url, prompt: nil, weight: 0.5)
            }
            
            // Convert character images to character references
            let characterReferences = script.selectedCharacterImages ?? []
            
            // Get the previous scene's end keyframe URL if available
            let previousSceneEndKeyframe = sceneIndex > 0 ? script.scenes[sceneIndex - 1].endKeyframe.imageUrl : nil
            
            print("DEBUG: Script overview: \(script.scriptOverview ?? "none")")
            
            // Generate both keyframes
            let (startUrl, endUrl) = try await lumaAIService.generateSceneKeyframes(
                startPrompt: updatedScene.startKeyframe.prompt ?? "Scene start: \(updatedScene.content)",
                endPrompt: updatedScene.endKeyframe.prompt ?? "Scene end: \(updatedScene.content)",
                visualDescription: updatedScene.content,
                references: references,
                characterReferences: characterReferences,
                previousSceneEndKeyframe: previousSceneEndKeyframe,
                scriptOverview: script.scriptOverview
            )
            
            print("DEBUG: Generated keyframes for scene \(sceneIndex)")
            print("DEBUG: Start keyframe: \(startUrl)")
            print("DEBUG: End keyframe: \(endUrl)")
            print("DEBUG: Previous scene end keyframe used: \(previousSceneEndKeyframe ?? "none")")
            
            // Update scene with generated images
            updatedScene.startKeyframe.imageUrl = startUrl
            updatedScene.startKeyframe.status = Keyframe.Status.completed
            updatedScene.endKeyframe.imageUrl = endUrl
            updatedScene.endKeyframe.status = Keyframe.Status.completed
            updatedScript.scenes[sceneIndex] = updatedScene
            
            // Check if all scenes have completed keyframes
            let allKeyframesCompleted = updatedScript.scenes.allSatisfy { scene in
                scene.startKeyframe.status == Keyframe.Status.completed && scene.endKeyframe.status == Keyframe.Status.completed
            }
            
            if allKeyframesCompleted {
                updatedScript.status = AIScript.Status.completed
                print("DEBUG: All keyframes completed for script \(scriptId)")
            }
            
            try await saveScript(updatedScript)
            return updatedScript
            
        } catch {
            // Handle failure
            updatedScene.startKeyframe.status = Keyframe.Status.failed
            updatedScene.endKeyframe.status = Keyframe.Status.failed
            updatedScript.scenes[sceneIndex] = updatedScene
            try await saveScript(updatedScript)
            
            print("ERROR: Keyframe generation failed: \(error.localizedDescription)")
            throw AIScriptError.keyframeGenerationFailed(error.localizedDescription)
        }
    }
    
    /// Load a script by ID
    /// - Parameter id: The script ID
    /// - Returns: The loaded script
    func loadScript(_ id: String) async throws -> AIScript {
        print("DEBUG: Loading script \(id)")
        
        let docRef = db.collection("ai_scripts").document(id)
        let snapshot = try await docRef.getDocument()
        
        guard let data = snapshot.data(),
              let script = AIScript.fromFirestore(data, id: id) else {
            print("ERROR: Failed to load script \(id)")
            throw AIScriptError.notFound
        }
        
        print("DEBUG: Loaded script with status: \(script.status)")
        return script
    }
    
    /// Delete a script and its associated resources
    /// - Parameter script: The script to delete
    func deleteScript(_ script: AIScript) async throws {
        guard let scriptId = script.id else {
            throw AIScriptError.invalidDraft
        }
        
        print("DEBUG: Deleting script \(scriptId)")
        
        // Delete the document
        try await db.collection("ai_scripts").document(scriptId).delete()
        
        // TODO: Delete associated storage files (keyframe images)
        
        print("DEBUG: Successfully deleted script \(scriptId)")
    }
    
    /// Generate a script based on selected characters and reference images
    func generateScript(
        characters: [ReferenceImage],
        references: [ReferenceImage]
    ) async throws -> AIScript {
        // TODO: Implement script generation using OpenAI
        // For now, return a mock script
        return AIScript(
            draftId: UUID().uuidString, // Mock draft ID
            userId: UUID().uuidString, // Mock user ID
            scenes: [
                StoryScene(
                    order: 0,
                    content: "Our heroes stand at the entrance of an ancient temple, its weathered stones telling tales of forgotten civilizations."
                ),
                StoryScene(
                    order: 1,
                    content: "Deep within the temple, they discover a chamber filled with mysterious artifacts and glowing crystals."
                ),
                StoryScene(
                    order: 2,
                    content: "As they decipher the ancient writings, they realize the true purpose of the temple - to protect an ancient power source."
                )
            ],
            status: AIScript.Status.draft,
            createdAt: Date(),
            updatedAt: Date(),
            selectedReferenceImages: references.map { $0.url }
        )
    }
    
    /// Generate a keyframe image for a scene
    func generateKeyframe(
        for scene: StoryScene,
        isStart: Bool,
        characters: [ReferenceImage],
        references: [ReferenceImage]
    ) async throws -> Keyframe {
        // TODO: Implement keyframe generation using Stable Diffusion
        // For now, return a mock keyframe
        return Keyframe(
            status: .completed,
            prompt: scene.content
        )
    }
    
    /// Save a script to Firestore
    func saveScript(_ script: AIScript) async throws -> AIScript {
        print("DEBUG: Saving script with status: \(script.status)")
        
        var updatedScript = AIScript(
            id: script.id,
            draftId: script.draftId,
            userId: script.userId,
            scenes: script.scenes,
            scriptOverview: script.scriptOverview,
            status: script.status,
            createdAt: script.createdAt,
            updatedAt: Date(),
            selectedCharacterId: script.selectedCharacterId,
            selectedCharacterImages: script.selectedCharacterImages,
            selectedReferenceImages: script.selectedReferenceImages,
            selectedReferenceTextIds: script.selectedReferenceTextIds
        )
        
        do {
            if script.id == nil {
                // New script
                let docRef = db.collection("ai_scripts").document()
                updatedScript.id = docRef.documentID // Set ID before saving
                try await docRef.setData(updatedScript.toFirestoreDocument)
                print("DEBUG: Created new script with ID: \(docRef.documentID)")
            } else {
                // Update existing
                let docRef = db.collection("ai_scripts").document(script.id!)
                try await docRef.updateData(updatedScript.toFirestoreDocument)
                print("DEBUG: Updated script \(script.id!)")
            }
            
            return updatedScript // Return the updated script with the new ID
        } catch {
            print("ERROR: Failed to save script: \(error.localizedDescription)")
            throw AIScriptError.saveFailed(error.localizedDescription)
        }
    }
    
    /// Load a script by draft ID and user ID
    func loadScript(draftId: String, userId: String) async throws -> AIScript? {
        print("DEBUG: Loading script for draft \(draftId)")
        
        let snapshot = try await db.collection("ai_scripts")
            .whereField("draftId", isEqualTo: draftId)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        guard let doc = snapshot.documents.first else {
            print("DEBUG: No script found for draft \(draftId)")
            return nil
        }
        
        guard let script = AIScript.fromFirestore(doc.data(), id: doc.documentID) else {
            print("ERROR: Failed to parse script data")
            throw AIScriptError.invalidState("Failed to parse script data")
        }
        
        print("DEBUG: Successfully loaded script with ID: \(script.id ?? "unknown")")
        return script
    }
    
    // MARK: - Private Methods
    
    /// Fetch draft content and reference texts
    private func fetchDraftContent(
        draftId: String,
        userId: String,
        referenceTextIds: [String]?
    ) async throws -> (String, [String]?) {
        print("DEBUG: Fetching draft \(draftId) and \(referenceTextIds?.count ?? 0) reference texts")
        
        // Fetch draft from user's drafts subcollection
        let draftDoc = try await db.collection("users")
            .document(userId)
            .collection("drafts")
            .document(draftId)
            .getDocument()
            
        guard let draftData = draftDoc.data(),
              let draft = Draft.fromFirestore(draftData, id: draftDoc.documentID) else {
            print("ERROR: Invalid draft data - failed to parse draft")
            throw AIScriptError.invalidDraft
        }
        
        print("DEBUG: Successfully parsed draft with title: \(draft.title)")
        
        // Fetch reference texts if any
        var referenceTexts: [String]?
        if let textIds = referenceTextIds, !textIds.isEmpty {
            var texts: [String] = []
            for textId in textIds {
                let textDoc = try await db.collection("users")
                    .document(userId)
                    .collection("referenceTexts")
                    .document(textId)
                    .getDocument()
                    
                if let textData = textDoc.data(),
                   let referenceText = ReferenceText.fromFirestore(textData, id: textDoc.documentID) {
                    texts.append(referenceText.content)
                }
            }
            referenceTexts = texts.isEmpty ? nil : texts
        }
        
        return (draft.content, referenceTexts)
    }
} 