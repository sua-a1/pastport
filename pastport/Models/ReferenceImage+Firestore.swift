// ReferenceImage+Firestore.swift
import Foundation
import FirebaseFirestore

// MARK: - Firestore Conversion
extension ReferenceImage {
    init?(from dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let url = dict["url"] as? String,
              let typeString = dict["type"] as? String,
              let type = ReferenceImageType(rawValue: typeString),
              let weight = dict["weight"] as? Double,
              let prompt = dict["prompt"] as? String? else {
            return nil
        }
        
        self.init(
            id: id,
            url: url,
            type: type,
            weight: weight,
            prompt: prompt
        )
    }
    
    var asDictionary: [String: Any] {
        return [
            "id": id,
            "url": url,
            "type": type.rawValue,
            "weight": weight,
            "prompt": prompt as Any
        ]
    }
}

// MARK: - Debug Support
extension ReferenceImage {
    static var mock: ReferenceImage {
        ReferenceImage(
            url: "https://example.com/image.jpg",
            type: .reference,
            weight: 0.5,
            prompt: "A sample reference image"
        )
    }
} 