import Foundation
import FirebaseStorage
import Photos
import UIKit
import AVFoundation

/// Service for handling Firebase Storage operations
actor StorageService {
    static let shared = StorageService()
    
    private let storage = Storage.storage()
    
    private init() {}
    
    /// Upload video to Firebase Storage
    /// - Parameters:
    ///   - url: Local URL of the video file
    ///   - path: The storage path
    ///   - metadata: Additional metadata for the video
    /// - Returns: The download URL of the uploaded video
    func uploadVideo(url: URL, to path: String, metadata customMetadata: [String: String]? = nil) async throws -> String {
        print("DEBUG: Starting video upload to path: \(path)")
        let storageRef = storage.reference().child(path)
        
        // Create metadata
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"
        if let customMetadata = customMetadata {
            print("DEBUG: Adding custom metadata: \(customMetadata)")
            metadata.customMetadata = customMetadata
        }
        
        // Verify file exists and get size
        guard FileManager.default.fileExists(atPath: url.path),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? Int64 else {
            print("ERROR: File not found or cannot get attributes at path: \(url.path)")
            throw StorageError.invalidURL
        }
        
        print("DEBUG: Uploading file of size: \(fileSize) bytes")
        
        return try await withCheckedThrowingContinuation { continuation in
            let uploadTask = storageRef.putFile(from: url, metadata: metadata)
            
            // Monitor progress
            let progressHandle = uploadTask.observe(.progress) { snapshot in
                let percentComplete = Double(snapshot.progress?.completedUnitCount ?? 0) / Double(snapshot.progress?.totalUnitCount ?? 1) * 100
                print("DEBUG: Upload progress: \(String(format: "%.1f", percentComplete))%")
            }
            
            // Handle success
            let successHandle = uploadTask.observe(.success) { _ in
                print("DEBUG: Upload completed successfully")
                uploadTask.removeAllObservers()
                
                // Get download URL
                Task {
                    do {
                        print("DEBUG: Attempting to get download URL for path: \(path)")
                        let downloadURL = try await storageRef.downloadURL()
                        print("DEBUG: Successfully retrieved download URL: \(downloadURL.absoluteString)")
                        continuation.resume(returning: downloadURL.absoluteString)
                    } catch {
                        print("ERROR: Failed to get download URL: \(error.localizedDescription)")
                        if let nsError = error as? NSError {
                            print("ERROR: Domain: \(nsError.domain), Code: \(nsError.code)")
                            print("ERROR: User info: \(nsError.userInfo)")
                        }
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            // Handle failure
            let failureHandle = uploadTask.observe(.failure) { snapshot in
                print("DEBUG: Upload failed")
                uploadTask.removeAllObservers()
                if let error = snapshot.error {
                    print("ERROR: Upload failed with error: \(error.localizedDescription)")
                    if let nsError = error as? NSError {
                        print("ERROR: Domain: \(nsError.domain), Code: \(nsError.code)")
                        print("ERROR: User info: \(nsError.userInfo)")
                    }
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Get the download URL for a video
    /// - Parameter filename: The storage path of the video
    /// - Returns: The download URL of the video
    func getVideoURL(filename: String) async throws -> String {
        let storageRef = storage.reference().child(filename)
        let url = try await storageRef.downloadURL()
        return url.absoluteString
    }
    
    /// Delete a video from storage
    /// - Parameter url: The URL of the video to delete
    func deleteVideo(at url: URL) async throws {
        // Extract the path from the URL
        let components = url.pathComponents
        let filteredComponents = components.filter { component in
            component != "v0" && component != "b"
        }
        guard let path = filteredComponents.joined(separator: "/").removingPercentEncoding else {
            throw StorageError.invalidURL
        }
        
        try await deleteFile(at: path)
    }
    
    /// Save a video to the device's Photos library
    /// - Parameter url: The URL of the video to save
    func saveVideoToPhotos(from url: URL) async throws {
        // Request Photos library access
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized else {
            throw StorageError.photosAccessDenied
        }
        
        // Download video data
        let data = try await downloadVideoData(from: url)
        
        // Create a temporary file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        try data.write(to: tempURL)
        
        // Save to Photos library
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tempURL)
        }
        
        // Clean up temp file
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    /// Download video data from a URL
    /// - Parameter url: The URL of the video
    /// - Returns: The video data
    private func downloadVideoData(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw StorageError.downloadFailed
        }
        
        return data
    }
    
    /// Upload image data to Firebase Storage
    /// - Parameters:
    ///   - data: The image data to upload
    ///   - path: The storage path
    ///   - contentType: The content type (default: "image/jpeg")
    /// - Returns: The download URL of the uploaded file
    func uploadImage(data: Data, path: String, contentType: String = "image/jpeg") async throws -> URL {
        let storageRef = storage.reference().child(path)
        
        // Create metadata
        let metadata = StorageMetadata()
        metadata.contentType = contentType
        
        // Upload data using continuation to handle non-Sendable types
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            storageRef.putData(data, metadata: metadata) { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        
        // Get download URL
        return try await storageRef.downloadURL()
    }
    
    /// Delete a file from Firebase Storage
    /// - Parameter path: The storage path of the file to delete
    func deleteFile(at path: String) async throws {
        let storageRef = storage.reference().child(path)
        try await storageRef.delete()
    }
    
    /// Get the download URL and metadata for a scene video
    /// - Parameters:
    ///   - scriptId: The ID of the script
    ///   - sceneIndex: The index of the scene
    /// - Returns: Tuple containing the download URL and metadata of the video
    func getSceneVideoURLAndMetadata(scriptId: String, sceneIndex: Int) async throws -> (String, [String: String]) {
        print("DEBUG: Getting URL and metadata for scene video - Script: \(scriptId), Scene: \(sceneIndex)")
        let basePath = "videos/scripts/\(scriptId)/scenes"
        let storageRef = storage.reference().child(basePath)
        
        // List all items in the directory
        print("DEBUG: Listing items in directory: \(basePath)")
        let result = try await storageRef.listAll()
        
        // Find the file that starts with our scene index
        let prefix = "\(sceneIndex)_"
        let matchingItems = result.items.filter { $0.name.hasPrefix(prefix) }
        
        guard let videoRef = matchingItems.first else {
            print("DEBUG: No video found for scene \(sceneIndex) in \(basePath)")
            throw StorageError.downloadFailed
        }
        
        print("DEBUG: Found video file: \(videoRef.name)")
        
        // Get metadata
        let metadata = try await videoRef.getMetadata()
        let customMetadata = metadata.customMetadata ?? [:]
        print("DEBUG: Retrieved metadata: \(customMetadata)")
        
        // Get download URL
        let downloadURL = try await videoRef.downloadURL()
        print("DEBUG: Got download URL: \(downloadURL.absoluteString)")
        
        return (downloadURL.absoluteString, customMetadata)
    }
    
    /// Delete a scene video
    /// - Parameters:
    ///   - scriptId: The ID of the script
    ///   - sceneIndex: The index of the scene
    func deleteSceneVideo(scriptId: String, sceneIndex: Int) async throws {
        print("DEBUG: Deleting scene video - Script: \(scriptId), Scene: \(sceneIndex)")
        let path = "videos/scripts/\(scriptId)/scenes/\(sceneIndex).mp4"
        try await deleteFile(at: path)
    }
    
    /// Upload a scene video
    /// - Parameters:
    ///   - url: Local URL of the video file
    ///   - scriptId: The ID of the script
    ///   - sceneIndex: The index of the scene
    ///   - metadata: Additional metadata for the video
    /// - Returns: The download URL of the uploaded video
    func uploadSceneVideo(url: URL, scriptId: String, sceneIndex: Int, metadata: [String: String]? = nil) async throws -> String {
        print("DEBUG: Uploading scene video - Script: \(scriptId), Scene: \(sceneIndex)")
        let path = "videos/scripts/\(scriptId)/scenes/\(sceneIndex).mp4"
        return try await uploadVideo(url: url, to: path, metadata: metadata)
    }
    
    /// Upload a final concatenated video
    /// - Parameters:
    ///   - url: Local URL of the video file
    ///   - scriptId: The ID of the script
    ///   - metadata: Additional metadata for the video
    /// - Returns: The download URL of the uploaded video
    func uploadFinalVideo(url: URL, scriptId: String, metadata: [String: String]? = nil) async throws -> String {
        print("DEBUG: Uploading final video for script: \(scriptId)")
        let path = "videos/scripts/\(scriptId)/final.mp4"
        return try await uploadVideo(url: url, to: path, metadata: metadata)
    }
    
    /// Get the download URL for a final video
    /// - Parameter scriptId: The ID of the script
    /// - Returns: The download URL of the video
    func getFinalVideoURL(scriptId: String) async throws -> String {
        print("DEBUG: Getting URL for final video - Script: \(scriptId)")
        let path = "videos/scripts/\(scriptId)/final.mp4"
        return try await getVideoURL(filename: path)
    }
    
    /// Delete a final video
    /// - Parameter scriptId: The ID of the script
    func deleteFinalVideo(scriptId: String) async throws {
        print("DEBUG: Deleting final video - Script: \(scriptId)")
        let path = "videos/scripts/\(scriptId)/final.mp4"
        try await deleteFile(at: path)
    }
}

// MARK: - Errors

extension StorageService {
    enum StorageError: LocalizedError {
        case invalidURL
        case downloadFailed
        case photosAccessDenied
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid video URL"
            case .downloadFailed:
                return "Failed to download video"
            case .photosAccessDenied:
                return "Access to Photos library denied"
            }
        }
    }
} 