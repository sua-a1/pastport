import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import PhotosUI
import AVKit
import FirebaseAuth

// MARK: - Notifications
extension Notification.Name {
    static let draftDeleted = Notification.Name("draftDeleted")
    static let draftUpdated = Notification.Name("draftUpdated")
    static let draftCreated = Notification.Name("draftCreated")
}

struct DraftEditView: View {
    @Binding var draft: Draft
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var title: String
    @State private var content: String
    @State private var category: DraftCategory
    @State private var subcategory: DraftSubcategory?
    @State private var showSaveAlert = false
    @State private var showReferenceSheet = false
    @State private var selectedReferenceForEdit: ReferenceText?
    let storage = Storage.storage().reference()
    
    init(draft: Binding<Draft>) {
        _draft = draft
        _title = State(initialValue: draft.wrappedValue.title)
        _content = State(initialValue: draft.wrappedValue.content)
        _category = State(initialValue: draft.wrappedValue.category)
        _subcategory = State(initialValue: draft.wrappedValue.subcategory)
    }
    
    // MARK: - Reference Management
    private func addReference(_ reference: ReferenceText) async {
        do {
            print("DEBUG: Adding reference \(reference.id) to draft \(draft.id)")
            let db = Firestore.firestore()
            
            // First update the reference text to include this draft
            var updatedReference = reference
            updatedReference.draftIds.append(draft.id)
            updatedReference.updatedAt = Date()
            
            try await db.collection("users")
                .document(draft.userId)
                .collection("referenceTexts")
                .document(reference.id)
                .setData(updatedReference.toFirestore(), merge: true)
            
            // Then update the draft
            var updatedDraft = draft
            updatedDraft.referenceTextIds.append(reference.id)
            updatedDraft.updatedAt = Date()
            
            try await db.collection("users")
                .document(draft.userId)
                .collection("drafts")
                .document(draft.id)
                .setData(updatedDraft.toFirestore(), merge: true)
            
            print("DEBUG: Successfully added reference. Draft now has \(updatedDraft.referenceTextIds.count) references")
            draft = updatedDraft
        } catch {
            print("DEBUG: Failed to add reference: \(error)")
            errorMessage = "Failed to add reference: \(error.localizedDescription)"
        }
    }
    
