import SwiftUI
import FirebaseFirestore
import FirebaseStorage

@MainActor
final class ProfileViewModel: ObservableObject {
    // MARK: - Properties
    @Published var user: User
    @Published var userPosts: [Post] = []
    @Published var userDrafts: [Draft] = []
    @Published var isLoadingVideos = false
    @Published var isLoadingDrafts = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    // MARK: - Initialization
    init(user: User) {
        self.user = user
    }
    
    func loadInitialData() {
        Task {
            await fetchUserPosts()
            await fetchUserDrafts()
        }
    }
    
    // MARK: - Methods
    public func fetchUserPosts() async {
        isLoadingVideos = true
        print("DEBUG: Starting to fetch user posts for user ID: \(user.id)")
        
        do {
            let snapshot = try await db.collection("users")
                .document(user.id)
                .collection("posts")
                .order(by: "timestamp", descending: true)
                .getDocuments()
            
            print("DEBUG: Found \(snapshot.documents.count) posts")
            userPosts = snapshot.documents.compactMap { document in
                Post(id: document.documentID, data: document.data())
            }
            print("DEBUG: Successfully parsed \(userPosts.count) posts")
        } catch {
            print("DEBUG: Failed to fetch user posts: \(error)")
        }
        
        isLoadingVideos = false
    }
    
    public func fetchUserDrafts() async {
        isLoadingDrafts = true
        print("DEBUG: Starting to fetch user drafts for user ID: \(user.id)")
        
        do {
            let snapshot = try await db.collection("users")
                .document(user.id)
                .collection("drafts")
                .order(by: "updatedAt", descending: true)
                .getDocuments()
            
            print("DEBUG: Found \(snapshot.documents.count) drafts")
            userDrafts = snapshot.documents.compactMap { document in
                Draft.fromFirestore(document.data(), id: document.documentID)
            }
            print("DEBUG: Successfully parsed \(userDrafts.count) drafts")
        } catch {
            print("DEBUG: Failed to fetch user drafts: \(error)")
        }
        
        isLoadingDrafts = false
    }
    
    public func updateProfile(username: String, bio: String?, preferredCategories: [String]) async throws {
        // Update Firestore
        try await db.collection("users").document(user.id).updateData([
            "username": username,
            "bio": bio ?? NSNull(),
            "preferredCategories": preferredCategories
        ])
        
        // Update local state
        user.username = username
        user.bio = bio
        user.preferredCategories = preferredCategories
    }
    
    public func uploadProfileImage(_ imageData: Data) async throws -> String {
        let filename = "\(UUID().uuidString).jpg"
        let path = "users/\(user.id)/profile/\(filename)"
        let storageRef = Storage.storage().reference().child(path)
        
        let _ = try await storageRef.putDataAsync(imageData)
        let url = try await storageRef.downloadURL()
        
        // Update Firestore
        try await db.collection("users").document(user.id).updateData([
            "profileImageUrl": url.absoluteString
        ])
        
        // Update local state
        user.profileImageUrl = url.absoluteString
        return url.absoluteString
    }
} 