import SwiftUI
import PhotosUI
import AVKit
import UIKit
import FirebaseFirestore

struct DraftDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false
    @State private var showEditSheet = false
    @State private var isDeleting = false
    @State private var references: [ReferenceText] = []
    @State private var errorMessage: String?
    @State private var draft: Draft
    @State private var showingVideoGeneration = false
    @State private var isGeneratingVideo = false
    let onDraftDeleted: (() -> Void)?
    
    init(draft: Draft, onDraftDeleted: (() -> Void)? = nil) {
        _draft = State(initialValue: draft)
        self.onDraftDeleted = onDraftDeleted
    }
    
    var body: some View {
        List {
            // First section with content
            Section {
                VStack(alignment: .leading, spacing: 24) {
                    // Title and Status
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Title", systemImage: "text.quote")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        HStack {
                            Text(draft.title)
                                .font(.title3)
                            
                            Spacer()
                            
                            StatusBadge(status: draft.status)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        )
                    }
                    
                    // Category and Type
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Category", systemImage: "tag.fill")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        HStack(spacing: 12) {
                            CategoryBadge(category: draft.category)
                            if let subcategory = draft.subcategory {
                                Text(subcategory.rawValue)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color(.systemGray6))
                                    )
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        )
                    }
                    
                    // Content
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Story Content", systemImage: "doc.text.fill")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Text(draft.content)
                            .font(.body)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            )
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } header: {
                Text("Story Details")
                    .textCase(.uppercase)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Images Section
            if !draft.imageUrls.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Images", systemImage: "photo.fill")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 12) {
                                ForEach(draft.imageUrls, id: \.self) { url in
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
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Media")
                        .textCase(.uppercase)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Videos Section
            if !draft.videoUrls.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Videos", systemImage: "video.fill")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 12) {
                                ForEach(draft.videoUrls, id: \.self) { url in
                                    DraftVideoThumbnailView(url: url)
                                        .frame(width: 160, height: 180)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            
            // Reference Texts Section
            if !references.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("References", systemImage: "text.book.closed.fill")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        ForEach(references) { reference in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(reference.title)
                                    .font(.headline)
                                
                                Text(reference.content)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                                
                                if let source = reference.source {
                                    Text("Source: \(source)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Text("Last updated: \(reference.updatedAt.formatted(.relative(presentation: .named)))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            )
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } header: {
                    Text("References")
                        .textCase(.uppercase)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Metadata Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Details", systemImage: "info.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    VStack(spacing: 12) {
                        MetadataRow(label: "Created", value: draft.createdAt.formatted(.relative(presentation: .named)))
                        MetadataRow(label: "Last Modified", value: draft.updatedAt.formatted(.relative(presentation: .named)))
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    )
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } header: {
                Text("Information")
                    .textCase(.uppercase)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // AI Actions Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("AI Actions", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    VStack(spacing: 12) {
                        Button {
                            handleVideoGeneration()
                        } label: {
                            HStack {
                                Image(systemName: "video.badge.plus")
                                Text("Create AI Video")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue)
                            )
                            .foregroundStyle(.white)
                        }
                        .disabled(isGeneratingVideo)
                        
                        Button {
                            handleScriptGeneration()
                        } label: {
                            HStack {
                                Image(systemName: "doc.text.below.ecg")
                                Text("Create Script")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemGray5))
                            )
                            .foregroundStyle(.primary)
                        }
                        .disabled(isGeneratingVideo)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    )
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } header: {
                Text("AI Features")
                    .textCase(.uppercase)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(isDeleting)
            }
        }
        .alert("Delete Draft", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteDraft()
                }
            }
        } message: {
            Text("Are you sure you want to delete this draft? This action cannot be undone.")
        }
        .sheet(isPresented: $showEditSheet) {
            NavigationStack {
                DraftEditView(draft: $draft)
            }
        }
        .sheet(isPresented: $showingVideoGeneration) {
            NavigationStack {
                VideoGenerationView(draft: draft)
            }
        }
        .task {
            await fetchReferences()
        }
        .onChange(of: draft.referenceTextIds) { _ in
            Task {
                await fetchReferences()
            }
        }
    }
    
    private func fetchReferences() async {
        do {
            print("DEBUG: Starting to fetch references for draft: \(draft.id)")
            print("DEBUG: Reference IDs to fetch: \(draft.referenceTextIds)")
            
            let db = Firestore.firestore()
            references = []
            
            for id in draft.referenceTextIds {
                print("DEBUG: Fetching reference with ID: \(id)")
                let docRef = db.collection("users")
                    .document(draft.userId)
                    .collection("referenceTexts")
                    .document(id)
                
                let doc = try await docRef.getDocument()
                print("DEBUG: Got document for reference \(id). Exists: \(doc.exists)")
                if doc.exists {
                    print("DEBUG: Document data: \(doc.data() ?? [:])")
                    if let reference = ReferenceText.fromFirestore(doc.data() ?? [:], id: doc.documentID) {
                        print("DEBUG: Successfully parsed reference: \(reference.title)")
                        references.append(reference)
                    } else {
                        print("DEBUG: Failed to parse reference from data")
                    }
                }
            }
            
            print("DEBUG: Finished fetching references. Found: \(references.count)")
        } catch {
            print("DEBUG: Failed to fetch references: \(error)")
            errorMessage = "Failed to fetch references: \(error.localizedDescription)"
        }
    }
    
    private func deleteDraft() async {
        isDeleting = true
        
        do {
            let db = Firestore.firestore()
            // Delete from Firestore
            try await db.collection("users")
                .document(draft.userId)
                .collection("drafts")
                .document(draft.id)
                .delete()
            
            // Call the callback
            onDraftDeleted?()
            
            // Dismiss the view
            dismiss()
        } catch {
            print("DEBUG: Failed to delete draft: \(error)")
            isDeleting = false
            errorMessage = "Failed to delete draft: \(error.localizedDescription)"
        }
    }
    
    private func handleVideoGeneration() {
        showingVideoGeneration = true
    }
    
    private func handleScriptGeneration() {
        // TODO: Implement script generation
    }
}

