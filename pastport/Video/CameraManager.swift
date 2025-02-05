import AVFoundation
import SwiftUI

@MainActor
class CameraManager: ObservableObject {
    @Published var isRecording = false
    let session = AVCaptureSession()
    private var camera: AVCaptureDevice?
    private var cameraInput: AVCaptureDeviceInput?
    private let movieOutput = AVCaptureMovieFileOutput()
    private var isConfigured = false
    
    init() {
        Task {
            await setupCamera()
        }
    }
    
    deinit {
        Task { @MainActor in
            await stopSession()
        }
    }
    
    private func setupCamera() async {
        // Check and request camera permissions
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            await configureSession()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                await configureSession()
            }
        default:
            break
        }
    }
    
    private func configureSession() async {
        guard !isConfigured else { return }
        
        session.beginConfiguration()
        
        // Add video input
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            do {
                camera = device
                let input = try AVCaptureDeviceInput(device: device)
                cameraInput = input
                if session.canAddInput(input) {
                    session.addInput(input)
                }
            } catch {
                print("DEBUG: Failed to create camera input: \(error.localizedDescription)")
            }
        }
        
        // Add audio input
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            do {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                }
            } catch {
                print("DEBUG: Failed to create audio input: \(error.localizedDescription)")
            }
        }
        
        // Add movie output
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }
        
        session.commitConfiguration()
        isConfigured = true
        
        await startSession()
    }
    
    private func startSession() async {
        guard !session.isRunning else { return }
        
        await Task.detached {
            self.session.startRunning()
        }.value
    }
    
    private func stopSession() async {
        guard session.isRunning else { return }
        
        await Task.detached {
            self.session.stopRunning()
        }.value
    }
    
    func switchCamera() {
        guard let currentInput = cameraInput else { return }
        
        let currentPosition = currentInput.device.position
        let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
        
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else { return }
        
        session.beginConfiguration()
        session.removeInput(currentInput)
        
        do {
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                cameraInput = newInput
                camera = newDevice
            }
        } catch {
            print("DEBUG: Failed to switch camera: \(error.localizedDescription)")
            if session.canAddInput(currentInput) {
                session.addInput(currentInput)
            }
        }
        
        session.commitConfiguration()
    }
}