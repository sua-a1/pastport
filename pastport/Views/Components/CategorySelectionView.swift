import SwiftUI

struct CategorySelectionView: View {
    @Binding var selectedCategory: PostCategory?
    @Binding var selectedSubcategory: PostSubcategory?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    ForEach(PostCategory.allCases, id: \.self) { category in
                        Button {
                            selectedCategory = category
                            // Reset subcategory when category changes
                            selectedSubcategory = nil
                        } label: {
                            Text(category.rawValue)
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(selectedCategory == category ? 
                                             Color(category == .historical ? "Historical.background" : "MythLore.background") :
                                             Color(.systemGray6))
                                )
                                .foregroundColor(selectedCategory == category ? .primary : .secondary)
                        }
                    }
                }
            }
            
            // Subcategory Selection (only show if category is selected)
            if selectedCategory != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Type")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        ForEach(PostSubcategory.allCases, id: \.self) { subcategory in
                            Button {
                                selectedSubcategory = subcategory
                            } label: {
                                Text(subcategory.rawValue)
                                    .font(.subheadline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(selectedSubcategory == subcategory ? 
                                                 Color(.systemBlue).opacity(0.2) :
                                                 Color(.systemGray6))
                                    )
                                    .foregroundColor(selectedSubcategory == subcategory ? .primary : .secondary)
                            }
                        }
                    }
                }
            }
        }
        .animation(.easeInOut, value: selectedCategory)
    }
} 