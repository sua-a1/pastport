import SwiftUI
import UIKit

/// A view that asynchronously loads and displays an image with caching
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    // MARK: - Properties
    
    /// URL of the image to load
    let url: URL?
    
    /// Content builder for the loaded image
    let content: (Image) -> Content
    
    /// Placeholder view while loading or on error
    let placeholder: () -> Placeholder
    
    /// Image cache instance
    @State private var cachedImage: UIImage?
    @State private var isLoading = true
    @State private var error: Error?
    
    // MARK: - Initialization
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if let image = cachedImage {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .task(id: url?.absoluteString) {
            await loadImage()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadImage() async {
        guard let url = url else {
            isLoading = false
            return
        }
        
        // Check if image is already cached
        if let cached = ImageCache.shared.get(for: url.absoluteString) {
            print("DEBUG: Using cached image for \(url)")
            cachedImage = cached
            isLoading = false
            return
        }
        
        do {
            print("DEBUG: Loading image from \(url)")
            isLoading = true
            error = nil
            
            // Download image data
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // Create UIImage and cache it
            if let image = UIImage(data: data) {
                ImageCache.shared.insert(image, for: url.absoluteString)
                cachedImage = image
            } else {
                throw URLError(.cannotDecodeRawData)
            }
            
        } catch {
            print("ERROR: Failed to load image: \(error.localizedDescription)")
            self.error = error
        }
        
        isLoading = false
    }
}

// MARK: - Image Cache

@MainActor
final class ImageCache: Sendable {
    static let shared = ImageCache()
    
    private init() {}
    
    private var cache = NSCache<NSString, UIImage>()
    
    func insert(_ image: UIImage?, for key: String) {
        guard let image = image else { return }
        cache.setObject(image, forKey: key as NSString)
    }
    
    func get(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }
} 