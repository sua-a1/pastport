import AVKit
import SwiftUI
import FirebaseAuth

@Observable final class VideoPlayerManager {
    static let shared = VideoPlayerManager()
    
    var currentPlayer: AVPlayer?
    var currentPostId: String?
    var isLoading = false
    var currentUser: FirebaseAuth.User? {
        Auth.auth().currentUser
    }
    
    private var playerLooper: AVPlayerLooper?
    private var timeObserver: Any?
    
    func setupPlayer(with url: URL, postId: String) async {
        isLoading = true
        currentPostId = postId
        
        // Create new player
        let player = AVQueuePlayer(url: url)
        
        // Configure looping
        if let playerItem = player.currentItem {
            playerLooper = AVPlayerLooper(player: player, templateItem: playerItem)
        }
        
        // Add time observer for progress tracking
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            // Handle progress updates if needed
        }
        
        currentPlayer = player
        isLoading = false
    }
    
    func play() {
        currentPlayer?.play()
    }
    
    func pause() {
        currentPlayer?.pause()
    }
    
    func cleanup() {
        // Remove time observer
        if let timeObserver = timeObserver {
            currentPlayer?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        // Cleanup player looper
        playerLooper = nil
        
        // Cleanup player
        currentPlayer?.pause()
        currentPlayer = nil
        currentPostId = nil
        isLoading = false
    }
    
    deinit {
        cleanup()
    }
} 