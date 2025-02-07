import SwiftUI
import PhotosUI
import AVKit
import FirebaseFirestore
import FirebaseStorage


// MARK: - Story Details Section
struct StoryDetailsSection: View {
    @Bindable var viewModel: CreateViewModel
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 24) {
                // Title Field
                VStack(alignment: .leading, spacing: 8) {
                    Label("Title", systemImage: "text.quote")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    TextField("Give your story a compelling title", text: $viewModel.title)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        )
                }
                
                // Category Selection
                VStack(alignment: .leading, spacing: 12) {
                    Label("Category", systemImage: "tag.fill")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Category", selection: $viewModel.category) {
                            ForEach(DraftCategory.allCases, id: \.self) { category in
                                Text(category.rawValue).tag(category)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        Menu {
                            Picker("Story Type", selection: $viewModel.subcategory) {
                                Text("Select Type").tag(Optional<DraftSubcategory>.none)
                                ForEach(DraftSubcategory.allCases, id: \.self) { subcategory in
                                    Text(subcategory.rawValue).tag(Optional(subcategory))
                                }
                            }
                        } label: {
                            HStack {
                                Text(viewModel.subcategory?.rawValue ?? "Select Story Type")
                                    .foregroundStyle(viewModel.subcategory == nil ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            )
                        }
                    }
                }
                
                // Content Field
                VStack(alignment: .leading, spacing: 8) {
                    Label("Story Content", systemImage: "doc.text.fill")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $viewModel.content)
                            .frame(minHeight: 180)
                            .padding(12)
                            .scrollContentBackground(.hidden)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            )
                        
                        if viewModel.content.isEmpty {
                            Text("Write your story here. Be descriptive - this will help the AI create better visuals.")
                                .foregroundColor(.gray)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 20)
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        } header: {
            Text("Story Details")
                .textCase(.uppercase)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Media Section
struct MediaSection: View {
    @Bindable var viewModel: CreateViewModel
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 24) {
                // Images Section
                ImagePickerSection(
                    selectedImages: viewModel.selectedImages,
                    onAddImage: { items in
                        Task {
                            await viewModel.addImages(items)
                        }
                    },
                    onDeleteImage: { id in
                        viewModel.removeImage(id: id)
                    }
                )
                
                Divider()
                    .padding(.vertical, 8)
                
                // Videos Section
                VideoPickerSection(
                    selectedVideos: viewModel.selectedVideos,
                    onAddVideo: { items in
                        Task {
                            await viewModel.addVideos(items)
                        }
                    },
                    onDeleteVideo: { id in
                        viewModel.removeVideo(id: id)
                    }
                )
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } header: {
            Text("Media")
                .textCase(.uppercase)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Image Picker Section
private struct ImagePickerSection: View {
    let selectedImages: [MediaItem]
    let onAddImage: ([PhotosPickerItem]) async -> Void
    let onDeleteImage: (UUID) -> Void
    @State private var currentSelection: [PhotosPickerItem] = []
    @State private var isUploading = false
    @State private var showPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Images", systemImage: "photo.stack")
                .font(.headline)
                .foregroundStyle(.primary)
            
            if !selectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(selectedImages) { mediaItem in
                            CreateImagePreviewView(
                                item: mediaItem.item,
                                onDelete: {
                                    withAnimation {
                                        onDeleteImage(mediaItem.id)
                                    }
                                }
                            )
                            .frame(width: 160, height: 200)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 220)
            }
            
            if isUploading {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Uploading images...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else if selectedImages.count < 4 {
                Button {
                    showPicker = true
                } label: {
                    Label("Add Images (\(selectedImages.count)/4)", systemImage: "photo.stack")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray6))
                        )
                }
                .photosPicker(
                    isPresented: $showPicker,
                    selection: $currentSelection,
                    maxSelectionCount: 4 - selectedImages.count,
                    matching: .images,
                    photoLibrary: .shared()
                )
            }
        }
        .onChange(of: currentSelection) { _, items in
            guard !items.isEmpty else { return }
            Task {
                isUploading = true
                await onAddImage(items)
                isUploading = false
                currentSelection = []
                showPicker = false
            }
        }
    }
}

// MARK: - Video Picker Section
private struct VideoPickerSection: View {
    let selectedVideos: [MediaItem]
    let onAddVideo: ([PhotosPickerItem]) async -> Void
    let onDeleteVideo: (UUID) -> Void
    @State private var currentSelection: [PhotosPickerItem] = []
    @State private var isUploading = false
    @State private var showPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Videos", systemImage: "video.fill")
                .font(.headline)
                .foregroundStyle(.primary)
            
