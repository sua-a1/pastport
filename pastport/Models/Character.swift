import Foundation
import SwiftData
import FirebaseFirestore

@Model
final class Character: Decodable {
    // MARK: - Properties
    var id: String
    var userId: String
    var name: String
    var characterDescription: String
    var stylePrompt: String
    var generatedImages: [String]
    var referenceImages: [ReferenceImage]
    var status: GenerationStatus
    var createdAt: Date
    var updatedAt: Date
    
    struct ReferenceImage: Codable {
        let url: String
        let prompt: String
        let weight: Double
    }
    
    // MARK: - Decodable
    enum CodingKeys: String, CodingKey {
        case id, userId, name, stylePrompt, generatedImages, referenceImages, status, createdAt, updatedAt
        case characterDescription = "description"
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        characterDescription = try container.decode(String.self, forKey: .characterDescription)
        stylePrompt = try container.decode(String.self, forKey: .stylePrompt)
        generatedImages = try container.decode([String].self, forKey: .generatedImages)
        referenceImages = try container.decode([ReferenceImage].self, forKey: .referenceImages)
        status = try container.decode(GenerationStatus.self, forKey: .status)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
    
    // MARK: - Initialization
    init(
        id: String = UUID().uuidString,
        userId: String,
        name: String,
        characterDescription: String,
        stylePrompt: String,
        generatedImages: [String] = [],
        referenceImages: [ReferenceImage] = [],
        status: GenerationStatus = .notStarted,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.characterDescription = characterDescription
        self.stylePrompt = stylePrompt
        self.generatedImages = generatedImages
        self.referenceImages = referenceImages
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Firestore Conversion
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "userId": userId,
            "name": name,
            "description": characterDescription,
            "stylePrompt": stylePrompt,
            "referenceImages": referenceImages.map { [
                "url": $0.url,
                "prompt": $0.prompt,
                "weight": $0.weight
            ] },
            "generatedImages": generatedImages,
            "status": status.rawValue
        ]
        
        // Only set timestamps on creation
        if createdAt == updatedAt {
            data["createdAt"] = FieldValue.serverTimestamp()
            data["updatedAt"] = FieldValue.serverTimestamp()
        } else {
            // For updates, only set updatedAt
            data["updatedAt"] = FieldValue.serverTimestamp()
        }
        
        return data
    }
}

// MARK: - Supporting Types
extension Character {
    enum GenerationStatus: String, Codable {
        case notStarted = "not_started"
        case generating = "generating"
        case completed = "completed"
        case failed = "failed"
    }
}

// MARK: - Identifiable
extension Character: Identifiable { }

// MARK: - Debug Description
extension Character: CustomDebugStringConvertible {
    var debugDescription: String {
        """
        Character(
            id: \(id),
            name: \(name),
            referenceImages: \(referenceImages.count),
            generatedImages: \(generatedImages.count)
        )
        """
    }
}

// MARK: - Firestore Conversion
extension Character {
    convenience init?(id: String, data: [String: Any]) {
        guard
            let userId = data["userId"] as? String,
            let name = data["name"] as? String,
            let characterDescription = data["description"] as? String,
            let stylePrompt = data["stylePrompt"] as? String,
            let referenceImagesData = data["referenceImages"] as? [[String: Any]],
            let generatedImages = data["generatedImages"] as? [String],
            let status = GenerationStatus(rawValue: data["status"] as? String ?? "not_started"),
            let createdAt = data["createdAt"] as? Date,
            let updatedAt = data["updatedAt"] as? Date
        else { return nil }
        
        let referenceImages = referenceImagesData.compactMap { data -> ReferenceImage? in
            guard
                let url = data["url"] as? String,
                let prompt = data["prompt"] as? String,
                let weight = data["weight"] as? Double
            else { return nil }
            
            return ReferenceImage(url: url, prompt: prompt, weight: weight)
        }
        
        self.init(
            id: id,
            userId: userId,
            name: name,
            characterDescription: characterDescription,
            stylePrompt: stylePrompt,
            generatedImages: generatedImages,
            referenceImages: referenceImages,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
} 