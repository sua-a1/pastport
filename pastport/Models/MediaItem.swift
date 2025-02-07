import SwiftUI
import PhotosUI

struct MediaItem: Identifiable {
    let id: UUID
    let item: PhotosPickerItem
    
    init(id: UUID = UUID(), item: PhotosPickerItem) {
        self.id = id
        self.item = item
    }
} 