import Foundation
import FirebaseFirestore
import Observation

/// Model representing an AI-generated script for a story
@Observable final class AIScript: Identifiable {
    /// Enumeration of possible script generation statuses
    enum Status: String, Codable, Hashable {
        case draft
        case generatingScript = "generating_script"
        case editingKeyframes = "editing_keyframes"
        case generatingVideo = "generating_video"
        case completed
        case failed
    }
    
    /// Status of video generation for a scene
    enum VideoGenerationStatus: Codable, Hashable {
        case notStarted
        case inProgress(sceneIndex: Int)
        case completed
        case failed(errorMessage: String)
        
        // For Firestore storage
        private enum CodingKeys: String, CodingKey {
            case type
            case sceneIndex
            case errorMessage
        }
        
        private enum StatusType: String, Codable {
            case notStarted = "not_started"
            case inProgress = "in_progress"
            case completed
            case failed
        }
        
        var description: String {
            switch self {
            case .notStarted:
                return "Not Started"
            case .inProgress(let index):
                return "Generating Scene \(index + 1)..."
            case .completed:
                return "Completed"
            case .failed(let message):
                return "Failed: \(message)"
            }
        }
        
        // Custom Codable implementation
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(StatusType.self, forKey: .type)
            
            switch type {
            case .notStarted:
                self = .notStarted
            case .inProgress:
                let index = try container.decode(Int.self, forKey: .sceneIndex)
                self = .inProgress(sceneIndex: index)
            case .completed:
                self = .completed
            case .failed:
                let message = try container.decode(String.self, forKey: .errorMessage)
                self = .failed(errorMessage: message)
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            switch self {
            case .notStarted:
                try container.encode(StatusType.notStarted, forKey: .type)
            case .inProgress(let index):
                try container.encode(StatusType.inProgress, forKey: .type)
                try container.encode(index, forKey: .sceneIndex)
            case .completed:
                try container.encode(StatusType.completed, forKey: .type)
            case .failed(let message):
                try container.encode(StatusType.failed, forKey: .type)
                try container.encode(message, forKey: .errorMessage)
            }
        }
    }
    
    /// Structure representing a generated video for a scene
    struct SceneVideo: Codable, Identifiable {
        var id: String { "\(sceneIndex)" }
        let sceneIndex: Int
        var videoUrl: String
        let duration: TimeInterval
        let status: VideoGenerationStatus
        let metadata: [String: Any]
        
        init(sceneIndex: Int, videoUrl: String, duration: TimeInterval, status: VideoGenerationStatus, metadata: [String: Any]) {
            self.sceneIndex = sceneIndex
            self.videoUrl = videoUrl
            self.duration = duration
            self.status = status
            self.metadata = metadata
        }
        
        private enum CodingKeys: String, CodingKey {
            case sceneIndex
            case videoUrl
            case duration
            case status
            case metadata
        }
        
        var firestoreData: [String: Any] {
            var data: [String: Any] = [
                "sceneIndex": sceneIndex,
                "videoUrl": videoUrl,
                "duration": duration
            ]
            
            // Encode status based on case
            switch status {
            case .notStarted:
                data["status"] = ["type": "not_started"]
            case .inProgress(let index):
                data["status"] = [
                    "type": "in_progress",
                    "sceneIndex": index
                ]
            case .completed:
                data["status"] = ["type": "completed"]
            case .failed(let message):
                data["status"] = [
                    "type": "failed",
                    "errorMessage": message
                ]
            }
            
            data["metadata"] = metadata
            return data
        }
        
        static func fromFirestore(_ data: [String: Any]) -> SceneVideo? {
            guard let sceneIndex = data["sceneIndex"] as? Int,
                  let videoUrl = data["videoUrl"] as? String,
                  let duration = data["duration"] as? TimeInterval,
                  let statusData = data["status"] as? [String: Any],
                  let statusType = statusData["type"] as? String else {
                return nil
            }
            
            let status: VideoGenerationStatus
            switch statusType {
            case "not_started":
                status = .notStarted
            case "in_progress":
                if let index = statusData["sceneIndex"] as? Int {
                    status = .inProgress(sceneIndex: index)
                } else {
                    return nil
                }
            case "completed":
                status = .completed
            case "failed":
                if let message = statusData["errorMessage"] as? String {
                    status = .failed(errorMessage: message)
                } else {
                    return nil
                }
            default:
                return nil
            }
            
            let metadata = data["metadata"] as? [String: Any] ?? [:]
            
            return SceneVideo(
                sceneIndex: sceneIndex,
                videoUrl: videoUrl,
                duration: duration,
                status: status,
                metadata: metadata
            )
        }
        
