import SwiftUI
import AVFoundation

struct VideoCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraManager = CameraManager()
    @State private var selectedTool: VideoTool?
    
    enum VideoTool {
        case sounds, flips, speed, filters, timer, flash, album
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Camera preview
                CameraPreviewView(session: cameraManager.session)
                    .ignoresSafeArea()
                
                // Overlay controls
                VStack {
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        Spacer()
                        Text("Sounds")
                        Spacer()
                        Button {
                            cameraManager.switchCamera()
                        } label: {
                            Image(systemName: "camera.rotate")
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Tool buttons
                    HStack(spacing: 20) {
                        ToolButton(tool: .flips, selectedTool: $selectedTool)
                        ToolButton(tool: .speed, selectedTool: $selectedTool)
                        ToolButton(tool: .filters, selectedTool: $selectedTool)
                        ToolButton(tool: .timer, selectedTool: $selectedTool)
                        ToolButton(tool: .flash, selectedTool: $selectedTool)
                    }
                    .padding(.bottom)
                    
                    // Record button
                    RecordButton(isRecording: $cameraManager.isRecording)
                        .padding(.bottom)
                }
            }
        }
        .onDisappear {
            // Ensure camera session is stopped when view disappears
            withAnimation {
                cameraManager.session.stopRunning()
            }
        }
    }
}

struct ToolButton: View {
    let tool: VideoCreationView.VideoTool
    @Binding var selectedTool: VideoCreationView.VideoTool?
    
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
    
    var iconName: String {
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
    
    var title: String {
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

struct RecordButton: View {
    @Binding var isRecording: Bool
    
    var body: some View {
        Button {
            isRecording.toggle()
        } label: {
            Circle()
                .stroke(Color.white, lineWidth: 4)
                .frame(width: 75, height: 75)
                .overlay(
                    Circle()
                        .fill(Color.red)
                        .frame(width: 65, height: 65)
                )
        }
    }
} 