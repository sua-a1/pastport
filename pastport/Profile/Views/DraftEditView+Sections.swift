import SwiftUI
import PhotosUI
import AVKit
import FirebaseFirestore
import FirebaseStorage

// MARK: - Form Sections
struct DraftBasicInfoSection: View {
    @Binding var title: String
    @Binding var category: DraftCategory
    @Binding var subcategory: DraftSubcategory?
    
    var body: some View {
        Section {
            TextField("Title", text: $title)
                .font(.headline)
            
            Picker("Category", selection: $category) {
                ForEach(DraftCategory.allCases, id: \.self) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            
            Picker("Story Type", selection: $subcategory) {
                Text("Select Type").tag(Optional<DraftSubcategory>.none)
                ForEach(DraftSubcategory.allCases, id: \.self) { subcategory in
                    Text(subcategory.rawValue).tag(Optional(subcategory))
                }
            }
        }
    }
}

struct DraftContentSection: View {
    @Binding var content: String
    
    var body: some View {
        Section {
            TextEditor(text: $content)
                .frame(minHeight: 200)
        } header: {
            Text("Content")
        }
    }
}

struct DraftAttachmentsSection: View {
    let draft: Draft
    let onHandleImages: ([PhotosPickerItem]) async -> Void
    let onHandleVideos: ([PhotosPickerItem]) async -> Void
    let onDeleteImage: (String) async -> Void
    let onDeleteVideo: (String) async -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Images Section
            DraftImagePickerSection(
                imageUrls: draft.imageUrls,
                onAddImage: onHandleImages,
                onDeleteImage: onDeleteImage
            )
            
            Divider()
                .padding(.vertical, 8)
            
            // Videos Section
            DraftVideoPickerSection(
                videoUrls: draft.videoUrls,
                onAddVideo: onHandleVideos,
                onDeleteVideo: onDeleteVideo
            )
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}

struct DraftReferencesSection: View {
    @Binding var draft: Draft
    @Binding var showReferenceSheet: Bool
    @Binding var selectedReferenceForEdit: ReferenceText?
    @State private var isDeleting = false
    @State private var references: [ReferenceText] = []
    @State private var errorMessage: String?
    @State private var showDeleteAlert = false
    @State private var referenceToDelete: ReferenceText?
    
