import FirebaseStorage

/// A Sendable wrapper for Firebase StorageMetadata
public struct SendableStorageMetadata: Sendable {
    /// The content type of the file
    public let contentType: String
    
    /// Create a new SendableStorageMetadata
    public init(contentType: String) {
        self.contentType = contentType
    }
    
    /// Convert to Firebase StorageMetadata
    public func toStorageMetadata() -> StorageMetadata {
        let metadata = StorageMetadata()
        metadata.contentType = contentType
        return metadata
    }
} 