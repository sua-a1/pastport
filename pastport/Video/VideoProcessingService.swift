import AVFoundation
import Foundation

/// Service for handling video processing operations
final class VideoProcessingService {
    // MARK: - Types
    
    /// Video quality settings
    enum VideoQuality {
        case low
        case medium
        case high
        
        var preset: String {
            switch self {
            case .low:
                return AVAssetExportPreset640x480
            case .medium:
                return AVAssetExportPreset960x540
            case .high:
                return AVAssetExportPreset1920x1080
            }
        }
        
        var targetBitrate: Int {
            switch self {
            case .low:
                return 800_000 // 800kbps
            case .medium:
                return 2_000_000 // 2Mbps
            case .high:
                return 4_000_000 // 4Mbps
            }
        }
    }
    
    /// Errors that can occur during video processing
    enum VideoProcessingError: LocalizedError {
        case exportFailed(String)
        case invalidAsset
        case compressionFailed
        case transitionGenerationFailed
        case concatenationFailed
        
        var errorDescription: String? {
            switch self {
            case .exportFailed(let message):
                return "Export failed: \(message)"
            case .invalidAsset:
                return "Invalid video asset"
            case .compressionFailed:
                return "Video compression failed"
            case .transitionGenerationFailed:
                return "Failed to generate transition"
            case .concatenationFailed:
                return "Failed to concatenate videos"
            }
        }
    }
    
    // MARK: - Properties
    
    static let shared = VideoProcessingService()
    private init() {}
    
    // MARK: - Public Methods
    
    /// Compress video with specified quality settings
    /// - Parameters:
    ///   - url: Source video URL
    ///   - quality: Target quality level
    /// - Returns: URL of the compressed video
    func compressVideo(url: URL, quality: VideoQuality) async throws -> URL {
        print("DEBUG: Starting video compression with quality: \(quality)")
        let asset = AVURLAsset(url: url)
        
        // Load video properties
        async let durationFuture = asset.load(.duration)
        async let trackFuture = asset.loadTracks(withMediaType: .video).first
        async let audioTrackFuture = asset.loadTracks(withMediaType: .audio).first
        
        let duration = try await durationFuture
        guard let track = try await trackFuture else {
            throw VideoProcessingError.invalidAsset
        }
        let audioTrack = try await audioTrackFuture
        
        let size = try await track.load(.naturalSize)
        let originalFileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
        
        print("DEBUG: Original video - Duration: \(duration.seconds)s, Size: \(size), FileSize: \(originalFileSize / 1024 / 1024)MB")
        
        // Create export session
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: quality.preset
        ) else {
            throw VideoProcessingError.invalidAsset
        }
        
        // Set output URL
        let compressedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        exportSession.outputURL = compressedURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        // Set video compression properties
        let videoBitrate = quality.targetBitrate
        let audioBitrate = audioTrack != nil ? 128_000 : 0 // 128kbps for audio if present
        
        let compressionProperties: [String: Any] = [
            AVVideoAverageBitRateKey: videoBitrate,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
        ]
        
        exportSession.videoComposition = createVideoComposition(
            for: asset,
            track: track,
            targetSize: size
        )
        
