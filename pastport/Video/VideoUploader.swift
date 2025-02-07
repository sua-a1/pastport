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
    
    func uploadVideo(url: URL, caption: String, categorization: PostCategorization) async throws -> String {
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
            "originalFilename": url.lastPathComponent,
            "category": categorization.category.rawValue,
            "subcategory": categorization.subcategory.rawValue
        ]
        
        // Upload video
        do {
            print("DEBUG: Starting upload")
            let data = try Data(contentsOf: url, options: .alwaysMapped)
            
            return try await withCheckedThrowingContinuation { continuation in
                var lastProgressUpdate = Date()
                
                // Create upload task with built-in chunked upload
                let task = videoRef.putData(data, metadata: metadata)
                
                // Monitor progress
                let progressHandle = task.observe(.progress) { [weak self] snapshot in
                    guard let self = self,
                          let progress = snapshot.progress else { return }
                    
                    let percentComplete = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                    
                    // Update progress at most once per second
                    let now = Date()
                    if now.timeIntervalSince(lastProgressUpdate) >= 1.0 {
                        lastProgressUpdate = now
                        self.uploadProgress = percentComplete
                        print("DEBUG: Upload progress: \(Int(percentComplete * 100))%")
                        
                        // Calculate speed
                        let bytesPerSecond = Double(progress.completedUnitCount) / now.timeIntervalSince(lastProgressUpdate)
                        print("DEBUG: Upload speed: \(String(format: "%.2f", bytesPerSecond / 1024 / 1024))MB/s")
                    }
                }
                
                // Handle success
                let successHandle = task.observe(.success) { [weak self] _ in
                    print("DEBUG: Upload completed successfully")
                    task.removeAllObservers()
                    
                    // Get download URL and create post document
                    Task {
                        do {
                            let downloadURL = try await videoRef.downloadURL()
                            print("DEBUG: Got download URL: \(downloadURL.absoluteString)")
                            
                            // Create post document
                            let post = [
                                "userId": uid,
                                "caption": caption,
                                "videoUrl": downloadURL.absoluteString,
                                "videoFilename": filename,
                                "timestamp": Timestamp(date: Date()),
                                "likes": 0,
                                "views": 0,
                                "shares": 0,
                                "comments": 0,
                                "category": categorization.category.rawValue,
                                "subcategory": categorization.subcategory.rawValue
                            ] as [String : Any]
                            
                            // Add to main posts collection
                            let docRef = try await self?.db.collection("posts").addDocument(data: post)
                            
                            // Add to user's posts subcollection
                            try await self?.db.collection("users").document(uid)
                                .collection("posts").document(docRef?.documentID ?? "")
                                .setData(post)
                            
                            print("DEBUG: Post documents created successfully")
                            continuation.resume(returning: docRef?.documentID ?? "")
                        } catch {
                            print("DEBUG: Failed to create post documents: \(error)")
                            continuation.resume(throwing: VideoUploadError.uploadFailed(error))
                        }
                    }
                }
                
                // Handle failure
                let failureHandle = task.observe(.failure) { snapshot in
                    print("DEBUG: Upload failed: \(snapshot.error?.localizedDescription ?? "Unknown error")")
                    task.removeAllObservers()
                    continuation.resume(throwing: VideoUploadError.uploadFailed(snapshot.error ?? NSError()))
                }
            }
        } catch {
            print("DEBUG: Upload failed with error: \(error)")
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