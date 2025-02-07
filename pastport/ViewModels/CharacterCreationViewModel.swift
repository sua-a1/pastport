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
    
    enum CreationState {
        case editing
        case generating
        case completed([String])
        case failed(Error)
    }
    
    // MARK: - Properties
    let user: User?
    private let lumaService = LumaAIService()
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    
    // Form State
    var name = ""
    var characterDescription = ""
    var stylePrompt = ""
    var referenceImages: [ReferenceImageState] = []
    var state: CreationState = .editing
    
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
                    
                    // Generate unique filename
                    let filename = "\(UUID().uuidString).jpg"
                    let path = "characters/\(userId)/reference_images/\(filename)"
                    let storageRef = self.storage.reference().child(path)
                    
                    // Compress image
                    let compressedData = try image.jpegData(compressionQuality: 0.7)
                    
                    // Upload with progress tracking
                    let url = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                        let uploadTask = storageRef.putData(compressedData!) { metadata, error in
                            if let error = error {
                                continuation.resume(throwing: error)
                                return
                            }
                            
                            storageRef.downloadURL { url, error in
                                if let error = error {
                                    continuation.resume(throwing: error)
                                    return
                                }
                                
                                continuation.resume(returning: url!.absoluteString)
                            }
                        }
                        
                        uploadTask.observe(.progress) { snapshot in
                            let progress = Double(snapshot.progress!.completedUnitCount) / Double(snapshot.progress!.totalUnitCount)
                            Task { @MainActor in
                                self.referenceImages[index].uploadProgress = progress
                            }
                        }
                    }
                    
                    // Update state with URL
                    await MainActor.run {
                        self.referenceImages[index].url = url
                        self.referenceImages[index].isUploading = false
                        self.referenceImages[index].uploadProgress = 1.0
                    }
                }
            }
            
            // Wait for all uploads to complete
            try await group.waitForAll()
        }
    }
    
    func generateCharacter() async throws {
        guard let userId = user?.id else {
            throw NSError(domain: "CharacterCreation", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        
        // Update state
        await MainActor.run {
            state = .generating
        }
        
        do {
            // 1. Upload reference images if needed
            if referenceImages.contains(where: { $0.url == nil }) {
                try await uploadReferenceImages()
            }
            
            // 2. Create character in Firestore with initial state
            let character = Character(
                userId: userId,
                name: name,
                characterDescription: characterDescription,
                stylePrompt: stylePrompt,
                referenceImages: referenceImages.compactMap { state in
                    guard let url = state.url else { return nil }
                    return Character.ReferenceImage(
                        url: url,
                        prompt: state.prompt ?? "",
                        weight: state.weight
                    )
                },
                status: .generating
            )
            
            try await db.collection("characters").document(character.id).setData(character.firestoreData)
            
            // 3. Build combined prompt
            var combinedPrompt = stylePrompt + ". " + characterDescription
            combinedPrompt += ". High quality, detailed character design, professional concept art"
            
            // 4. Generate multiple variations
            let generatedUrls = try await lumaService.generateImage(
                prompt: combinedPrompt,
                references: character.referenceImages.map { ref in
                    LumaAIService.ReferenceImage(url: ref.url, prompt: ref.prompt, weight: ref.weight)
                },
                numOutputs: 2,
                guidanceScale: 12.0, // Higher guidance for character consistency
                steps: 50 // More steps for quality
            )
            
            // 5. Update character with generated images
            try await db.collection("characters").document(character.id).updateData([
                "generatedImages": generatedUrls,
                "status": Character.GenerationStatus.completed.rawValue,
                "updatedAt": Date()
            ])
            
            // 6. Update state
            await MainActor.run {
                state = .completed(generatedUrls)
            }
            
        } catch {
            print("DEBUG: Character generation failed: \(error)")
            await MainActor.run {
                state = .failed(error)
            }
        }
    }
    
    func generateCharacterWithReference(selectedImages: [String], prompt: String) async throws -> [String] {
        print("DEBUG: Starting character reference generation with \(selectedImages.count) reference images")
        
        // Update state
        await MainActor.run {
            state = .generating
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
                state = .completed(generatedUrls)
            }
            
            return generatedUrls
            
        } catch {
            print("DEBUG: Character reference generation failed: \(error)")
            await MainActor.run {
                state = .failed(error)
            }
            throw error
        }
    }
    
    func saveCharacterImages(_ images: [String]) async throws {
        guard let userId = user?.id else {
            throw NSError(domain: "CharacterCreation", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        
        print("DEBUG: Saving \(images.count) character images")
        
        // Download and re-upload images to our storage
        let uploadedUrls = try await withThrowingTaskGroup(of: String.self) { group in
            for imageUrl in images {
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
                    let filename = "\(UUID().uuidString).jpg"
                    let path = "characters/\(userId)/generated_images/\(filename)"
                    let storageRef = self.storage.reference().child(path)
                    
                    print("DEBUG: Uploading image to path: \(path)")
                    
                    // Create metadata
                    let metadata = StorageMetadata()
                    metadata.contentType = "image/jpeg"
                    
                    // Upload to our storage with metadata
                    _ = try await storageRef.putData(data, metadata: metadata)
                    let downloadUrl = try await storageRef.downloadURL()
                    
                    print("DEBUG: Successfully uploaded image, got URL: \(downloadUrl.absoluteString)")
                    return downloadUrl.absoluteString
                }
            }
            
            var urls: [String] = []
            for try await url in group {
                urls.append(url)
            }
            return urls
        }
        
        print("DEBUG: Successfully uploaded \(uploadedUrls.count) images")
        
        do {
            // First try to find a generating character
            let generatingSnapshot = try await db.collection("characters")
                .whereField("userId", isEqualTo: userId)
                .whereField("status", isEqualTo: Character.GenerationStatus.generating.rawValue)
                .order(by: "createdAt", descending: true)
                .limit(to: 1)
                .getDocuments()
            
            if let characterDoc = generatingSnapshot.documents.first {
                print("DEBUG: Found generating character document: \(characterDoc.documentID)")
                try await characterDoc.reference.updateData([
                    "generatedImages": uploadedUrls,
                    "status": Character.GenerationStatus.completed.rawValue,
                    "updatedAt": Date()
                ])
                return
            }
            
            // If no generating character found, create a new one
            print("DEBUG: No generating character found, creating new one")
            let newCharacter = Character(
                userId: userId,
                name: name,
                characterDescription: characterDescription,
                stylePrompt: stylePrompt,
                generatedImages: uploadedUrls,
                status: .completed
            )
            
            try await db.collection("characters")
                .document(newCharacter.id)
                .setData(newCharacter.firestoreData)
            
            print("DEBUG: Successfully created new character document")
            
        } catch {
            print("DEBUG: Error updating Firestore: \(error)")
            throw error
        }
    }
    
    func reset() {
        name = ""
        characterDescription = ""
        stylePrompt = ""
        referenceImages = []
        state = .editing
    }
} 