            if !selectedVideos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(selectedVideos) { mediaItem in
                            CreateVideoPreviewView(
                                item: mediaItem.item,
                                onDelete: {
                                    withAnimation {
                                        onDeleteVideo(mediaItem.id)
                                    }
                                }
                            )
                            .frame(width: 160, height: 180)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 200)
            }
            
            if isUploading {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Uploading videos...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else if selectedVideos.count < 2 {
                Button {
                    showPicker = true
                } label: {
                    Label("Add Videos (\(selectedVideos.count)/2)", systemImage: "video.badge.plus")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray6))
                        )
                }
                .photosPicker(
                    isPresented: $showPicker,
                    selection: $currentSelection,
                    maxSelectionCount: 2 - selectedVideos.count,
                    matching: .videos,
                    photoLibrary: .shared()
                )
            }
        }
        .onChange(of: currentSelection) { _, items in
            guard !items.isEmpty else { return }
            Task {
                isUploading = true
                await onAddVideo(items)
                isUploading = false
                currentSelection = []
                showPicker = false
            }
        }
    }
}

// MARK: - Preview Components
private struct CreateImagePreviewView: View {
    let item: PhotosPickerItem
    let onDelete: () -> Void
    @State private var image: Image?
    @State private var isLoading = true
    @State private var showPreview = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let image = image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 160, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showPreview = true
                    }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(width: 160, height: 200)
                    .overlay {
                        if isLoading {
                            ProgressView()
                        }
                    }
            }
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white)
                    .background(Circle().fill(.black.opacity(0.5)))
                    .padding(8)
            }
        }
        .task {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        image = Image(uiImage: uiImage)
                    }
                }
            } catch {
                print("DEBUG: Failed to load image: \(error)")
            }
            isLoading = false
        }
        .sheet(isPresented: $showPreview) {
            if let image = image {
                NavigationStack {
                    ImageDetailView(image: image)
                }
            }
        }
    }
}

private struct CreateVideoPreviewView: View {
    let item: PhotosPickerItem
    let onDelete: () -> Void
    @State private var thumbnail: Image?
    @State private var isLoading = true
    @State private var showVideoPlayer = false
    @State private var videoURL: URL?
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                if let thumbnail = thumbnail {
                    thumbnail
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 160, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showVideoPlayer = true
                        }
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .frame(width: 160, height: 180)
                        .overlay {
                            if isLoading {
                                ProgressView()
                            }
                        }
                }
                
                // Play button overlay
                if thumbnail != nil {
                    Image(systemName: "play.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                }
            }
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white)
                    .background(Circle().fill(.black.opacity(0.5)))
                    .padding(8)
            }
        }
        .task {
            do {
                if let movie: MovieTransferable = try await item.loadTransferable(type: MovieTransferable.self) {
                    videoURL = movie.url
                    let asset: AVAsset = AVAsset(url: movie.url) // Ensure this line is present
                    let imageGenerator: AVAssetImageGenerator = AVAssetImageGenerator(asset: asset)
                    imageGenerator.appliesPreferredTrackTransform = true
                    
                    let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
                    thumbnail = Image(uiImage: UIImage(cgImage: cgImage))
                }
            } catch {
                print("DEBUG: Failed to load video thumbnail: \(error)")
            }
            isLoading = false
        }
        .sheet(isPresented: $showVideoPlayer) {
            if let videoURL = videoURL {
                DraftVideoPlayerView(url: videoURL)
            }
        }
    }
}

private struct ImageDetailView: View {
    let image: Image
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white)
                            .shadow(radius: 1)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
    }
}

private struct DraftVideoPlayerView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VideoPlayer(player: AVPlayer(url: url))
                .ignoresSafeArea()
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - Reference Texts Section
struct ReferenceTextsSection: View {
    @Bindable var viewModel: CreateViewModel
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                // Reference Text 1
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Title", text: $viewModel.referenceText1.title)
                        .textFieldStyle(.roundedBorder)
                    TextEditor(text: $viewModel.referenceText1.content)
                        .frame(height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2))
                        )
                    TextField("Source (Optional)", text: $viewModel.referenceText1.source)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Reference Text 2
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Title", text: $viewModel.referenceText2.title)
                        .textFieldStyle(.roundedBorder)
                    TextEditor(text: $viewModel.referenceText2.content)
                        .frame(height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2))
                        )
                    TextField("Source (Optional)", text: $viewModel.referenceText2.source)
                        .textFieldStyle(.roundedBorder)
                }
            }
        } header: {
            Text("Reference Texts")
        }
    }
} 