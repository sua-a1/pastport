import SwiftUI
import AVKit

struct ProfileVideoPlayerView: View {
    let post: Post
    let isActive: Bool
    @ObservedObject private var playerManager = VideoPlayerManager.shared
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if playerManager.isLoading || playerManager.currentPostId != post.id {
                    ProgressView()
                } else if let player = playerManager.currentPlayer {
                    VideoPlayer(player: player)
                        .frame(width: geometry.size.width, height: geometry.size.height)
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
                }
            }
        }
        .onDisappear {
            print("DEBUG: View disappearing for post: \(post.id)")
            if isActive {
                playerManager.pause()
            }
        }
    }
}

#Preview {
    ProfileVideoPlayerView(post: Post(id: "test", data: [:]), isActive: true)
} 