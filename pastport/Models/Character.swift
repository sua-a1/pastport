import Foundation
import SwiftData

@Model
final class Character {
    // MARK: - Properties
    var id: String
    var userId: String
    var name: String
    var characterDescription: String
    var stylePrompt: String
    var referenceImages: [ReferenceImage]
    var generatedImages: [String]
    var status: GenerationStatus
    var createdAt: Date
    var updatedAt: Date
    
    // MARK: - Initialization
    init(
        id: String = UUID().uuidString,
        userId: String,
        name: String,
        characterDescription: String,
        stylePrompt: String,
        referenceImages: [ReferenceImage] = [],
        generatedImages: [String] = [],
        status: GenerationStatus = .notStarted,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.characterDescription = characterDescription
        self.stylePrompt = stylePrompt
        self.referenceImages = referenceImages
        self.generatedImages = generatedImages
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
    
    struct ReferenceImage: Codable {
        let url: String
        let prompt: String?
        let weight: Double
    }
}

// MARK: - Firestore Conversion
extension Character {
    var firestoreData: [String: Any] {
        [
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
            "status": status.rawValue,
            "createdAt": createdAt,
            "updatedAt": updatedAt
        ]
    }
    
    convenience init?(id: String, data: [String: Any]) {
        guard
            let userId = data["userId"] as? String,
            let name = data["name"] as? String,
            let description = data["description"] as? String,
            let stylePrompt = data["stylePrompt"] as? String,
            let referenceImagesData = data["referenceImages"] as? [[String: Any]],
            let generatedImages = data["generatedImages"] as? [String],
            let statusRaw = data["status"] as? String,
            let status = GenerationStatus(rawValue: statusRaw),
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
            characterDescription: description,
            stylePrompt: stylePrompt,
            referenceImages: referenceImages,
            generatedImages: generatedImages,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
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
            status: \(status.rawValue),
            referenceImages: \(referenceImages.count),
            generatedImages: \(generatedImages.count)
        )
        """
    }
} 