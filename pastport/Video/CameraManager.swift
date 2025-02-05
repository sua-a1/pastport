import AVFoundation
import Photos
import UIKit
import AVKit

protocol RecordingDelegate: AnyObject {
    func finishRecording(_ videoURL: URL?, _ err: Error?)
}

@Observable final class CameraManager: NSObject, AVCaptureFileOutputRecordingDelegate {
    // MARK: - Properties
    private(set) var captureSession: AVCaptureSession?
    private(set) var currentCameraPosition: AVCaptureDevice.Position = .back
    private(set) var isRecording = false
    private(set) var cameraAndAudioAccessPermitted = false
    var lastRecordedVideoURL: URL?
    var showVideoPostingView = false
    var embeddingView: UIView?
    weak var delegate: RecordingDelegate?
    
    private let sessionQueue = DispatchQueue(label: "com.pastport.CameraSessionQueue")
    private var movieOutput: AVCaptureMovieFileOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var currentCameraInput: AVCaptureDeviceInput?
    private var photoLibrary: PHPhotoLibrary?
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // MARK: - Computed Properties
    private var tempFilePath: URL {
        let timestamp = Int(Date().timeIntervalSince1970)
        return documentsDirectory
            .appendingPathComponent("recording_\(timestamp)")
            .appendingPathExtension("mp4")
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        print("DEBUG: Initializing CameraManager")
        checkPermissionStatus()
        photoLibrary = PHPhotoLibrary.shared()
    }
    
