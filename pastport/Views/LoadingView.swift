import SwiftUI
import Lottie

struct AppLoadingView: View {
    var body: some View {
        ZStack {
            // Background color
            Color.pastportBackground
                .ignoresSafeArea()
            
            // Logo
            Image("pastport logo with name")
                .resizable()
                .scaledToFit()
                .frame(width: 200)
            
            // Loading animation
            LottieView(name: "Loading")
                .frame(width: 100, height: 100)
                .offset(y: 120)
        }
    }
}

struct InlineLoadingView: View {
    var message: String = "Loading..."
    
    var body: some View {
        VStack(spacing: 16) {
            LottieView(name: "Loading")
                .frame(width: 50, height: 50)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct LottieView: UIViewRepresentable {
    var name: String
    var loopMode: LottieLoopMode = .loop
    
    func makeUIView(context: Context) -> some UIView {
        let view = UIView()
        let animationView = LottieAnimationView()
        let animation = LottieAnimation.named(name)
        animationView.animation = animation
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = loopMode
        animationView.play()
        
        animationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animationView)
        
        NSLayoutConstraint.activate([
            animationView.heightAnchor.constraint(equalTo: view.heightAnchor),
            animationView.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])
        
        return view
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
    }
}

#Preview {
    AppLoadingView()
} 