        // Custom Codable implementation for metadata
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            sceneIndex = try container.decode(Int.self, forKey: .sceneIndex)
            videoUrl = try container.decode(String.self, forKey: .videoUrl)
            duration = try container.decode(TimeInterval.self, forKey: .duration)
            status = try container.decode(VideoGenerationStatus.self, forKey: .status)
            
            // Decode metadata as [String: String] and convert to [String: Any]
            let stringMetadata = try container.decode([String: String].self, forKey: .metadata)
            metadata = Dictionary(uniqueKeysWithValues: stringMetadata.map { ($0.key, $0.value as Any) })
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(sceneIndex, forKey: .sceneIndex)
            try container.encode(videoUrl, forKey: .videoUrl)
            try container.encode(duration, forKey: .duration)
            try container.encode(status, forKey: .status)
            
            // Convert metadata to [String: String] for encoding
            let stringMetadata = metadata.mapValues { "\($0)" }
            try container.encode(stringMetadata, forKey: .metadata)
        }
    }
    
    /// Unique identifier for the script
    var id: String?
    
    /// ID of the draft this script is associated with
    let draftId: String
    
    /// ID of the user who owns this script
    let userId: String
    
    /// Array of scenes in the script
    var scenes: [StoryScene]
    
    /// Overview of the entire script
    var scriptOverview: String?
    
    /// Current status of the script generation process
    var status: Status
    
    /// Timestamp when the script was created
    let createdAt: Date
    
    /// Timestamp when the script was last updated
    var updatedAt: Date
    
    /// Optional ID of the selected character for the script
    var selectedCharacterId: String?
    
    /// Optional array of selected character image URLs
    var selectedCharacterImages: [String]?
    
    /// Optional array of selected reference image URLs
    var selectedReferenceImages: [String]?
    
    /// Optional array of selected reference text IDs
    var selectedReferenceTextIds: [String]?
    
    /// Array of generated scene videos
    var sceneVideos: [SceneVideo]?
    
    /// Title of the script
    var title: String?
    
    /// Default initializer
    init(
        id: String? = nil,
        draftId: String,
        userId: String,
        scenes: [StoryScene],
        scriptOverview: String? = nil,
        status: Status,
        createdAt: Date,
        updatedAt: Date,
        selectedCharacterId: String? = nil,
        selectedCharacterImages: [String]? = nil,
        selectedReferenceImages: [String]? = nil,
        selectedReferenceTextIds: [String]? = nil,
        sceneVideos: [SceneVideo]? = nil,
        title: String? = nil
    ) {
        self.id = id
        self.draftId = draftId
        self.userId = userId
        self.scenes = scenes
        self.scriptOverview = scriptOverview
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.selectedCharacterId = selectedCharacterId
        self.selectedCharacterImages = selectedCharacterImages
        self.selectedReferenceImages = selectedReferenceImages
        self.selectedReferenceTextIds = selectedReferenceTextIds
        self.sceneVideos = sceneVideos
        self.title = title
    }
    
    /// Convert to Firestore data
    var toFirestoreDocument: [String: Any] {
        var data: [String: Any] = [
            "draftId": draftId,
            "userId": userId,
            "scenes": scenes.map { $0.firestoreData },
            "status": status.rawValue,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt)
        ]
        
        if let scriptOverview = scriptOverview {
            data["scriptOverview"] = scriptOverview
        }
        if let selectedCharacterId = selectedCharacterId {
            data["selectedCharacterId"] = selectedCharacterId
        }
        if let selectedCharacterImages = selectedCharacterImages {
            data["selectedCharacterImages"] = selectedCharacterImages
        }
        if let selectedReferenceImages = selectedReferenceImages {
            data["selectedReferenceImages"] = selectedReferenceImages
        }
        if let selectedReferenceTextIds = selectedReferenceTextIds {
            data["selectedReferenceTextIds"] = selectedReferenceTextIds
        }
        if let sceneVideos = sceneVideos {
            data["sceneVideos"] = sceneVideos.map { $0.firestoreData }
        }
        
        return data
    }
    
    /// Convert from Firestore data
    static func fromFirestore(_ data: [String: Any], id: String) -> AIScript? {
        guard let draftId = data["draftId"] as? String,
              let userId = data["userId"] as? String,
              let scenesData = data["scenes"] as? [[String: Any]],
              let statusRaw = data["status"] as? String,
              let status = Status(rawValue: statusRaw),
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let updatedAtTimestamp = data["updatedAt"] as? Timestamp else {
            return nil
        }
        
        let scenes = scenesData.compactMap { StoryScene.fromFirestore($0) }
        let scriptOverview = data["scriptOverview"] as? String
        let selectedCharacterId = data["selectedCharacterId"] as? String
        let selectedCharacterImages = data["selectedCharacterImages"] as? [String]
        let selectedReferenceImages = data["selectedReferenceImages"] as? [String]
        let selectedReferenceTextIds = data["selectedReferenceTextIds"] as? [String]
        let sceneVideosData = data["sceneVideos"] as? [[String: Any]]
        let sceneVideos = sceneVideosData?.compactMap { SceneVideo.fromFirestore($0) }
        
        return AIScript(
            id: id,
            draftId: draftId,
            userId: userId,
            scenes: scenes,
            scriptOverview: scriptOverview,
            status: status,
            createdAt: createdAtTimestamp.dateValue(),
            updatedAt: updatedAtTimestamp.dateValue(),
            selectedCharacterId: selectedCharacterId,
            selectedCharacterImages: selectedCharacterImages,
            selectedReferenceImages: selectedReferenceImages,
            selectedReferenceTextIds: selectedReferenceTextIds,
            sceneVideos: sceneVideos
        )
    }
}

