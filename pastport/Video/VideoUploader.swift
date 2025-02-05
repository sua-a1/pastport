import Foundation
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth

enum VideoUploadError: Error {
    case noUser
    case uploadFailed(Error)
    case invalidVideoData
    case compressionFailed
    case thumbnailGenerationFailed
}

@Observable
final class VideoUploader {
    private let storage = Storage.storage().reference()
    private let db = Firestore.firestore()
    private(set) var uploadProgress: Double = 0
    
    func uploadVideo(url: URL, caption: String) async throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw VideoUploadError.noUser
        }
        
        print("DEBUG: Starting video upload process")
        
        // Generate unique filename
        let filename = "\(uid)_\(Date().timeIntervalSince1970).mp4"
        let videoRef = storage.child("videos/\(filename)")
        
        print("DEBUG: Uploading to path: videos/\(filename)")
        
        // Upload metadata
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"
        
        // Upload video
        do {
            // Create upload task
            let task = videoRef.putFile(from: url, metadata: metadata)
            
            // Monitor progress
            task.observe(.progress) { [weak self] snapshot in
                guard let self = self,
                      let progress = snapshot.progress else { return }
                
                let percentComplete = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                print("DEBUG: Upload progress: \(Int(percentComplete * 100))%")
                self.uploadProgress = percentComplete
            }
            
            // Wait for completion
            _ = try await task.snapshot
            let downloadURL = try await videoRef.downloadURL()
            
            print("DEBUG: Video uploaded successfully")
            print("DEBUG: Download URL: \(downloadURL.absoluteString)")
            
            // Create post document
            let post = [
                "userId": uid,
                "caption": caption,
                "videoUrl": downloadURL.absoluteString,
                "timestamp": FieldValue.serverTimestamp(),
                "likes": 0,
                "views": 0,
                "shares": 0,
                "comments": 0
            ] as [String : Any]
            
            try await db.collection("posts").addDocument(data: post)
            print("DEBUG: Post document created in Firestore")
            
            return downloadURL.absoluteString
        } catch {
            print("DEBUG: Upload failed: \(error.localizedDescription)")
            throw VideoUploadError.uploadFailed(error)
        }
    }
} 