import SwiftUI
import AVKit
import FirebaseAuth

struct StitchedVideoPostingView: View {
    let videoURL: URL
    let script: AIScript
    @State private var videoUploader = VideoUploader()
    @Environment(\.dismiss) private var dismiss
    @Binding var showCameraView: Bool
    @Binding var selectedTab: Int
    
    @State private var caption: String = ""
    @State private var selectedCategory: PostCategory?
    @State private var selectedSubcategory: PostSubcategory?
    @State private var isUploading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccessAlert = false
    @State private var navigateToProfile = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                contentView
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showSuccessAlert) {
                Button("View Profile") {
                    dismiss()
                    showCameraView = false
                    selectedTab = 4  // Switch to profile tab
                }
                Button("Done") {
                    dismiss()
                    showCameraView = false
                }
            } message: {
                Text("Your video has been posted successfully!")
            }
        }
        .interactiveDismissDisabled(isUploading)
        .presentationBackground(.background)
    }
    
    private var contentView: some View {
        VStack(spacing: 20) {
            videoPreview
            captionInput
            CategorySelectionView(
                selectedCategory: $selectedCategory,
                selectedSubcategory: $selectedSubcategory
            )
            uploadProgressView
        }
        .padding()
    }
    
    private var videoPreview: some View {
        VideoPlayer(player: AVPlayer(url: videoURL))
            .frame(height: 400)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var captionInput: some View {
        TextField("Write a caption...", text: $caption, axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .lineLimit(3...6)
    }
    
    private var uploadProgressView: some View {
        Group {
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
    
    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    if isUploading {
                        showError = true
                        errorMessage = "Please wait for the upload to complete or cancel it"
                    } else {
                        dismiss()
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Post") {
                    uploadVideo()
                }
                .disabled(isUploading || caption.isEmpty || selectedCategory == nil || selectedSubcategory == nil)
            }
        }
    }
    
    private func uploadVideo() {
        guard let category = selectedCategory,
              let subcategory = selectedSubcategory else {
            return
        }
        
        isUploading = true
        
        Task {
            do {
                let categorization = PostCategorization(
                    category: category,
                    subcategory: subcategory
                )
                
                // Upload the video using VideoUploader
                _ = try await videoUploader.uploadVideo(
                    url: videoURL,
                    caption: caption,
                    categorization: categorization
                )
                
                await MainActor.run {
                    isUploading = false
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                    showError = true
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
} 