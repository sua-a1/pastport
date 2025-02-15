import Foundation
import Cloudinary

/// Service responsible for stitching multiple video clips together using Cloudinary
@Observable final class VideoStitchingService {
    // MARK: - Types
    
    enum StitchingError: LocalizedError {
        case invalidVideoUrls
        case concatenationFailed(String)
        case noOutputUrl
        case cloudinaryError(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidVideoUrls:
                return "Invalid video URLs provided"
            case .concatenationFailed(let message):
                return "Video concatenation failed: \(message)"
            case .noOutputUrl:
                return "No output URL in response"
            case .cloudinaryError(let message):
                return "Cloudinary error: \(message)"
            }
        }
    }
    
    // MARK: - Properties
    
    private let cloudinary: CLDCloudinary
    private var currentProgress: Double = 0.0
    private(set) var isProcessing = false
    private(set) var errorMessage: String?
    private let transitionDuration: Int
    private let clipDuration: Int
    
    // MARK: - Initialization
    
    init(cloudName: String, apiKey: String, apiSecret: String, transitionDuration: Int = 1, clipDuration: Int = 5) {
        print("DEBUG: Initializing VideoStitchingService")
        // Configure Cloudinary with credentials
        let config = CLDConfiguration(cloudName: cloudName, apiKey: apiKey, apiSecret: apiSecret, secure: true)
        self.cloudinary = CLDCloudinary(configuration: config)
        self.transitionDuration = transitionDuration
        self.clipDuration = clipDuration
        print("DEBUG: Cloudinary initialized with config: cloudName=\(cloudName)")
    }
    
    // MARK: - Public Methods
    
    /// Stitches multiple video clips together using Cloudinary
    /// - Parameters:
    ///   - videoUrls: Array of video URLs to stitch together
    ///   - prompt: Description of the overall video sequence (used for metadata)
    /// - Returns: URL of the final stitched video
    func stitchVideos(videoUrls: [String], prompt: String) async throws -> URL {
        print("DEBUG: Starting video stitching process with Cloudinary")
        print("DEBUG: Number of clips to stitch: \(videoUrls.count)")
        
        guard videoUrls.count >= 2 else {
            print("ERROR: Need at least 2 videos to stitch")
            throw StitchingError.invalidVideoUrls
        }
        
        isProcessing = true
        currentProgress = 0.0
        errorMessage = nil
        
        do {
            // First, download all videos from Firebase and upload to Cloudinary
            print("DEBUG: Starting video upload process to Cloudinary")
            var cloudinaryIds: [String] = []
            
            for (index, firebaseUrl) in videoUrls.enumerated() {
                print("DEBUG: Processing video \(index + 1) of \(videoUrls.count)")
                
                // Download video from Firebase
                print("DEBUG: Downloading video from Firebase: \(firebaseUrl)")
                let (tempUrl, _) = try await URLSession.shared.download(from: URL(string: firebaseUrl)!)
                
                // Upload to Cloudinary
                print("DEBUG: Uploading video \(index + 1) to Cloudinary")
                let publicId = try await uploadVideo(url: tempUrl)
                cloudinaryIds.append(publicId)
                
                // Clean up temp file
                try? FileManager.default.removeItem(at: tempUrl)
                
                // Update progress
                currentProgress = Double(index + 1) / Double(videoUrls.count)
            }
            
            print("DEBUG: All videos uploaded to Cloudinary. Public IDs: \(cloudinaryIds)")
            
            // Create the base transformation for the first video
            var transformation = CLDTransformation()
                .setDuration(String(clipDuration)) // Set duration for first video
            
            // Add each subsequent video with a fade transition
            for i in 1..<cloudinaryIds.count {
                print("DEBUG: Adding video \(i) to transformation chain")
                
                transformation = transformation
                    .chain()
                    .setFlags("splice:transition_(name_fade;du_\(transitionDuration))")
                    .setOverlay("video:\(cloudinaryIds[i])")
                    .chain()
                    .setDuration(String(clipDuration)) // Set duration for each video
                    .chain()
                    .setFlags("layer_apply")
            }
            
            // Generate the final URL
            print("DEBUG: Generating final video URL")
            let finalUrl = cloudinary.createUrl()
                .setResourceType("video")
                .setTransformation(transformation)
                .generate(cloudinaryIds[0]) ?? ""
            
            guard let outputUrl = URL(string: finalUrl) else {
                throw StitchingError.noOutputUrl
            }
            
            print("DEBUG: Final video URL generated: \(finalUrl)")
            
            isProcessing = false
            currentProgress = 1.0
            
            return outputUrl
            
        } catch {
            isProcessing = false
            errorMessage = error.localizedDescription
            print("ERROR: Video stitching failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Upload a video to Cloudinary
    /// - Parameter url: Local URL of the video file
    /// - Returns: Public ID of the uploaded video
    private func uploadVideo(url: URL) async throws -> String {
        print("DEBUG: Starting Cloudinary upload for video: \(url)")
        
        return try await withCheckedThrowingContinuation { continuation in
            let params = CLDUploadRequestParams()
            params.setResourceType("video")
            
            cloudinary.createUploader().upload(
                url: url,
                uploadPreset: "pastport_videos",
                params: params
            ) { result, error in
                if let error = error {
                    print("ERROR: Failed to upload video to Cloudinary: \(error.localizedDescription)")
                    continuation.resume(throwing: StitchingError.cloudinaryError(error.localizedDescription))
                    return
                }
                
                guard let result = result, let publicId = result.publicId else {
                    print("ERROR: No public ID in Cloudinary upload response")
                    continuation.resume(throwing: StitchingError.cloudinaryError("No public ID in response"))
                    return
                }
                
                print("DEBUG: Video uploaded successfully to Cloudinary. Public ID: \(publicId)")
                continuation.resume(returning: publicId)
            }
        }
    }
} 