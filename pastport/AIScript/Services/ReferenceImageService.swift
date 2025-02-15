import Foundation
import FirebaseFirestore

/// Errors that can occur in reference image operations
enum ReferenceImageError: LocalizedError {
    case invalidImageType
    case missingRequiredData(String)
    case fetchError(Error)
    case unauthorized
    case maxImagesExceeded(ReferenceImageType)
    
    var errorDescription: String? {
        switch self {
        case .invalidImageType:
            return "Invalid image type"
        case .missingRequiredData(let field):
            return "Missing required data: \(field)"
        case .fetchError(let error):
            return "Failed to fetch images: \(error.localizedDescription)"
        case .unauthorized:
            return "User not authorized"
        case .maxImagesExceeded(let type):
            return "Maximum number of \(type) images exceeded"
        }
    }
}

/// Service for managing reference images in Firestore
public final class ReferenceImageService {
    // MARK: - Properties
    
    private let db: Firestore
    private let draftId: String
    
    /// Available character images
    private(set) var characterImages: [ReferenceImage] = []
    
    /// Available reference images
    private(set) var referenceImages: [ReferenceImage] = []
    
    // MARK: - Initialization
    
    public init(db: Firestore = Firestore.firestore(), draftId: String) {
        self.db = db
        self.draftId = draftId
    }
    
    // MARK: - Public Methods
    
    /// Validate character selection
    /// - Parameters:
    ///   - characterId: ID of the character
    ///   - images: Selected images
    /// - Returns: Error if validation fails
    func validateCharacterSelection(_ characterId: String, images: [ReferenceImage]) -> Error? {
        // Basic validation
        if images.isEmpty {
            return ReferenceImageError.missingRequiredData("No images selected")
        }
        
        // Validate image types
        for image in images {
            if image.type != .character {
                return ReferenceImageError.invalidImageType
            }
        }
        
        // Check maximum limit
        if images.count > 4 {
            return ReferenceImageError.maxImagesExceeded(.character)
        }
        
        return nil
    }
    
