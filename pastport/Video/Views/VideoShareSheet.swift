import SwiftUI
import FirebaseStorage
import AVKit
import Photos

struct VideoShareSheet: View {
    let post: Post
    @Environment(\.dismiss) private var dismiss
    @State private var isGeneratingLink = false
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccessToast = false
    @State private var successMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    // Video Preview
                    if let videoURL = URL(string: post.videoUrl) {
                        ZStack {
                            VideoPlayer(player: AVPlayer(url: videoURL))
                                .frame(height: 250)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            
                            // Only show progress overlay when downloading
                            if isDownloading {
                                ZStack {
                                    Color.black.opacity(0.5)
                                    VStack(spacing: 12) {
                                        ProgressView(value: downloadProgress) {
                                            Text("Downloading...")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                        }
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                        
                                        Text("\(Int(downloadProgress * 100))%")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                    .padding()
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }
                    
                    // Share Options
                    VStack(spacing: 24) {
                        // Share button
                        ShareButton(
                            title: "Share Video",
                            icon: "square.and.arrow.up",
                            isLoading: isGeneratingLink,
                            action: shareVideo
                        )
                        
                        // Copy Link button
                        ShareButton(
                            title: "Copy Link",
                            icon: "link",
                            isLoading: isGeneratingLink,
                            action: copyLink
                        )
                        
                        // Download button
                        ShareButton(
                            title: "Download Video",
                            icon: "arrow.down.circle",
                            isLoading: isDownloading,
                            action: downloadVideo
                        )
                    }
                    .padding(.horizontal)
                    
                    // Video Info Card
                    VStack(spacing: 16) {
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
                        
                        if !post.caption.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Caption")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(post.caption)
                                    .font(.body)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                    )
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top)
            }
            .navigationTitle("Share Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .overlay(
                // Success toast
                ToastView(message: successMessage, isShowing: $showSuccessToast)
                    .animation(.spring(), value: showSuccessToast)
            )
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func shareVideo() {
        Task {
            do {
                isGeneratingLink = true
                let storage = Storage.storage().reference()
                let videoRef = storage.child("videos/\(post.videoFilename)")
                
                let url = try await videoRef.downloadURL()
                
                let activityVC = UIActivityViewController(
                    activityItems: [
                        url,
                        post.caption,
                        "Check out this \(post.category) story on Pastport!"
                    ],
                    applicationActivities: nil
                )
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController {
                    await MainActor.run {
                        activityVC.popoverPresentationController?.sourceView = rootVC.view
                        rootVC.present(activityVC, animated: true)
                    }
                }
            } catch {
                print("DEBUG: Failed to generate share URL: \(error)")
                errorMessage = "Failed to generate share link. Please try again."
                showError = true
            }
            isGeneratingLink = false
        }
    }
    
    private func copyLink() {
        Task {
            do {
                isGeneratingLink = true
                let storage = Storage.storage().reference()
                let videoRef = storage.child("videos/\(post.videoFilename)")
                
                let url = try await videoRef.downloadURL()
                UIPasteboard.general.string = url.absoluteString
                
                await MainActor.run {
                    successMessage = "Link copied to clipboard!"
                    showSuccessToast = true
                }
                
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            } catch {
                print("DEBUG: Failed to copy link: \(error)")
                errorMessage = "Failed to copy link. Please try again."
                showError = true
            }
            isGeneratingLink = false
        }
    }
    
    private func downloadVideo() {
        Task {
            do {
                isDownloading = true
                let storage = Storage.storage().reference()
                let videoRef = storage.child("videos/\(post.videoFilename)")
                
                // Create a temporary file URL
                let temporaryDirURL = FileManager.default.temporaryDirectory
                let temporaryFileURL = temporaryDirURL.appendingPathComponent(post.videoFilename)
                
                // Download with progress tracking
                let downloadTask = videoRef.write(toFile: temporaryFileURL) { url, error in
                    if let error = error {
                        print("DEBUG: Download failed: \(error)")
                        errorMessage = "Failed to download video. Please try again."
                        showError = true
                        isDownloading = false
                        return
                    }
                    
                    // Save to Photos
                    PHPhotoLibrary.requestAuthorization { status in
                        guard status == .authorized else {
                            errorMessage = "Photo library access required to save video."
                            showError = true
                            isDownloading = false
                            return
                        }
                        
                        PHPhotoLibrary.shared().performChanges {
                            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: temporaryFileURL)
                        } completionHandler: { success, error in
                            if success {
                                successMessage = "Video saved to Photos!"
                                showSuccessToast = true
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                            } else {
                                errorMessage = "Failed to save video to Photos."
                                showError = true
                            }
                            
                            // Clean up temporary file
                            try? FileManager.default.removeItem(at: temporaryFileURL)
                            isDownloading = false
                        }
                    }
                }
                
                // Observe download progress
                downloadTask.observe(.progress) { snapshot in
                    if let progress = snapshot.progress {
                        downloadProgress = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                    }
                }
            } catch {
                print("DEBUG: Download setup failed: \(error)")
                errorMessage = "Failed to start download. Please try again."
                showError = true
                isDownloading = false
            }
        }
    }
}

// MARK: - Supporting Views
struct ShareButton: View {
    let title: String
    let icon: String
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Image(systemName: icon)
                        .font(.title3)
                }
                
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue)
            )
            .foregroundColor(.white)
        }
        .disabled(isLoading)
    }
}

struct ToastView: View {
    let message: String
    @Binding var isShowing: Bool
    
    var body: some View {
        if isShowing {
            VStack {
                Spacer()
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.8))
                    )
                    .padding(.bottom, 40)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    isShowing = false
                }
            }
        }
    }
}

#Preview {
    VideoShareSheet(post: Post(id: "test", data: [
        "caption": "Test video",
        "category": "Historical",
        "subcategory": "Canonical",
        "videoUrl": "https://example.com/video.mp4",
        "videoFilename": "test.mp4"
    ]))
} 