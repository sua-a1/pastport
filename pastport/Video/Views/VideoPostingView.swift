import SwiftUI
import AVKit
import PhotosUI
import Firebase
import FirebaseAuth

struct VideoPostingView: View {
    let videoURL: URL
    @State private var caption = ""
    @State private var isUploading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccessAlert = false
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer
    @State private var videoUploader = VideoUploader()
    @Binding var showCameraView: Bool
    @Binding var selectedTab: Int
    @State private var navigateToProfile = false
    
    init(videoURL: URL, showCameraView: Binding<Bool>, selectedTab: Binding<Int>) {
        self.videoURL = videoURL
        _player = State(initialValue: AVPlayer(url: videoURL))
        _showCameraView = showCameraView
        _selectedTab = selectedTab
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
                                
                                // Add cancel button during upload
                                if isUploading {
                                    Button("Cancel Upload", role: .destructive) {
                                        // TODO: Implement cancel functionality
                                        isUploading = false
                                        dismiss()
                                    }
                                    .padding()
                                }
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
                    .disabled(isUploading || caption.isEmpty)
                }
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
        .fullScreenCover(isPresented: $navigateToProfile) {
            if let user = Auth.auth().currentUser {
                ProfileDetailView(authViewModel: AuthenticationViewModel())
            }
        }
    }
    
    private func uploadVideo() {
        print("DEBUG: Starting video upload in VideoPostingView")
        print("DEBUG: Video URL: \(videoURL)")
        print("DEBUG: Video exists: \(FileManager.default.fileExists(atPath: videoURL.path))")
        if let attributes = try? FileManager.default.attributesOfItem(atPath: videoURL.path) {
            print("DEBUG: Video file attributes: \(attributes)")
        }
        
        isUploading = true
        
        Task {
            do {
                print("DEBUG: Attempting to upload video")
                let url = try await videoUploader.uploadVideo(url: videoURL, caption: caption)
                print("DEBUG: Video upload completed successfully with URL: \(url)")
                await MainActor.run {
                    isUploading = false
                    showSuccessAlert = true
                }
            } catch {
                print("DEBUG: Video upload failed with error: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("DEBUG: Error details - Domain: \(nsError.domain), Code: \(nsError.code)")
                    print("DEBUG: Error user info: \(nsError.userInfo)")
                }
                await MainActor.run {
                    isUploading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
} 