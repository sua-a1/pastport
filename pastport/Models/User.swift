import Foundation

struct User: Identifiable, Codable {
    let id: String
    var username: String
    let email: String
    var profileImageUrl: String?
    var bio: String?
    
    // Additional fields for social features
    var followersCount: Int = 0
    var followingCount: Int = 0
    var postsCount: Int = 0
    
    // Content creation tracking
    var createdPosts: [String] = []  // Post IDs
    var createdCharacters: [String] = []  // Character IDs
    var savedDrafts: [String] = []  // Draft IDs
    
    // User preferences & metadata
    var preferredCategories: [String] = []  // "history", "mythology", etc.
    var dateJoined: Date = Date()
    var lastActive: Date = Date()
    
    // Custom coding keys to match Firestore fields
    enum CodingKeys: String, CodingKey {
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
        case savedDrafts = "saved_drafts"
        case preferredCategories = "preferred_categories"
        case dateJoined = "date_joined"
        case lastActive = "last_active"
    }
} 