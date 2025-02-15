import SwiftUI

// Import our models
import struct pastport.ReferenceImage
import struct pastport.ReferenceText
import enum pastport.ReferenceImageType

/// View for selecting reference images and texts
struct ReferenceSelectionView: View {
    // MARK: - Properties
    
    @Binding var selectedReferenceImages: [ReferenceImage]
    @Binding var selectedCharacterImages: [ReferenceImage]
    @Binding var selectedTextIds: [String]
    
    let referenceTexts: [ReferenceText]
    let availableReferenceImages: [ReferenceImage]
    let availableCharacterImages: [ReferenceImage]
    let onComplete: () -> Void
    
    // Add error state
    @State private var errorMessage: String?
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 24) {
            // Selected images section
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Selected Images")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(selectedReferenceImages.count + selectedCharacterImages.count)/4")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
                
                if selectedReferenceImages.isEmpty && selectedCharacterImages.isEmpty {
                    Text("Select up to 4 images to guide the visual style")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    // Selected images grid
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 140), spacing: 16)
                    ], spacing: 16) {
                        // Character images
                        ForEach(selectedCharacterImages) { image in
                            ReferenceImageCell(
                                image: image,
                                type: .character,
                                onRemove: {
                                    selectedCharacterImages.removeAll { $0.id == image.id }
                                    errorMessage = nil
                                }
                            )
                        }
                        
                        // Reference images
                        ForEach(selectedReferenceImages) { image in
                            ReferenceImageCell(
                                image: image,
                                type: .reference,
                                onRemove: {
                                    selectedReferenceImages.removeAll { $0.id == image.id }
                                    errorMessage = nil
                                }
                            )
                        }
                    }
                }
            }
            
            // Available character images section
            if !availableCharacterImages.isEmpty && (selectedReferenceImages.count + selectedCharacterImages.count) < 4 {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Character Images")
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHGrid(rows: [
                            GridItem(.fixed(80))
                        ], spacing: 12) {
                            ForEach(availableCharacterImages) { image in
                                if !selectedCharacterImages.contains(where: { $0.id == image.id }) {
                                    AvailableImageCell(
                                        image: image,
                                        type: .character
                                    ) {
                                        addCharacterImage(image)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }
            
            // Available reference images section
            if !availableReferenceImages.isEmpty && (selectedReferenceImages.count + selectedCharacterImages.count) < 4 {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Reference Images")
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHGrid(rows: [
                            GridItem(.fixed(80))
                        ], spacing: 12) {
                            ForEach(availableReferenceImages) { image in
                                if !selectedReferenceImages.contains(where: { $0.id == image.id }) {
                                    AvailableImageCell(
                                        image: image,
                                        type: .reference
                                    ) {
                                        addReferenceImage(image)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }
            
            Divider()
            
            // Text selection section
            VStack(alignment: .leading, spacing: 16) {
                Text("Reference Texts")
                    .font(.headline)
                
                if referenceTexts.isEmpty {
                    Text("No reference texts available")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(referenceTexts) { text in
                        ReferenceTextCell(
                            text: text,
                            isSelected: selectedTextIds.contains(text.id)
                        ) {
                            // Toggle selection
                            if selectedTextIds.contains(text.id) {
                                selectedTextIds.removeAll { $0 == text.id }
                            } else {
                                selectedTextIds.append(text.id)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // Continue button
            Button("Continue") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedReferenceImages.isEmpty && selectedCharacterImages.isEmpty && selectedTextIds.isEmpty)
        }
        .padding()
    }
    
    // MARK: - Private Methods
    
    private func addCharacterImage(_ image: ReferenceImage) {
        if selectedCharacterImages.count + selectedReferenceImages.count >= 4 {
            errorMessage = "You can select up to 4 images"
            return
        }
        selectedCharacterImages.append(image)
        errorMessage = nil
    }
    
    private func addReferenceImage(_ image: ReferenceImage) {
        if selectedCharacterImages.count + selectedReferenceImages.count >= 4 {
            errorMessage = "You can select up to 4 images"
            return
        }
        selectedReferenceImages.append(image)
        errorMessage = nil
    }
}

// MARK: - Supporting Views

private struct ReferenceImageCell: View {
    let image: ReferenceImage
    let type: ReferenceImageType
    let onRemove: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                CachedAsyncImage(url: URL(string: image.url)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                        .overlay {
                            Image(systemName: type == .character ? "person.fill" : "photo")
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(type == .character ? Color.purple.opacity(0.5) : Color.blue.opacity(0.5), lineWidth: 2)
                }
                
                // Remove button
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white, Color.black.opacity(0.5))
                        .background(Color.black.opacity(0.2))
                        .clipShape(Circle())
                }
                .padding(4)
            }
            
            // Weight slider
            VStack(spacing: 4) {
                Text("Weight: \(Int(image.weight * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Slider(value: .constant(image.weight), in: 0...1)
            }
            .padding(.horizontal, 4)
        }
    }
}

private struct AvailableImageCell: View {
    let image: ReferenceImage
    let type: ReferenceImageType
    let onSelect: () -> Void
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            CachedAsyncImage(url: URL(string: image.url)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.3)
                    .overlay {
                        Image(systemName: type == .character ? "person.fill" : "photo")
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(type == .character ? Color.purple.opacity(0.5) : Color.blue.opacity(0.5), lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ReferenceTextCell: View {
    let text: ReferenceText
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(text.title)
                        .font(.subheadline)
                        .foregroundStyle(isSelected ? .primary : .secondary)
                    
                    Text(text.content)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }
            .padding()
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview Models

private extension ReferenceText {
    static let preview = ReferenceText(
        id: "preview",
        userId: "preview",
        title: "Ancient Egypt",
        content: "The ancient Egyptian civilization...",
        source: "Wikipedia",
        draftIds: []
    )
} 