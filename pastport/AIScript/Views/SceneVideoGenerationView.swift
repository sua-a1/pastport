import SwiftUI
import AVKit
import Foundation

// Import our models
import class pastport.AIScript
import class pastport.StoryScene
import class pastport.VideoPlayerManager
import class pastport.SceneVideoGenerationViewModel
import class pastport.StorageService
import class pastport.VideoCompressionService

/// View for managing scene-by-scene video generation
struct SceneVideoGenerationView: View {
    // MARK: - Properties
    
    let script: AIScript
    @Binding var showCameraView: Bool
    @Binding var selectedTab: Int
    
    @State private var selectedSceneIndex: Int?
    @State private var showVideoPreview = false
    @State private var previewVideoURL: URL?
    @State private var generatingSceneIndex: Int?
    @State private var showSuccessMessage = false
    @State private var successMessage: String?
    @State private var initializationError: String?
    @Environment(\.dismiss) private var dismiss
    
    private let playerManager = VideoPlayerManager.shared
    
    // Add new state properties after other @State properties
    @State private var isGeneratingCompleteVideo = false
    @State private var showCompleteVideoPreview = false
    @State private var completeVideoURL: URL?
    
    // Use @State with lazy initialization for the view model
    @State private var model: SceneVideoGenerationViewModel?
    private let compressionService = VideoCompressionService.shared
    
    // MARK: - Initialization
    
