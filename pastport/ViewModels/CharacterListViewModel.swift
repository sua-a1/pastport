import SwiftUI
import FirebaseFirestore
import SwiftData

@Observable final class CharacterListViewModel {
    // MARK: - Properties
    private let userId: String
    private let db = Firestore.firestore()
    var characters: [Character] = []
    var isLoading = false
    var errorMessage: String?
    
    // MARK: - Initialization
    init(userId: String) {
        self.userId = userId
        Task {
            await fetchCharacters()
        }
    }
    
    // MARK: - Methods
    @MainActor
    func fetchCharacters() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch from Firestore
            let snapshot = try await db.collection("characters")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            // Parse documents
            characters = snapshot.documents.compactMap { document in
                try? document.data(as: Character.self)
            }
            
            // Sort by creation date
            characters.sort { $0.createdAt > $1.createdAt }
            
        } catch {
            print("DEBUG: Failed to fetch characters: \(error)")
            errorMessage = "Failed to load characters. Please try again."
        }
        
        isLoading = false
    }
    
    func deleteCharacter(_ character: Character) async {
        do {
            // Delete from Firestore
            try await db.collection("characters").document(character.id).delete()
            
            // Delete associated images from Storage
            // TODO: Implement cleanup of character images
            
            // Update local state
            await MainActor.run {
                characters.removeAll { $0.id == character.id }
            }
        } catch {
            print("DEBUG: Failed to delete character: \(error)")
            errorMessage = "Failed to delete character. Please try again."
        }
    }
} 