import SwiftUI

struct CharacterListView: View {
    let viewModel: CharacterListViewModel
    @State private var showingDeleteConfirmation = false
    @State private var characterToDelete: Character?
    @State private var showingCharacterDetail = false
    @State private var selectedCharacter: Character?
    
    var body: some View {
        ZStack {
            Color.pastportBackground
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                ProgressView("Loading characters...")
                    .padding()
            } else {
                ScrollView {
                    if viewModel.characters.isEmpty {
                        ContentUnavailableView(
                            "No Characters Yet",
                            systemImage: "person.fill.questionmark",
                            description: Text("Create your first character to bring your stories to life!")
                        )
                        .padding()
                    } else {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16)
                            ],
                            spacing: 16
                        ) {
                            ForEach(viewModel.characters) { character in
                                CharacterCell(character: character)
                                    .onTapGesture {
                                        selectedCharacter = character
                                        showingCharacterDetail = true
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            characterToDelete = character
                                            showingDeleteConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                }
            }
        }
        .alert("Delete Character", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let character = characterToDelete {
                    Task {
                        await viewModel.deleteCharacter(character)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this character? This action cannot be undone.")
        }
        .sheet(isPresented: $showingCharacterDetail) {
            if let character = selectedCharacter {
                CharacterDetailView(character: character)
            }
        }
        .task {
            await viewModel.loadCharacters()
        }
    }
}

// MARK: - Supporting Views
private struct CharacterCell: View {
    let character: Character
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Character Image Container
            if let imageUrl = character.generatedImages.first {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                } placeholder: {
                    ProgressView()
                        .frame(height: 200)
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemGray6))
                    .frame(height: 200)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
            }
            
            // Character Info
            VStack(alignment: .leading, spacing: 6) {
                Text(character.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(character.characterDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "#E4E4E4"))
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        )
    }
} 