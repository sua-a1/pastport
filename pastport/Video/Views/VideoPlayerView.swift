import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let post: Post
    @State private var player: AVPlayer?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if let player = player {
                VideoPlayer(player: player)
                    .edgesIgnoringSafeArea(.all)
            } else {
                ProgressView()
            }
            
            // Overlay controls
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .font(.title2)
                            .padding()
                    }
                    Spacer()
                }
                Spacer()
                
                // Video info
                VStack(alignment: .leading, spacing: 8) {
                    Text(post.caption)
                        .foregroundColor(.white)
                        .font(.body)
                        .padding(.horizontal)
                    
                    HStack {
                        Label("\(post.views)", systemImage: "play.fill")
                        Label("\(post.likes)", systemImage: "heart.fill")
                        Label("\(post.comments)", systemImage: "message.fill")
                        Label("\(post.shares)", systemImage: "square.and.arrow.up")
                    }
                    .foregroundColor(.white)
                    .font(.caption)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, .black.opacity(0.5)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
    
    private func setupPlayer() {
        guard let url = URL(string: post.videoUrl) else { return }
        let player = AVPlayer(url: url)
        self.player = player
        player.play()
    }
} 