    var body: some View {
        Section("References (\(draft.referenceTextIds.count)/2)") {
            if !references.isEmpty {
                ForEach(references) { reference in
                    ReferenceTextRow(reference: reference, isDeleting: isDeleting)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            print("DEBUG: Setting selectedReferenceForEdit to \(reference.id)")
                            selectedReferenceForEdit = reference
                        }
                        .swipeActions {
                            Button("Edit") {
                                print("DEBUG: Setting selectedReferenceForEdit to \(reference.id) from swipe")
                                selectedReferenceForEdit = reference
                            }
                            .tint(.blue)
                            
                            Button("Delete", role: .destructive) {
                                referenceToDelete = reference
                                showDeleteAlert = true
                            }
                        }
                }
            } else {
                ContentUnavailableView(
                    "No References",
                    systemImage: "text.book.closed",
                    description: Text("Add a reference to provide context for your story")
                )
            }
            
            if draft.referenceTextIds.count < 2 {
                Button {
                    print("DEBUG: Opening reference sheet. Current references: \(draft.referenceTextIds.count)")
                    showReferenceSheet = true
                } label: {
                    Label("Add Reference", systemImage: "text.book.closed")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .task {
            print("DEBUG: Initial fetch of references")
            await fetchReferences()
        }
        .onChange(of: draft.referenceTextIds) { _ in
            print("DEBUG: Reference IDs changed, fetching references")
            Task {
                await fetchReferences()
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .alert("Delete Reference", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {
                referenceToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let reference = referenceToDelete {
                    Task {
                        await deleteReference(reference)
                        referenceToDelete = nil
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this reference? This action cannot be undone.")
        }
    }
    
    private func fetchReferences() async {
        do {
            let db = Firestore.firestore()
            references = []
            
            for id in draft.referenceTextIds {
                let docRef = db.collection("users")
                    .document(draft.userId)
                    .collection("referenceTexts")
                    .document(id)
                
                let doc = try await docRef.getDocument()
                if doc.exists,
                   let reference = ReferenceText.fromFirestore(doc.data() ?? [:], id: doc.documentID) {
                    references.append(reference)
                }
            }
        } catch {
            print("DEBUG: Failed to fetch references: \(error)")
            errorMessage = "Failed to fetch references: \(error.localizedDescription)"
        }
    }
    
    private func deleteReference(_ reference: ReferenceText) async {
        isDeleting = true
        defer { isDeleting = false }
        
        do {
            let db = Firestore.firestore()
            
            // First update the reference text to remove this draft
            var updatedReference = reference
            updatedReference.draftIds.removeAll { $0 == draft.id }
            updatedReference.updatedAt = Date()
            
            // If this was the last draft using this reference, delete it
            if updatedReference.draftIds.isEmpty {
                try await db.collection("users")
                    .document(draft.userId)
                    .collection("referenceTexts")
                    .document(reference.id)
                    .delete()
            } else {
                try await db.collection("users")
                    .document(draft.userId)
                    .collection("referenceTexts")
                    .document(reference.id)
                    .setData(updatedReference.toFirestore(), merge: true)
            }
            
            // Then update the draft
            var updatedDraft = draft
            updatedDraft.referenceTextIds.removeAll { $0 == reference.id }
            updatedDraft.updatedAt = Date()
            
            try await db.collection("users")
                .document(draft.userId)
                .collection("drafts")
                .document(draft.id)
                .setData(updatedDraft.toFirestore(), merge: true)
            
            draft = updatedDraft
        } catch {
            print("DEBUG: Failed to delete reference: \(error)")
            errorMessage = "Failed to delete reference: \(error.localizedDescription)"
        }
    }
}

private struct ReferenceTextRow: View {
    let reference: ReferenceText
    let isDeleting: Bool
    
    var body: some View {
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
            
            Text("Last updated: \(reference.updatedAt.formatted(.relative(presentation: .named)))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .opacity(isDeleting ? 0.5 : 1)
        .overlay(alignment: .trailing) {
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.trailing, 4)
        }
    }
}

private struct ImageGridView: View {
    let imageUrls: [String]
    let onDelete: (String) -> Void
    
    var body: some View {
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
                        
                        Button {
                            onDelete(url)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white)
                                .background(Circle().fill(.black.opacity(0.5)))
                                .padding(8)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct ReferenceTextView: View {
    let reference: ReferenceText
    let onDelete: () -> Void
    
    var body: some View {
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
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct VideoGridView: View {
    let videoUrls: [String]
    let onDelete: (String) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(videoUrls, id: \.self) { url in
                    ZStack(alignment: .topTrailing) {
                        DraftVideoThumbnailView(url: url)
                            .frame(width: 160, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Button {
                            onDelete(url)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white)
                                .background(Circle().fill(.black.opacity(0.5)))
                                .padding(8)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
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
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
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
                    .font(.largeTitle)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
            }
        }
        .task {
            await loadThumbnail()
        }
        .sheet(isPresented: $showVideoPlayer) {
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

// MARK: - Media Picker View
private struct MediaPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: PhotosPickerItem?
    let mediaTypes: PHPickerFilter
    let onDismiss: () -> Void
    
    var body: some View {
        PhotosPicker(
            selection: $selection,
            matching: mediaTypes,
            photoLibrary: .shared()
        ) {
            Text("Select Media")
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
        }
        .onChange(of: selection) { _, _ in
            onDismiss()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .navigationTitle(mediaTypes == .images ? "Select Image" : "Select Video")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Image Picker Section
private struct DraftImagePickerSection: View {
    let imageUrls: [String]
    let onAddImage: ([PhotosPickerItem]) async -> Void
    let onDeleteImage: (String) async -> Void
    @State private var currentSelection: [PhotosPickerItem] = []
    @State private var isUploading = false
    @State private var showPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Images", systemImage: "photo.stack")
                .font(.headline)
                .foregroundStyle(.primary)
            
            if !imageUrls.isEmpty {
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
                                
                                Button {
                                    Task {
                                        await onDeleteImage(url)
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white)
                                        .background(Circle().fill(.black.opacity(0.5)))
                                        .padding(8)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 220)
            }
            
            if isUploading {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Uploading images...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else if imageUrls.count < 4 {
                Button {
                    showPicker = true
                } label: {
                    Label("Add Images (\(imageUrls.count)/4)", systemImage: "photo.stack")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray6))
                        )
                }
                .photosPicker(
                    isPresented: $showPicker,
                    selection: $currentSelection,
                    maxSelectionCount: 4 - imageUrls.count,
                    matching: .images,
                    photoLibrary: .shared()
                )
            }
        }
        .onChange(of: currentSelection) { _, items in
            guard !items.isEmpty else { return }
            Task {
                isUploading = true
                await onAddImage(items)
                isUploading = false
                currentSelection = []
                showPicker = false
            }
        }
    }
}

// MARK: - Video Picker Section
private struct DraftVideoPickerSection: View {
    let videoUrls: [String]
    let onAddVideo: ([PhotosPickerItem]) async -> Void
    let onDeleteVideo: (String) async -> Void
    @State private var currentSelection: [PhotosPickerItem] = []
    @State private var isUploading = false
    @State private var showPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Videos", systemImage: "video.fill")
                .font(.headline)
                .foregroundStyle(.primary)
            
            if !videoUrls.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(videoUrls, id: \.self) { url in
                            ZStack(alignment: .topTrailing) {
                                DraftVideoThumbnailView(url: url)
                                    .frame(width: 160, height: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                
                                Button {
                                    Task {
                                        await onDeleteVideo(url)
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white)
                                        .background(Circle().fill(.black.opacity(0.5)))
                                        .padding(8)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 200)
            }
            
            if isUploading {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Uploading videos...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else if videoUrls.count < 2 {
                Button {
                    showPicker = true
                } label: {
                    Label("Add Videos (\(videoUrls.count)/2)", systemImage: "video.badge.plus")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray6))
                        )
                }
                .photosPicker(
                    isPresented: $showPicker,
                    selection: $currentSelection,
                    maxSelectionCount: 2 - videoUrls.count,
                    matching: .videos,
                    photoLibrary: .shared()
                )
            }
        }
        .onChange(of: currentSelection) { _, items in
            guard !items.isEmpty else { return }
            Task {
                isUploading = true
                await onAddVideo(items)
                isUploading = false
                currentSelection = []
                showPicker = false
            }
        }
    }
} 