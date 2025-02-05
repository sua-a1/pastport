import Foundation
import FirebaseFirestore
import FirebaseStorage

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: User
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init(user: User) {
        self.user = user
        print("DEBUG: ProfileViewModel initialized for user: \(user.id)")
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
            let filename = "\(user.id)_profile.jpg"
            let storageRef = Storage.storage().reference().child("profile_images/\(filename)")
            print("DEBUG: Starting image upload for user: \(user.id)")
            print("DEBUG: Image data size: \(imageData.count) bytes")
            
            // Upload metadata
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            // Upload image with metadata
            _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
            print("DEBUG: Image uploaded successfully")
            
            let url = try await storageRef.downloadURL()
            print("DEBUG: Got download URL: \(url.absoluteString)")
            
            // Update user profile with new image URL
            var updatedUser = user
            updatedUser.profileImageUrl = url.absoluteString
            
            let encodedUser = try Firestore.Encoder().encode(updatedUser)
            try await Firestore.firestore().collection("users").document(user.id).updateData(encodedUser)
            
            self.user = updatedUser
            print("DEBUG: Updated user profile with new image URL")
            return url.absoluteString
        } catch {
            print("DEBUG: Failed to upload image: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            throw error
        }
    }
} 