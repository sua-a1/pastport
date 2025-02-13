import SwiftUI
import UIKit
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth

// MARK: - Image Detail Container
// Remove the ImageDetailContainer struct

struct CharacterDetailView: View {
    let character: Character
    @Environment(\.dismiss) private var dismiss
    @State private var selectedImageIndex = 0
    @State private var showingFullScreenImage = false
    @State private var selectedFullScreenImage: String?
    @State private var selectedImageType: ImageType = .generated
    @State private var isLoadingImages = true
    @State private var errorMessage: String?
    @State private var generatedImages: [String]
    @State private var migratedUrls: [String: String] = [:]
    
    init(character: Character) {
        self.character = character
        self._generatedImages = State(initialValue: character.generatedImages)
        print("[DEBUG] CharacterDetailView: Initialized with character: \(character.id)")
    }
    
    private enum ImageType {
        case generated
        case reference
    }
    
    // This function is no longer needed.
    // private func getStorageDownloadURL(for imageUrl: String) async throws -> URL { ... }
    
    private func checkIfImageExists(at path: String) async throws -> Bool {
        let storage = Storage.storage()
        let storageRef = storage.reference().child(path)
        
        do {
            _ = try await storageRef.downloadURL()
            print("[DEBUG] CharacterDetailView: Image already exists at path: \(path)")
            return true
        } catch {
            print("[DEBUG] CharacterDetailView: Image does not exist at path: \(path)")
            return false
        }
    }
    
    private func migrateImageIfNeeded(imageUrl: String, index: Int) async throws -> String {
        print("[DEBUG] CharacterDetailView: migrateImageIfNeeded for image \(index): \(imageUrl)")
        let storage = Storage.storage()
        let db = Firestore.firestore()
        let characterId = character.id
        
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "CharacterDetail", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Check if we have already migrated this URL
        if let migratedUrl = migratedUrls[imageUrl] {
            print("[DEBUG] CharacterDetailView: Using previously migrated URL: \(migratedUrl)")
            return migratedUrl
        }
        
        // If it's already a Firebase Storage URL with the correct path structure, just refresh it
        if imageUrl.contains("firebasestorage.googleapis.com") {
            if let path = extractPathFromUrl(imageUrl) {
                print("[DEBUG] CharacterDetailView: Found Firebase path: \(path)")
                
                let ref = storage.reference().child(path)
                let freshUrl = try await ref.downloadURL()
                
                // Store the refreshed URL
                await MainActor.run {
                    migratedUrls[imageUrl] = freshUrl.absoluteString
                }
                
                return freshUrl.absoluteString
            }
        }
        
        // For Luma CDN URLs or if Firebase URL handling failed, download and upload to Firebase
        guard let url = URL(string: imageUrl) else {
            throw NSError(domain: "CharacterDetail", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image URL"])
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              !data.isEmpty else {
            throw NSError(domain: "CharacterDetail", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to download image"])
        }
        
        // Use the correct path structure
        let filename = "\(characterId)_\(index).jpg"
        let path = "characters/\(userId)/generated_images/\(filename)"
        print("[DEBUG] CharacterDetailView: Will upload to path: \(path)")
        
        let storageRef = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = [
            "characterId": characterId,
            "imageIndex": String(index),
            "originalUrl": imageUrl
        ]
        
        _ = try await storageRef.putDataAsync(data, metadata: metadata)
        let downloadUrl = try await storageRef.downloadURL()
        
        // Store the migrated URL
        await MainActor.run {
            migratedUrls[imageUrl] = downloadUrl.absoluteString
        }
        
        return downloadUrl.absoluteString
    }
    
    private func extractPathFromUrl(_ urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let host = url.host,
              host.contains("firebasestorage.googleapis.com") else {
            return nil
        }
        
        // Extract the path after /o/
        if let range = urlString.range(of: "/o/"),
           let endRange = urlString.range(of: "?") {
            let startIndex = range.upperBound
            let endIndex = endRange.lowerBound
            let path = String(urlString[startIndex..<endIndex])
                .removingPercentEncoding ?? ""
            return path
        }
        return nil
    }
    
    @MainActor
    private func loadImages() async {
        print("[DEBUG] CharacterDetailView: Starting image load for character: \(character.id)")
        isLoadingImages = true
        
        do {
            let db = Firestore.firestore()
            let characterId = character.id
            
            let uploadedUrls = try await withThrowingTaskGroup(of: (Int, String).self) { group in
                for (index, imageUrl) in character.generatedImages.enumerated() {
                    group.addTask {
                        print("[DEBUG] CharacterDetailView: Processing image \(index): \(imageUrl)")
                        let migratedUrl = try await migrateImageIfNeeded(imageUrl: imageUrl, index: index)
                        return (index, migratedUrl)
                    }
                }
                
                var results: [(Int, String)] = []
                for try await result in group {
                    results.append(result)
                }
                
                return results.sorted { $0.0 < $1.0 }.map { $0.1 }
            }
            
            print("[DEBUG] CharacterDetailView: Successfully processed \(uploadedUrls.count) images")
            
            // Update Firestore if URLs have changed
            if uploadedUrls != character.generatedImages {
                print("[DEBUG] CharacterDetailView: URLs have changed, updating Firestore")
                let updateData: [String: Any] = [
                    "generatedImages": uploadedUrls,
                    "updatedAt": FieldValue.serverTimestamp()
                ]
                
                try await db.collection("characters").document(characterId).updateData(updateData)
                print("[DEBUG] CharacterDetailView: Updated character with new image URLs")
            }
            
            generatedImages = uploadedUrls
            
        } catch {
            print("[ERROR] CharacterDetailView: Failed to process images: \(error)")
            errorMessage = "Failed to load some images. Please try again. Error: \(error.localizedDescription)"
        }
        
        isLoadingImages = false
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.pastportBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        if !generatedImages.isEmpty {
                            GeneratedImagesSection(
                                images: generatedImages,
                                selectedIndex: $selectedImageIndex,
                                onImageTap: { url in
                                    print("[DEBUG] CharacterDetailView: Generated image tapped with URL: \(url)")
                                    selectedImageType = .generated
                                    selectedFullScreenImage = url
                                    showingFullScreenImage = true
                                }
                            )
                        }
                        
                        CharacterInfoSection(character: character)
                        
                        if !character.referenceImages.isEmpty {
                            ReferenceImagesSection(
                                references: character.referenceImages,
                                onImageTap: { url in
                                    print("[DEBUG] CharacterDetailView: Reference image tapped with URL: \(url)")
                                    selectedImageType = .reference
                                    selectedFullScreenImage = url
                                    showingFullScreenImage = true
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                }
                .navigationTitle(character.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.title3)
                        }
                    }
                }
                .refreshable {
                    print("[DEBUG] CharacterDetailView: Manual refresh triggered")
                    await loadImages()
                }
                
                // Loading overlay
                if isLoadingImages {
                    LoadingOverlay(
                        title: "Loading images...",
                        subtitle: "Please wait while we load your character's images"
                    )
                }
                
                // Error overlay
                if let error = errorMessage {
                    ErrorOverlay(message: error) {
                        errorMessage = nil
                    }
                }
            }
            .sheet(isPresented: $showingFullScreenImage) {
                if let imageUrl = selectedFullScreenImage {
                    FullScreenImageView(
                        imageUrl: imageUrl,
                        caption: selectedImageType == .reference ? character.referenceImages.first(where: { $0.url == imageUrl })?.prompt : nil
                    )
                }
            }
            .presentationBackground(Color.pastportBackground)
            .task(priority: .userInitiated) {
                await loadImages()
            }
        }
    }
}

