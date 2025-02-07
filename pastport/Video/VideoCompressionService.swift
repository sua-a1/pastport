import AVFoundation
import UIKit

enum VideoCompressionError: Error {
    case exportFailed(String)
    case invalidAsset
    case compressionCancelled
}

final class VideoCompressionService {
    static let shared = VideoCompressionService()
    private init() {}
    
    /// Compresses video with optimized settings for quality and speed
    /// - Parameters:
    ///   - url: Source video URL
    ///   - maxWidth: Maximum width of the output video (default: 1080)
    ///   - targetSize: Target file size in bytes (default: 8MB)
    /// - Returns: URL of the compressed video
    func compressVideo(
        at url: URL,
        maxWidth: CGFloat = 1080,
        targetSize: Int64 = 8 * 1024 * 1024 // 8MB default target
    ) async throws -> URL {
        let asset = AVURLAsset(url: url)
        
        // Load video properties in parallel
        async let durationFuture = asset.load(.duration)
        async let trackFuture = asset.loadTracks(withMediaType: .video).first
        async let audioTrackFuture = asset.loadTracks(withMediaType: .audio).first
        
        let duration = try await durationFuture
        guard let track = try await trackFuture else {
            throw VideoCompressionError.invalidAsset
        }
        let audioTrack = try await audioTrackFuture
        
        let size = try await track.load(.naturalSize)
        let originalFileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
        
        print("DEBUG: Original video - Duration: \(duration.seconds)s, Size: \(size), FileSize: \(originalFileSize / 1024 / 1024)MB")
        
        // Calculate optimal bitrate based on target size
        let videoBitrate = calculateOptimalBitrate(
            duration: duration.seconds,
            targetSize: targetSize,
            hasAudio: audioTrack != nil
        )
        
        // Create export session with optimized settings
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPreset960x540 // Use lower preset for faster compression
        ) else {
            throw VideoCompressionError.invalidAsset
        }
        
        // Set output URL in temp directory
        let compressedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        exportSession.outputURL = compressedURL
        exportSession.outputFileType = AVFileType.mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        // Set video compression settings
        if size.width > maxWidth {
            let scale = maxWidth / size.width
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
            
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
            layerInstruction.setTransform(transform, at: .zero)
            instruction.layerInstructions = [layerInstruction]
            
            let composition = AVMutableVideoComposition()
            composition.instructions = [instruction]
            composition.frameDuration = CMTime(value: 1, timescale: 30)
            composition.renderSize = CGSize(width: maxWidth, height: size.height * scale)
            
            exportSession.videoComposition = composition
        }
        
        // Set bitrate limit
        exportSession.fileLengthLimit = targetSize
        
        // Export with progress tracking
        try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously { 
                if exportSession.status == AVAssetExportSession.Status.completed {
                    continuation.resume()
                } else if let error = exportSession.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: VideoCompressionError.exportFailed("Unknown error"))
                }
            }
        }
        
        guard exportSession.status == AVAssetExportSession.Status.completed else {
            throw VideoCompressionError.exportFailed(
                exportSession.error?.localizedDescription ?? "Unknown error"
            )
        }
        
        // Get file sizes for comparison
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
    
    private func calculateOptimalBitrate(duration: Double, targetSize: Int64, hasAudio: Bool) -> Int {
        // Reserve 128kbps for audio if present
        let audioSize = hasAudio ? Int64(duration * 128_000 / 8) : 0
        let availableSize = max(0, targetSize - audioSize)
        
        // Calculate video bitrate (bits per second)
        let videoBitrate = Int(Double(availableSize) * 8 / duration)
        
        // Ensure minimum quality
        let minimumBitrate = 800_000 // 800kbps minimum
        let maximumBitrate = 2_500_000 // 2.5Mbps maximum
        
        return min(maximumBitrate, max(minimumBitrate, videoBitrate))
    }
} 