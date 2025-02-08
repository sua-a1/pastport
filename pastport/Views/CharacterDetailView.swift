import SwiftUI

struct CharacterDetailView: View {
    let character: Character
    @Environment(\.dismiss) private var dismiss
    @State private var selectedImageIndex = 0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Generated Images Section
                    if !character.generatedImages.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Generated Images")
                                .font(.title3.bold())
                                .padding(.horizontal)
                            
                            TabView(selection: $selectedImageIndex) {
                                ForEach(Array(character.generatedImages.enumerated()), id: \.element) { index, imageUrl in
                                    AsyncImage(url: URL(string: imageUrl)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        ProgressView()
                                    }
                                    .tag(index)
                                }
                            }
                            .frame(height: 400)
                            .tabViewStyle(.page)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 24) {
                        // Character Info
                        VStack(alignment: .leading, spacing: 16) {
                            // Name and Creation Date
                            VStack(alignment: .leading, spacing: 4) {
                                Text(character.name)
                                    .font(.title)
                                    .bold()
                                
                                Text("Created \(character.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            // Description
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(.headline)
                                
                                Text(character.characterDescription)
                                    .font(.body)
                            }
                            
                            // Style Prompt
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Style")
                                    .font(.headline)
                                
                                Text(character.stylePrompt)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Reference Images Section
                        if !character.referenceImages.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Reference Images")
                                    .font(.title3.bold())
                                    .padding(.horizontal)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 16) {
                                        ForEach(character.referenceImages, id: \.url) { reference in
                                            VStack(alignment: .leading, spacing: 8) {
                                                AsyncImage(url: URL(string: reference.url)) { image in
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                } placeholder: {
                                                    ProgressView()
                                                }
                                                .frame(width: 200, height: 200)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    if !reference.prompt.isEmpty {
                                                        Text(reference.prompt)
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)
                                                            .lineLimit(2)
                                                    }
                                                    
                                                    Text("Weight: \(String(format: "%.1f", reference.weight))")
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                }
                                                .padding(.horizontal, 4)
                                            }
                                            .frame(width: 200)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                                .frame(height: 260)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
} 