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
    @State private var showingScriptGeneration = false
    @State private var isGeneratingVideo = false
    @State private var showCameraView = false
    @State private var selectedMainTab = 0
    let onDraftDeleted: (() -> Void)?
    
    init(draft: Draft, onDraftDeleted: (() -> Void)? = nil) {
        _draft = State(initialValue: draft)
        self.onDraftDeleted = onDraftDeleted
    }
    
    var body: some View {
        List {
            DraftDetailStorySection(viewModel: DraftDetailStorySection.ViewModel(draft: draft))
            
            if !draft.imageUrls.isEmpty {
                DraftMediaSection(imageUrls: draft.imageUrls, videoUrls: draft.videoUrls)
            }
            
            if !references.isEmpty {
                ReferencesSection(references: references)
            }
            
            MetadataSection(draft: draft)
            
            AIFeaturesSection(
                draft: draft,
                isGeneratingVideo: $isGeneratingVideo,
                showingVideoGeneration: $showingVideoGeneration,
                showingScriptGeneration: $showingScriptGeneration
            )
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
        .sheet(isPresented: $showingScriptGeneration) {
            NavigationStack {
                ScriptGenerationView(
                    draftId: draft.id,
                    userId: draft.userId,
                    showCameraView: $showCameraView,
                    selectedMainTab: $selectedMainTab
                )
            }
        }
        .task {
            await loadReferences()
        }
    }
    
    private func loadReferences() async {
        guard !draft.referenceTextIds.isEmpty else { return }
        
        do {
            let db = Firestore.firestore()
            var loadedReferences: [ReferenceText] = []
            
            for id in draft.referenceTextIds {
                if let reference = try await db.collection("users")
                    .document(draft.userId)
                    .collection("referenceTexts")
                    .document(id)
                    .getDocument()
                    .data()
                    .flatMap({ ReferenceText.fromFirestore($0, id: id) }) {
                    loadedReferences.append(reference)
                }
            }
            
            self.references = loadedReferences
        } catch {
            print("DEBUG: Failed to fetch references: \(error)")
            errorMessage = "Failed to fetch references: \(error.localizedDescription)"
        }
    }
    
    private func deleteDraft() async {
        isDeleting = true
        
        do {
            let db = Firestore.firestore()
            try await db.collection("users")
                .document(draft.userId)
                .collection("drafts")
                .document(draft.id)
                .delete()
            
            onDraftDeleted?()
            dismiss()
        } catch {
            print("DEBUG: Failed to delete draft: \(error)")
            isDeleting = false
            errorMessage = "Failed to delete draft: \(error.localizedDescription)"
        }
    }
}

// MARK: - Story Details Section
private struct DraftDetailStorySection: View {
    @Observable final class ViewModel {
        var draft: Draft
        
        init(draft: Draft) {
            self.draft = draft
        }
    }
    
    let viewModel: ViewModel
    
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 24) {
                // Title and Status
                VStack(alignment: .leading, spacing: 8) {
                    Label("Title", systemImage: "text.quote")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    HStack {
                        Text(viewModel.draft.title)
                            .font(.title3)
                        
                        Spacer()
                        
                        StatusBadge(status: viewModel.draft.status)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemBackground))
                    )
                }
                
                // Category
                VStack(alignment: .leading, spacing: 8) {
                    Label("Category", systemImage: "folder")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    CategoryBadge(category: viewModel.draft.category)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    Label("Content", systemImage: "doc.text")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(viewModel.draft.content)
                        .font(.body)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemBackground))
                        )
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } header: {
            Text("Story")
                .textCase(.uppercase)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Video Thumbnail View
private struct DraftVideoThumbnailView: View {
    let url: String
    @State private var player: AVPlayer?
    
    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .onDisappear {
                        player.pause()
                    }
            } else {
                Color.gray
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .task {
            player = AVPlayer(url: URL(string: url)!)
        }
    }
}

// MARK: - Media Section
private struct DraftMediaSection: View {
    let imageUrls: [String]
    let videoUrls: [String]
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 24) {
                if !imageUrls.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Images", systemImage: "photo.fill")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        ImageGridView(imageUrls: imageUrls)
                    }
                }
                
                if !videoUrls.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Videos", systemImage: "video.fill")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        VideoGridView(videoUrls: videoUrls)
                    }
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
}

// MARK: - References Section
private struct ReferencesSection: View {
    let references: [ReferenceText]
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Reference Texts", systemImage: "text.book.closed.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                ForEach(references) { reference in
                    ReferenceTextView(reference: reference)
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
}

// MARK: - Metadata Section
private struct MetadataSection: View {
    let draft: Draft
    
    var body: some View {
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
    }
}

// MARK: - AI Features Section
private struct AIFeaturesSection: View {
    let draft: Draft
    @Binding var isGeneratingVideo: Bool
    @Binding var showingVideoGeneration: Bool
    @Binding var showingScriptGeneration: Bool
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("AI Features", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                VStack(spacing: 12) {
                    NavigationLink {
                        ScriptGenerationView(
                            draftId: draft.id,
                            userId: draft.userId,
                            showCameraView: .constant(false),
                            selectedMainTab: .constant(0)
                        )
                    } label: {
                        HStack {
                            Image(systemName: "text.book.closed.fill")
                            Text("Generate Script")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                    }
                    
                    NavigationLink {
                        VideoGenerationView(draft: draft)
                    } label: {
                        HStack {
                            Image(systemName: "video.fill")
                            Text("Generate Video")
                            Spacer()
                            Image(systemName: "chevron.right")
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
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } header: {
            Text("AI Features")
                .textCase(.uppercase)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
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