import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable {
    let id: String
    var username: String
    var email: String
    var profileImageUrl: String?
    var bio: String?
    
    // Social features
    var followersCount: Int
    var followingCount: Int
    var postsCount: Int
    
    // Content creation tracking
    var createdPosts: [String]
    var createdCharacters: [String]
    var preferredCategories: [String]
    
    var dateJoined: Date
    var lastActive: Date
    
    // Firestore coding keys
    private enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case profileImageUrl = "profile_image_url"
        case bio
        case followersCount = "followers_count"
        case followingCount = "following_count"
        case postsCount = "posts_count"
        case createdPosts = "created_posts"
        case createdCharacters = "created_characters"
        case preferredCategories = "preferred_categories"
        case dateJoined = "date_joined"
        case lastActive = "last_active"
    }
    
    // MARK: - Initialization
    init(
        id: String,
        username: String,
        email: String,
        profileImageUrl: String? = nil,
        bio: String? = nil,
        followersCount: Int = 0,
        followingCount: Int = 0,
        postsCount: Int = 0,
        createdPosts: [String] = [],
        createdCharacters: [String] = [],
        preferredCategories: [String] = [],
        dateJoined: Date = Date(),
        lastActive: Date = Date()
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.profileImageUrl = profileImageUrl
        self.bio = bio
        self.followersCount = followersCount
        self.followingCount = followingCount
        self.postsCount = postsCount
        self.createdPosts = createdPosts
        self.createdCharacters = createdCharacters
        self.preferredCategories = preferredCategories
        self.dateJoined = dateJoined
        self.lastActive = lastActive
    }
    
    // MARK: - Firestore
    func toFirestore() -> [String: Any] {
        return [
            "id": id,
            "username": username,
            "email": email,
            "profile_image_url": profileImageUrl as Any,
            "bio": bio as Any,
            "followers_count": followersCount,
            "following_count": followingCount,
            "posts_count": postsCount,
            "created_posts": createdPosts,
            "created_characters": createdCharacters,
            "preferred_categories": preferredCategories,
            "date_joined": dateJoined,
            "last_active": lastActive
        ]
    }
    
    static func fromFirestore(_ data: [String: Any], id: String) -> User? {
        guard
            let username = data["username"] as? String,
            let email = data["email"] as? String
        else { return nil }
        
        return User(
            id: id,
            username: username,
            email: email,
            profileImageUrl: data["profile_image_url"] as? String,
            bio: data["bio"] as? String,
            followersCount: data["followers_count"] as? Int ?? 0,
            followingCount: data["following_count"] as? Int ?? 0,
            postsCount: data["posts_count"] as? Int ?? 0,
            createdPosts: data["created_posts"] as? [String] ?? [],
            createdCharacters: data["created_characters"] as? [String] ?? [],
            preferredCategories: data["preferred_categories"] as? [String] ?? [],
            dateJoined: (data["date_joined"] as? Timestamp)?.dateValue() ?? Date(),
            lastActive: (data["last_active"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
} 