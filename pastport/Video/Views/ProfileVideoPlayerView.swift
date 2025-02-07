import SwiftUI
import AVKit
import FirebaseStorage
import FirebaseFirestore

struct ProfileVideoPlayerView: View {
    let post: Post
    let isActive: Bool
    private let playerManager = VideoPlayerManager.shared
    @State private var isLiked = false
    @State private var showShareSheet = false
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    // Add delete functionality
    private func deleteVideo() async {
        guard !isDeleting else { return }
        isDeleting = true
        var hadError = false
        var errorDetails = ""
        
        do {
            print("DEBUG: Starting deletion for post: \(post.id) by user: \(post.userId)")
            
            // 1. Stop video playback first
            playerManager.pause()
            playerManager.cleanup()
            
            let db = Firestore.firestore()
            
            // 2. Verify ownership in main posts collection first
            print("DEBUG: Verifying post ownership")
            print("DEBUG: Checking post ID: \(post.id)")
            
            // Try both possible paths
            let mainPost = try await db.collection("posts").document(post.id).getDocument()
            let userPost = try await db.collection("users").document(post.userId)
                .collection("posts").document(post.id).getDocument()
            
            print("DEBUG: Main post exists: \(mainPost.exists)")
            print("DEBUG: User post exists: \(userPost.exists)")
            
            // Use whichever document exists
            let postDoc = userPost.exists ? userPost : mainPost
            
            guard postDoc.exists,
                  let postData = postDoc.data(),
                  let postUserId = postData["userId"] as? String,
                  let currentUserId = playerManager.currentUser?.uid,
                  postUserId == currentUserId else {
                print("DEBUG: Ownership verification failed")
                print("DEBUG: Post user ID: \(postDoc.data()?["userId"] as? String ?? "nil")")
                print("DEBUG: Current user ID: \(playerManager.currentUser?.uid ?? "nil")")
                throw NSError(domain: "PostDeletion", code: -1, userInfo: [NSLocalizedDescriptionKey: "Video not found or you don't have permission to delete it"])
            }
            
            // 3. Delete from collections based on where the document exists
            if mainPost.exists {
                print("DEBUG: Deleting from main posts collection")
                do {
                    try await db.collection("posts").document(post.id).delete()
                    print("DEBUG: Successfully deleted from main posts collection")
                } catch {
                    print("DEBUG: Failed to delete from main posts collection: \(error)")
                    hadError = true
                    errorDetails = "failed to remove from main feed"
                }
            }
            
            if userPost.exists {
                print("DEBUG: Deleting from user's posts subcollection")
                do {
                    try await db.collection("users").document(post.userId)
                        .collection("posts").document(post.id).delete()
                    print("DEBUG: Successfully deleted from user's posts subcollection")
                } catch {
                    print("DEBUG: Failed to delete from user's posts subcollection: \(error)")
                    hadError = true
                    if !errorDetails.isEmpty {
                        errorDetails += " and "
                    }
                    errorDetails += "failed to remove from your profile"
                }
            }
            
            // 4. Delete from Storage last
            print("DEBUG: Deleting video file from storage")
            let storage = Storage.storage().reference()
            let videoRef = storage.child("videos/\(post.videoFilename)")
            try await videoRef.delete()
            print("DEBUG: Successfully deleted video file from storage")
            
            // 6. Handle completion on main thread
            await MainActor.run {
                showDeleteAlert = false // Dismiss delete confirmation sheet first
            }
            
            // Add delay between UI updates
            try await Task.sleep(for: .milliseconds(300))
            
            await MainActor.run {
                isDeleting = false
                if hadError {
                    errorMessage = "Some cleanup failed: \(errorDetails). Please refresh your profile."
                    showErrorAlert = true
                }
            }
            
            // Add delay before dismissal
            if hadError {
                try await Task.sleep(for: .milliseconds(1000))
            }
            
            await MainActor.run {
                dismiss()
            }
            
        } catch {
            print("DEBUG: Failed to delete video: \(error)")
            print("DEBUG: Error details - Domain: \(error._domain), Code: \(error._code)")
            
            if let firestoreError = error as NSError? {
                print("DEBUG: Full error info - \(firestoreError.userInfo)")
            }
            
            // Handle error on main thread
            await MainActor.run {
                showDeleteAlert = false // Dismiss delete confirmation sheet first
            }
            
            try? await Task.sleep(for: .milliseconds(300))
            
            await MainActor.run {
                isDeleting = false
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
            
            try? await Task.sleep(for: .milliseconds(1000))
            
            await MainActor.run {
                dismiss()
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if playerManager.isLoading || playerManager.currentPostId != post.id {
                    ProgressView()
                } else if let player = playerManager.currentPlayer {
                    VideoPlayer(player: player)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .edgesIgnoringSafeArea(.all)
                    
                    // Overlay Content
                    ZStack(alignment: .bottom) {
                        // Gradient overlay
                        LinearGradient(
                            gradient: Gradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .clear, location: 0.6),
                                    .init(color: .black.opacity(0.7), location: 1.0)
                                ]
                            ),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: geometry.size.height * 0.4)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        
                        // Content
                        HStack(alignment: .bottom, spacing: 0) {
                            // Left side - Description and Music
                            VStack(alignment: .leading, spacing: 10) {
                                Spacer()
                                
                                // Username
                                HStack(spacing: 8) {
                                    Text("@\(post.userId)")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                
                                // Caption
                                if !post.caption.isEmpty {
                                    Text(post.caption)
                                        .font(.system(size: 15))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.leading)
                                }
                                
                                // Category Tags
                                CategoryTagView(
                                    category: post.category,
                                    subcategory: post.subcategory,
                                    isOverVideo: true
                                )
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Right side - Interaction Buttons
                            VStack(spacing: 20) {
                                Spacer()
                                
                                // Profile Button (we'll implement navigation later)
                                Button(action: {
                                    // TODO: Navigate to profile
                                }) {
                                    Circle()
                                        .fill(Color.black.opacity(0.4))
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            Image(systemName: "person.circle.fill")
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .foregroundColor(.white)
                                                .padding(12)
                                        )
                                }
                                
                                // Like Button
                                VStack(spacing: 4) {
                                    Button(action: {
                                        isLiked.toggle()
                                    }) {
                                        Image(systemName: isLiked ? "heart.fill" : "heart")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 30, height: 30)
                                            .foregroundColor(isLiked ? .red : .white)
                                    }
                                    Text("\(post.likes)")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                
                                // Comment Button
                                VStack(spacing: 4) {
                                    Button(action: {
                                        // TODO: Show comments
                                    }) {
                                        Image(systemName: "bubble.right")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 30, height: 30)
                                            .foregroundColor(.white)
                                    }
                                    Text("\(post.comments)")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                
                                // Share Button
                                VStack(spacing: 4) {
                                    Button(action: {
                                        showShareSheet = true
                                    }) {
                                        Image(systemName: "arrowshape.turn.up.right")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 30, height: 30)
                                            .foregroundColor(.white)
                                    }
                                    Text("\(post.shares)")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                
                                // Delete Button (only show for user's own videos)
                                if post.userId == playerManager.currentUser?.uid {
                                    VStack(spacing: 4) {
                                        Button(action: {
                                            showDeleteAlert = true
                                        }) {
                                            Image(systemName: "trash")
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 30, height: 30)
                                                .foregroundColor(.white)
                                        }
                                        Text("Delete")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .padding(.trailing, 16)
                            .padding(.bottom, 20)
                        }
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
        // Add double tap gesture for like
        .onTapGesture(count: 2) {
            if !isLiked {
                isLiked = true
                // TODO: Implement heart animation
            }
        }
        .sheet(isPresented: $showShareSheet) {
            VideoShareSheet(post: post)
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(isDeleting)
        }
        .sheet(isPresented: $showDeleteAlert) {
            VideoDeleteSheet(post: post, isDeleting: $isDeleting, onDelete: {
                Task {
                    await deleteVideo()
                }
            })
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(isDeleting)
        }
        .alert("Notice", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
}

struct VideoDeleteSheet: View {
    let post: Post
    @Binding var isDeleting: Bool
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 24) {
                    // Warning Icon
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                        .padding(.top)
                    
                    // Warning Text
                    Text("Delete Video?")
                        .font(.title2.bold())
                    
                    Text("This action cannot be undone. The video will be permanently deleted from your profile.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Video Info Card
                    VStack(spacing: 16) {
                        if !post.caption.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Caption")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(post.caption)
                                    .font(.body)
                            }
                        }
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Category")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                CategoryTagView(
                                    category: post.category,
                                    subcategory: post.subcategory,
                                    isOverVideo: false
                                )
                            }
                            Spacer()
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                    )
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Delete Button
                    Button(action: onDelete) {
                        HStack {
                            if isDeleting {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isDeleting ? "Deleting..." : "Delete Video")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red)
                        )
                        .foregroundColor(.white)
                    }
                    .disabled(isDeleting)
                    .padding(.horizontal)
                    
                    // Cancel Button
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.headline)
                    .padding(.bottom)
                }
                .padding(.top)
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    ProfileVideoPlayerView(post: Post(id: "test", data: [
        "caption": "Test video",
        "category": "Historical",
        "subcategory": "Canonical",
        "views": 100,
        "likes": 50,
        "comments": 10,
        "shares": 5
    ]), isActive: true)
} 