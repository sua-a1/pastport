import SwiftUI

struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background color
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // App Icon
                if let appIconImage = UIImage(named: "AppIcon") {
                    Image(uiImage: appIconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                } else {
                    // Fallback app icon using SF Symbol
                    Image(systemName: "clock.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .foregroundColor(.gray)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                }
                
                // Loading indicator
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.gray)
                
                // App name
                Text("Pastport")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.gray)
                    .opacity(isAnimating ? 1.0 : 0.7)
            }
            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isAnimating)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    LoadingView()
} 