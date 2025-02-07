import Foundation
import SwiftUI
import AVFoundation
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth
import PhotosUI

enum VideoUploadError: LocalizedError {
    case noUser
    case uploadFailed(Error)
    case invalidVideoData
    case compressionFailed
    case thumbnailGenerationFailed
    
    var errorDescription: String? {
        switch self {
        case .noUser:
            return "No authenticated user found. Please sign in and try again."
        case .uploadFailed(let error):
            return "Upload failed: \(error.localizedDescription)"
        case .invalidVideoData:
            return "Invalid video data. Please try again with a different video."
        case .compressionFailed:
            return "Video compression failed. Please try again."
        case .thumbnailGenerationFailed:
            return "Failed to generate video thumbnail."
        }
    }
}

@Observable
final class VideoUploader {
    private let storage = Storage.storage().reference()
    private let db = Firestore.firestore()
    private(set) var uploadProgress: Double = 0
    
    func uploadVideo(url: URL, caption: String) async throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("DEBUG: Upload failed - No authenticated user")
            throw VideoUploadError.noUser
        }
        
        // Verify video exists and is readable
        guard FileManager.default.fileExists(atPath: url.path),
              let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 else {
            print("DEBUG: Upload failed - Invalid video data or file not accessible")
            throw VideoUploadError.invalidVideoData
        }
        
        print("DEBUG: Starting video upload process")
        print("DEBUG: Video file size: \(fileSize) bytes")
        
        // Generate unique filename with user ID
        let timestamp = Date().timeIntervalSince1970
        let filename = "\(uid)_\(timestamp).mp4"
        let videoRef = storage.child("videos/\(filename)")
        
        print("DEBUG: Uploading to path: videos/\(filename)")
        
        // Upload metadata
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"
        metadata.customMetadata = [
            "userId": uid,
            "caption": caption,
            "timestamp": String(timestamp),
            "originalFilename": url.lastPathComponent
        ]
        
        // Upload video
        do {
            print("DEBUG: Creating upload task with metadata")
            
            return try await withCheckedThrowingContinuation { continuation in
                print("DEBUG: Starting upload continuation")
                
                // Create upload task
                let task = videoRef.putFile(from: url, metadata: metadata)
                var handles: Set<String> = []
                
                // Monitor progress
                let progressHandle = task.observe(.progress) { [weak self] snapshot in
                    guard let self = self,
                          let progress = snapshot.progress else {
                        print("DEBUG: Failed to get upload progress")
                        return
                    }
                    
                    let percentComplete = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                    print("DEBUG: Upload progress: \(Int(percentComplete * 100))%")
                    self.uploadProgress = percentComplete
                }
                
                // Handle success
                let successHandle = task.observe(.success) { [weak self] _ in
                    print("DEBUG: Upload completed successfully, removing observers")
                    
                    // Remove observers
                    task.removeAllObservers()
                    
                    // Get download URL and create post document
                    Task {
                        do {
                            print("DEBUG: Attempting to get download URL")
                            let downloadURL = try await videoRef.downloadURL()
                            print("DEBUG: Got download URL: \(downloadURL.absoluteString)")
                            
                            // Create post document with metadata
                            let post = [
                                "userId": uid,
                                "caption": caption,
                                "videoUrl": downloadURL.absoluteString,
                                "videoFilename": filename,
                                "timestamp": FieldValue.serverTimestamp(),
                                "likes": 0,
                                "views": 0,
                                "shares": 0,
                                "comments": 0,
                                "category": "history",
                                "type": "video",
                                "status": "active",
                                "metadata": [
                                    "originalFilename": url.lastPathComponent,
                                    "uploadTimestamp": timestamp,
                                    "fileSize": fileSize
                                ] as [String: Any]
                            ] as [String : Any]
                            
                            print("DEBUG: Creating Firestore post document")
                            // Add to posts collection
                            try await self?.db.collection("posts").addDocument(data: post)
                            print("DEBUG: Post document created in Firestore")
                            
                            // Add to user's posts collection
                            try await self?.db.collection("users").document(uid)
                                .collection("posts").addDocument(data: post)
                            print("DEBUG: Added to user's posts collection")
                            
                            continuation.resume(returning: downloadURL.absoluteString)
                        } catch {
                            print("DEBUG: Post-upload processing failed: \(error.localizedDescription)")
                            continuation.resume(throwing: VideoUploadError.uploadFailed(error))
                        }
                    }
                }
                
                // Handle failure
                let failureHandle = task.observe(.failure) { snapshot in
                    print("DEBUG: Upload failed with error: \(String(describing: snapshot.error))")
                    if let error = snapshot.error as NSError? {
                        print("DEBUG: Error details - Domain: \(error.domain), Code: \(error.code)")
                        print("DEBUG: Error user info: \(error.userInfo)")
                    }
                    
                    // Remove observers
                    task.removeAllObservers()
                    
                    if let error = snapshot.error {
                        continuation.resume(throwing: VideoUploadError.uploadFailed(error))
                    } else {
                        continuation.resume(throwing: VideoUploadError.uploadFailed(NSError(domain: "VideoUploader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown upload error"])))
                    }
                }
                
                print("DEBUG: Upload observers set up with metadata:")
                print("DEBUG: Content type: \(metadata.contentType ?? "nil")")
                if let customMetadata = metadata.customMetadata {
                    print("DEBUG: Custom metadata: \(customMetadata)")
                }
                
                // Add state observer
                task.observe(.resume) { snapshot in
                    print("DEBUG: Upload task resumed")
                }
                task.observe(.pause) { snapshot in
                    print("DEBUG: Upload task paused")
                }
                
                print("DEBUG: Upload observers set up")
            }
        } catch {
            print("DEBUG: Upload failed: \(error.localizedDescription)")
            throw VideoUploadError.uploadFailed(error)
        }
    }
    
    func getVideoURL(filename: String) async throws -> URL {
        let videoRef = storage.child("videos/\(filename)")
        return try await videoRef.downloadURL()
    }
    
    func getPostsByUser(userId: String, limit: Int = 10) async throws -> [[String: Any]] {
        let snapshot = try await db.collection("users").document(userId)
            .collection("posts")
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.map { $0.data() }
    }
    
    func getAllPosts(limit: Int = 10) async throws -> [[String: Any]] {
        let snapshot = try await db.collection("posts")
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.map { $0.data() }
    }
    
    static func uploadVideo(from item: PhotosPickerItem, to path: String) async throws -> String {
        print("DEBUG: Starting video upload process")
        
        // Load video data
        guard let movie = try? await item.loadTransferable(type: MovieTransferable.self) else {
            throw NSError(domain: "VideoUploader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load video data"])
        }
        
        // Create AVAsset for compression
        let asset = AVAsset(url: movie.url)
        
        // Create temp URL for compressed video
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        // Compress video
        print("DEBUG: Compressing video")
        try await compressVideo(asset: asset, outputURL: tempURL)
        
        // Upload to Firebase
        print("DEBUG: Uploading compressed video")
        let storage = Storage.storage().reference()
        let videoRef = storage.child(path)
        
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"
        
        _ = try await videoRef.putFileAsync(from: tempURL, metadata: metadata)
        let downloadURL = try await videoRef.downloadURL()
        
        // Clean up temp file
        try? FileManager.default.removeItem(at: tempURL)
        
        print("DEBUG: Video upload complete")
        return downloadURL.absoluteString
    }
    
    private static func compressVideo(asset: AVAsset, outputURL: URL) async throws {
        let composition = AVMutableComposition()
        guard let compositionTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw NSError(domain: "VideoUploader", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create composition track"])
        }
        
        guard let assetTrack = try? await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "VideoUploader", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to load video track"])
        }
        
        try compositionTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: try await asset.load(.duration)),
            of: assetTrack,
            at: .zero
        )
        
        // Configure compression settings
        guard let session = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetMediumQuality
        ) else {
            throw NSError(domain: "VideoUploader", code: -4, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }
        
        session.outputURL = outputURL
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true
        
        await session.export()
        
        if let error = session.error {
            throw error
        }
    }
} 