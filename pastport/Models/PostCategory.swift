import Foundation

enum PostCategory: String, CaseIterable, Codable {
    case historical = "Historical"
    case mythLore = "Myth/Lore"
}

enum PostSubcategory: String, CaseIterable, Codable {
    case canonical = "Canonical"
    case speculative = "Speculative"
    case alternate = "Alternate"
}

struct PostCategorization: Codable, Equatable {
    let category: PostCategory
    let subcategory: PostSubcategory
    
    var displayText: String {
        "\(category.rawValue) • \(subcategory.rawValue)"
    }
    
    // Helper for UI display
    var categoryColor: String {
        switch category {
        case .historical:
            return "Historical.background"  // We'll define these colors in Assets
        case .mythLore:
            return "MythLore.background"
        }
    }
    
    var textColor: String {
        switch category {
        case .historical:
            return "Historical.text"
        case .mythLore:
            return "MythLore.text"
        }
    }
} 