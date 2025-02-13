import Foundation

extension DraftCategory {
    var toPostCategory: PostCategory {
        switch self {
        case .historical:
            return .historical
        case .mythAndLore:
            return .mythLore
        }
    }
}

extension DraftSubcategory {
    var toPostSubcategory: PostSubcategory {
        switch self {
        case .canonical:
            return .canonical
        case .speculative:
            return .speculative
        case .alternate:
            return .alternate
        }
    }
} 