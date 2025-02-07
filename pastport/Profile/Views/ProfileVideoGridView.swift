import SwiftUI
import AVKit

struct ProfileVideoGridView: View {
    let videos: [Post]
    @Binding var showVideoFeed: Bool
    @Binding var selectedVideoIndex: Int
    
    let columns = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1)
    ]
    
    var body: some View {
        let width = UIScreen.main.bounds.width
        LazyVGrid(columns: columns, spacing: 1) {
            ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
                VideoThumbnailView(video: video, showVideoFeed: $showVideoFeed, selectedVideoIndex: $selectedVideoIndex, index: index)
                    .frame(width: width / 3 - 1, height: width / 3 - 1)
                    .clipped()
            }
        }
    }
}

struct VideoThumbnailView: View {
    let video: Post
    @Binding var showVideoFeed: Bool
    @Binding var selectedVideoIndex: Int
    let index: Int
    @State private var thumbnailImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .onTapGesture {
                        selectedVideoIndex = index
                        showVideoFeed = true
                    }
            } else if isLoading {
                ProgressView()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        Image(systemName: "video.fill")
                            .foregroundColor(.gray)
                    }
            }
            
            // Video stats overlay
            VStack {
                Spacer()
                HStack {
                    Image(systemName: "play.fill")
                        .foregroundColor(.white)
                    Text("\(video.views)")
                        .foregroundColor(.white)
                        .font(.caption)
                }
                .padding(4)
                .background(.black.opacity(0.5))
                .cornerRadius(4)
            }
            .padding(4)
        }
        .aspectRatio(1, contentMode: .fit)
        .task {
            await generateThumbnail()
        }
    }
    
    private func generateThumbnail() async {
        guard let videoURL = URL(string: video.videoUrl) else {
            isLoading = false
            return
        }
        
        do {
            let asset = AVAsset(url: videoURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            // Generate thumbnail at 0.0 seconds
            let cgImage = try await imageGenerator.image(at: .zero).image
            thumbnailImage = UIImage(cgImage: cgImage)
        } catch {
            print("DEBUG: Failed to generate thumbnail for video: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
}

#Preview {
    ProfileVideoGridView(videos: [
        Post(id: "test", data: [
            "videoUrl": "https://example.com/video.mp4",
            "views": 100
        ])
    ], showVideoFeed: .constant(false), selectedVideoIndex: .constant(0))
} 