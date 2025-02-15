import SwiftUI
import AVKit
import PhotosUI
import UIKit
import FirebaseFirestore
import FirebaseStorage

// Import models
@_implementationOnly import Firebase

struct VideoGenerationView: View {
    // MARK: - Properties
    let draft: Draft
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Generation State
    @State private var generationState: GenerationState = .preparing
    @State private var progress: Double = 0
    @State private var isProcessing = false
    
    // MARK: - Media State
    @State private var player: AVPlayer?
    @State private var generatedVideoURL: URL?
    
    // MARK: - Content State
    @State private var editedContent: String = ""
    @State private var selectedImageUrls: Set<String> = []
    @State private var selectedReferenceIds: Set<String> = []
    @State private var references: [ReferenceText] = []
    
    // MARK: - UI State
    @State private var isEditingContent = false
    @State private var showPostCreationSheet = false
    @State private var showError = false
    @State private var showSuccessAlert = false
    @State private var errorMessage: String?
    
    // MARK: - Services
    private let videoUploader = VideoUploader()
    private var lumaService: LumaAIService?
    
    // MARK: - Initialization
    init(draft: Draft) {
        self.draft = draft
        
        // Initialize content state
        _editedContent = State(initialValue: draft.content)
        _selectedImageUrls = State(initialValue: Set(draft.imageUrls))
        _selectedReferenceIds = State(initialValue: Set(draft.referenceTextIds))
        
        // Initialize Luma service
        do {
            self.lumaService = try LumaAIService()
        } catch {
            print("DEBUG: Failed to initialize Luma service: \(error)")
            _errorMessage = State(initialValue: error.localizedDescription)
            _generationState = State(initialValue: .failed)
        }
    }
    
    // MARK: - Types
    enum GenerationState {
        case preparing
        case generating
        case preview
        case saving
        case completed
        case failed
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Content Editor
                        ContentEditorSection(
                            editedContent: $editedContent,
                            isEditingContent: $isEditingContent
                        )
                        
                        // Reference Images
                        if !draft.imageUrls.isEmpty {
                            ReferenceImagesSection(
                                imageUrls: draft.imageUrls,
                                selectedImageUrls: selectedImageUrls,
                                onImageSelect: toggleImageSelection
                            )
                        }
                        
                        // Reference Texts
                        if !references.isEmpty {
                            ReferenceTextsSectionView(
                                references: references,
                                selectedReferenceIds: selectedReferenceIds,
                                onReferenceSelect: toggleReferenceSelection
                            )
                        }
                        
