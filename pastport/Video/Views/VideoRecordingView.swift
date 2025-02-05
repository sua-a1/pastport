import SwiftUI
import AVFoundation
import PhotosUI

struct VideoRecordingView: View {
    @State private var cameraManager = CameraManager()
    @State private var selectedTool: VideoTool?
    @State private var showPermissionAlert = false
    @State private var permissionAlertMessage = ""
    @State private var showPhotoPicker = false
    @State private var selectedItem: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Video Tools
    enum VideoTool {
        case sounds, flips, speed, filters, timer, flash, album
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                // Camera Preview
                if let session = cameraManager.captureSession {
                    CameraPreviewView(session: session)
                        .edgesIgnoringSafeArea(.all)
                }
                
                // Overlay Controls
                VStack {
                    // Top Controls
                    HStack {
                        Button(action: {
                            cameraManager.stopSession()
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                                .font(.title2)
                                .padding()
                        }
                        Spacer()
                        Text("Sounds")
                            .foregroundColor(.white)
                        Spacer()
                        Button {
                            cameraManager.switchCamera()
                        } label: {
                            Image(systemName: "camera.rotate")
                                .foregroundColor(.white)
                                .font(.title2)
                                .padding()
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Tool Buttons
                    HStack(spacing: 20) {
                        ToolButton(tool: .flips, selectedTool: $selectedTool)
                        ToolButton(tool: .speed, selectedTool: $selectedTool)
                        ToolButton(tool: .filters, selectedTool: $selectedTool)
                        ToolButton(tool: .timer, selectedTool: $selectedTool)
                        ToolButton(tool: .flash, selectedTool: $selectedTool)
                    }
                    .padding(.bottom)
                    
                    // Bottom Controls
                    HStack {
                        // Spacer for left side to balance Album button
                        Spacer()
                            .frame(width: 70)
                        
                        // Record Button
                        Button(action: toggleRecording) {
                            Circle()
                                .fill(cameraManager.isRecording ? Color.red : Color.white)
                                .frame(width: 65, height: 65)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 4)
                                        .frame(width: 75, height: 75)
                                )
                        }
                        
                        // Album Button
                        Button(action: { showPhotoPicker = true }) {
                            VStack(spacing: 4) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                Text("Album")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .frame(width: 70)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .alert("Permission Required", isPresented: $showPermissionAlert) {
            Button("Settings", action: openSettings)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(permissionAlertMessage)
        }
        .fullScreenCover(isPresented: $cameraManager.showVideoPostingView) {
            if let videoURL = cameraManager.lastRecordedVideoURL {
                VideoPostingView(videoURL: videoURL)
                    .presentationDragIndicator(.visible)
            }
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedItem,
            matching: .any(of: [.videos, .not(.images)]),
            preferredItemEncoding: .current
        )
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let item = newItem {
                    await handleVideoSelection(item)
                }
            }
            // Reset selection after handling
            selectedItem = nil
        }
        .task {
            // Check permissions first
            checkPermissions()
            
            // Setup and start session if we have permissions
            if cameraManager.cameraAndAudioAccessPermitted {
                cameraManager.setupSession()
                cameraManager.startSession()
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
    
    private func handleVideoSelection(_ item: PhotosPickerItem) async {
        do {
            // Try to load the video data directly
            guard let videoData = try await item.loadTransferable(type: Data.self) else {
                print("DEBUG: Failed to load video data")
                return
            }
            
            print("DEBUG: Video data loaded, size: \(videoData.count) bytes")
            
            // Create a temporary URL for the video
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp4")
            
            print("DEBUG: Writing video to temp location: \(tempURL)")
            
            // Write the data to the temporary file
            try videoData.write(to: tempURL)
            
            print("DEBUG: Video written successfully")
            
            await MainActor.run {
                cameraManager.handleSelectedVideo(tempURL)
            }
        } catch {
            print("DEBUG: Failed to process video: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Actions
    private func toggleRecording() {
        if cameraManager.isRecording {
            cameraManager.stopRecording()
        } else {
            cameraManager.startRecording()
        }
    }
    
    private func checkPermissions() {
        if !cameraManager.cameraAndAudioAccessPermitted {
            cameraManager.requestCameraAccess { granted in
                if !granted {
                    showPermissionAlert = true
                    permissionAlertMessage = "Camera access is required to record videos"
                }
            }
            
            cameraManager.requestMicrophoneAccess { granted in
                if !granted {
                    showPermissionAlert = true
                    permissionAlertMessage = "Microphone access is required to record videos"
                }
            }
        }
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - Tool Button
struct ToolButton: View {
    let tool: VideoRecordingView.VideoTool
    @Binding var selectedTool: VideoRecordingView.VideoTool?
    
    var body: some View {
        Button {
            selectedTool = tool
        } label: {
            VStack {
                Image(systemName: iconName)
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(.white)
        }
    }
    
    private var iconName: String {
        switch tool {
        case .flips: return "camera.rotate"
        case .speed: return "speedometer"
        case .filters: return "camera.filters"
        case .timer: return "timer"
        case .flash: return "bolt.fill"
        case .sounds: return "music.note"
        case .album: return "photo.on.rectangle"
        }
    }
    
    private var title: String {
        switch tool {
        case .flips: return "Flip"
        case .speed: return "Speed"
        case .filters: return "Filters"
        case .timer: return "Timer"
        case .flash: return "Flash"
        case .sounds: return "Sounds"
        case .album: return "Album"
        }
    }
} 