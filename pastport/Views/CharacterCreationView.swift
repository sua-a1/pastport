import SwiftUI
import PhotosUI
import UIKit
@_spi(Experimental) import Firebase

struct CharacterCreationView: View {
    @Bindable var viewModel: CharacterCreationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showingImagePicker = false
    @State private var showingGenerationResults = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 8) {
                        Text("Create Your Character")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        
                        Text("Fill in the details below to generate your character using AI")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 16)
                    
                    // Basic Info Section
                    VStack(alignment: .leading, spacing: 20) {
                        SectionHeader(title: "Basic Information", systemImage: "person.fill")
                        
                        VStack(alignment: .leading, spacing: 16) {
                            InputField(
                                title: "Character Name",
                                placeholder: "Enter character name",
                                text: $viewModel.name
                            )
                            
                            InputField(
                                title: "Description/Backstory",
                                placeholder: "Write a brief description or backstory for your character",
                                text: $viewModel.characterDescription,
                                isMultiline: true
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Style Prompt Section
                    VStack(alignment: .leading, spacing: 20) {
                        SectionHeader(title: "Style Description", systemImage: "paintbrush.fill")
                        
                        VStack(alignment: .leading, spacing: 16) {
                            InputField(
                                title: "Visual Style",
                                placeholder: "Describe the character's visual style, appearance, clothing, etc.",
                                text: $viewModel.stylePrompt,
                                isMultiline: true,
                                helpText: "Include details about appearance, clothing, lighting, mood, and artistic style"
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Reference Images Section
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            SectionHeader(title: "Reference Images", systemImage: "photo.stack.fill")
                            Spacer()
                            if !viewModel.referenceImages.isEmpty {
                                Text("\(viewModel.referenceImages.count)/4")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if viewModel.referenceImages.isEmpty {
                            // Empty State
                            Button {
                                showingImagePicker = true
                            } label: {
                                VStack(spacing: 16) {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 40))
                                        .foregroundStyle(.blue)
                                    
                                    VStack(spacing: 4) {
                                        Text("Add Reference Images")
                                            .font(.headline)
                                        
                                        Text("Add up to 4 images to guide the AI")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(.systemBackground))
                                        .shadow(color: .black.opacity(0.05), radius: 4)
                                )
                            }
                            .buttonStyle(.plain)
                            
                        } else {
                            // Image Grid
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16)
                            ], spacing: 16) {
                                ForEach(Array(viewModel.referenceImages.enumerated()), id: \.element.id) { index, imageState in
                                    ReferenceImageCell(
                                        imageState: imageState,
                                        onPromptChange: { newPrompt in
                                            viewModel.referenceImages[index].prompt = newPrompt
                                        },
                                        onWeightChange: { newWeight in
                                            viewModel.referenceImages[index].weight = newWeight
                                        },
                                        onDelete: {
                                            viewModel.removeReferenceImage(at: index)
                                        }
                                    )
                                }
                                
                                if viewModel.referenceImages.count < 4 {
                                    Button {
                                        showingImagePicker = true
                                    } label: {
                                        VStack(spacing: 8) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 32))
                                                .foregroundStyle(.blue)
                                            Text("Add Image")
                                                .font(.subheadline)
                                                .foregroundStyle(.blue)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 200)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color(.systemGray6))
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            do {
                                try await viewModel.generateCharacter()
                                showingGenerationResults = true
                            } catch {
                                errorMessage = error.localizedDescription
                                showingError = true
                            }
                        }
                    } label: {
                        Text("Generate")
                            .fontWeight(.semibold)
                    }
                    .disabled(!viewModel.isValid)
                }
            }
            .photosPicker(
                isPresented: $showingImagePicker,
                selection: $selectedPhotos,
                maxSelectionCount: 4 - viewModel.referenceImages.count,
                matching: .images
            )
            .onChange(of: selectedPhotos) { _, newValue in
                Task {
                    for item in newValue {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            await MainActor.run {
                                viewModel.addReferenceImage(image)
                            }
                        }
                    }
                    selectedPhotos = []
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if case .generating = viewModel.state {
                    LoadingOverlay(
                        title: "Generating your character...",
                        subtitle: "This may take a few moments"
                    )
                }
            }
            .fullScreenCover(isPresented: $showingGenerationResults) {
                if case .completed(let urls) = viewModel.state {
                    GenerationResultsView(
                        urls: urls,
                        viewModel: viewModel,
                        onDismiss: {
                            dismiss()
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Supporting Views
private struct SectionHeader: View {
    let title: String
    let systemImage: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.headline)
            Text(title)
                .font(.headline)
        }
        .foregroundStyle(.primary)
    }
}

private struct InputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isMultiline: Bool = false
    var helpText: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if isMultiline {
                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
            }
            
            if let helpText = helpText {
                Text(helpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct LoadingOverlay: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6).opacity(0.9))
            )
        }
    }
}

