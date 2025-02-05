import Foundation
import FirebaseFirestore

struct Post: Identifiable, Codable {
    let id: String
    let userId: String
    let caption: String
    let videoUrl: String
    let videoFilename: String
    var timestamp: Date
    var likes: Int
    var views: Int
    var shares: Int
    var comments: Int
    let category: String
    let type: String
    let status: String
    let metadata: [String: Any]
    
    init(id: String, data: [String: Any]) {
        self.id = id
        self.userId = data["userId"] as? String ?? ""
        self.caption = data["caption"] as? String ?? ""
        self.videoUrl = data["videoUrl"] as? String ?? ""
        self.videoFilename = data["videoFilename"] as? String ?? ""
        self.timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        self.likes = data["likes"] as? Int ?? 0
        self.views = data["views"] as? Int ?? 0
        self.shares = data["shares"] as? Int ?? 0
        self.comments = data["comments"] as? Int ?? 0
        self.category = data["category"] as? String ?? "history"
        self.type = data["type"] as? String ?? "video"
        self.status = data["status"] as? String ?? "active"
        self.metadata = data["metadata"] as? [String: Any] ?? [:]
    }
    
    // Custom coding keys to match Firestore fields
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case caption
        case videoUrl
        case videoFilename
        case timestamp
        case likes
        case views
        case shares
        case comments
        case category
        case type
        case status
        case metadata
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        caption = try container.decode(String.self, forKey: .caption)
        videoUrl = try container.decode(String.self, forKey: .videoUrl)
        videoFilename = try container.decode(String.self, forKey: .videoFilename)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        likes = try container.decode(Int.self, forKey: .likes)
        views = try container.decode(Int.self, forKey: .views)
        shares = try container.decode(Int.self, forKey: .shares)
        comments = try container.decode(Int.self, forKey: .comments)
        category = try container.decode(String.self, forKey: .category)
        type = try container.decode(String.self, forKey: .type)
        status = try container.decode(String.self, forKey: .status)
        
        // Handle metadata as a special case since it's [String: Any]
        let metadataContainer = try container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: .metadata)
        var metadata: [String: Any] = [:]
        for key in metadataContainer.allKeys {
            if let stringValue = try? metadataContainer.decode(String.self, forKey: key) {
                metadata[key.stringValue] = stringValue
            } else if let intValue = try? metadataContainer.decode(Int.self, forKey: key) {
                metadata[key.stringValue] = intValue
            } else if let doubleValue = try? metadataContainer.decode(Double.self, forKey: key) {
                metadata[key.stringValue] = doubleValue
            } else if let boolValue = try? metadataContainer.decode(Bool.self, forKey: key) {
                metadata[key.stringValue] = boolValue
            }
        }
        self.metadata = metadata
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(caption, forKey: .caption)
        try container.encode(videoUrl, forKey: .videoUrl)
        try container.encode(videoFilename, forKey: .videoFilename)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(likes, forKey: .likes)
        try container.encode(views, forKey: .views)
        try container.encode(shares, forKey: .shares)
        try container.encode(comments, forKey: .comments)
        try container.encode(category, forKey: .category)
        try container.encode(type, forKey: .type)
        try container.encode(status, forKey: .status)
        
        // Handle metadata encoding
        var metadataContainer = container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: .metadata)
        for (key, value) in metadata {
            let codingKey = DynamicCodingKeys(stringValue: key)
            if let stringValue = value as? String {
                try metadataContainer.encode(stringValue, forKey: codingKey)
            } else if let intValue = value as? Int {
                try metadataContainer.encode(intValue, forKey: codingKey)
            } else if let doubleValue = value as? Double {
                try metadataContainer.encode(doubleValue, forKey: codingKey)
            } else if let boolValue = value as? Bool {
                try metadataContainer.encode(boolValue, forKey: codingKey)
            }
        }
    }
}

// Dynamic coding keys for metadata dictionary
struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init(stringValue: String) {
        self.stringValue = stringValue
    }
    
    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = String(intValue)
    }
} 