    /// Load available images for a user
    /// - Parameter userId: ID of the user
    func loadAvailableImages(for userId: String) async throws {
        print("DEBUG: Loading available images for user \(userId) and draft \(draftId)")
        
        do {
            // Load character images from root characters collection
            let characterSnapshot = try await db.collection("characters")
                .whereField("userId", isEqualTo: userId)
                .whereField("status", isEqualTo: "completed")  // Only get completed characters
                .getDocuments()
            
            print("DEBUG: Found \(characterSnapshot.documents.count) character documents")
            
            characterImages = characterSnapshot.documents.flatMap { doc -> [ReferenceImage] in
                guard let data = doc.data() as? [String: Any],
                      let generatedImages = data["generatedImages"] as? [String],
                      !generatedImages.isEmpty,
                      let description = data["description"] as? String,
                      let name = data["name"] as? String,
                      let stylePrompt = data["stylePrompt"] as? String else {
                    print("DEBUG: Skipping character \(doc.documentID) - missing required data")
                    return []
                }
                
                print("DEBUG: Processing character \(doc.documentID) with \(generatedImages.count) images")
                
                // Create a ReferenceImage for each generated image
                return generatedImages.enumerated().map { index, imageUrl in
                    // Ensure the URL is properly formatted for the storage path
                    let fullUrl = imageUrl.hasPrefix("http") ? imageUrl : "https://storage.googleapis.com/\(imageUrl)"
                    return ReferenceImage(
                        id: "\(doc.documentID)_\(index)",  // Make unique ID for each image
                        url: fullUrl,
                        type: .character,
                        weight: 0.5,
                        prompt: "\(name): \(description)\nStyle: \(stylePrompt)"  // Include name, description and style
                    )
                }
            }
            
            // Load reference images from the current draft document
            let draftRef = db.collection("users")
                .document(userId)
                .collection("drafts")
                .document(draftId)
            
            print("DEBUG: Attempting to load draft document: \(draftRef.path)")
            
            let draftDoc = try await draftRef.getDocument()
            
            print("DEBUG: Draft document exists: \(draftDoc.exists)")
            
            if draftDoc.exists {
                print("DEBUG: Draft data: \(String(describing: draftDoc.data()))")
            }
            
            var allReferenceImages: [ReferenceImage] = []
            
            if let data = draftDoc.data() {
                print("DEBUG: Draft data fields: \(data.keys)")
                
                // First try to get reference images from the referenceImages array
                if let referenceImageUrls = data["referenceImages"] as? [[String: Any]] {
                    print("DEBUG: Found referenceImages array with \(referenceImageUrls.count) items")
                    print("DEBUG: First reference image data: \(referenceImageUrls.first ?? [:])")
                    
                    let images = referenceImageUrls.compactMap { imageData -> ReferenceImage? in
                        print("DEBUG: Processing image data: \(imageData)")
                        
                        guard let url = imageData["url"] as? String else {
                            print("DEBUG: Skipping reference image - missing URL")
                            return nil
                        }
                        let prompt = imageData["prompt"] as? String
                        print("DEBUG: Processing reference image with URL: \(url)")
                        
                        // Ensure the URL is properly formatted for the storage path
                        let fullUrl = url.hasPrefix("http") ? url : "https://storage.googleapis.com/\(url)"
                        return ReferenceImage(
                            id: "\(draftId)_\(url.hashValue)",
                            url: fullUrl,
                            type: .reference,
                            weight: 0.5,
                            prompt: prompt ?? "Reference Image"
                        )
                    }
                    
                    print("DEBUG: Successfully processed \(images.count) reference images")
                    allReferenceImages = images
                } else if let imageUrls = data["imageUrls"] as? [String] {
                    // If no referenceImages array, try to use imageUrls
                    print("DEBUG: Using imageUrls array with \(imageUrls.count) items")
                    
                    let images = imageUrls.enumerated().map { index, url -> ReferenceImage in
                        print("DEBUG: Processing image URL: \(url)")
                        
                        // Create a reference image from the URL
                        return ReferenceImage(
                            id: "\(draftId)_\(index)",
                            url: url,
                            type: .reference,
                            weight: 0.5,
                            prompt: "Reference Image \(index + 1)"
                        )
                    }
                    
                    print("DEBUG: Successfully processed \(images.count) reference images from imageUrls")
                    allReferenceImages = images
                } else {
                    print("DEBUG: No reference images or imageUrls found in draft data")
                }
            } else {
                print("DEBUG: No data found in draft document")
            }
            
            // Update reference images
            self.referenceImages = allReferenceImages
            
            print("DEBUG: Successfully loaded \(characterImages.count) character images and \(referenceImages.count) reference images")
            print("DEBUG: Character image URLs: \(characterImages.map { $0.url })")
            print("DEBUG: Reference image URLs: \(referenceImages.map { $0.url })")
            
        } catch {
            print("ERROR: Failed to load images: \(error.localizedDescription)")
            print("ERROR: Detailed error: \(error)")
            throw ReferenceImageError.fetchError(error)
        }
    }
    
    // MARK: - Private Methods
    
    private func validateImage(_ image: ReferenceImage) -> Error? {
        // Basic validation
        if image.weight < 0 || image.weight > 1 {
            return ReferenceImageError.missingRequiredData("Weight must be between 0 and 1")
        }
        
        if image.url.isEmpty {
            return ReferenceImageError.missingRequiredData("URL")
        }
        
        // Type-specific validation
        switch image.type {
        case .character:
            // Character images require a prompt
            if image.prompt == nil || image.prompt?.isEmpty == true {
                return ReferenceImageError.missingRequiredData("Character images require a prompt")
            }
        case .reference:
            // No additional validation needed for reference images
            break
        }
        
        return nil
    }
}

 