import Foundation
import FirebaseFirestore
import Observation

/// Model representing a scene in an AI-generated script
@Observable final class StoryScene: Identifiable, Codable {
    /// Unique identifier for the scene
    let id: String
    
    /// Order of the scene in the script
    let order: Int
    
    /// Content/description of the scene
    var content: String
    
    /// Start keyframe of the scene
    var startKeyframe: Keyframe
    
    /// End keyframe of the scene
    var endKeyframe: Keyframe
    
    /// Default initializer
    init(
        id: String = UUID().uuidString,
        order: Int,
        content: String,
        startKeyframe: Keyframe = Keyframe(),
        endKeyframe: Keyframe = Keyframe()
    ) {
        self.id = id
        self.order = order
        self.content = content
        self.startKeyframe = startKeyframe
        self.endKeyframe = endKeyframe
    }
    
    /// Convert to Firestore data
    var firestoreData: [String: Any] {
        [
            "id": id,
            "order": order,
            "content": content,
            "startKeyframe": startKeyframe.firestoreData,
            "endKeyframe": endKeyframe.firestoreData
        ]
    }
    
    /// Convert from Firestore data
    static func fromFirestore(_ data: [String: Any]) -> StoryScene? {
        guard let id = data["id"] as? String,
              let order = data["order"] as? Int,
              let content = data["content"] as? String,
              let startKeyframeData = data["startKeyframe"] as? [String: Any],
              let endKeyframeData = data["endKeyframe"] as? [String: Any],
              let startKeyframe = Keyframe.fromFirestore(startKeyframeData),
              let endKeyframe = Keyframe.fromFirestore(endKeyframeData) else {
            return nil
        }
        
        return StoryScene(
            id: id,
            order: order,
            content: content,
            startKeyframe: startKeyframe,
            endKeyframe: endKeyframe
        )
    }
}

// MARK: - Equatable & Hashable
extension StoryScene: Equatable, Hashable {
    static func == (lhs: StoryScene, rhs: StoryScene) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
} 