import SwiftUI

// Import our models
import class pastport.AIScript
import class pastport.StoryScene
import struct pastport.Keyframe
import struct pastport.CachedAsyncImage

/// View for visualizing the script's scene structure
struct ScriptDiagramView: View {
    // MARK: - Properties
    
    let script: AIScript
    let onSelectScene: (Int) -> Void
    let onGenerateKeyframes: (Int) -> Void
    let onRegenerateKeyframes: (Int) -> Void
    let onDelete: () -> Void
    let onCreateVideo: () -> Void
    
    @Namespace private var animation
    @State private var selectedSceneIndex: Int?
    @State private var showKeyframeDetail = false
    @State private var showDeleteConfirmation = false
    
    private var canCreateVideo: Bool {
        script.scenes.allSatisfy { scene in
            scene.startKeyframe.status == .completed && scene.endKeyframe.status == .completed
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Progress indicator
                if script.status != .completed {
                    ProgressView(value: progressValue)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                        .padding(.horizontal)
                }
                
                Spacer(minLength: 16)
                
                // Create Video Button
                Button(action: onCreateVideo) {
                    Label("Create Video from Keyframes", systemImage: "film")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canCreateVideo ? Color.blue : Color.blue.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canCreateVideo)
                .padding(.horizontal)
                
                // Scene flow diagram
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 24) {
                        ForEach(Array(script.scenes.enumerated()), id: \.element.id) { index, scene in
                            SceneCard(
                                scene: scene,
                                index: index,
                                isSelected: selectedSceneIndex == index,
                                namespace: animation,
                                onSelect: {
                                    withAnimation(.spring()) {
                                        selectedSceneIndex = index
                                    }
                                    onSelectScene(index)
                                },
                                onGenerateKeyframes: { onGenerateKeyframes(index) },
                                onRegenerateKeyframes: { onRegenerateKeyframes(index) }
                            )
                        }
                    }
                    .padding()
                }
                
                // Selected scene details
                if let index = selectedSceneIndex {
                    SceneDetailView(
                        scene: script.scenes[index],
                        index: index,
                        namespace: animation,
                        onGenerateKeyframes: { onGenerateKeyframes(index) },
                        onRegenerateKeyframes: { onRegenerateKeyframes(index) }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle("Script Generation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    // Delete progress
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Progress", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Delete Progress", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete this script and start over? This action cannot be undone.")
        }
    }
    
    // MARK: - Private Methods
    
    private var progressValue: Double {
        switch script.status {
        case .draft:
            return 0.0
        case .generatingScript:
            return 0.3
        case .editingKeyframes:
            // Calculate progress based on completed keyframes
            let totalKeyframes = Double(script.scenes.count * 2) // 2 keyframes per scene
            let completedKeyframes = Double(script.scenes.reduce(0) { count, scene in
                count + (scene.startKeyframe.status == .completed ? 1 : 0) +
                       (scene.endKeyframe.status == .completed ? 1 : 0)
            })
            return 0.3 + (0.7 * (completedKeyframes / totalKeyframes))
        case .generatingVideo:
            return 0.9
        case .completed:
            return 1.0
        case .failed:
            return 0.0
        }
    }
}

// MARK: - Scene Card

private struct SceneCard: View {
    let scene: StoryScene
    let index: Int
    let isSelected: Bool
    let namespace: Namespace.ID
    let onSelect: () -> Void
    let onGenerateKeyframes: () -> Void
    let onRegenerateKeyframes: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Scene title
            Text("Scene \(index + 1)")
                .font(.headline)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .matchedGeometryEffect(id: "title\(scene.id)", in: namespace, isSource: !isSelected)
            
            // Scene content preview
            Text(scene.content)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(width: 200)
                .multilineTextAlignment(.center)
                .matchedGeometryEffect(id: "content\(scene.id)", in: namespace, isSource: !isSelected)
            
