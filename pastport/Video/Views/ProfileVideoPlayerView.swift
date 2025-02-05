import SwiftUI
import AVKit

struct ProfileVideoPlayerView: View {
    let post: Post
    @StateObject private var playerManager = VideoPlayerManager()
    @State private var isVisible = false
    
    var body: some View {
        ZStack {
            if playerManager.isLoading {
                ProgressView()
            } else if let player = playerManager.player {
                VideoPlayer(player: player)
                    .edgesIgnoringSafeArea(.all)
                
                // Video Info Overlay
                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(post.caption)
                                .foregroundColor(.white)
                                .font(.body)
                            
                            HStack {
                                Label("\(post.views)", systemImage: "play.fill")
                                Label("\(post.likes)", systemImage: "heart.fill")
                                Label("\(post.comments)", systemImage: "message.fill")
                                Label("\(post.shares)", systemImage: "square.and.arrow.up")
                            }
                            .foregroundColor(.white)
                            .font(.caption)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .black.opacity(0.5)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            } else {
                ProgressView()
            }
        }
        .task {
            await setupPlayer()
        }
        .onAppear {
            isVisible = true
            if !playerManager.isLoading {
                playerManager.play()
            }
        }
        .onDisappear {
            isVisible = false
            playerManager.pause()
        }
    }
    
    private func setupPlayer() async {
        guard let url = URL(string: post.videoUrl) else { return }
        await playerManager.setupPlayer(with: url)
        if isVisible {
            playerManager.play()
        }
    }
}

#Preview {
    ProfileVideoPlayerView(post: Post(id: "test", data: [:]))
} 