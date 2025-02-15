import Foundation

/// Type of reference image
public enum ReferenceImageType: String, Codable, Sendable {
    case character
    case reference
}

/// Model representing a reference image with its weight
public struct ReferenceImage: Identifiable, Codable {
    public let id: String
    public let url: String
    public let type: ReferenceImageType
    public var weight: Double
    public var prompt: String?
    
    public init(
        id: String = UUID().uuidString,
        url: String,
        type: ReferenceImageType = .reference,
        weight: Double = 0.5,
        prompt: String? = nil
    ) {
        self.id = id
        self.url = url
        self.type = type
        self.weight = min(max(weight, 0.0), 1.0)
        self.prompt = prompt
    }
} 