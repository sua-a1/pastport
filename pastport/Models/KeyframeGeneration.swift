import Foundation

/// Model representing a keyframe generation request
struct KeyframeGeneration: Codable {
    /// Type of keyframe to generate
    let type: KeyframeType
    
    /// Scene content for context
    let sceneContent: String
    
    /// Selected images with their weights
    let selectedImages: [ReferenceImage]
    
    /// Additional prompt for generation
    let prompt: String
    
    /// Previous keyframe URL if generating end keyframe
    let previousKeyframeUrl: String?
    
    /// Enumeration of keyframe types
    enum KeyframeType: String, Codable {
        case start
        case end
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case sceneContent = "scene_content"
        case selectedImages = "selected_images"
        case prompt
        case previousKeyframeUrl = "previous_keyframe_url"
    }
    
    /// Decoding initializer
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(KeyframeType.self, forKey: .type)
        sceneContent = try container.decode(String.self, forKey: .sceneContent)
        selectedImages = try container.decode([ReferenceImage].self, forKey: .selectedImages)
        prompt = try container.decode(String.self, forKey: .prompt)
        previousKeyframeUrl = try container.decodeIfPresent(String.self, forKey: .previousKeyframeUrl)
    }
    
    /// Default initializer
    init(
        type: KeyframeType,
        sceneContent: String,
        selectedImages: [ReferenceImage],
        prompt: String,
        previousKeyframeUrl: String? = nil
    ) {
        self.type = type
        self.sceneContent = sceneContent
        self.selectedImages = selectedImages
        self.prompt = prompt
        self.previousKeyframeUrl = previousKeyframeUrl
    }
    
    /// Create a generation request for a start keyframe
    static func forStartKeyframe(
        sceneContent: String,
        selectedImages: [ReferenceImage],
        prompt: String
    ) -> KeyframeGeneration {
        KeyframeGeneration(
            type: .start,
            sceneContent: sceneContent,
            selectedImages: selectedImages,
            prompt: prompt
        )
    }
    
    /// Create a generation request for an end keyframe
    static func forEndKeyframe(
        sceneContent: String,
        selectedImages: [ReferenceImage],
        prompt: String,
        startKeyframeUrl: String
    ) -> KeyframeGeneration {
        KeyframeGeneration(
            type: .end,
            sceneContent: sceneContent,
            selectedImages: selectedImages,
            prompt: prompt,
            previousKeyframeUrl: startKeyframeUrl
        )
    }
}

// MARK: - Request Data

extension KeyframeGeneration {
    /// Convert to request parameters for API calls
    var requestParameters: [String: Any] {
        var params: [String: Any] = [
            "type": type.rawValue,
            "scene_content": sceneContent,
            "character_ref": selectedImages.filter { $0.type == .character }.map { [
                "url": $0.url,
                "weight": $0.weight
            ] },
            "image_ref": selectedImages.filter { $0.type == .reference }.map { [
                "url": $0.url,
                "weight": $0.weight
            ] },
            "prompt": prompt
        ]
        
        if let previousUrl = previousKeyframeUrl {
            params["previous_keyframe_url"] = previousUrl
        }
        
        return params
    }
} 