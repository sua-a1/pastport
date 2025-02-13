import SwiftUI
import PhotosUI
import FirebaseStorage
import FirebaseFirestore

@Observable final class CharacterCreationViewModel {
    // MARK: - Types
    struct ReferenceImageState: Identifiable {
        let id = UUID()
        var image: UIImage?
        var prompt: String? = nil
        var weight: Double = 0.5
        var isUploading = false
        var uploadProgress: Double = 0
        var url: String?
        var error: String?
    }
    
    enum CreationState: Equatable {
        case editing
        case generating
        case completed([String])
        case failed(Error)
        case saving
        
        static func == (lhs: CreationState, rhs: CreationState) -> Bool {
            switch (lhs, rhs) {
            case (.editing, .editing),
                 (.generating, .generating),
                 (.saving, .saving):
                return true
            case (.completed(let lhsUrls), .completed(let rhsUrls)):
                return lhsUrls == rhsUrls
            case (.failed, .failed):
                // Consider errors equal for UI purposes
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - Properties
    let user: User?
    var character: Character?
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var lumaService: LumaAIService?
    private var lumaServiceError: Error?
    private var temporaryGeneratedUrls: [String] = []
    
    // Form State
    var name = ""
    var characterDescription = ""
    var stylePrompt = ""
    var referenceImages: [ReferenceImageState] = []
    var state: CreationState = .editing
    var isRefining = false
    
    // Validation
    var isValid: Bool {
        !name.isEmpty &&
        !characterDescription.isEmpty &&
        !stylePrompt.isEmpty &&
        !referenceImages.isEmpty &&
        !referenceImages.contains(where: { $0.isUploading })
    }
    
    // MARK: - Initialization
    init(user: User?) {
        self.user = user
        
        // Initialize Luma service
        do {
            self.lumaService = try LumaAIService()
        } catch {
            print("DEBUG: Failed to initialize Luma service: \(error)")
            self.lumaServiceError = error
        }
    }
    
    // MARK: - Public Methods
    func addReferenceImage(_ image: UIImage) {
        guard referenceImages.count < 4 else { return }
        referenceImages.append(ReferenceImageState(image: image))
    }
    
    func removeReferenceImage(at index: Int) {
        referenceImages.remove(at: index)
    }
    
    func uploadReferenceImages() async throws {
        guard let userId = user?.id else {
            throw NSError(domain: "CharacterCreation", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        
        print("DEBUG: Starting reference image upload for user \(userId)")
        
        // Upload images in parallel
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (index, imageState) in referenceImages.enumerated() {
                guard let image = imageState.image else { continue }
                
                group.addTask {
                    // Update state
                    await MainActor.run {
                        self.referenceImages[index].isUploading = true
                        self.referenceImages[index].uploadProgress = 0
                    }
                    
                    // Generate unique filename using UUID
                    let filename = "\(UUID().uuidString).jpg"
                    let path = "characters/\(userId)/reference_images/\(filename)"
                    print("DEBUG: Uploading image \(index) to path: \(path)")
                    
                    let storageRef = self.storage.reference().child(path)
                    
                    // Compress image
                    guard let compressedData = image.jpegData(compressionQuality: 0.7) else {
                        throw NSError(domain: "CharacterCreation", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
                    }
                    
                    // Create metadata
                    let metadata = StorageMetadata()
                    metadata.contentType = "image/jpeg"
                    
                    print("DEBUG: Starting upload for image \(index) with size: \(compressedData.count) bytes")
                    
                    // Upload with async/await
                    do {
                        // Upload the data
                        _ = try await storageRef.putDataAsync(compressedData, metadata: metadata)
                        print("DEBUG: Successfully uploaded image \(index)")
                        
                        // Get download URL
                        let url = try await storageRef.downloadURL()
                        print("DEBUG: Got download URL for image \(index): \(url.absoluteString)")
                        
                        // Update state with URL
                        await MainActor.run {
                            self.referenceImages[index].url = url.absoluteString
                            self.referenceImages[index].isUploading = false
                            self.referenceImages[index].uploadProgress = 1.0
                        }
                    } catch {
                        print("DEBUG: Failed to upload image \(index): \(error)")
                        throw error
                    }
                }
            }
            
            print("DEBUG: Waiting for all uploads to complete")
            try await group.waitForAll()
            print("DEBUG: All reference image uploads completed successfully")
        }
    }
    
    // MARK: - Character Generation Methods
    func generateCharacter() async throws {
        guard let userId = user?.id else {
            throw NSError(domain: "CharacterCreation", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        
        // Check if Luma service is available
        if let error = lumaServiceError {
            throw error
        }
        
        guard let lumaService = lumaService else {
            throw NSError(domain: "CharacterCreation", code: -1, userInfo: [NSLocalizedDescriptionKey: "Luma AI service is not initialized"])
        }
        
        print("DEBUG: Starting character generation for user \(userId)")
        
        // Update state
        await MainActor.run {
            state = .generating
        }
        
        do {
            // Upload reference images first
            try await uploadReferenceImages()
            
            // Build combined prompt
            var combinedPrompt = stylePrompt + ". " + characterDescription
            combinedPrompt += ". High quality, detailed character design, professional concept art"
            
            print("DEBUG: Built combined prompt: \(combinedPrompt)")
            
            // Get reference images with URLs
            let references = referenceImages.compactMap { state -> LumaAIService.ReferenceImage? in
                guard let url = state.url else { return nil }
                return LumaAIService.ReferenceImage(
                    url: url,
                    prompt: state.prompt,
                    weight: state.weight
                )
            }
            
            print("DEBUG: Using \(references.count) reference images for generation")
            
            // Generate multiple variations
            print("DEBUG: Starting Luma AI generation")
            let generatedUrls = try await lumaService.generateImage(
                prompt: combinedPrompt,
                references: references,
                numOutputs: 2,
                guidanceScale: 12.0,
                steps: 50
            )
            
            print("DEBUG: Successfully generated \(generatedUrls.count) images from Luma AI")
            
            // Store URLs temporarily
            await MainActor.run {
                temporaryGeneratedUrls = generatedUrls
                state = .completed(generatedUrls)
            }
            
        } catch {
            print("DEBUG: Character generation failed: \(error)")
            await MainActor.run {
                state = .failed(error)
            }
            throw error
        }
    }
    
    func generateCharacterWithReference(selectedImages: [String], prompt: String) async throws -> [String] {
        print("DEBUG: Starting character reference generation with \(selectedImages.count) reference images")
        
        // Check if Luma service is available
        if let error = lumaServiceError {
            throw error
        }
        
        guard let lumaService = lumaService else {
            throw NSError(domain: "CharacterCreation", code: -1, userInfo: [NSLocalizedDescriptionKey: "Luma AI service is not initialized"])
        }
        
        // Update state
        await MainActor.run {
            state = .generating
            isRefining = true
        }
        
        do {
            // Build combined prompt
            var combinedPrompt = prompt
            combinedPrompt += ". Maintain the exact same character identity, appearance, and style."
            combinedPrompt += ". High quality, detailed character design, professional concept art"
            
            // Generate using character references
            let generatedUrls = try await lumaService.generateImage(
                prompt: combinedPrompt,
                characterReferences: selectedImages,
                numOutputs: 2,
                guidanceScale: 12.0,
                steps: 50
            )
            
            // Update state
            await MainActor.run {
                temporaryGeneratedUrls = generatedUrls
                state = .completed(generatedUrls)
            }
            
            return generatedUrls
            
        } catch {
            print("DEBUG: Character reference generation failed: \(error)")
            await MainActor.run {
                state = .failed(error)
                isRefining = false
            }
            throw error
        }
    }
    
    // MARK: - Save Methods
    func saveNewCharacter(selectedImages: [String]) async throws {
        guard let userId = user?.id else {
            throw NSError(domain: "CharacterCreation", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        
        print("DEBUG: Starting new character save with \(selectedImages.count) selected images")
        
        do {
            // 1. Upload reference images
            try await uploadReferenceImages()
            
            // 2. Upload selected generated images
            let uploadedUrls = try await uploadSelectedImages(selectedImages)
            
            // 3. Create character in Firestore
            let character = Character(
                userId: userId,
                name: name,
                characterDescription: characterDescription,
                stylePrompt: stylePrompt,
                generatedImages: uploadedUrls,
                referenceImages: referenceImages.compactMap { state in
                    guard let url = state.url else { return nil }
                    return Character.ReferenceImage(
                        url: url,
                        prompt: state.prompt ?? "",
                        weight: state.weight
                    )
                },
                status: .completed
            )
            
            // 4. Save to Firestore
            try await db.collection("characters").document(character.id).setData(character.firestoreData)
            print("DEBUG: Successfully saved new character")
            
            await MainActor.run {
                self.character = character
                state = .completed(uploadedUrls)
            }
            
        } catch {
            print("DEBUG: Failed to save character: \(error)")
            await MainActor.run {
                state = .failed(error)
            }
            throw error
        }
    }
    
    func saveRefinedCharacter(characterId: String, selectedImages: [String]) async throws {
        print("DEBUG: Starting refined character save with \(selectedImages.count) selected images")
        
        do {
            // 1. Upload selected images
            let uploadedUrls = try await uploadSelectedImages(selectedImages)
            
            // 2. Get current character document
            let characterRef = db.collection("characters").document(characterId)
            let snapshot = try await characterRef.getDocument()
            
            guard let data = snapshot.data(),
                  var currentImages = data["generatedImages"] as? [String] else {
                throw NSError(domain: "CharacterCreation", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get current images"])
            }
            
            print("DEBUG: Current images count before update: \(currentImages.count)")
            print("DEBUG: New images to add: \(uploadedUrls.count)")
            
            // 3. Append new images to existing ones
            currentImages.append(contentsOf: uploadedUrls)
            
            print("DEBUG: Total images after merge: \(currentImages.count)")
            
            // 4. Update Firestore
            let updateData: [String: Any] = [
                "generatedImages": currentImages,
                "status": Character.GenerationStatus.completed.rawValue,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
            try await characterRef.updateData(updateData)
            print("DEBUG: Successfully saved refined character images")
            
            // 5. Update local character state
            if var updatedCharacter = Character(id: characterId, data: data) {
                updatedCharacter.generatedImages = currentImages
                await MainActor.run {
                    self.character = updatedCharacter
                    state = .completed(currentImages)
                }
            }
            
        } catch {
            print("DEBUG: Failed to save refined character: \(error)")
            await MainActor.run {
                state = .failed(error)
            }
            throw error
        }
    }
    
    private func uploadSelectedImages(_ images: [String]) async throws -> [String] {
        guard let userId = user?.id else {
            throw NSError(domain: "CharacterCreation", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        
        print("DEBUG: Uploading \(images.count) selected images")
        
        return try await withThrowingTaskGroup(of: String.self) { group in
            for (index, imageUrl) in images.enumerated() {
                group.addTask {
                    // Download image data
                    guard let url = URL(string: imageUrl) else {
                        throw NSError(domain: "CharacterCreation", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image URL"])
                    }
                    
                    let (data, response) = try await URLSession.shared.data(from: url)
                    
                    // Verify we got an image
                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200,
                          !data.isEmpty else {
                        throw NSError(domain: "CharacterCreation", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to download image"])
                    }
                    
                    // Generate unique filename
                    let timestamp = Int(Date().timeIntervalSince1970)
                    let filename = "\(timestamp)_\(index).jpg"
                    let path = "characters/\(userId)/generated_images/\(filename)"
                    let storageRef = self.storage.reference().child(path)
                    
                    print("DEBUG: Uploading image to path: \(path)")
                    
                    // Create metadata
                    let metadata = StorageMetadata()
                    metadata.contentType = "image/jpeg"
                    metadata.customMetadata = [
                        "userId": userId,
                        "imageIndex": String(index),
                        "originalUrl": imageUrl,
                        "timestamp": String(timestamp)
                    ]
                    
                    // Upload to storage
                    _ = try await storageRef.putDataAsync(data, metadata: metadata)
                    let downloadUrl = try await storageRef.downloadURL()
                    
                    print("DEBUG: Successfully uploaded image, got URL: \(downloadUrl.absoluteString)")
                    return downloadUrl.absoluteString
                }
            }
            
            var urls: [String] = []
            for try await url in group {
                urls.append(url)
            }
            return urls.sorted()
        }
    }
    
    func reset() {
        name = ""
        characterDescription = ""
        stylePrompt = ""
        referenceImages = []
        temporaryGeneratedUrls = []
        state = .editing
        isRefining = false
    }
} 