private struct ReferenceImageCell: View {
    let imageState: CharacterCreationViewModel.ReferenceImageState
    let onPromptChange: (String?) -> Void
    let onWeightChange: (Double) -> Void
    let onDelete: () -> Void
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Image
            if let image = imageState.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        Group {
                            if imageState.isUploading {
                                ZStack {
                                    Color.black.opacity(0.5)
                                    ProgressView()
                                        .tint(.white)
                                }
                            }
                        }
                    )
                    .overlay(alignment: .topTrailing) {
                        Button(action: onDelete) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .padding(8)
                        }
                    }
            }
            
            // Expand/Collapse Button
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(isExpanded ? "Hide Details" : "Show Details")
                        .font(.caption)
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .foregroundStyle(.secondary)
            }
            
            if isExpanded {
                VStack(spacing: 12) {
                    // Prompt
                    TextField("Describe this reference", text: .init(
                        get: { imageState.prompt ?? "" },
                        set: { onPromptChange($0.isEmpty ? nil : $0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    
                    // Weight Slider
                    VStack(spacing: 4) {
                        HStack {
                            Text("Weight")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.1f", imageState.weight))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Slider(value: .init(
                            get: { imageState.weight },
                            set: onWeightChange
                        ), in: 0...1, step: 0.1)
                    }
                }
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - Generation Results Components
private struct GeneratedImageGrid: View {
    let urls: [String]
    let selectedImages: Set<String>
    let onImageTap: (String) -> Void
    
    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ],
            spacing: 16
        ) {
            ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                Button {
                    onImageTap(url)
                } label: {
                    AsyncImage(url: URL(string: url)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedImages.contains(url) ? Color.blue : Color.clear, lineWidth: 3)
                    )
                    .overlay(alignment: .topTrailing) {
                        if selectedImages.contains(url) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                                .padding(8)
                        }
                    }
                }
                .id(index)
            }
        }
        .padding(.horizontal)
    }
}

private struct ActionButtons: View {
    let selectedImages: Set<String>
    let isRegenerating: Bool
    let viewModel: CharacterCreationViewModel
    let onRefine: () -> Void
    let onRegenerate: () -> Void
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Binding var errorMessage: String
    @Binding var showingCharacterRefinement: Bool
    @State private var isSaving = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Save button
            Button {
                withAnimation {
                    isSaving = true
                }
                Task {
                    do {
                        try await viewModel.saveNewCharacter(selectedImages: Array(selectedImages))
                        withAnimation {
                            isSaving = false
                        }
                        // Don't dismiss the entire flow
                        showingCharacterRefinement = false
                    } catch {
                        print("DEBUG: Failed to save character: \(error)")
                        errorMessage = error.localizedDescription
                        withAnimation {
                            isSaving = false
                        }
                    }
                }
            } label: {
                HStack {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Save Selected Images")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedImages.isEmpty || viewModel.state == .saving || isSaving)
            .opacity((selectedImages.isEmpty || isSaving) ? 0.5 : 1.0)
            
            // Refine Button
            Button(action: onRefine) {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text("Refine Character")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.purple)
                )
                .foregroundColor(.white)
            }
            .disabled(selectedImages.isEmpty || isSaving)
            .opacity((selectedImages.isEmpty || isSaving) ? 0.5 : 1.0)
            
            // Regenerate Button
            Button(action: onRegenerate) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Generate New Variations")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray4))
                )
                .foregroundColor(.primary)
            }
            .disabled(isSaving)
            .opacity(isSaving ? 0.5 : 1.0)
        }
        .padding(.horizontal)
        .disabled(isRegenerating)
    }
}

