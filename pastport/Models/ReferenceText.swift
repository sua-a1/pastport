import Foundation
import FirebaseFirestore

struct ReferenceText: Identifiable, Codable {
    let id: String
    let userId: String
    var title: String
    var content: String
    var source: String?
    var draftIds: [String]
    
    // Timestamps
    var createdAt: Date
    var updatedAt: Date
    
    // Firestore coding keys
    private enum CodingKeys: String, CodingKey {
        case id
        case userId
        case title
        case content
        case source
        case draftIds
        case createdAt
        case updatedAt
    }
    
    // MARK: - Initialization
    init(
        id: String = UUID().uuidString,
        userId: String,
        title: String,
        content: String,
        source: String? = nil,
        draftIds: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.content = content
        self.source = source
        self.draftIds = draftIds
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
            "draftIds": draftIds,
            "createdAt": createdAt,
            "updatedAt": updatedAt
        ]
        
        if let source = source {
            data["source"] = source
        }
        
        return data
    }
    
    static func fromFirestore(_ data: [String: Any], id: String) -> ReferenceText? {
        guard
            let userId = data["userId"] as? String,
            let title = data["title"] as? String,
            let content = data["content"] as? String
        else { return nil }
        
        return ReferenceText(
            id: id,
            userId: userId,
            title: title,
            content: content,
            source: data["source"] as? String,
            draftIds: data["draftIds"] as? [String] ?? [],
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
    
    // MARK: - Draft Management
    mutating func addDraft(_ draftId: String) {
        if !draftIds.contains(draftId) {
            draftIds.append(draftId)
            updatedAt = Date()
        }
    }
    
    mutating func removeDraft(_ draftId: String) {
        draftIds.removeAll { $0 == draftId }
        updatedAt = Date()
    }
    
    // MARK: - Content Management
    mutating func updateContent(title: String, content: String, source: String?) {
        self.title = title
        self.content = content
        self.source = source
        self.updatedAt = Date()
    }
} 