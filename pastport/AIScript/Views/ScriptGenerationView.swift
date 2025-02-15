import SwiftUI

// Import our models
import struct pastport.ReferenceImage
import struct pastport.ReferenceText
import enum pastport.ReferenceImageType
import struct pastport.Draft

/// View for managing script generation
struct ScriptGenerationView: View {
    @State private var model: ScriptGenerationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var isInitialLoading = true
    @State private var editedContent: String = ""
    @State private var isEditingContent = false
    @State private var draft: Draft?
    @State private var references: [ReferenceText] = []
    @State private var showVideoGeneration = false
    @Binding var showCameraView: Bool
    @Binding var selectedMainTab: Int
    
    init(draftId: String, userId: String, showCameraView: Binding<Bool>, selectedMainTab: Binding<Int>) {
        _model = State(initialValue: try! ScriptGenerationViewModel(draftId: draftId, userId: userId))
        _showCameraView = showCameraView
        _selectedMainTab = selectedMainTab
    }
    
    var body: some View {
        VStack(spacing: 20) {
            tabView
            navigationButtons
        }
        .navigationTitle("Create Script")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .task {
            await loadInitialData()
        }
        .overlay {
            loadingOverlay
            noImagesOverlay
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
        .navigationDestination(isPresented: $showVideoGeneration) {
            if let script = model.script {
                SceneVideoGenerationView(
                    script: script,
                    showCameraView: $showCameraView,
                    selectedTab: $selectedMainTab
                )
            }
        }
    }
    
    // MARK: - Subviews
    
    private var tabView: some View {
        TabView(selection: $selectedTab) {
            storyReviewTab
                .tag(0)
            
            characterSelectionTab
                .tag(1)
            
            if let script = model.script, !script.scenes.isEmpty {
                scriptDiagramTab(script: script)
                    .tag(2)
            }
        }
        .tabViewStyle(.page)
    }
    
    private var storyReviewTab: some View {
        VStack(spacing: 16) {
            Text("Review Story & Select Characters")
                .font(.headline)
            
            if isInitialLoading {
                ProgressView("Loading...")
                    .tint(.blue)
            } else {
                storyReviewContent
            }
        }
    }
    
    private var storyReviewContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                storyContentSection
                referenceTextsSection
            }
        }
    }
    
    private var storyContentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Story Content", systemImage: "doc.text.fill")
                .font(.headline)
            
            if isEditingContent {
                editableContent
            } else {
                displayContent
            }
            
            editButton
        }
        .padding(.horizontal)
    }
    
    private var editableContent: some View {
        TextEditor(text: $editedContent)
            .frame(minHeight: 150)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2))
            )
    }
    
    private var displayContent: some View {
        Text(draft?.content ?? "")
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemBackground))
            )
    }
    
    private var editButton: some View {
        Button(isEditingContent ? "Save Changes" : "Edit Content") {
            if isEditingContent {
                Task {
                    await model.updateDraftContent(editedContent)
                    isEditingContent = false
                }
            } else {
                editedContent = draft?.content ?? ""
                isEditingContent = true
            }
        }
        .font(.subheadline)
        .padding(.top, 4)
    }
    
    private var referenceTextsSection: some View {
        Group {
            if !references.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Reference Texts", systemImage: "text.book.closed.fill")
                        .font(.headline)
                    
                    ForEach(references) { reference in
                        referenceCard(reference)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func referenceCard(_ reference: ReferenceText) -> some View {
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
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
        )
    }
    
    private var characterSelectionTab: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Select Images")
                        .font(.title3.bold())
                    
                    Text("Choose character and reference images for your story")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                if let draft = draft {
                    draftContentPreview(draft)
                }
                
                // Character Selection Section
                VStack(alignment: .leading, spacing: 16) {
                    if !model.characterImages.isEmpty {
                        Text("Character Images")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 160), spacing: 16)
                            ],
                            spacing: 16
                        ) {
                            ForEach(model.characterImages) { character in
                                ReferenceGridItem(
                                    image: character,
                                    isSelected: model.selectedCharacterImages.contains { $0.id == character.id }
                                )
                                .onTapGesture {
                                    model.toggleCharacterSelection(character)
                                }
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        ContentUnavailableView(
                            "No Characters Available",
                            systemImage: "person.fill.questionmark",
                            description: Text("Create some characters first to use them in your story")
                        )
                    }
                }
                
                // Reference Images Section
                VStack(alignment: .leading, spacing: 16) {
                    if !model.availableReferenceImages.isEmpty {
                        Text("Reference Images")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 160), spacing: 16)
                            ],
                            spacing: 16
                        ) {
                            ForEach(model.availableReferenceImages) { reference in
                                ReferenceGridItem(
                                    image: reference,
                                    isSelected: model.selectedReferenceImages.contains { $0.id == reference.id }
                                )
                                .onTapGesture {
                                    model.toggleReferenceSelection(reference)
                                }
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        ContentUnavailableView(
                            "No Reference Images",
                            systemImage: "photo.on.rectangle.angled",
                            description: Text("Add some reference images to enhance your story visualization")
                        )
                    }
                }
            }
            .padding(.bottom, 32)
        }
    }
    
    private func draftContentPreview(_ draft: Draft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Story Content", systemImage: "doc.text.fill")
                .font(.headline)
            
            Text(draft.content)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemBackground))
                )
        }
        .padding(.horizontal)
    }
    
    private func scriptDiagramTab(script: AIScript) -> some View {
        ScriptDiagramView(
            script: script,
            onSelectScene: { index in
                print("DEBUG: Selected scene at index \(index)")
            },
            onGenerateKeyframes: { index in
                Task {
                    await model.generateKeyframes(forSceneIndex: index)
                }
            },
            onRegenerateKeyframes: { index in
                Task {
                    await model.regenerateKeyframes(forSceneIndex: index)
                }
            },
            onDelete: {
                Task {
                    await model.deleteScript()
                    dismiss()
                }
            },
            onCreateVideo: {
                Task {
                    await model.prepareForVideoGeneration()
                    showVideoGeneration = true
                }
            }
        )
    }
    
    private var navigationButtons: some View {
        HStack {
            if selectedTab > 0 {
                Button("Back") {
                    withAnimation {
                        selectedTab -= 1
                    }
                }
            }
            
            Spacer()
            
            if selectedTab < 2 {
                Button(selectedTab == 1 ? "Generate Script" : "Next") {
                    if selectedTab == 1 {
                        Task {
                            await model.generateScenes()
                            withAnimation {
                                selectedTab += 1
                            }
                        }
                    } else {
                        withAnimation {
                            selectedTab += 1
                        }
                    }
                }
                .disabled(selectedTab == 0 && model.selectedCharacterImages.isEmpty)
            }
        }
        .padding(.horizontal)
    }
    
    private var loadingOverlay: some View {
        Group {
            if model.isLoading {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .frame(width: 200, height: 150)
                        .overlay {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                    .tint(.blue)
                                
                                Text("Generating Script...")
                                    .font(.headline)
                                
                                Text("This may take a few moments")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                        }
                }
                .transition(.opacity)
            }
        }
    }
    
    private var noImagesOverlay: some View {
        Group {
            if !isInitialLoading && model.availableCharacterImages.isEmpty && model.availableReferenceImages.isEmpty {
                ContentUnavailableView(
                    "No Images Available",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Create some characters or add reference images first.")
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadInitialData() async {
        isInitialLoading = true
        await model.loadReferenceImages()
        await model.loadDraft()
        await model.loadReferenceTexts()
        self.draft = model.draft
        self.references = model.referenceTexts
        await model.startGeneration()
        isInitialLoading = false
    }
}

// MARK: - Grid Items

private struct ReferenceGridItem: View {
    let image: ReferenceImage
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Reference image
            AsyncImage(url: URL(string: image.url)) { phase in
                switch phase {
                case .empty:
                    Color.gray
                        .overlay {
                            ProgressView()
                                .tint(.white)
                        }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure(_):
                    Color.gray
                        .overlay {
                            Image(systemName: image.type == .character ? "person.fill" : "photo")
                                .foregroundStyle(.white)
                        }
                @unknown default:
                    Color.gray
                }
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isSelected ? Color.accentColor : (image.type == .character ? Color.purple.opacity(0.5) : .clear),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            
            // Reference prompt
            if let prompt = image.prompt {
                Text(prompt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            
            // Type indicator
            HStack {
                Image(systemName: image.type == .character ? "person.fill" : "photo")
                Text(image.type == .character ? "Character" : "Reference")
            }
            .font(.caption2)
            .foregroundStyle(image.type == .character ? .purple : .blue)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(image.type == .character ? Color.purple.opacity(0.1) : Color.blue.opacity(0.1))
            )
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}