private struct GenerationResultsView: View {
    let urls: [String]
    let viewModel: CharacterCreationViewModel
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedImages: Set<String> = []
    @State private var isRegenerating = false
    @State private var regeneratedUrls: [String] = []
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingCharacterRefinement = false
    
    var displayUrls: [String] {
        regeneratedUrls.isEmpty ? urls : regeneratedUrls
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.pastportBackground
                    .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Your character has been generated!")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .padding(.top)
                            
                            Text("Select up to 2 images to save or refine your character")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Image Grid
                        GeneratedImageGrid(
                            urls: displayUrls,
                            selectedImages: selectedImages,
                            onImageTap: toggleImageSelection
                        )
                        
                        if isRegenerating {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text("Generating new variations...")
                                    .font(.headline)
                                Text("This may take a few moments")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        }
                        
                        // Action Buttons
                        ActionButtons(
                            selectedImages: selectedImages,
                            isRegenerating: isRegenerating,
                            viewModel: viewModel,
                            onRefine: {
                                if !selectedImages.isEmpty && selectedImages.count <= 2 {
                                    showingCharacterRefinement = true
                                }
                            },
                            onRegenerate: regenerate,
                            onDismiss: onDismiss,
                            errorMessage: $errorMessage,
                            showingCharacterRefinement: $showingCharacterRefinement
                        )
                    }
                    .padding(.bottom, 32)
                }
                .blur(radius: isRegenerating ? 3 : 0)
                
                if isRegenerating {
                    LoadingOverlay(
                        title: "Generating variations...",
                        subtitle: "This may take a few moments"
                    )
                }
            }
            .navigationTitle("Results")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: 
                Button("Done") {
                    // Only dismiss when explicitly done
                    dismiss()
                    onDismiss()
                }
                .disabled(isRegenerating)
            )
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        .sheet(isPresented: $showingCharacterRefinement) {
            if !selectedImages.isEmpty {
                CharacterRefinementView(
                    selectedImages: Array(selectedImages),
                    viewModel: viewModel,
                    character: viewModel.character,
                    onDismiss: {
                        showingCharacterRefinement = false
                        onDismiss()
                    }
                )
            }
        }
        .overlay {
            if case .saving = viewModel.state {
                LoadingOverlay(
                    title: "Saving character...",
                    subtitle: "Please wait while we save your character"
                )
            }
        }
    }
    
    private func toggleImageSelection(_ url: String) {
        if selectedImages.contains(url) {
            selectedImages.remove(url)
        } else if selectedImages.count < 2 {
            selectedImages.insert(url)
        }
    }
    
    private func regenerate() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isRegenerating = true
            selectedImages.removeAll()
        }
        
        Task {
            do {
                let urls: [String]
                if !selectedImages.isEmpty {
                    urls = try await viewModel.generateCharacterWithReference(
                        selectedImages: Array(selectedImages),
                        prompt: "Generate new variations of the same character"
                    )
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            regeneratedUrls = urls
                            isRegenerating = false
                        }
                    }
                } else {
                    try await viewModel.generateCharacter()
                    if case .completed(let newUrls) = viewModel.state {
                        await MainActor.run {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                regeneratedUrls = newUrls
                                isRegenerating = false
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        errorMessage = error.localizedDescription
                        showingError = true
                        isRegenerating = false
                    }
                }
            }
        }
    }
}

private struct CharacterRefinementView: View {
    let selectedImages: [String]
    let viewModel: CharacterCreationViewModel
    let character: Character?
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var prompt = ""
    @State private var isGenerating = false
    @State private var selectedRefinedImages: Set<String> = []
    @State private var generatedUrls: [String] = []
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.pastportBackground
                    .ignoresSafeArea()
                