        // Export with progress tracking
        try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously {
                if exportSession.status == .completed {
                    continuation.resume()
                } else if let error = exportSession.error {
                    continuation.resume(throwing: VideoProcessingError.exportFailed(error.localizedDescription))
                } else {
                    continuation.resume(throwing: VideoProcessingError.exportFailed("Unknown error"))
                }
            }
        }
        
        // Log compression results
        let compressedSize = try FileManager.default.attributesOfItem(atPath: compressedURL.path)[.size] as? Int64 ?? 0
        print("""
            DEBUG: Video compression completed
            - Original size: \(originalFileSize / 1024 / 1024)MB
            - Compressed size: \(compressedSize / 1024 / 1024)MB
            - Reduction: \(String(format: "%.1f", (1 - Double(compressedSize) / Double(originalFileSize)) * 100))%
            - Target bitrate: \(videoBitrate / 1024 / 1024)Mbps
            """)
        
        return compressedURL
    }
    
    /// Concatenate multiple videos into a single video
    /// - Parameter urls: Array of video URLs to concatenate
    /// - Returns: URL of the concatenated video
    func concatenateVideos(urls: [URL]) async throws -> URL {
        print("DEBUG: Starting video concatenation for \(urls.count) videos")
        
        // Create composition
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ),
        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VideoProcessingError.concatenationFailed
        }
        
        // Add each video to the composition
        var currentTime = CMTime.zero
        for url in urls {
            let asset = AVURLAsset(url: url)
            
            // Load tracks
            let videoAssetTrack = try await asset.loadTracks(withMediaType: .video).first
            let audioAssetTrack = try await asset.loadTracks(withMediaType: .audio).first
            let duration = try await asset.load(.duration)
            
            // Add video track
            if let videoAssetTrack = videoAssetTrack {
                try videoTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: videoAssetTrack,
                    at: currentTime
                )
            }
            
            // Add audio track if present
            if let audioAssetTrack = audioAssetTrack {
                try audioTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: audioAssetTrack,
                    at: currentTime
                )
            }
            
            currentTime = CMTimeAdd(currentTime, duration)
        }
        
        // Create export session
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw VideoProcessingError.concatenationFailed
        }
        
        // Set output URL
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        // Export
        try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously {
                if exportSession.status == .completed {
                    continuation.resume()
                } else if let error = exportSession.error {
                    continuation.resume(throwing: VideoProcessingError.concatenationFailed)
                    print("DEBUG: Concatenation failed: \(error.localizedDescription)")
                } else {
                    continuation.resume(throwing: VideoProcessingError.concatenationFailed)
                }
            }
        }
        
        print("DEBUG: Video concatenation completed")
        return outputURL
    }
    
    /// Generate a transition video between two videos
    /// - Parameters:
    ///   - fromURL: Source video URL
    ///   - toURL: Destination video URL
    /// - Returns: URL of the generated transition video
    func generateTransition(from fromURL: URL, to toURL: URL) async throws -> URL {
        print("DEBUG: Generating transition between videos")
        
        // Load assets
        let fromAsset = AVURLAsset(url: fromURL)
        let toAsset = AVURLAsset(url: toURL)
        
        // Create composition
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VideoProcessingError.transitionGenerationFailed
        }
        
        // Load durations
        let fromDuration = try await fromAsset.load(.duration)
        let toDuration = try await toAsset.load(.duration)
        
        // Create transition of 1 second
        let transitionDuration = CMTime(seconds: 1, preferredTimescale: 600)
        let fromRange = CMTimeRange(
            start: CMTimeSubtract(fromDuration, transitionDuration),
            duration: transitionDuration
        )
        let toRange = CMTimeRange(
            start: .zero,
            duration: transitionDuration
        )
        
        // Create transition instructions
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: transitionDuration)
        
        // Add transition layers
        if let fromTrack = try await fromAsset.loadTracks(withMediaType: .video).first,
           let toTrack = try await toAsset.loadTracks(withMediaType: .video).first {
            let fromLayer = AVMutableVideoCompositionLayerInstruction(assetTrack: fromTrack)
            let toLayer = AVMutableVideoCompositionLayerInstruction(assetTrack: toTrack)
            
            // Set opacity ramp for cross-fade
            fromLayer.setOpacityRamp(fromStartOpacity: 1.0, toEndOpacity: 0.0, timeRange: fromRange)
            toLayer.setOpacityRamp(fromStartOpacity: 0.0, toEndOpacity: 1.0, timeRange: toRange)
            
            instruction.layerInstructions = [fromLayer, toLayer]
        }
        
        // Create video composition
        let videoComposition = AVMutableVideoComposition()
        videoComposition.instructions = [instruction]
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.renderSize = CGSize(width: 1080, height: 1920) // 9:16 aspect ratio
        
        // Create export session
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw VideoProcessingError.transitionGenerationFailed
        }
        
        // Set output URL
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true
        
        // Export
        try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously {
                if exportSession.status == .completed {
                    continuation.resume()
                } else if let error = exportSession.error {
                    continuation.resume(throwing: VideoProcessingError.transitionGenerationFailed)
                    print("DEBUG: Transition generation failed: \(error.localizedDescription)")
                } else {
                    continuation.resume(throwing: VideoProcessingError.transitionGenerationFailed)
                }
            }
        }
        
        print("DEBUG: Transition generation completed")
        return outputURL
    }
    
    // MARK: - Private Methods
    
    private func createVideoComposition(
        for asset: AVAsset,
        track: AVAssetTrack,
        targetSize: CGSize
    ) -> AVMutableVideoComposition? {
        let composition = AVMutableVideoComposition()
        composition.frameDuration = CMTime(value: 1, timescale: 30)
        composition.renderSize = targetSize
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(
            start: .zero,
            duration: track.timeRange.duration
        )
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        instruction.layerInstructions = [layerInstruction]
        
        composition.instructions = [instruction]
        return composition
    }
} 