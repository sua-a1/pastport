import SwiftUI
import PhotosUI
import FirebaseFirestore
import FirebaseStorage
import AVKit

struct CreateView: View {
    @State private var showVideoCreation = false
    @State private var showDraftCreation = false
    @State private var showCharacterCreation = false
    @EnvironmentObject private var authViewModel: AuthenticationViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background color
                Color.pastportBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Title and description
                        VStack(spacing: 12) {
                            Text("Create")
                                .font(.title.bold())
                            
                            Text("Choose how you want to tell your story")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 24)
                        
                        // Creation Options
                        VStack(spacing: 24) {
                            // Video Creation Button
                            CreationOptionButton(
                                icon: "video.fill",
                                title: "Create Video",
                                description: "Record or upload a video to share your story",
                                action: { showVideoCreation = true }
                            )
                            
                            // AI Draft Button
                            CreationOptionButton(
                                icon: "doc.text.fill",
                                title: "Create AI Draft",
                                description: "Write your story and let AI help bring it to life",
                                action: { showDraftCreation = true }
                            )
                            
                            // Character Creation Button
                            CreationOptionButton(
                                icon: "person.fill.viewfinder",
                                title: "Create Character",
                                description: "Design a character with AI for your stories",
                                action: { showCharacterCreation = true }
                            )
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showVideoCreation) {
                VideoRecordingView(showCameraView: $showVideoCreation, selectedTab: .constant(2))
                    .environmentObject(authViewModel)
            }
            .sheet(isPresented: $showDraftCreation) {
                NavigationStack {
                    DraftCreationView(viewModel: {
                        let viewModel = CreateViewModel()
                        viewModel.user = authViewModel.currentUser
                        return viewModel
                    }())
                    .environmentObject(authViewModel)
                }
            }
            .sheet(isPresented: $showCharacterCreation) {
                NavigationStack {
                    CharacterCreationView(viewModel: CharacterCreationViewModel(user: authViewModel.currentUser))
                        .environmentObject(authViewModel)
                }
            }
        }
    }
}

// MARK: - Supporting Views
private struct CreationOptionButton: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
                
                // Text Content
                VStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helper Extensions
extension UIImage {
    func resizedIfNeeded(maxDimension: CGFloat) async -> UIImage {
        let ratio = max(size.width, size.height) / maxDimension
        if ratio <= 1 { return self }
        
        let newSize = CGSize(
            width: size.width / ratio,
            height: size.height / ratio
        )
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let renderer = UIGraphicsImageRenderer(size: newSize)
                let resized = renderer.image { context in
                    self.draw(in: CGRect(origin: .zero, size: newSize))
                }
                continuation.resume(returning: resized)
            }
        }
    }
}

extension TimeInterval {
    func formatDuration() -> String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Preview
#Preview {
    CreateView()
        .environmentObject(AuthenticationViewModel())
} 