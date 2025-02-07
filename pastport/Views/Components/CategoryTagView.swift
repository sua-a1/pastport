import SwiftUI

struct CategoryTagView: View {
    let category: String
    let subcategory: String
    var isOverVideo: Bool = true
    
    private var backgroundColor: Color {
        let baseColor = category == "Historical" ? 
            Color("Historical.background") : 
            Color("MythLore.background")
        return baseColor.opacity(isOverVideo ? 0.8 : 0.2)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Text(category)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(backgroundColor)
                )
                .foregroundColor(isOverVideo ? .white : .primary)
            
            Text(subcategory)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6)
                            .opacity(isOverVideo ? 0.3 : 1))
                )
                .foregroundColor(isOverVideo ? .white : .primary)
        }
    }
} 