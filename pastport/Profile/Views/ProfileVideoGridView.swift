import SwiftUI
import AVKit

struct ProfileVideoGridView: View {
    let videos: [Post]
    @Binding var showVideoFeed: Bool
    
    let columns = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 1) {
            ForEach(videos) { video in
                VideoThumbnailView(video: video, showVideoFeed: $showVideoFeed)
            }
        }
    }
}

struct VideoThumbnailView: View {
    let video: Post
    @Binding var showVideoFeed: Bool
    @State private var thumbnailImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = thumbnailImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .clipped()
                        .onTapGesture {
                            showVideoFeed = true
                        }
                } else if isLoading {
                    ProgressView()
                        .frame(width: geometry.size.width, height: geometry.size.width)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: geometry.size.width, height: geometry.size.width)
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
    ], showVideoFeed: .constant(false))
} 