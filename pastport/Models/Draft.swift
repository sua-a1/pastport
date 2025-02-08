import Foundation
import FirebaseFirestore

enum DraftCategory: String, Codable, CaseIterable {
    case historical = "Historical"
    case mythAndLore = "Myth & Lore"
}

enum DraftSubcategory: String, Codable, CaseIterable {
    case canonical = "Canonical"
    case speculative = "Speculative"
    case alternate = "Alternate"
}

enum DraftStatus: String, Codable {
    case draft = "Draft"
    case readyForAI = "Ready for AI"
    case generating = "Generating"
    case published = "Published"
}

struct Draft: Identifiable, Codable {
    let id: String
    let userId: String
    var title: String
    var content: String
    var category: DraftCategory
    var subcategory: DraftSubcategory?
    var status: DraftStatus
    
    // Media attachments
    var imageUrls: [String]
    var videoUrls: [String]
    var referenceTextIds: [String]
    
    // Timestamps
    var createdAt: Date
    var updatedAt: Date
    
    // Firestore coding keys
    private enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case content
        case category
        case subcategory
        case status
        case imageUrls = "image_urls"
        case videoUrls = "video_urls"
        case referenceTextIds = "reference_text_ids"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // MARK: - Initialization
    init(
        id: String = UUID().uuidString,
        userId: String,
        title: String,
        content: String,
        category: DraftCategory,
        subcategory: DraftSubcategory? = nil,
        status: DraftStatus = .draft,
        imageUrls: [String] = [],
        videoUrls: [String] = [],
        referenceTextIds: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.content = content
        self.category = category
        self.subcategory = subcategory
        self.status = status
        self.imageUrls = imageUrls
        self.videoUrls = videoUrls
        self.referenceTextIds = referenceTextIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Firestore
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "userId": userId,
            "title": title,
            "content": content,
            "category": category.rawValue,
            "status": status.rawValue,
            "imageUrls": imageUrls,
            "videoUrls": videoUrls,
            "referenceTextIds": referenceTextIds,
            "createdAt": createdAt,
            "updatedAt": updatedAt
        ]
        
        if let subcategory = subcategory {
            data["subcategory"] = subcategory.rawValue
        }
        
        return data
    }
    
    static func fromFirestore(_ data: [String: Any], id: String) -> Draft? {
        print("DEBUG: Parsing draft with ID: \(id)")
        print("DEBUG: Raw data: \(data)")
        
        // Check userId
        guard let userId = data["userId"] as? String else {
            print("DEBUG: Failed to parse userId")
            return nil
        }
        
        // Check title
        guard let title = data["title"] as? String else {
            print("DEBUG: Failed to parse title")
            return nil
        }
        
        // Check content
        guard let content = data["content"] as? String else {
            print("DEBUG: Failed to parse content")
            return nil
        }
        
        // Check category
        guard let categoryString = data["category"] as? String,
              let category = DraftCategory(rawValue: categoryString) else {
            print("DEBUG: Failed to parse category")
            return nil
        }
        
        // Optional subcategory
        let subcategory = (data["subcategory"] as? String).flatMap(DraftSubcategory.init)
        
        // Check status
        let statusString = data["status"] as? String ?? DraftStatus.draft.rawValue
        guard let status = DraftStatus(rawValue: statusString) else {
            print("DEBUG: Failed to parse status")
            return nil
        }
        
        // Handle timestamps
        let createdAt: Date
        let updatedAt: Date
        
        if let createdTimestamp = data["createdAt"] as? Timestamp {
            createdAt = createdTimestamp.dateValue()
        } else {
            print("DEBUG: Failed to parse createdAt timestamp")
            createdAt = Date()
        }
        
        if let updatedTimestamp = data["updatedAt"] as? Timestamp {
            updatedAt = updatedTimestamp.dateValue()
        } else {
            print("DEBUG: Failed to parse updatedAt timestamp")
            updatedAt = createdAt
        }
        
        // Handle arrays
        let imageUrls: [String]
        if let urls = data["imageUrls"] as? [String] {
            imageUrls = urls
        } else if let urls = (data["imageUrls"] as? NSArray)?.compactMap({ $0 as? String }) {
            imageUrls = urls
        } else {
            imageUrls = []
        }
        
        let videoUrls: [String]
        if let urls = data["videoUrls"] as? [String] {
            videoUrls = urls
        } else if let urls = (data["videoUrls"] as? NSArray)?.compactMap({ $0 as? String }) {
            videoUrls = urls
        } else {
            videoUrls = []
        }
        
        let referenceTextIds: [String]
        if let ids = data["referenceTextIds"] as? [String] {
            referenceTextIds = ids
        } else if let ids = (data["referenceTextIds"] as? NSArray)?.compactMap({ $0 as? String }) {
            referenceTextIds = ids
        } else {
            referenceTextIds = []
        }
        
        return Draft(
            id: id,
            userId: userId,
            title: title,
            content: content,
            category: category,
            subcategory: subcategory,
            status: status,
            imageUrls: imageUrls,
            videoUrls: videoUrls,
            referenceTextIds: referenceTextIds,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    // MARK: - Media Management
    mutating func addImage(url: String) {
        imageUrls.append(url)
        updatedAt = Date()
    }
    
    mutating func removeImage(url: String) {
        imageUrls.removeAll { $0 == url }
        updatedAt = Date()
    }
    
    mutating func addVideo(url: String) {
        videoUrls.append(url)
        updatedAt = Date()
    }
    
    mutating func removeVideo(url: String) {
        videoUrls.removeAll { $0 == url }
        updatedAt = Date()
    }
    
    mutating func addReferenceText(_ referenceId: String) {
        if !referenceTextIds.contains(referenceId) {
            referenceTextIds.append(referenceId)
            updatedAt = Date()
        }
    }
    
    mutating func removeReferenceText(_ referenceId: String) {
        referenceTextIds.removeAll { $0 == referenceId }
        updatedAt = Date()
    }
} 