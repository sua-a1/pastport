import SwiftUI
import AVKit

struct ProfileVideoFeedView: View {
    let posts: [Post]
    @State private var currentIndex: Int?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                            ProfileVideoPlayerView(post: post)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .id(index)
                        }
                    }
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $currentIndex)
                .scrollDisabled(false)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea(edges: .all)
        .background(Color.black)
    }
}

#Preview {
    if let user = AuthenticationViewModel().currentUser {
        ProfileVideoFeedView(posts: [Post(id: "test", data: [:])])
    }
} 