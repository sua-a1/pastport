import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> PreviewView {
        print("DEBUG: Creating camera preview view")
        let view = PreviewView()
        view.backgroundColor = .black
        
        // Configure preview layer
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.videoPreviewLayer.connection?.videoOrientation = .portrait
        
        print("DEBUG: Camera preview view created and configured")
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        // Update preview layer frame if needed
        uiView.videoPreviewLayer.frame = uiView.bounds
    }
}

class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer.frame = bounds
    }
} 