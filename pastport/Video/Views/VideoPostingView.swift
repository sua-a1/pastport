import SwiftUI
import AVKit
import PhotosUI

struct VideoPostingView: View {
    let videoURL: URL
    @State private var caption = ""
    @State private var isUploading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer
    @State private var videoUploader = VideoUploader()
    
    init(videoURL: URL) {
        self.videoURL = videoURL
        _player = State(initialValue: AVPlayer(url: videoURL))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Video Preview
                        VideoPlayer(player: player)
                            .frame(height: 400)
                            .onAppear {
                                player.play()
                            }
                            .onDisappear {
                                player.pause()
                            }
                        
                        // Caption Input
                        TextField("Describe your video...", text: $caption, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                            .padding(.horizontal)
                        
                        if isUploading {
                            VStack {
                                ProgressView(value: videoUploader.uploadProgress) {
                                    Text("Uploading video...")
                                        .foregroundColor(.secondary)
                                } currentValueLabel: {
                                    Text("\(Int(videoUploader.uploadProgress * 100))%")
                                        .foregroundColor(.secondary)
                                }
                                .progressViewStyle(.linear)
                                .padding()
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isUploading)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Post") {
                        uploadVideo()
                    }
                    .disabled(isUploading || caption.isEmpty)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .interactiveDismissDisabled(isUploading)
        .presentationBackground(.background)
    }
    
    private func uploadVideo() {
        isUploading = true
        
        // First save to photo library
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized else {
                handleError("Photo library access required to save video")
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            }) { success, error in
                if let error = error {
                    handleError(error.localizedDescription)
                    return
                }
                
                // Then upload to Firebase
                Task {
                    do {
                        _ = try await videoUploader.uploadVideo(url: videoURL, caption: caption)
                        await MainActor.run {
                            isUploading = false
                            dismiss()
                        }
                    } catch {
                        handleError(error.localizedDescription)
                    }
                }
            }
        }
    }
    
    private func handleError(_ message: String) {
        Task { @MainActor in
            errorMessage = message
            showError = true
            isUploading = false
        }
    }
} 