                        // Generation State
                        switch generationState {
                        case .preparing:
                            PrepareView(
                                onGenerate: startGeneration,
                                isGenerateEnabled: !editedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            )
                            
                        case .generating:
                            GeneratingView(progress: progress)
                            
                        case .preview:
                            if let player = player {
                                VideoPreviewView(
                                    player: player,
                                    onSave: { Task { await saveVideoOnly() } },
                                    onPost: { Task { await prepareForPosting() } },
                                    onRegenerate: startGeneration,
                                    onDiscard: { dismiss() },
                                    onDownload: downloadVideoToDevice,
                                    onDelete: deleteGeneratedVideo
                                )
                            }
                            
                        case .saving:
                            SavingView()
                            
                        case .completed:
                            CompletedView()
                            
                        case .failed:
                            FailedView(
                                error: errorMessage ?? "Unknown error occurred",
                                onRetry: startGeneration
                            )
                        }
                    }
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Generate AI Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
            }
            .alert("Message", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .sheet(isPresented: $showPostCreationSheet) {
                if let videoURL = generatedVideoURL {
                    NavigationStack {
                        VideoPostingView(
                            videoURL: videoURL,
                            showCameraView: .constant(false),
                            selectedTab: .constant(0)
                        )
                    }
                }
            }
        }
        .task {
            await fetchReferences()
        }
    }
    
    // MARK: - Methods
    private func toggleImageSelection(_ url: String) {
        if selectedImageUrls.contains(url) {
            selectedImageUrls.remove(url)
        } else {
            selectedImageUrls.insert(url)
        }
    }
    
    private func toggleReferenceSelection(_ id: String) {
        if selectedReferenceIds.contains(id) {
            selectedReferenceIds.remove(id)
        } else {
            selectedReferenceIds.insert(id)
        }
    }
    
    private func buildVideoPrompt() -> String {
        // Start with the main content and title
        var prompt = draft.title + ". " + editedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add reference image instructions explicitly
        if !selectedImageUrls.isEmpty {
            prompt += "\n\nReference Images Instructions:"
            prompt += "\n- Use the provided reference images as strict visual guides"
            prompt += "\n- Maintain exact character appearance and proportions throughout"
            prompt += "\n- Keep character features, clothing, and details perfectly consistent"
            prompt += "\n- Adapt historical elements while preserving character identity"
        }
        
        // Add selected reference text content with lower weight
        let selectedReferences = references.filter { selectedReferenceIds.contains($0.id) }
        if !selectedReferences.isEmpty {
            prompt += "\n\nHistorical context (consider as supplementary information):"
            for reference in selectedReferences {
                prompt += "\n- " + reference.title + ": " + reference.content
            }
        }
        
        // Add style hints optimized for Luma AI
        prompt += "\n\nStyle requirements:"
        prompt += "\n- Create clear, high-quality video with near-static scenes"
        prompt += "\n- Use perfectly stable, well-lit scenes with zero camera movement"
        prompt += "\n- Maintain exact visual consistency between frames"
        prompt += "\n- Focus on historical accuracy with clear, uncluttered details"
        prompt += "\n- Ensure strong subject focus with minimal to no background elements"
        prompt += "\n- Keep character appearance perfectly consistent throughout"
        
        // Add technical quality requirements
        prompt += "\n\nTechnical requirements:"
        prompt += "\n- High resolution with sharp, clear details"
        prompt += "\n- Absolute minimum motion, only essential micro-movements"
        prompt += "\n- Clean, balanced, centered composition"
        prompt += "\n- Perfectly stable framing with no camera effects"
        prompt += "\n- Maximum 1-2 elements/characters in each scene"
        prompt += "\n- No floating artifacts, partial elements, or background complexity"
        prompt += "\n- Maintain exact character proportions and features"
        prompt += "\n- Consistent lighting and perspective across all frames"
        
        print("DEBUG: Generated prompt for video: \(prompt)")
        print("DEBUG: Using \(selectedImageUrls.count) reference images for generation")
        selectedImageUrls.forEach { url in
            print("DEBUG: Reference image URL: \(url)")
        }
        return prompt
    }
    
    private func startGeneration() {
        print("DEBUG: Starting video generation for draft: \(draft.id)")
        withAnimation {
            generationState = .generating
            isProcessing = true
            progress = 0
        }
        
        // Start progress animation
        withAnimation(.linear(duration: 5 * 60)) { // Estimate 5 minutes
            progress = 0.9 // Go to 90% over 5 minutes
        }
        
        // Convert draft content to video prompt
        let prompt = buildVideoPrompt()
        
        // Only use selected image URLs as references
        let references = Array(selectedImageUrls).map { url in
            LumaAIService.ReferenceImage(url: url, prompt: nil, weight: 0.5)
        }
        
        Task {
            do {
                guard let lumaService = lumaService else {
                    throw NSError(domain: "VideoGeneration", code: -1, userInfo: [NSLocalizedDescriptionKey: "Luma AI service is not initialized"])
                }
                
                // Generate video
                let videoUrl = try await lumaService.generateVideo(
                    prompt: prompt,
                    keyframes: [:] // Empty keyframes dictionary since this is a simple video generation
                )
                
                // Download video to local temporary URL
                let tempUrl = try await downloadVideo(from: videoUrl)
                
                // Create player
                let player = AVPlayer(url: tempUrl)
                
                await MainActor.run {
                    withAnimation {
                        self.generatedVideoURL = tempUrl
                        self.player = player
                        self.generationState = .preview
                        self.isProcessing = false
                        self.progress = 1.0
                    }
                }
            } catch {
                print("DEBUG: Video generation failed: \(error)")
                await MainActor.run {
                    withAnimation {
                        self.errorMessage = error.localizedDescription
                        self.generationState = .failed
                        self.isProcessing = false
                        self.progress = 0
                    }
                }
            }
        }
    }
    
    private func downloadVideo(from url: URL) async throws -> URL {
        let (tempUrl, _) = try await URLSession.shared.download(from: url)
        
        // Move to a new temporary location that we control
        let newTempUrl = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        try FileManager.default.moveItem(at: tempUrl, to: newTempUrl)
        
        return newTempUrl
    }
    
    private func saveVideoOnly() async {
        withAnimation {
            generationState = .saving
            isProcessing = true
        }
        
        do {
            print("DEBUG: Starting video save process")
            
            guard let videoURL = generatedVideoURL else { return }
            
            // First compress the video
            let compressedURL = try await VideoCompressionService.shared.compressVideo(
                at: videoURL,
                maxWidth: 1080,
                targetSize: 8 * 1024 * 1024 // 8MB target size
            )
            
            print("DEBUG: Video compressed successfully")
            
            // Generate unique filename with user ID and timestamp
            let timestamp = Date().timeIntervalSince1970
            let filename = "\(draft.userId)_\(timestamp)_ai.mp4"
            
            // Create metadata
            let metadata = StorageMetadata()
            metadata.contentType = "video/mp4"
            metadata.customMetadata = [
                "userId": draft.userId,
                "draftId": draft.id,
                "title": draft.title,
                "timestamp": String(timestamp),
                "type": "ai_generated",
                "duration": "5",
                "resolution": "720p",
                "fps": "30",
                "referenceImagesCount": String(selectedImageUrls.count),
                "referenceImages": selectedImageUrls.joined(separator: ",")
            ]
            
            // Upload to storage only
            let storageRef = Storage.storage().reference().child("videos/\(filename)")
            _ = try await storageRef.putFileAsync(from: compressedURL, metadata: metadata)
            let downloadURL = try await storageRef.downloadURL()
            
            // Clean up temporary files
            try? FileManager.default.removeItem(at: compressedURL)
            
            await MainActor.run {
                withAnimation {
                    generationState = .completed
                    isProcessing = false
                    // Show success message without dismissing
                    errorMessage = "Video saved successfully!"
                    showError = true // Using error alert for success message to avoid dismissal
                }
            }
            
        } catch {
            print("DEBUG: Failed to save video: \(error)")
            await MainActor.run {
                withAnimation {
                    errorMessage = error.localizedDescription
                    generationState = .failed
                    isProcessing = false
                    showError = true
                }
            }
        }
    }
    
    private func prepareForPosting() async {
        // Show post creation sheet with video
        withAnimation {
            showPostCreationSheet = true
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
    
    private func downloadVideoToDevice() {
        guard let videoURL = generatedVideoURL else { return }
        
        Task {
            do {
                // Create a destination URL in the Documents directory
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let destinationURL = documentsPath.appendingPathComponent("AI_Video_\(Date().timeIntervalSince1970).mp4")
                
                // Copy the file
                try FileManager.default.copyItem(at: videoURL, to: destinationURL)
                
                // Save to photo library
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: destinationURL)
                } completionHandler: { success, error in
                    Task { @MainActor in
                        if success {
                            // Show success message without dismissing
                            errorMessage = "Video saved to Photos successfully!"
                            showError = true // Using error alert for success message to avoid dismissal
                        } else {
                            errorMessage = "Failed to save video: \(error?.localizedDescription ?? "Unknown error")"
                            showError = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save video: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func deleteGeneratedVideo() {
        guard let videoURL = generatedVideoURL else { return }
        
        // Delete local file
        try? FileManager.default.removeItem(at: videoURL)
        
        // Reset state
        withAnimation {
            player = nil
            generatedVideoURL = nil
            generationState = .preparing
            progress = 0
        }
    }
}

// MARK: - Content Section Views
private struct ContentEditorSection: View {
    @Binding var editedContent: String
    @Binding var isEditingContent: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Story Content", systemImage: "doc.text.fill")
                    .font(.headline)
                Spacer()
                Button {
                    isEditingContent.toggle()
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.subheadline)
                }
            }
            
            if isEditingContent {
                TextEditor(text: $editedContent)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
            } else {
                Text(editedContent)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
            }
        }
        .padding(.horizontal)
    }
}

private struct ReferenceImagesSection: View {
    let imageUrls: [String]
    let selectedImageUrls: Set<String>
    let onImageSelect: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Reference Images", systemImage: "photo.fill")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(imageUrls, id: \.self) { url in
                        Button {
                            onImageSelect(url)
                        } label: {
                            AsyncImage(url: URL(string: url)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 120, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedImageUrls.contains(url) ? Color.blue : Color.clear, lineWidth: 3)
                            )
                            .overlay(alignment: .topTrailing) {
                                if selectedImageUrls.contains(url) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.blue)
                                        .padding(8)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.horizontal)
    }
}

