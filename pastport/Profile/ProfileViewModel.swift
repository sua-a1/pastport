import Foundation
import FirebaseFirestore
import FirebaseStorage

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: User
    @Published var isLoadingVideos = false
    @Published var isLoadingDrafts = false
    @Published var isLoading = false  // For profile updates only
    @Published var errorMessage: String?
    @Published var userPosts: [Post] = []
    @Published var userDrafts: [Draft] = []
    
    private let firestore = Firestore.firestore()
    
    init(user: User) {
        self.user = user
        print("DEBUG: ProfileViewModel initialized for user: \(user.id)")
        Task {
            async let posts = fetchUserPosts()
            async let drafts = fetchUserDrafts()
            _ = await [posts, drafts]
        }
    }
    
    @MainActor
    func updateProfile(username: String, bio: String?, preferredCategories: [String]) async throws -> User {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Update user object
            var updatedUser = user
            updatedUser.username = username
            updatedUser.bio = bio
            updatedUser.preferredCategories = preferredCategories
            updatedUser.lastActive = Date()
            
            // Update Firestore
            let encodedUser = try Firestore.Encoder().encode(updatedUser)
            try await Firestore.firestore().collection("users").document(user.id).updateData(encodedUser)
            
            // Fetch fresh user data to ensure consistency
            let snapshot = try await Firestore.firestore().collection("users").document(user.id).getDocument()
            updatedUser = try snapshot.data(as: User.self)
            self.user = updatedUser
            
            print("DEBUG: Updated profile for user: \(user.id) with username: \(username)")
            return updatedUser
        } catch {
            errorMessage = error.localizedDescription
            print("DEBUG: Failed to update profile: \(error.localizedDescription)")
            throw error
        }
    }
    
    func uploadProfileImage(_ imageData: Data) async throws -> String {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Compress image data if needed
            let maxSize: Int = 2 * 1024 * 1024 // 2MB
            var finalImageData = imageData
            if imageData.count > maxSize {
                print("DEBUG: Compressing image from \(imageData.count) bytes")
                if let image = UIImage(data: imageData),
                   let compressedData = image.jpegData(compressionQuality: 0.5) {
                    finalImageData = compressedData
                    print("DEBUG: Compressed to \(finalImageData.count) bytes")
                }
            }
            
            let filename = "\(user.id)_profile.jpg"
            let storageRef = Storage.storage().reference().child("profile_images/\(filename)")
            print("DEBUG: Starting image upload for user: \(user.id)")
            print("DEBUG: Image data size: \(finalImageData.count) bytes")
            
            // Delete existing image if it exists
            do {
                _ = try await storageRef.delete()
                print("DEBUG: Deleted existing profile image")
            } catch {
                print("DEBUG: No existing profile image to delete or error: \(error.localizedDescription)")
            }
            
            // Upload image with metadata
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            // Upload image with metadata
            _ = try await storageRef.putDataAsync(finalImageData, metadata: metadata)
            print("DEBUG: Image uploaded successfully")
            
            let url = try await storageRef.downloadURL()
            print("DEBUG: Got download URL: \(url.absoluteString)")
            
            // Update user profile with new image URL
            var updatedUser = user
            updatedUser.profileImageUrl = url.absoluteString
            
            let encodedUser = try Firestore.Encoder().encode(updatedUser)
            try await Firestore.firestore().collection("users").document(user.id).updateData(encodedUser)
            
            // Fetch fresh user data to ensure consistency
            let snapshot = try await Firestore.firestore().collection("users").document(user.id).getDocument()
            if let freshUser = try? snapshot.data(as: User.self) {
                await MainActor.run {
                    self.user = freshUser
                }
            }
            
            print("DEBUG: Updated user profile with new image URL")
            return url.absoluteString
        } catch {
            print("DEBUG: Failed to upload image: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    @MainActor
    func fetchUserPosts() async {
        guard !isLoadingVideos else { return }
        isLoadingVideos = true
        defer { isLoadingVideos = false }
        
        do {
            let snapshot = try await Firestore.firestore()
                .collection("users")
                .document(user.id)
                .collection("posts")
                .order(by: "timestamp", descending: true)
                .getDocuments()
            
            userPosts = snapshot.documents.map { doc in
                Post(id: doc.documentID, data: doc.data())
            }
            
            print("DEBUG: Fetched \(userPosts.count) posts for user: \(user.id)")
        } catch {
            print("DEBUG: Failed to fetch user posts: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    func fetchUserDrafts() async {
        guard !isLoadingDrafts else { return }
        isLoadingDrafts = true
        
        do {
            print("DEBUG: Fetching drafts for user: \(user.id)")
            let snapshot = try await firestore
                .collection("users")
                .document(user.id)
                .collection("drafts")
                .order(by: "updatedAt", descending: true)
                .getDocuments()
            
            let drafts = snapshot.documents.compactMap { document -> Draft? in
                guard let draft = Draft.fromFirestore(document.data(), id: document.documentID) else {
                    print("DEBUG: Failed to parse draft: \(document.documentID)")
                    return nil
                }
                return draft
            }
            
            print("DEBUG: Fetched \(drafts.count) drafts")
            self.userDrafts = drafts
            self.isLoadingDrafts = false
        } catch {
            print("DEBUG: Error fetching drafts: \(error)")
            errorMessage = "Failed to load drafts"
            isLoadingDrafts = false
        }
    }
} 