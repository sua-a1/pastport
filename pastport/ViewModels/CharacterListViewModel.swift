import SwiftUI
import FirebaseFirestore
import FirebaseStorage

@Observable final class CharacterListViewModel {
    // MARK: - Properties
    var characters: [Character] = []
    var isLoading = false
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private let userId: String
    var errorMessage: String?
    
    // MARK: - Initialization
    init(userId: String) {
        self.userId = userId
        print("DEBUG: CharacterListViewModel initialized for user: \(userId)")
        Task {
            await loadCharacters()
        }
    }
    
    // MARK: - Methods
    func loadCharacters() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            print("DEBUG: Starting character load for user: \(userId)")
            
            // Query characters for the current user, ordered by creation date
            let snapshot = try await db.collection("characters")
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            print("DEBUG: Found \(snapshot.documents.count) characters")
            
            let loadedCharacters = snapshot.documents.compactMap { document -> Character? in
                do {
                    let data = document.data()
                    // Convert Timestamp to Date
                    var mutableData = data
                    if let createdTimestamp = data["createdAt"] as? Timestamp {
                        mutableData["createdAt"] = createdTimestamp.dateValue()
                    }
                    if let updatedTimestamp = data["updatedAt"] as? Timestamp {
                        mutableData["updatedAt"] = updatedTimestamp.dateValue()
                    }
                    
                    return Character(id: document.documentID, data: mutableData)
                } catch {
                    print("DEBUG: Failed to parse character document: \(error)")
                    return nil
                }
            }
            
            print("DEBUG: Successfully parsed \(loadedCharacters.count) characters")
            
            await MainActor.run {
                self.characters = loadedCharacters
            }
        } catch {
            print("DEBUG: Failed to load characters: \(error)")
            errorMessage = "Failed to load characters. Please try again."
        }
    }
    
    func deleteCharacter(_ character: Character) async {
        do {
            print("DEBUG: Starting deletion of character: \(character.id)")
            
            // Delete character document from Firestore
            try await db.collection("characters").document(character.id).delete()
            
            // Delete associated images from Storage
            let storageRef = storage.reference()
            
            // Delete reference images
            for refImage in character.referenceImages {
                if let imagePath = extractPathFromUrl(refImage.url) {
                    try? await storageRef.child(imagePath).delete()
                }
            }
            
            // Delete generated images
            for imageUrl in character.generatedImages {
                if let imagePath = extractPathFromUrl(imageUrl) {
                    try? await storageRef.child(imagePath).delete()
                }
            }
            
            // Update local state
            await MainActor.run {
                characters.removeAll { $0.id == character.id }
            }
            
            print("DEBUG: Successfully deleted character and associated images")
        } catch {
            print("DEBUG: Failed to delete character: \(error)")
            errorMessage = "Failed to delete character. Please try again."
        }
    }
    
    private func extractPathFromUrl(_ urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let host = url.host,
              host.contains("firebasestorage.googleapis.com") else {
            return nil
        }
        
        // Extract the path after /o/
        if let range = urlString.range(of: "/o/"),
           let endRange = urlString.range(of: "?") {
            let startIndex = range.upperBound
            let endIndex = endRange.lowerBound
            let path = String(urlString[startIndex..<endIndex])
                .removingPercentEncoding ?? ""
            return path
        }
        return nil
    }
} 