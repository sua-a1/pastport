import SwiftUI
import PhotosUI
import FirebaseFirestore
import FirebaseStorage

struct DraftCreationView: View {
    @Bindable var viewModel: CreateViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthenticationViewModel
    
    var body: some View {
        NavigationStack {
            List {
                StoryDetailsSection(viewModel: viewModel)
                
                MediaSection(viewModel: viewModel)
                
                ReferenceTextsSection(viewModel: viewModel)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Create Draft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(viewModel.isSaving)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(viewModel.isSaving ? "Saving..." : "Save") {
                        if viewModel.isValidDraft {
                            Task {
                                await saveDraft()
                            }
                        } else {
                            viewModel.showValidationAlert = true
                        }
                    }
                }
            }
            .overlay {
                if viewModel.isSaving {
                    SaveDraftLoadingView(message: "Saving draft...")
                }
            }
            .alert("Cannot Save Draft", isPresented: $viewModel.showValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.validationErrors.joined(separator: "\n"))
            }
            .alert("Error Saving Draft", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .alert("Draft Saved", isPresented: $viewModel.showSuccessMessage) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your draft has been saved successfully!")
            }
            .onAppear {
                viewModel.user = authViewModel.currentUser
            }
        }
    }
    
    private func saveDraft() async {
        guard let user = viewModel.user else {
            print("DEBUG: No user found")
            viewModel.errorMessage = "User not found"
            return
        }
        
        viewModel.isSaving = true
        print("DEBUG: Starting draft save process")
        
        do {
            let db = Firestore.firestore()
            let storage = Storage.storage().reference()
            
            // Create draft ID first
            let draftId = UUID().uuidString
            
            // Upload images
            print("DEBUG: Uploading \(viewModel.selectedImages.count) images")
            var imageUrls: [String] = []
            
            for mediaItem in viewModel.selectedImages {
                guard let data = try? await mediaItem.item.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: data) else {
                    continue
                }
                
                // Compress image if needed
                let maxSize: Int = 2 * 1024 * 1024 // 2MB
                var imageData = data
                if data.count > maxSize {
                    let compression: CGFloat = CGFloat(maxSize) / CGFloat(data.count)
                    imageData = uiImage.jpegData(compressionQuality: compression) ?? data
                }
                
                let filename = "\(UUID().uuidString).jpg"
                let imageRef = storage.child("drafts/\(user.id)/\(draftId)/images/\(filename)")
                
                let metadata = StorageMetadata()
                metadata.contentType = "image/jpeg"
                
                _ = try await imageRef.putDataAsync(imageData, metadata: metadata)
                let url = try await imageRef.downloadURL()
                imageUrls.append(url.absoluteString)
            }
            
            // Upload videos
            print("DEBUG: Uploading \(viewModel.selectedVideos.count) videos")
            var videoUrls: [String] = []
            
            for mediaItem in viewModel.selectedVideos {
                let filename = "\(UUID().uuidString).mp4"
                let path = "drafts/\(user.id)/\(draftId)/videos/\(filename)"
                
                let url = try await VideoUploader.uploadVideo(from: mediaItem.item, to: path)
                videoUrls.append(url)
            }
            
            // Create and save reference texts
            print("DEBUG: Creating reference texts")
            var referenceTextIds: [String] = []
            
            if !viewModel.referenceText1.content.isEmpty && !viewModel.referenceText1.title.isEmpty {
                let reference1 = ReferenceText(
                    userId: user.id,
                    title: viewModel.referenceText1.title,
                    content: viewModel.referenceText1.content,
                    source: viewModel.referenceText1.source.isEmpty ? nil : viewModel.referenceText1.source
                )
                
                let referenceRef = db.collection("users").document(user.id)
                    .collection("referenceTexts").document(reference1.id)
                try await referenceRef.setData(reference1.toFirestore())
                referenceTextIds.append(reference1.id)
            }
            
            if !viewModel.referenceText2.content.isEmpty && !viewModel.referenceText2.title.isEmpty {
                let reference2 = ReferenceText(
                    userId: user.id,
                    title: viewModel.referenceText2.title,
                    content: viewModel.referenceText2.content,
                    source: viewModel.referenceText2.source.isEmpty ? nil : viewModel.referenceText2.source
                )
                
                let referenceRef = db.collection("users").document(user.id)
                    .collection("referenceTexts").document(reference2.id)
                try await referenceRef.setData(reference2.toFirestore())
                referenceTextIds.append(reference2.id)
            }
            
            print("DEBUG: Creating draft object")
            let draft = Draft(
                id: draftId,
                userId: user.id,
                title: viewModel.title,
                content: viewModel.content,
                category: viewModel.category,
                subcategory: viewModel.subcategory,
                imageUrls: imageUrls,
                videoUrls: videoUrls,
                referenceTextIds: referenceTextIds
            )
            
            // Save to Firestore
            print("DEBUG: Saving to Firestore")
            let draftRef = db.collection("users").document(draft.userId)
                .collection("drafts").document(draft.id)
            try await draftRef.setData(draft.toFirestore())
            
            print("DEBUG: Draft saved successfully")
            
            // Post notification for draft creation
            NotificationCenter.default.post(name: .draftCreated, object: nil)
            
            await MainActor.run {
                viewModel.isSaving = false
                viewModel.showSuccessMessage = true
            }
        } catch {
            print("DEBUG: Error saving draft: \(error)")
            await MainActor.run {
                viewModel.isSaving = false
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Loading View
private struct SaveDraftLoadingView: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text(message)
                    .font(.headline)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(radius: 8)
            )
        }
    }
} 