    private func updateReference(_ reference: ReferenceText) async {
        do {
            let db = Firestore.firestore()
            try await db.collection("users")
                .document(draft.userId)
                .collection("referenceTexts")
                .document(reference.id)
                .setData(reference.toFirestore(), merge: true)
            
            // Trigger a refresh of the references
            var updatedDraft = draft
            updatedDraft.updatedAt = Date()
            draft = updatedDraft
        } catch {
            print("DEBUG: Failed to update reference: \(error)")
            errorMessage = "Failed to update reference: \(error.localizedDescription)"
        }
    }
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 24) {
                    // Title Field
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Title", systemImage: "text.quote")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        TextField("Give your story a compelling title", text: $title)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            )
                    }
                    
                    // Content Field
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Story Content", systemImage: "doc.text.fill")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $content)
                                .frame(minHeight: 180)
                                .padding(12)
                                .scrollContentBackground(.hidden)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(.systemBackground))
                                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                                )
                            
                            if content.isEmpty {
                                Text("Write your story here. Be descriptive - this will help the AI create better visuals.")
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 20)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                    
                    // Category Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Category", systemImage: "tag.fill")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Category", selection: $category) {
                                ForEach(DraftCategory.allCases, id: \.self) { category in
                                    Text(category.rawValue).tag(category)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            Menu {
                                Picker("Story Type", selection: $subcategory) {
                                    Text("Select Type").tag(Optional<DraftSubcategory>.none)
                                    ForEach(DraftSubcategory.allCases, id: \.self) { subcategory in
                                        Text(subcategory.rawValue).tag(Optional(subcategory))
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(subcategory?.rawValue ?? "Select Story Type")
                                        .foregroundStyle(subcategory == nil ? .secondary : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(.systemBackground))
                                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                                )
                            }
                        }
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } header: {
                Text("Story Details")
                    .textCase(.uppercase)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Media Section
            Section {
                DraftAttachmentsSection(
                    draft: draft,
                    onHandleImages: handleSelectedImages,
                    onHandleVideos: handleSelectedVideos,
                    onDeleteImage: handleDeleteImage,
                    onDeleteVideo: handleDeleteVideo
                )
            } header: {
                Text("Media")
                    .textCase(.uppercase)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // References Section
            Section {
                DraftReferencesSection(
                    draft: $draft,
                    showReferenceSheet: $showReferenceSheet,
                    selectedReferenceForEdit: $selectedReferenceForEdit
                )
            } header: {
                Text("References")
                    .textCase(.uppercase)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Edit Draft")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(isSaving)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        if isValid {
                            Task {
                                await saveDraft()
                            }
                        } else {
                            showSaveAlert = true
                        }
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .disabled(isSaving)
                    
                    Button(role: .destructive) {
                        Task {
                            await deleteDraft()
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(isSaving)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .bold()
                }
            }
        }
        .alert("Cannot Save Draft", isPresented: $showSaveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(validationMessage)
        }
        .alert("Error Saving Draft", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .sheet(item: $selectedReferenceForEdit) { reference in
            NavigationView {
                ReferenceTextEditView(reference: reference) { updatedReference in
                    Task {
                        await updateReference(updatedReference)
                        selectedReferenceForEdit = nil
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showReferenceSheet) {
            NavigationView {
                ReferenceTextSelectionView(userId: draft.userId) { reference in
                    Task {
                        print("DEBUG: Reference selected: \(reference.id)")
                        await addReference(reference)
                        showReferenceSheet = false
                    }
                }
            }
        }
    }
    
    private func handleSelectedImages(_ items: [PhotosPickerItem]) async {
        print("DEBUG: Processing \(items.count) selected images")
        
        // Debug authentication state
        if let currentUser = Auth.auth().currentUser {
            print("DEBUG: Current user ID: \(currentUser.uid)")
            print("DEBUG: Draft user ID: \(draft.userId)")
            print("DEBUG: Are IDs matching? \(currentUser.uid == draft.userId)")
        } else {
            print("DEBUG: No authenticated user found!")
        }
        
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else {
                print("DEBUG: Failed to load image data")
                continue
            }
            
            do {
                // Compress image if needed
                let maxSize: Int = 2 * 1024 * 1024 // 2MB
                var imageData = data
                if data.count > maxSize {
                    let compression: CGFloat = CGFloat(maxSize) / CGFloat(data.count)
                    imageData = uiImage.jpegData(compressionQuality: compression) ?? data
                }
                
                print("DEBUG: Image size: \(imageData.count) bytes")
                
                let filename = "\(UUID().uuidString).jpg"
                let imageRef = storage.child("drafts/\(draft.userId)/\(draft.id)/images/\(filename)")
                
                print("DEBUG: Uploading image to path: \(imageRef.fullPath)")
                
                // Set content type metadata
                let metadata = StorageMetadata()
                metadata.contentType = "image/jpeg"
                
                _ = try await imageRef.putDataAsync(imageData, metadata: metadata)
                let url = try await imageRef.downloadURL()
                print("DEBUG: Image uploaded successfully to \(url.absoluteString)")
                
                await MainActor.run {
                    draft.imageUrls.append(url.absoluteString)
                }
            } catch {
                print("DEBUG: Failed to upload image: \(error)")
                print("DEBUG: Full error details: \(String(describing: error))")
                errorMessage = "Failed to upload image: \(error.localizedDescription)"
            }
        }
    }
    
    private func handleSelectedVideos(_ items: [PhotosPickerItem]) async {
        print("DEBUG: Processing \(items.count) selected videos")
        
        // Debug authentication state
        if let currentUser = Auth.auth().currentUser {
            print("DEBUG: Current user ID: \(currentUser.uid)")
            print("DEBUG: Draft user ID: \(draft.userId)")
            print("DEBUG: Are IDs matching? \(currentUser.uid == draft.userId)")
        } else {
            print("DEBUG: No authenticated user found!")
        }
        
        for item in items {
            guard let movie = try? await item.loadTransferable(type: MovieTransferable.self) else {
                continue
            }
            
            do {
                let filename = "\(UUID().uuidString).mov"
                let videoRef = storage.child("drafts/\(draft.userId)/\(draft.id)/videos/\(filename)")
                
                print("DEBUG: Uploading video to path: \(videoRef.fullPath)")
                
                // Set content type metadata
                let metadata = StorageMetadata()
                metadata.contentType = "video/quicktime"
                
                _ = try await videoRef.putFileAsync(from: movie.url, metadata: metadata)
                let url = try await videoRef.downloadURL()
                print("DEBUG: Video uploaded successfully to \(url.absoluteString)")
                
                await MainActor.run {
                    draft.videoUrls.append(url.absoluteString)
                }
            } catch {
                print("DEBUG: Failed to upload video: \(error)")
                print("DEBUG: Full error details: \(String(describing: error))")
                errorMessage = "Failed to upload video: \(error.localizedDescription)"
            }
        }
    }
    
    private func handleDeleteImage(_ url: String) async {
        do {
            if let storageURL = URL(string: url),
               let imagePath = storageURL.path.components(separatedBy: "/o/").last?.removingPercentEncoding {
                // The path will be in format: drafts/{userId}/{draftId}/images/{imageId}
                let storageRef = storage.child(imagePath)
                print("DEBUG: Attempting to delete image at path: \(imagePath)")
                try await storageRef.delete()
                print("DEBUG: Successfully deleted image from storage")
            }
            
            await MainActor.run {
                draft.imageUrls.removeAll { $0 == url }
            }
        } catch {
            print("DEBUG: Failed to delete image: \(error)")
            errorMessage = "Failed to delete image: \(error.localizedDescription)"
        }
    }
    
    private func handleDeleteVideo(_ url: String) async {
        do {
            if let storageURL = URL(string: url),
               let videoPath = storageURL.path.components(separatedBy: "/o/").last?.removingPercentEncoding {
                // The path will be in format: drafts/{userId}/{draftId}/videos/{videoId}
                let storageRef = storage.child(videoPath)
                print("DEBUG: Attempting to delete video at path: \(videoPath)")
                try await storageRef.delete()
                print("DEBUG: Successfully deleted video from storage")
            }
            
            await MainActor.run {
                draft.videoUrls.removeAll { $0 == url }
            }
        } catch {
            print("DEBUG: Failed to delete video: \(error)")
            errorMessage = "Failed to delete video: \(error.localizedDescription)"
        }
    }
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        subcategory != nil
    }
    
    private var validationMessage: String {
        var messages: [String] = []
        
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append("Please enter a title")
        }
        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append("Please enter your story content")
        }
        if subcategory == nil {
            messages.append("Please select a story type")
        }
        
        return messages.joined(separator: "\n")
    }
    
    private func saveDraft() async {
        isSaving = true
        
        do {
            let db = Firestore.firestore()
            var updatedDraft = draft
            updatedDraft.title = title
            updatedDraft.content = content
            updatedDraft.category = category
            updatedDraft.subcategory = subcategory
            updatedDraft.updatedAt = Date()
            
            // Save to Firestore
            try await db.collection("users")
                .document(draft.userId)
                .collection("drafts")
                .document(draft.id)
                .setData(updatedDraft.toFirestore(), merge: true)
            
            print("DEBUG: Draft saved successfully")
            
            // Update binding
            draft = updatedDraft
            
            // Post notification for refresh
            NotificationCenter.default.post(name: .draftUpdated, object: nil)
            
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        } catch {
            print("DEBUG: Failed to save draft: \(error)")
            await MainActor.run {
                isSaving = false
                errorMessage = "Failed to save draft: \(error.localizedDescription)"
            }
        }
    }
    
    private func deleteDraft() async {
        isSaving = true
        
        do {
            let db = Firestore.firestore()
            // Delete from Firestore
            try await db.collection("users")
                .document(draft.userId)
                .collection("drafts")
                .document(draft.id)
                .delete()
            
            print("DEBUG: Deleted draft from Firestore")
            
            // Post notification for refresh
            NotificationCenter.default.post(name: .draftDeleted, object: nil)
            
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        } catch {
            print("DEBUG: Failed to delete draft: \(error)")
            await MainActor.run {
                isSaving = false
                errorMessage = "Failed to delete draft: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Form Sections

// Supporting Views
private struct ImageGridView: View {
    let imageUrls: [String]
    let onDelete: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Images", systemImage: "photo.fill")
                .font(.headline)
                .foregroundStyle(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(imageUrls, id: \.self) { url in
                        ZStack(alignment: .topTrailing) {
                            AsyncImage(url: URL(string: url)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 160, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            
                            Button {
                                onDelete(url)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.white)
                                    .shadow(radius: 1)
                                    .padding(8)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct VideoGridView: View {
    let videoUrls: [String]
    let onDelete: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Videos", systemImage: "video.fill")
                .font(.headline)
                .foregroundStyle(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(videoUrls, id: \.self) { url in
                        ZStack(alignment: .topTrailing) {
                            DraftVideoThumbnailView(url: url)
                                .frame(width: 160, height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            
                            Button {
                                onDelete(url)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.white)
                                    .shadow(radius: 1)
                                    .padding(8)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct ReferenceTextView: View {
    let reference: ReferenceText
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(reference.title)
                        .font(.headline)
                    
                    Text(reference.content)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    
                    if let source = reference.source {
                        Text("Source: \(source)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

// Add extension for image resizing
extension CIImage {
    func resized(to scale: CGFloat) -> CIImage {
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        return transformed(by: transform)
    }
}

private struct DraftVideoPlayerView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VideoPlayer(player: AVPlayer(url: url))
                .ignoresSafeArea()
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.white)
                                .shadow(radius: 1)
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

private struct DraftVideoThumbnailView: View {
    let url: String
    @State private var thumbnail: Image?
    @State private var showVideoPlayer = false
    
    var body: some View {
        Button {
            showVideoPlayer = true
        } label: {
            ZStack {
                if let thumbnail = thumbnail {
                    thumbnail
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color(.systemGray6))
                        .overlay {
                            ProgressView()
                        }
                }
                
                // Play button overlay
                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .shadow(radius: 1)
            }
        }
        .task {
            await loadThumbnail()
        }
        .fullScreenCover(isPresented: $showVideoPlayer) {
            if let videoURL = URL(string: url) {
                DraftVideoPlayerView(url: videoURL)
            }
        }
    }
    
    private func loadThumbnail() async {
        guard let url = URL(string: url) else { return }
        
        do {
            let asset = AVURLAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            let cgImage = try await imageGenerator.image(at: .zero).image
            thumbnail = Image(uiImage: UIImage(cgImage: cgImage))
        } catch {
            print("DEBUG: Failed to generate thumbnail: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        DraftEditView(draft: .constant(Draft(
            userId: "preview_user",
            title: "Sample Draft",
            content: "This is a sample draft content for preview purposes.",
            category: .historical,
            subcategory: .canonical
        )))
    }
} 