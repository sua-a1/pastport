import AVKit
import SwiftUI

final class VideoPlayerManager: ObservableObject {
    static let shared = VideoPlayerManager()
    
    @Published private(set) var isLoading = true
    @Published private(set) var currentPostId: String?
    private let player: AVPlayer
    private var currentItem: AVPlayerItem?
    private var loopObserver: NSObjectProtocol?
    private var setupTask: Task<Void, Never>?
    
    private init() {
        print("DEBUG: VideoPlayerManager initialized")
        self.player = AVPlayer()
        setupLoopingObserver()
        configurePlayer()
    }
    
    private func configurePlayer() {
        // Configure player for high quality playback
        player.automaticallyWaitsToMinimizeStalling = true
        player.allowsExternalPlayback = true
        player.preventsDisplaySleepDuringVideoPlayback = true
        
        // Set preferred peakBitRate to high quality (10 Mbps)
        player.currentItem?.preferredPeakBitRate = 10_000_000
    }
    
    private func setupLoopingObserver() {
        // Observe when video reaches end and seek back to start
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.player.seek(to: .zero)
            self?.player.play()
        }
    }
    
    var currentPlayer: AVPlayer? {
        return isLoading ? nil : player
    }
    
    func setupPlayer(with url: URL, postId: String) async {
        // Cancel any ongoing setup
        setupTask?.cancel()
        
        // Create new setup task
        setupTask = Task { @MainActor in
            // If we're already playing this post, don't set up again
            if currentPostId == postId && !isLoading {
                print("DEBUG: Already playing post: \(postId)")
                return
            }
            
            print("DEBUG: Starting setup for URL: \(url) for post: \(postId)")
            
            // Pause current playback before switching
            player.pause()
            isLoading = true
            
            do {
                // Create asset with options for async loading
                let asset = AVURLAsset(url: url)
                
                // Configure for high quality playback
                let resourceLoader = asset.resourceLoader
                resourceLoader.preloadsEligibleContentKeys = true
                
                // Create player item with high quality settings
                let item = AVPlayerItem(asset: asset)
                item.preferredPeakBitRate = 10_000_000 // 10 Mbps for high quality
                item.preferredForwardBufferDuration = 5 // 5 seconds buffer
                
                // Check if task was cancelled
                if Task.isCancelled {
                    print("DEBUG: Setup cancelled for post: \(postId)")
                    return
                }
                
                // Set new item
                currentItem = item
                player.replaceCurrentItem(with: item)
                currentPostId = postId
                isLoading = false
                print("DEBUG: Player setup completed for post: \(postId)")
            } catch {
                print("DEBUG: Failed to setup player: \(error)")
                isLoading = false
                currentPostId = nil
            }
        }
        
        // Wait for setup to complete
        await setupTask?.value
    }
    
    func play() {
        Task { @MainActor in
            guard !isLoading else { 
                print("DEBUG: Skipping play - player is loading")
                return 
            }
            print("DEBUG: Playing video for post: \(currentPostId ?? "unknown")")
            player.play()
        }
    }
    
    func pause() {
        Task { @MainActor in
            print("DEBUG: Pausing video for post: \(currentPostId ?? "unknown")")
            player.pause()
        }
    }
    
    deinit {
        print("DEBUG: VideoPlayerManager deinit started")
        setupTask?.cancel()
        NotificationCenter.default.removeObserver(self)
        player.pause()
        player.replaceCurrentItem(with: nil)
        print("DEBUG: VideoPlayerManager deinit completed")
    }
} 