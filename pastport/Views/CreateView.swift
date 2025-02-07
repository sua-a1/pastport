import SwiftUI
import PhotosUI
import FirebaseFirestore
import FirebaseStorage
import AVKit

struct CreateView: View {
    @State private var showVideoCreation = false
    @State private var showDraftCreation = false
    @EnvironmentObject private var authViewModel: AuthenticationViewModel
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Title and description
                VStack(spacing: 8) {
                    Text("Create")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Choose how you want to tell your story")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)
                
                // Video Creation Button
                Button {
                    showVideoCreation = true
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 32))
                        
                        Text("Create Video")
                            .font(.headline)
                        
                        Text("Record or upload a video to share your story")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(radius: 2)
                    )
                }
                .buttonStyle(.plain)
                
                // AI Draft Button
                Button {
                    showDraftCreation = true
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 32))
                        
                        Text("Create AI Draft")
                            .font(.headline)
                        
                        Text("Write your story and let AI help bring it to life")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(radius: 2)
                    )
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding()
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
        }
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