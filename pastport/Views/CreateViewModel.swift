import SwiftUI
import PhotosUI
import FirebaseFirestore
import FirebaseStorage

@Observable
final class CreateViewModel {
    var selectedMode: CreateMode = .video
    var title: String = ""
    var content: String = ""
    var category: DraftCategory = .historical
    var subcategory: DraftSubcategory?
    var user: User?
    
    var selectedSubcategoryText: String {
        subcategory?.rawValue ?? "Select Story Type"
    }
    
    // Reference text structure
    struct ReferenceTextInput: Identifiable {
        let id = UUID()
        var title: String = ""
        var content: String = ""
        var source: String = ""
    }
    
    var selectedImages: [MediaItem] = []
    var selectedVideos: [MediaItem] = []
    var referenceText1 = ReferenceTextInput()
    var referenceText2 = ReferenceTextInput()
    
    // Save state
    var isSaving = false
    var errorMessage: String?
    var showSuccessMessage = false
    var showValidationAlert = false
    
    // Validation
    var isValidDraft: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        subcategory != nil
    }
    
    var validationErrors: [String] {
        var errors: [String] = []
        
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Please enter a title")
        }
        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Please enter your story content")
        }
        if subcategory == nil {
            errors.append("Please select a story type")
        }
        
        return errors
    }
    
    // Media management
    func addImages(_ items: [PhotosPickerItem]) {
        items.forEach { item in
            selectedImages.append(MediaItem(item: item))
        }
    }
    
    func removeImage(id: UUID) {
        selectedImages.removeAll { $0.id == id }
    }
    
    func addVideos(_ items: [PhotosPickerItem]) {
        items.forEach { item in
            selectedVideos.append(MediaItem(item: item))
        }
    }
    
    func removeVideo(id: UUID) {
        selectedVideos.removeAll { $0.id == id }
    }
} 