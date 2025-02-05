import AVKit

final class VideoPlayerManager: ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published private(set) var isLoading = false
    private var playerLooper: AVPlayerLooper?
    
    public init() { }
    
    @MainActor
    func setupPlayer(with url: URL) async {
        isLoading = true
        print("DEBUG: Setting up player with URL: \(url)")
        
        do {
            let asset = AVAsset(url: url)
            // Load key properties asynchronously
            try await asset.load(.isPlayable)
            let playerItem = AVPlayerItem(asset: asset)
            
            let queuePlayer = AVQueuePlayer(playerItem: playerItem)
            self.player = queuePlayer
            self.playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
            print("DEBUG: Player setup complete")
        } catch {
            print("DEBUG: Failed to setup player: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func play() {
        print("DEBUG: Playing video")
        player?.play()
    }
    
    func pause() {
        print("DEBUG: Pausing video")
        player?.pause()
    }
    
    func cleanup() {
        pause()
        player = nil
        playerLooper = nil
    }
    
    deinit {
        print("DEBUG: VideoPlayerManager deinit")
        cleanup()
    }
} 