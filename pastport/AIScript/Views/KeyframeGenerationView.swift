import SwiftUI
import PhotosUI

// Import our models
import class pastport.StoryScene
import struct pastport.ReferenceImage
import struct pastport.Keyframe
import class pastport.AIScript
import class pastport.KeyframeGenerationViewModel

/// View for managing keyframe generation and editing
struct KeyframeGenerationView: View {
    // MARK: - Properties
    
    @State var model: KeyframeGenerationViewModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var showingWeightSheet = false
    @State private var selectedImageForWeight: ReferenceImage?
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Scene content
            ScrollView {
                VStack(spacing: 24) {
                    // Scene description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Scene Description")
                            .font(.headline)
                        
                        Text(model.script.scenes[model.sceneIndex].content)
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Keyframe previews
                    keyframePreviews
                    
                    // Reference image selection
                    referenceImageSection
                    
                    // Generation controls
                    controlSection
                }
                .padding()
            }
        }
        .navigationTitle("Scene \(model.sceneIndex + 1) Keyframes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if case .completed = model.state {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var keyframePreviews: some View {
        VStack(spacing: 16) {
            Text("Keyframes")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 20) {
                // Start keyframe
                VStack(spacing: 8) {
                    Text("Start")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    keyframePreview(
                        imageUrl: model.script.scenes[model.sceneIndex].startKeyframe.imageUrl,
                        prompt: $model.startKeyframePrompt
                    )
                }
                
                // End keyframe
                VStack(spacing: 8) {
                    Text("End")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    keyframePreview(
                        imageUrl: model.script.scenes[model.sceneIndex].endKeyframe.imageUrl,
                        prompt: $model.endKeyframePrompt
                    )
                }
            }
        }
    }
    
    private func keyframePreview(imageUrl: String?, prompt: Binding<String>) -> some View {
        VStack(spacing: 8) {
            Group {
                if let urlString = imageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        if model.isGenerating {
                            Color.blue.opacity(0.3)
                                .overlay {
                                    ProgressView()
                                }
                        } else {
                            Color.gray.opacity(0.3)
                                .overlay {
                                    Image(systemName: "photo")
                                        .foregroundStyle(.secondary)
                                }
                        }
                    }
                } else if model.isGenerating {
                    Color.blue.opacity(0.3)
                        .overlay {
                            ProgressView()
                        }
                } else {
                    Color.gray.opacity(0.3)
                        .overlay {
                            Image(systemName: "plus")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 160, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            TextField("Enter prompt...", text: prompt)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var referenceImageSection: some View {
        VStack(spacing: 16) {
            Text("Reference Images")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if model.selectedImages.isEmpty {
                Text("Add reference images to guide the generation")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 150), spacing: 16)
                ], spacing: 16) {
                    ForEach(model.selectedImages, id: \.url) { image in
                        ReferenceImageCell(
                            image: image,
                            onTapWeight: {
                                selectedImageForWeight = image
                                showingWeightSheet = true
                            },
                            onRemove: {
                                model.removeReferenceImage(url: image.url)
                            }
                        )
                    }
                }
            }
            
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label("Add Reference", systemImage: "plus")
            }
            .buttonStyle(.bordered)
        }
        .sheet(isPresented: $showingWeightSheet) {
            if let image = selectedImageForWeight {
                WeightAdjustmentSheet(
                    image: image,
                    onSave: { weight in
                        model.updateImageWeight(url: image.url, weight: weight)
                        selectedImageForWeight = nil
                    }
                )
            }
        }
        .onChange(of: selectedItem) { item in
            if let item {
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        // TODO: Upload image to storage and get URL
                        // For now using a placeholder URL
                        let url = "placeholder_url"
                        model.addReferenceImage(url: url)
                    }
                }
            }
        }
    }
    
    private var controlSection: some View {
        VStack(spacing: 16) {
            if case .completed = model.state {
                Button {
                    Task {
                        await model.regenerateKeyframes()
                    }
                } label: {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            } else if !model.isGenerating {
                Button {
                    Task {
                        await model.generateKeyframes()
                    }
                } label: {
                    Text("Generate Keyframes")
                }
                .buttonStyle(.borderedProminent)
            }
            
            if let error = model.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top)
    }
}

// MARK: - Reference Image Cell

private struct ReferenceImageCell: View {
    let image: ReferenceImage
    let onTapWeight: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Image
            AsyncImage(url: URL(string: image.url)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray
                    .overlay {
                        ProgressView()
                    }
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Weight indicator
            Button(action: onTapWeight) {
                HStack {
                    Text("Weight: \(Int(image.weight * 100))%")
                        .font(.caption)
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            
            // Remove button
            Button(role: .destructive, action: onRemove) {
                Label("Remove", systemImage: "trash")
                    .font(.caption)
            }
        }
    }
}

// MARK: - Weight Adjustment Sheet

private struct WeightAdjustmentSheet: View {
    let image: ReferenceImage
    let onSave: (Double) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var weight: Double
    
    init(image: ReferenceImage, onSave: @escaping (Double) -> Void) {
        self.image = image
        self.onSave = onSave
        _weight = State(initialValue: image.weight)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Image preview
                AsyncImage(url: URL(string: image.url)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Color.gray
                        .overlay {
                            ProgressView()
                        }
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Weight slider
                VStack(spacing: 8) {
                    Text("Reference Weight: \(Int(weight * 100))%")
                        .font(.headline)
                    
                    Slider(value: $weight, in: 0...1, step: 0.1)
                }
                .padding()
                
                Text("Adjust how much influence this image should have on the generated keyframes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Adjust Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(weight)
                        dismiss()
                    }
                }
            }
        }
    }
} 