            // Keyframe previews
            HStack(spacing: 16) {
                KeyframePreview(
                    imageUrl: scene.startKeyframe.imageUrl,
                    status: scene.startKeyframe.status,
                    type: "Start",
                    onGenerate: onGenerateKeyframes,
                    onRegenerate: onRegenerateKeyframes
                )
                .matchedGeometryEffect(id: "start\(scene.id)", in: namespace, isSource: !isSelected)
                
                KeyframePreview(
                    imageUrl: scene.endKeyframe.imageUrl,
                    status: scene.endKeyframe.status,
                    type: "End",
                    onGenerate: onGenerateKeyframes,
                    onRegenerate: onRegenerateKeyframes
                )
                .matchedGeometryEffect(id: "end\(scene.id)", in: namespace, isSource: !isSelected)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
        )
        .onTapGesture(perform: onSelect)
    }
}

// MARK: - Keyframe Preview

private struct KeyframePreview: View {
    let imageUrl: String?
    let status: Keyframe.Status
    let type: String
    let onGenerate: () -> Void
    let onRegenerate: () -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            Text(type)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Group {
                if let urlString = imageUrl, let url = URL(string: urlString) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .overlay(alignment: .topTrailing) {
                        Button(action: onRegenerate) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .shadow(radius: 1)
                                .padding(4)
                        }
                    }
                } else {
                    Button(action: status == .notStarted ? onGenerate : onRegenerate) {
                        Group {
                            switch status {
                            case .notStarted:
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                            case .generating:
                                ProgressView()
                                    .controlSize(.regular)
                            case .completed:
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.green)
                            case .failed:
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .disabled(status == .generating)
                }
            }
            .frame(width: 60, height: 60)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Scene Detail View

private struct SceneDetailView: View {
    let scene: StoryScene
    let index: Int
    let namespace: Namespace.ID
    let onGenerateKeyframes: () -> Void
    let onRegenerateKeyframes: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Scene header
            Text("Scene \(index + 1)")
                .font(.title2.bold())
                .matchedGeometryEffect(id: "title\(scene.id)", in: namespace, isSource: true)
            
            // Scene content
            Text(scene.content)
                .font(.body)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)
                .matchedGeometryEffect(id: "content\(scene.id)", in: namespace, isSource: true)
            
            // Keyframes
            HStack(spacing: 24) {
                // Start keyframe
                VStack(spacing: 8) {
                    Text("Start Keyframe")
                        .font(.headline)
                    
                    KeyframeDetailView(
                        keyframe: scene.startKeyframe,
                        onGenerate: onGenerateKeyframes,
                        onRegenerate: onRegenerateKeyframes
                    )
                    .matchedGeometryEffect(id: "start\(scene.id)", in: namespace, isSource: true)
                }
                
                // End keyframe
                VStack(spacing: 8) {
                    Text("End Keyframe")
                        .font(.headline)
                    
                    KeyframeDetailView(
                        keyframe: scene.endKeyframe,
                        onGenerate: onGenerateKeyframes,
                        onRegenerate: onRegenerateKeyframes
                    )
                    .matchedGeometryEffect(id: "end\(scene.id)", in: namespace, isSource: true)
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

// MARK: - Keyframe Detail View

private struct KeyframeDetailView: View {
    let keyframe: Keyframe
    let onGenerate: () -> Void
    let onRegenerate: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Image preview
            if let urlString = keyframe.imageUrl,
               let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    Button(action: onRegenerate) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .shadow(radius: 1)
                            .padding(4)
                    }
                }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    switch keyframe.status {
                    case .notStarted:
                        Button(action: onGenerate) {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title)
                                Text("Generate")
                                    .font(.caption)
                            }
                            .foregroundStyle(.blue)
                        }
                    case .generating:
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("Generating...")
                                .font(.caption)
                        }
                    case .completed:
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(.green)
                            Text("Completed")
                                .font(.caption)
                        }
                    case .failed:
                        Button(action: onRegenerate) {
                            VStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.title)
                                    .foregroundStyle(.red)
                                Text("Retry")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            
            // Generation prompt
            if let prompt = keyframe.prompt {
                Text(prompt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            // Action buttons
            if keyframe.status == .completed {
                Button(action: onRegenerate) {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }
        }
    }
} 