// MARK: - Supporting Views
private struct StatusBadge: View {
    let status: DraftStatus
    
    var body: some View {
        Text(status.rawValue)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(statusColor.opacity(0.15))
            )
            .foregroundStyle(statusColor)
    }
    
    private var statusColor: Color {
        switch status {
        case .draft:
            return .gray
        case .readyForAI:
            return .blue
        case .generating:
            return .orange
        case .published:
            return .green
        }
    }
}

private struct CategoryBadge: View {
    let category: DraftCategory
    
    var body: some View {
        Text(category.rawValue)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(categoryColor.opacity(0.15))
            )
            .foregroundStyle(categoryColor)
    }
    
    private var categoryColor: Color {
        switch category {
        case .historical:
            return .blue
        case .mythAndLore:
            return .purple
        }
    }
}

private struct ImageGridView: View {
    let imageUrls: [String]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(imageUrls, id: \.self) { url in
                    AsyncImage(url: URL(string: url)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 160, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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

private struct VideoGridView: View {
    let videoUrls: [String]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(videoUrls, id: \.self) { url in
                    DraftVideoThumbnailView(url: url)
                        .frame(width: 160, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct ReferenceTextView: View {
    let reference: ReferenceText
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(reference.title)
                .font(.headline)
            
            Text(reference.content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            
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
    }
}

private struct MetadataRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
        }
    }
}

#Preview {
    NavigationStack {
        DraftDetailView(draft: Draft(
            userId: "preview_user",
            title: "Sample Draft",
            content: "This is a sample draft content for preview purposes.",
            category: .historical,
            subcategory: .canonical
        ))
    }
} 