                ScrollView(.vertical) {
                    VStack(spacing: 24) {
                        // Explanation Section
                        VStack(spacing: 8) {
                            Text("Refine Your Character")
                                .font(.title2.bold())
                                .multilineTextAlignment(.center)
                            
                            Text("Use your selected images to create more personalized variations with different poses and expressions.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top)
                        
                        // Selected Images
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ],
                            spacing: 16
                        ) {
                            ForEach(selectedImages, id: \.self) { url in
                                AsyncImage(url: URL(string: url)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    ProgressView()
                                }
                                .frame(height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal)
                        
                        // Prompt Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Describe the variations you want")
                                .font(.headline)
                            
                            TextField("E.g., different poses, expressions, or angles", text: $prompt, axis: .vertical)
                                .lineLimit(3...6)
                                .padding()
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                            
                            Text("The AI will maintain your character's appearance while applying these variations")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        
                        if !generatedUrls.isEmpty {
                            // Generated Results
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Generated Variations")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible()),
                                        GridItem(.flexible())
                                    ],
                                    spacing: 16
                                ) {
                                    ForEach(generatedUrls, id: \.self) { url in
                                        Button {
                                            toggleRefinedImageSelection(url)
                                        } label: {
                                            AsyncImage(url: URL(string: url)) { image in
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                            } placeholder: {
                                                ProgressView()
                                            }
                                            .frame(height: 200)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(selectedRefinedImages.contains(url) ? Color.blue : Color.clear, lineWidth: 3)
                                            )
                                            .overlay(alignment: .topTrailing) {
                                                if selectedRefinedImages.contains(url) {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.title2)
                                                        .foregroundStyle(.blue)
                                                        .padding(8)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // Save button for refined images
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isSaving = true
                                }
                                
                                Task {
                                    do {
                                        if let character = character {
                                            print("DEBUG: Saving refined images to existing character: \(character.id)")
                                            try await viewModel.saveRefinedCharacter(
                                                characterId: character.id,
                                                selectedImages: Array(selectedRefinedImages)
                                            )
                                        } else {
                                            print("DEBUG: No existing character found, saving as new character")
                                            try await viewModel.saveNewCharacter(
                                                selectedImages: Array(selectedRefinedImages)
                                            )
                                        }
                                        
                                        await MainActor.run {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                isSaving = false
                                            }
                                            dismiss()
                                            onDismiss()
                                        }
                                    } catch {
                                        print("DEBUG: Failed to save refined images: \(error)")
                                        await MainActor.run {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                errorMessage = error.localizedDescription
                                                showingError = true
                                                isSaving = false
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    if isSaving {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text(character != nil ? "Add to Character" : "Save as New Character")
                                            .font(.headline)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(selectedRefinedImages.isEmpty || isSaving)
                            .opacity((selectedRefinedImages.isEmpty || isSaving) ? 0.5 : 1.0)
                            .padding(.horizontal)
                        }
                        
                        // Generate Button
                        if generatedUrls.isEmpty {
                            Button {
                                generateRefinedCharacter()
                            } label: {
                                HStack {
                                    if isGenerating {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text("Generate Variations")
                                            .font(.headline)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue)
                            )
                            .foregroundColor(.white)
                            .disabled(prompt.isEmpty || isGenerating)
                            .opacity((prompt.isEmpty || isGenerating) ? 0.5 : 1.0)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 32)
                }
                .blur(radius: (isGenerating || isSaving) ? 3 : 0)
                .disabled(isGenerating || isSaving)
                
                if isGenerating || isSaving {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .transition(.opacity)
                    
                    LoadingOverlay(
                        title: isGenerating ? "Generating variations..." : "Saving images...",
                        subtitle: isGenerating ? "This may take a few moments" : "Please wait while we save your refined character"
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                        onDismiss()
                    }
                    .disabled(isSaving || isGenerating)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .interactiveDismissDisabled(isSaving || isGenerating)
            .animation(.easeInOut(duration: 0.2), value: isGenerating)
            .animation(.easeInOut(duration: 0.2), value: isSaving)
        }
    }
    
    private func toggleRefinedImageSelection(_ url: String) {
        if selectedRefinedImages.contains(url) {
            selectedRefinedImages.remove(url)
        } else if selectedRefinedImages.count < 2 {
            selectedRefinedImages.insert(url)
        }
    }
    
    private func generateRefinedCharacter() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isGenerating = true
        }
        
        Task {
            do {
                let urls = try await viewModel.generateCharacterWithReference(
                    selectedImages: selectedImages,
                    prompt: prompt
                )
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        generatedUrls = urls
                        isGenerating = false
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        errorMessage = error.localizedDescription
                        showingError = true
                        isGenerating = false
                    }
                }
            }
        }
    }
}

#Preview {
    CharacterCreationView(viewModel: CharacterCreationViewModel(user: nil))
} 