private struct ReferenceTextsSectionView: View {
    let references: [ReferenceText]
    let selectedReferenceIds: Set<String>
    let onReferenceSelect: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Reference Texts", systemImage: "text.book.closed.fill")
                .font(.headline)
            
            ForEach(references) { reference in
                Button {
                    onReferenceSelect(reference.id)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(reference.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Text(reference.content)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedReferenceIds.contains(reference.id) ? Color.blue : Color(.systemGray4), lineWidth: selectedReferenceIds.contains(reference.id) ? 2 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Supporting Views
private struct PrepareView: View {
    let onGenerate: () -> Void
    let isGenerateEnabled: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Ready to Generate")
                .font(.headline)
            
            Text("We'll create a 5-second video based on your story content and selected references.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onGenerate) {
                Label("Generate Video", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isGenerateEnabled ? Color.blue : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!isGenerateEnabled)
        }
        .padding()
    }
}

private struct GeneratingView: View {
    let progress: Double
    
    var body: some View {
        VStack(spacing: 24) {
            ProgressView(value: progress) {
                Text("Generating Video")
                    .font(.headline)
            }
            .progressViewStyle(.circular)
            .tint(.blue)
            
            Text("\(Int(progress * 100))%")
                .font(.title2.monospacedDigit())
                .foregroundStyle(.secondary)
            
            Text("This may take a few minutes...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

private struct VideoPreviewView: View {
    let player: AVPlayer
    let onSave: () -> Void
    let onPost: () -> Void
    let onRegenerate: () -> Void
    let onDiscard: () -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            VideoPlayer(player: player)
                .frame(height: 400)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(spacing: 16) {
                // Primary actions
                HStack(spacing: 16) {
                    Button(action: onPost) {
                        Label("Post Video", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                
                // Secondary actions
                HStack(spacing: 16) {
                    Menu {
                        Button(role: .destructive, action: onDelete) {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        Button(action: onDownload) {
                            Label("Save to Device", systemImage: "square.and.arrow.down")
                        }
                        
                        Button(action: onDiscard) {
                            Label("Discard", systemImage: "xmark")
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button(action: onRegenerate) {
                        Label("Regenerate", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button(action: onSave) {
                        Label("Save Only", systemImage: "square.and.arrow.down.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct SavingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            
            Text("Saving video...")
                .font(.headline)
        }
        .padding()
    }
}

private struct CompletedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            
            Text("Video Generated!")
                .font(.headline)
            
            Text("Your video has been saved and will appear in your profile.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

private struct FailedView: View {
    let error: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            
            Text("Generation Failed")
                .font(.headline)
            
            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onRetry) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }
}

#Preview {
    VideoGenerationView(draft: Draft(
        userId: "preview_user",
        title: "Sample Draft",
        content: "This is a sample draft content for preview purposes.",
        category: .historical,
        subcategory: .canonical
    ))
} 