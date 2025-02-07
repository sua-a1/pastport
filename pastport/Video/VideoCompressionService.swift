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
    ///   - maxWidth: Maximum width of the output video (default: 1280)
    ///   - bitrate: Target bitrate in bits per second (default: 2.5Mbps)
    /// - Returns: URL of the compressed video
    func compressVideo(
        at url: URL,
        maxWidth: CGFloat = 1280,
        bitrate: Int = 2_500_000
    ) async throws -> URL {
        let asset = AVURLAsset(url: url)
        
        // Load video properties
        async let durationFuture = asset.load(.duration)
        async let trackFuture = asset.loadTracks(withMediaType: .video).first
        
        let duration = try await durationFuture
        guard let track = try await trackFuture else {
            throw VideoCompressionError.invalidAsset
        }
        
        let size = try await track.load(.naturalSize)
        print("DEBUG: Original video - Duration: \(duration.seconds)s, Size: \(size)")
        
        // Create export session with optimized settings
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: "AVAssetExportPresetHighestQuality"
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
        
        // Set compression properties
        let compressionDict: [String: Any] = [
            AVVideoAverageBitRateKey: bitrate,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC
        ]
        
        // Export with progress tracking
        try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously { 
                if exportSession.status == .completed {
                    continuation.resume()
                } else if let error = exportSession.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: VideoCompressionError.exportFailed("Unknown error"))
                }
            }
        }
        
        guard exportSession.status == .completed else {
            throw VideoCompressionError.exportFailed(
                exportSession.error?.localizedDescription ?? "Unknown error"
            )
        }
        
        // Get file sizes for comparison
        let originalSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
        let compressedSize = try FileManager.default.attributesOfItem(atPath: compressedURL.path)[.size] as? Int64 ?? 0
        
        print("""
            DEBUG: Video compression completed
            - Original size: \(originalSize / 1024 / 1024)MB
            - Compressed size: \(compressedSize / 1024 / 1024)MB
            - Reduction: \(String(format: "%.1f", (1 - Double(compressedSize) / Double(originalSize)) * 100))%
            """)
        
        return compressedURL
    }
} 