    init(script: AIScript, showCameraView: Binding<Bool>, selectedTab: Binding<Int>) {
        self.script = script
        self._showCameraView = showCameraView
        self._selectedTab = selectedTab
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if let error = initializationError {
                errorView(error)
            } else if let model = model {
                mainView(model)
            } else {
                loadingView
                    .task {
                        await initializeViewModel()
                    }
            }
        }
        .navigationTitle("Generate Videos")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func initializeViewModel() async {
        do {
            print("DEBUG: Initializing view model once")
            let viewModel = try SceneVideoGenerationViewModel(script: script)
            await MainActor.run {
                self.model = viewModel
            }
        } catch {
            print("ERROR: Failed to initialize view model: \(error)")
            await MainActor.run {
                self.initializationError = error.localizedDescription
            }
        }
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView("Initializing...")
                .tint(.blue)
        }
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Text("Failed to initialize video generation")
                .font(.headline)
                .foregroundColor(.red)
            Text(error)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Dismiss") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    private func mainView(_ model: SceneVideoGenerationViewModel) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                mainContent
            }
            .padding(.bottom, 100)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showVideoPreview) {
            if let url = previewVideoURL {
                VideoPreviewSheet(videoURL: url)
            }
        }
        .alert("Error", isPresented: .constant(model.errorMessage != nil)) {
            Button("OK") {
                model.clearError()
            }
        } message: {
            if let error = model.errorMessage {
                Text(error)
            }
        }
        .overlay(alignment: .bottom) {
            if showSuccessMessage, let message = successMessage {
                Text(message)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            withAnimation(.easeOut(duration: 0.5)) {
                                showSuccessMessage = false
                                successMessage = nil
                            }
                        }
                    }
            }
        }
    }
    
    // MARK: - Private Views
    
    private var mainContent: some View {
        VStack(spacing: 24) {
            if let model = model {
                progressView
                sceneFlowDiagram
                selectedSceneDetail
                completeVideoButton
            }
        }
    }
    
    private var progressView: some View {
        VStack(spacing: 8) {
            if let model = model {
                ProgressView(value: model.progress)
                    .progressViewStyle(.linear)
                    .tint(.blue)
                
                if let generatingIndex = generatingSceneIndex {
                    Text("Generating video for Scene \(generatingIndex + 1)...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var sceneFlowDiagram: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            if let model = model {
                HStack(spacing: 24) {
                    ForEach(Array(script.scenes.enumerated()), id: \.element.id) { index, scene in
                        let videoURL = model.sceneVideos[index]?.videoUrl
                        
                        SceneVideoCard(
                            scene: scene,
                            index: index,
                            isSelected: selectedSceneIndex == index,
                            isGenerating: generatingSceneIndex == index,
                            videoURL: videoURL,
                            onSelect: {
                                withAnimation(.spring()) {
                                    selectedSceneIndex = index
                                }
                            },
                            onGenerate: {
                                Task {
                                    do {
                                        print("DEBUG: Starting video generation for Scene \(index + 1)")
                                        generatingSceneIndex = index
                                        try await model.generateVideoForScene(scene)
                                        print("DEBUG: Video generation completed for scene \(index)")
                                        print("DEBUG: Scene videos after generation: \(model.sceneVideos)")
                                        
                                        await MainActor.run {
                                            withAnimation {
                                                successMessage = "Video successfully generated for Scene \(index + 1)"
                                                showSuccessMessage = true
                                            }
                                            generatingSceneIndex = nil
                                        }
                                    } catch {
                                        print("DEBUG: Video generation failed: \(error.localizedDescription)")
                                        await MainActor.run {
                                            generatingSceneIndex = nil
                                        }
                                    }
                                }
                            },
                            onPreview: { url in
                                print("DEBUG: Opening video preview for URL: \(url)")
                                previewVideoURL = url
                                showVideoPreview = true
                            }
                        )
                        .id("\(scene.id)_\(videoURL ?? "none")")
                    }
                }
                .padding()
            }
        }
    }
    
    private var selectedSceneDetail: some View {
        Group {
            if let model = model, let index = selectedSceneIndex {
                SceneVideoDetailView(
                    scene: script.scenes[index],
                    index: index,
                    isGenerating: generatingSceneIndex == index,
                    videoURL: model.sceneVideos[index]?.videoUrl,
                    onGenerate: {
                        Task {
                            do {
                                generatingSceneIndex = index
                                try await model.generateVideoForScene(script.scenes[index])
                                
                                withAnimation {
                                    successMessage = "Video successfully generated for Scene \(index + 1)"
                                    showSuccessMessage = true
                                }
                            } catch {
                                print("DEBUG: Video generation failed: \(error.localizedDescription)")
                            }
                            generatingSceneIndex = nil
                        }
                    },
                    onPreview: { url in
                        previewVideoURL = url
                        showVideoPreview = true
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    private var completeVideoButton: some View {
        Group {
            if let model = model {
                Button {
                    Task {
                        do {
                            print("DEBUG: Starting complete video generation")
                            isGeneratingCompleteVideo = true
                            
                            let finalVideoUrl = try await model.generateCompleteVideo()
                            
                            await MainActor.run {
                                print("DEBUG: Complete video generation finished, showing posting view")
                                completeVideoURL = finalVideoUrl
                                showCompleteVideoPreview = true
                                isGeneratingCompleteVideo = false
                            }
                        } catch {
                            print("ERROR: Complete video generation failed: \(error.localizedDescription)")
                            await MainActor.run {
                                isGeneratingCompleteVideo = false
                            }
                        }
                    }
                } label: {
                    HStack {
                        if isGeneratingCompleteVideo {
                            ProgressView()
                                .controlSize(.small)
                            Text("Generating Complete Video...")
                        } else {
                            Image(systemName: "film.stack")
                                .font(.title2)
                            Text(model.areAllScenesComplete() ? "Generate Complete Video" : "Generate Complete Video (Some Scenes Not Ready)")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(model.areAllScenesComplete() ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isGeneratingCompleteVideo)
                .padding(.horizontal)
                .sheet(isPresented: $showCompleteVideoPreview) {
                    if let url = completeVideoURL {
                        StitchedVideoPostingView(
                            videoURL: url,
                            script: script,
                            showCameraView: self.$showCameraView,
                            selectedTab: self.$selectedTab
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Generated Video Thumbnail

private struct GeneratedVideoThumbnail: View {
    let video: AIScript.SceneVideo
    let index: Int
    @State private var showVideoPlayer = false
    
    var body: some View {
        Button {
            showVideoPlayer = true
        } label: {
            DraftVideoThumbnailView(url: video.videoUrl)
                .frame(width: 160, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topLeading) {
                    Text("Scene \(index + 1)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.black.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(8)
                }
        }
        .sheet(isPresented: $showVideoPlayer) {
            if let url = URL(string: video.videoUrl) {
                DraftVideoPlayerView(url: url)
            }
        }
    }
}

// MARK: - Video Components

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

// MARK: - Scene Video Card

private struct SceneVideoCard: View {
    let scene: StoryScene
    let index: Int
    let isSelected: Bool
    let isGenerating: Bool
    let videoURL: String?
    let onSelect: () -> Void
    let onGenerate: () -> Void
    let onPreview: (URL) -> Void
    
    var body: some View {
        ZStack(alignment: .top) {
            // Main card content
            VStack(spacing: 12) {
                // Scene header
                Text("Scene \(index + 1)")
                    .font(.headline)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                
                // Scene content
                Text(scene.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Keyframe previews
                HStack(spacing: 16) {
                    AsyncImage(url: URL(string: scene.startKeyframe.imageUrl ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    AsyncImage(url: URL(string: scene.endKeyframe.imageUrl ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Action button
                if let urlString = videoURL, let url = URL(string: urlString) {
                    Button {
                        print("DEBUG: Preview button tapped for URL: \(url)")
                        onPreview(url)
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("Watch Video")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                    
                    // Completion indicator
                    Label("Video Generated", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                } else {
                    Button(action: onGenerate) {
                        HStack {
                            if isGenerating {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Generating...")
                            } else {
                                Image(systemName: "film")
                                Text("Generate Video")
                            }
                        }
                        .font(.headline)
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isGenerating)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
            .frame(width: 280)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            
            // Notification label above the card
            if videoURL != nil {
                Text("✨ Video Ready!")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.green)
                            .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                    )
                    .offset(y: -20)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onTapGesture(perform: onSelect)
    }
}

// MARK: - Scene Video Detail View

private struct SceneVideoDetailView: View {
    let scene: StoryScene
    let index: Int
    let isGenerating: Bool
    let videoURL: String?
    let onGenerate: () -> Void
    let onPreview: (URL) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Scene header
            Text("Scene \(index + 1)")
                .font(.title2.bold())
            
            // Scene content
            Text(scene.content)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Generation and preview buttons
            VStack(spacing: 12) {
                // Generate button
                Button(action: onGenerate) {
                    VStack {
                        if isGenerating {
                            ProgressView()
                                .controlSize(.large)
                            Text("Generating Video...")
                        } else {
                            Image(systemName: "film")
                                .font(.system(size: 48))
                            Text("Generate Video")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isGenerating)
                
                // Preview button (if video exists)
                if let urlString = videoURL, let url = URL(string: urlString) {
                    Button {
                        onPreview(url)
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.title)
                            Text("Preview Video")
                                .font(.title3)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            
            // Keyframes
            HStack(spacing: 24) {
                // Start keyframe
                VStack(spacing: 8) {
                    Text("Start Keyframe")
                        .font(.headline)
                    
                    AsyncImage(url: URL(string: scene.startKeyframe.imageUrl ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // End keyframe
                VStack(spacing: 8) {
                    Text("End Keyframe")
                        .font(.headline)
                    
                    AsyncImage(url: URL(string: scene.endKeyframe.imageUrl ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.1))
        )
    }
}

// MARK: - Video Preview Sheet

private struct VideoPreviewSheet: View {
    let videoURL: URL
    @Environment(\.dismiss) private var dismiss
    private let playerManager = VideoPlayerManager.shared
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)
                    
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else if let player = playerManager.currentPlayer {
                        AVKit.VideoPlayer(player: player)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .edgesIgnoringSafeArea(.all)
                    }
                }
            }
            .navigationTitle("Video Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        print("DEBUG: Dismissing video preview")
                        playerManager.pause() // Only pause, don't cleanup
                        dismiss()
                    }
                }
            }
        }
        .task {
            print("DEBUG: Setting up video player in preview sheet with URL: \(videoURL)")
            isLoading = true
            await playerManager.setupPlayer(with: videoURL, postId: videoURL.lastPathComponent)
            playerManager.play()
            isLoading = false
            print("DEBUG: Video player setup completed in preview sheet")
        }
        .onDisappear {
            print("DEBUG: Preview sheet disappeared")
            playerManager.pause() // Only pause, don't cleanup when disappearing
        }
    }
} 