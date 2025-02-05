import Foundation
import FirebaseFirestore

struct Post: Identifiable, Codable {
    let id: String
    let userId: String
    let caption: String
    let videoUrl: String
    let videoFilename: String
    let timestamp: Date
    var likes: Int
    var views: Int
    var shares: Int
    var comments: Int
    let category: String
    let type: String
    let status: String
    let metadata: [String: String]
    
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
        metadata = try container.decode([String: String].self, forKey: .metadata)
    }
    
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
        self.metadata = (data["metadata"] as? [String: String]) ?? [:]
    }
} 