private struct LoadingOverlay: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6).opacity(0.9))
            )
        }
    }
}

private struct ErrorOverlay: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Text(message)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
            
            Button("Dismiss") {
                onDismiss()
            }
            .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

private struct GeneratedImagesSection: View {
    let images: [String]
    @Binding var selectedIndex: Int
    let onImageTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Generated Images")
                .font(.title3.bold())
            
            TabView(selection: $selectedIndex) {
                ForEach(Array(images.enumerated()), id: \.element) { index, imageUrl in
                    Button {
                        onImageTap(imageUrl)
                    } label: {
                        AsyncImage(url: URL(string: imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .frame(height: 400)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        } placeholder: {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 400)
                        }
                    }
                    .buttonStyle(.plain)
                    .tag(index)
                }
            }
            .frame(height: 400)
            .tabViewStyle(.page)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

private struct CharacterInfoSection: View {
    let character: Character
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Name and Creation Date
            VStack(alignment: .leading, spacing: 8) {
                Text(character.name)
                    .font(.title2.bold())
                
                Text("Created \(character.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.headline)
                
                Text(character.characterDescription)
                    .font(.body)
            }
            
            // Style Prompt
            VStack(alignment: .leading, spacing: 8) {
                Text("Style")
                    .font(.headline)
                
                Text(character.stylePrompt)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        )
    }
}

private struct ReferenceImagesSection: View {
    let references: [Character.ReferenceImage]
    let onImageTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reference Images")
                .font(.title3.bold())
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(references, id: \.url) { reference in
                        ReferenceImageCell(reference: reference, onTap: { onImageTap(reference.url) })
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(height: 280)
        }
    }
}

private struct ReferenceImageCell: View {
    let reference: Character.ReferenceImage
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onTap) {
                AsyncImage(url: URL(string: reference.url)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 220, height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .shadow(color: .black.opacity(0.1), radius: 5, y: 3)
            
            VStack(alignment: .leading, spacing: 4) {
                if !reference.prompt.isEmpty {
                    Text(reference.prompt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Text("Weight: \(String(format: "%.1f", reference.weight))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .frame(width: 220)
    }
}

// MARK: - Supporting Views
private struct FullScreenImageView: View {
    let imageUrl: String
    let caption: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                // Content
                if let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.5)
                                .onAppear {
                                    print("[DEBUG] FullScreenImageView: Loading state for URL: \(url)")
                                }
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                                .onAppear {
                                    print("[DEBUG] FullScreenImageView: Successfully loaded image for URL: \(url)")
                                }
                        case .failure(let error):
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                                Text("Failed to load image")
                                    .foregroundColor(.white)
                                Text(error.localizedDescription)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .onAppear {
                                print("[ERROR] FullScreenImageView: Failed to load image: \(error.localizedDescription)")
                            }
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                        Text("Invalid image URL")
                            .foregroundColor(.white)
                    }
                    .padding()
                    .onAppear {
                        print("[ERROR] FullScreenImageView: Invalid URL provided: \(imageUrl)")
                    }
                }
                
                // Caption overlay at the bottom
                if let caption = caption {
                    VStack {
                        Spacer()
                        Text(caption)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding()
                            .background(.black.opacity(0.6))
                            .cornerRadius(8)
                            .padding(.bottom)
                    }
                }
                
                // Dismiss button overlay
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            print("[DEBUG] FullScreenImageView: Dismiss button tapped")
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                        }
                    }
                    Spacer()
                }
            }
        }
        .background(Color.black)
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            print("[DEBUG] FullScreenImageView: View appeared with URL: \(imageUrl)")
        }
    }
} 