// MARK: - Codable

extension AIScript: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case draftId
        case userId
        case scenes
        case scriptOverview
        case status
        case createdAt
        case updatedAt
        case selectedCharacterId
        case selectedCharacterImages
        case selectedReferenceImages
        case selectedReferenceTextIds
        case title
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decodeIfPresent(String.self, forKey: .id),
            draftId: try container.decode(String.self, forKey: .draftId),
            userId: try container.decode(String.self, forKey: .userId),
            scenes: try container.decode([StoryScene].self, forKey: .scenes),
            scriptOverview: try container.decodeIfPresent(String.self, forKey: .scriptOverview),
            status: try container.decode(Status.self, forKey: .status),
            createdAt: try container.decode(Date.self, forKey: .createdAt),
            updatedAt: try container.decode(Date.self, forKey: .updatedAt),
            selectedCharacterId: try container.decodeIfPresent(String.self, forKey: .selectedCharacterId),
            selectedCharacterImages: try container.decodeIfPresent([String].self, forKey: .selectedCharacterImages),
            selectedReferenceImages: try container.decodeIfPresent([String].self, forKey: .selectedReferenceImages),
            selectedReferenceTextIds: try container.decodeIfPresent([String].self, forKey: .selectedReferenceTextIds),
            title: try container.decodeIfPresent(String.self, forKey: .title)
        )
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(draftId, forKey: .draftId)
        try container.encode(userId, forKey: .userId)
        try container.encode(scenes, forKey: .scenes)
        try container.encode(status, forKey: .status)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(selectedCharacterId, forKey: .selectedCharacterId)
        try container.encodeIfPresent(selectedCharacterImages, forKey: .selectedCharacterImages)
        try container.encodeIfPresent(selectedReferenceImages, forKey: .selectedReferenceImages)
        try container.encodeIfPresent(selectedReferenceTextIds, forKey: .selectedReferenceTextIds)
        try container.encodeIfPresent(title, forKey: .title)
    }
}

// MARK: - Firestore

extension AIScript {
    /// Convert to Firestore data
    var firestoreData: [String: Any] {
        [
            "draftId": draftId,
            "userId": userId,
            "scenes": scenes.map { $0.firestoreData },
            "scriptOverview": scriptOverview as Any,
            "status": status.rawValue,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "selectedCharacterId": selectedCharacterId as Any,
            "selectedCharacterImages": selectedCharacterImages as Any,
            "selectedReferenceImages": selectedReferenceImages as Any,
            "selectedReferenceTextIds": selectedReferenceTextIds as Any,
            "title": title as Any
        ]
    }
} 