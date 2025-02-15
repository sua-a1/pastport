import Foundation
import FirebaseFirestore

/// Model representing a keyframe in a scene
struct Keyframe: Codable, Hashable {
    /// Status of the keyframe generation
    var status: Status
    
    /// URL of the generated image, if any
    var imageUrl: String?
    
    /// Array of selected images with their weights for generation
    var selectedImages: [SelectedImage]
    
    /// Prompt used for image generation
    var prompt: String?
    
    /// Enumeration of possible keyframe generation statuses
    enum Status: String, Codable, Hashable {
        case notStarted = "not_started"
        case generating
        case completed
        case failed
    }
    
    /// Model representing a selected image with its weight
    struct SelectedImage: Codable, Hashable {
        /// URL of the image
        let url: String
        
        /// Weight of the image in generation (0.0 to 1.0)
        let weight: Double
        
        /// Default initializer
        init(url: String, weight: Double) {
            self.url = url
            self.weight = min(max(weight, 0.0), 1.0) // Clamp between 0 and 1
        }
    }
    
    /// Default initializer
    init(
        status: Status = .notStarted,
        imageUrl: String? = nil,
        selectedImages: [SelectedImage] = [],
        prompt: String? = nil
    ) {
        self.status = status
        self.imageUrl = imageUrl
        self.selectedImages = selectedImages
        self.prompt = prompt
    }
    
    /// Convert to Firestore data
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "status": status.rawValue,
            "selectedImages": selectedImages.map { [
                "url": $0.url,
                "weight": $0.weight
            ] }
        ]
        
        if let imageUrl = imageUrl {
            data["imageUrl"] = imageUrl
        }
        
        if let prompt = prompt {
            data["prompt"] = prompt
        }
        
        return data
    }
    
    /// Convert from Firestore data
    static func fromFirestore(_ data: [String: Any]) -> Keyframe? {
        guard let statusRaw = data["status"] as? String,
              let status = Status(rawValue: statusRaw) else {
            return nil
        }
        
        let imageUrl = data["imageUrl"] as? String
        let prompt = data["prompt"] as? String
        
        // Convert selected images
        var selectedImages: [SelectedImage] = []
        if let selectedImagesData = data["selectedImages"] as? [[String: Any]] {
            selectedImages = selectedImagesData.compactMap { imageData in
                guard let url = imageData["url"] as? String,
                      let weight = imageData["weight"] as? Double else {
                    return nil
                }
                return SelectedImage(url: url, weight: weight)
            }
        }
        
        return Keyframe(
            status: status,
            imageUrl: imageUrl,
            selectedImages: selectedImages,
            prompt: prompt
        )
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(status)
        hasher.combine(imageUrl)
        hasher.combine(selectedImages)
        hasher.combine(prompt)
    }
} 