    // MARK: - Session Setup
    func setupSession() {
        print("DEBUG: Setting up camera session")
        guard captureSession == nil else { return }
        
        captureSession = AVCaptureSession()
        guard let session = captureSession else { return }
        
        // Use serial queue for configuration
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            print("DEBUG: Beginning session configuration")
            session.beginConfiguration()
            
            // Set quality level
            if session.canSetSessionPreset(.high) {
                session.sessionPreset = .high
            }
            
            // Setup video input
            self.setupVideoInput()
            
            // Setup audio input
            self.setupAudioInput()
            
            // Setup movie output
            self.setupMovieOutput()
            
            session.commitConfiguration()
            print("DEBUG: Session configuration completed")
            
            // Start running on the session queue
            session.startRunning()
            print("DEBUG: Session started running")
        }
    }
    
    private func setupVideoInput() {
        guard let session = captureSession else { return }
        print("DEBUG: Setting up video input")
        
        // Remove existing input if any
        if let currentInput = currentCameraInput {
            session.removeInput(currentInput)
        }
        
        // Add new input
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                 for: .video,
                                                 position: currentCameraPosition) else {
            print("DEBUG: Failed to get camera device")
            return
        }
        
        do {
            // Configure device for better low light performance
            try device.lockForConfiguration()
            if device.isLowLightBoostEnabled {
                device.automaticallyEnablesLowLightBoostWhenAvailable = true
            }
            
            // Enable auto focus and exposure
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            
            device.unlockForConfiguration()
            
            let deviceInput = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(deviceInput) {
                session.addInput(deviceInput)
                currentCameraInput = deviceInput
                print("DEBUG: Video input setup successfully")
            }
        } catch {
            print("DEBUG: Failed to create video device input: \(error.localizedDescription)")
        }
    }
    
    private func setupAudioInput() {
        guard let session = captureSession,
              let audioDevice = AVCaptureDevice.default(for: .audio) else {
            print("DEBUG: Failed to get audio device")
            return
        }
        
        do {
            let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
            if session.canAddInput(audioDeviceInput) {
                session.addInput(audioDeviceInput)
                print("DEBUG: Audio input setup successfully")
            }
        } catch {
            print("DEBUG: Failed to create audio device input: \(error.localizedDescription)")
        }
    }
    
    private func setupMovieOutput() {
        guard let session = captureSession else { return }
        print("DEBUG: Setting up movie output")
        
        movieOutput = AVCaptureMovieFileOutput()
        if let movieOutput = movieOutput, session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            
            if let connection = movieOutput.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
                
                // Enable video orientation updates
                connection.videoOrientation = .portrait
                
                print("DEBUG: Movie output setup successfully")
            }
        }
    }
    
    private func setupPreviewLayer() {
        if let session = captureSession {
            previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer?.videoGravity = .resizeAspectFill
        }
    }
    
    // MARK: - Camera Controls
    func switchCamera() {
        print("DEBUG: Switching camera")
        currentCameraPosition = currentCameraPosition == .back ? .front : .back
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession?.beginConfiguration()
            self.setupVideoInput()
            self.captureSession?.commitConfiguration()
        }
    }
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let session = self.captureSession else { return }
            
            if !session.isRunning {
                print("DEBUG: Starting capture session")
                session.startRunning()
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let session = self.captureSession else { return }
            
            if session.isRunning {
                print("DEBUG: Stopping capture session")
                session.stopRunning()
            }
        }
    }
    
    // MARK: - Recording Controls
    func startRecording() {
        print("DEBUG: Starting recording")
        guard !isRecording else { return }
        isRecording = true
        movieOutput?.startRecording(to: tempFilePath, recordingDelegate: self)
    }
    
    func stopRecording() {
        print("DEBUG: Stopping recording")
        guard isRecording else { return }
        isRecording = false
        movieOutput?.stopRecording()
    }
    
    // MARK: - Video Processing
    private func compressVideo(at sourceURL: URL) async throws -> URL {
        print("DEBUG: Starting video compression")
        let startTime = Date()
        
        let asset = AVAsset(url: sourceURL)
        let duration = try await asset.load(.duration)
        let size = try await asset.load(.tracks).first?.load(.naturalSize) ?? .zero
        
        print("DEBUG: Original video - Duration: \(duration.seconds)s, Size: \(size)")
        
        // Create compression configuration
        let preset = AVAssetExportPresetMediumQuality
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            print("DEBUG: Failed to create export session")
            throw VideoUploadError.compressionFailed
        }
        
        // Set output URL in documents directory
        let compressedURL = documentsDirectory
            .appendingPathComponent("compressed_\(UUID().uuidString)")
            .appendingPathExtension("mp4")
        
        // Configure export session
        session.outputURL = compressedURL
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true
        
        // Export the video
        await session.export()
        
        // Check export status
        switch session.status {
        case .completed:
            let endTime = Date()
            let compressionTime = endTime.timeIntervalSince(startTime)
            
            // Get file sizes for comparison
            let originalSize = try FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int64 ?? 0
            let compressedSize = try FileManager.default.attributesOfItem(atPath: compressedURL.path)[.size] as? Int64 ?? 0
            
            print("""
                DEBUG: Video compression completed
                - Time taken: \(String(format: "%.2f", compressionTime))s
                - Original size: \(originalSize / 1024 / 1024)MB
                - Compressed size: \(compressedSize / 1024 / 1024)MB
                - Reduction: \(String(format: "%.1f", (1 - Double(compressedSize) / Double(originalSize)) * 100))%
                """)
            
            return compressedURL
            
        case .failed:
            print("DEBUG: Export failed: \(session.error?.localizedDescription ?? "Unknown error")")
            throw VideoUploadError.compressionFailed
            
        case .cancelled:
            print("DEBUG: Export cancelled")
            throw VideoUploadError.compressionFailed
            
        default:
            print("DEBUG: Export ended with status: \(session.status.rawValue)")
            throw VideoUploadError.compressionFailed
        }
    }
    
    // MARK: - AVCaptureFileOutputRecordingDelegate
    func fileOutput(_ output: AVCaptureFileOutput, 
                   didFinishRecordingTo outputFileURL: URL, 
                   from connections: [AVCaptureConnection], 
                   error: Error?) {
        if let error = error {
            print("DEBUG: Recording failed: \(error.localizedDescription)")
        } else {
            print("DEBUG: Recording finished successfully")
            Task {
                do {
                    // First compress the video
                    let compressedURL = try await compressVideo(at: outputFileURL)
                    print("DEBUG: Video compressed successfully")
                    
                    // Move the compressed video to final location
                    let finalURL = tempFilePath
                    if FileManager.default.fileExists(atPath: finalURL.path) {
                        try FileManager.default.removeItem(at: finalURL)
                    }
                    try FileManager.default.moveItem(at: compressedURL, to: finalURL)
                    print("DEBUG: Moved compressed recording to documents directory: \(finalURL.path)")
                    
                    await MainActor.run {
                        lastRecordedVideoURL = finalURL
                        showVideoPostingView = true
                    }
                } catch {
                    print("DEBUG: Failed to process recording: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Permissions
    private func checkPermissionStatus() {
        let cameraAuth = AVCaptureDevice.authorizationStatus(for: .video)
        let audioAuth = AVCaptureDevice.authorizationStatus(for: .audio)
        
        cameraAndAudioAccessPermitted = (cameraAuth == .authorized) && (audioAuth == .authorized)
    }
    
    func requestCameraAccess(_ completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] access in
            self?.checkPermissionStatus()
            DispatchQueue.main.async {
                completion(access)
            }
        }
    }
    
    func requestMicrophoneAccess(_ completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] access in
            self?.checkPermissionStatus()
            DispatchQueue.main.async {
                completion(access)
            }
        }
    }
    
    // MARK: - Save to Library
    func saveToLibrary(videoURL: URL) {
        func save() {
            sessionQueue.async { [weak self] in
                self?.photoLibrary?.performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                }, completionHandler: { (saved, error) in
                    if let error = error {
                        print("DEBUG: Saving to Photo Library Failed: \(error.localizedDescription)")
                    } else {
                        print("DEBUG: Video saved to library")
                    }
                })
            }
        }
        
        if PHPhotoLibrary.authorizationStatus() != .authorized {
            PHPhotoLibrary.requestAuthorization({ status in
                if status == .authorized {
                    save()
                }
            })
        } else {
            save()
        }
    }
    
    // MARK: - Video Selection
    func handleSelectedVideo(_ url: URL) {
        Task {
            do {
                // First compress the video
                let compressedURL = try await compressVideo(at: url)
                print("DEBUG: Video compressed successfully")
                
                // Move to final location
                let finalURL = tempFilePath
                if FileManager.default.fileExists(atPath: finalURL.path) {
                    try FileManager.default.removeItem(at: finalURL)
                }
                try FileManager.default.moveItem(at: compressedURL, to: finalURL)
                print("DEBUG: Moved compressed video to documents directory: \(finalURL.path)")
                
                await MainActor.run {
                    lastRecordedVideoURL = finalURL
                    showVideoPostingView = true
                }
            } catch {
                print("DEBUG: Failed to process selected video: \(error.localizedDescription)")
            }
        }
    }
    
    // Clean up old recordings
    private func cleanupOldRecordings() {
        do {
            let fileManager = FileManager.default
            let files = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            let recordings = files.filter { $0.pathExtension == "mp4" }
            
            // Keep only the 5 most recent recordings
            if recordings.count > 5 {
                let sortedRecordings = recordings.sorted { $0.lastPathComponent > $1.lastPathComponent }
                for recording in sortedRecordings[5...] {
                    try fileManager.removeItem(at: recording)
                    print("DEBUG: Cleaned up old recording: \(recording.lastPathComponent)")
                }
            }
        } catch {
            print("DEBUG: Failed to cleanup old recordings: \(error.localizedDescription)")
        }
    }
    
    deinit {
        cleanupOldRecordings()
    }
}