import SwiftUI
import AVKit

struct ProfileVideoFeedView: View {
    let posts: [Post]
    let initialIndex: Int
    @State private var currentIndex: Int?
    @State private var isInitialized = false
    @State private var isScrolling = false
    @State private var pendingIndex: Int?
    @Environment(\.dismiss) private var dismiss
    private let playerManager = VideoPlayerManager.shared
    
    private func playVideo(at index: Int) async {
        guard let post = posts[safe: index] else { return }
        print("DEBUG: Attempting to play video at index \(index) for post: \(post.id)")
        
        if let url = URL(string: post.videoUrl) {
            await playerManager.setupPlayer(with: url, postId: post.id)
            await MainActor.run {
                playerManager.play()
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                            ProfileVideoPlayerView(
                                post: post,
                                isActive: index == currentIndex
                            )
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .id(index)
                            .onAppear {
                                print("DEBUG: Video view appeared at index \(index)")
                                Task { @MainActor in
                                    pendingIndex = index
                                }
                            }
                        }
                    }
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $currentIndex)
                .scrollDisabled(false)
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { _ in
                            Task { @MainActor in
                                if !isScrolling {
                                    isScrolling = true
                                    playerManager.pause()
                                    print("DEBUG: Started scrolling")
                                }
                            }
                        }
                        .onEnded { _ in
                            print("DEBUG: Drag ended")
                            Task { @MainActor in
                                // Handle scroll end immediately
                                if let index = pendingIndex {
                                    print("DEBUG: Will play pending video at index \(index)")
                                    currentIndex = index
                                    await playVideo(at: index)
                                }
                                isScrolling = false
                            }
                        }
                )
                .onChange(of: currentIndex) { oldValue, newValue in
                    print("DEBUG: Scroll position changed from \(oldValue?.description ?? "nil") to \(newValue?.description ?? "nil")")
                    
                    Task { @MainActor in
                        if let newValue = newValue {
                            // Only switch videos if not scrolling and index changed
                            if !isScrolling && newValue != oldValue {
                                print("DEBUG: Index changed while not scrolling, switching to video at index \(newValue)")
                                if let oldValue = oldValue {
                                    print("DEBUG: Will stop video at index \(oldValue)")
                                    playerManager.pause()
                                }
                                await playVideo(at: newValue)
                            }
                        } else if let pending = pendingIndex {
                            // Recover position using pending index
                            print("DEBUG: Recovering position to pending index: \(pending)")
                            currentIndex = pending
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { 
                        playerManager.pause()
                        dismiss() 
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
            }
            .ignoresSafeArea()
            .task {
                // Set initial state immediately
                print("DEBUG: Setting initial state with index \(initialIndex)")
                await MainActor.run {
                    currentIndex = initialIndex
                    pendingIndex = initialIndex
                }
                
                // Start playing initial video after a short delay
                try? await Task.sleep(for: .milliseconds(100))
                await playVideo(at: initialIndex)
                
                // Mark as initialized after initial playback
                await MainActor.run {
                    isInitialized = true
                }
            }
        }
        .ignoresSafeArea(edges: .all)
        .background(Color.black)
    }
}

struct VideoPostView: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !post.caption.isEmpty {
                Text(post.caption)
                    .font(.subheadline)
                    .padding(.horizontal)
            }
            
            CategoryTagView(category: post.category, subcategory: post.subcategory)
                .padding(.horizontal)
        }
    }
}

// Safe array access extension
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    if let user = AuthenticationViewModel().currentUser {
        ProfileVideoFeedView(posts: [Post(id: "test", data: [:])], initialIndex: 0)
    }
} 