import SwiftUI
import AVKit

struct ProfileVideoGridView: View {
    let videos: [Post]
    let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(videos) { post in
                NavigationLink(destination: VideoPlayerView(post: post)) {
                    VideoThumbnailView(post: post)
                        .aspectRatio(9/16, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipped()
                }
            }
        }
    }
}

struct VideoThumbnailView: View {
    let post: Post
    @State private var thumbnailImage: UIImage?
    
    var body: some View {
        ZStack {
            if let thumbnail = thumbnailImage {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(9/16, contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(9/16, contentMode: .fill)
                    .overlay {
                        ProgressView()
                    }
            }
            
            // Video stats overlay
            VStack {
                Spacer()
                HStack {
                    Image(systemName: "play.fill")
                        .foregroundColor(.white)
                    Text("\(post.views)")
                        .foregroundColor(.white)
                        .font(.caption)
                }
                .padding(.bottom, 4)
            }
        }
        .onAppear {
            generateThumbnail()
        }
    }
    
    private func generateThumbnail() {
        guard let videoURL = URL(string: post.videoUrl) else { return }
        
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        // Get thumbnail at 0 seconds
        let time = CMTime(seconds: 0, preferredTimescale: 1)
        
        Task {
            do {
                let cgImage = try await imageGenerator.image(at: time).image
                await MainActor.run {
                    thumbnailImage = UIImage(cgImage: cgImage)
                }
            } catch {
                print("DEBUG: Failed to generate thumbnail: \(error.localizedDescription)")
            }
        }
    }
} 