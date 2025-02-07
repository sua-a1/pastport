import SwiftUI
import PhotosUI
import FirebaseFirestore

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var profileViewModel: ProfileViewModel
    @State private var username: String
    @State private var bio: String
    @State private var selectedCategories: Set<String> = []
    @State private var showError = false
    @State private var showSuccess = false
    @State private var selectedImage: PhotosPickerItem?
    let user: User
    let onSave: (User) -> Void
    
    private let categories = ["History", "Mythology", "Ancient Civilizations", "Folklore", "Legends"]
    
    init(user: User, onSave: @escaping (User) -> Void) {
        self.user = user
        self.onSave = onSave
        let viewModel = ProfileViewModel(user: user)
        _profileViewModel = StateObject(wrappedValue: viewModel)
        _username = State(initialValue: user.username)
        _bio = State(initialValue: user.bio ?? "")
        _selectedCategories = State(initialValue: Set(user.preferredCategories))
    }
    
    var body: some View {
        List {
            // Profile Photo Section
            Section {
                VStack(spacing: 20) {
                    // Profile Image
                    if let imageUrl = profileViewModel.user.profileImageUrl,
                       let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color(.systemGray5), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 4)
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 120, height: 120)
                            .foregroundStyle(.gray)
                    }
                    
                    // Photo Picker Button
                    PhotosPicker(selection: $selectedImage, matching: .images) {
                        Label("Change Photo", systemImage: "camera.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            )
                    }
                    .disabled(profileViewModel.isLoading)
                }
                .listRowBackground(Color.clear)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } header: {
                Text("Profile Photo")
                    .textCase(.uppercase)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Basic Info Section
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // Username Field
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Username", systemImage: "person.fill")
                            .font(.headline)
                        
                        TextField("Enter username", text: $username)
                            .textInputAutocapitalization(.never)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            )
                    }
                    
                    // Bio Field
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Bio", systemImage: "text.quote")
                            .font(.headline)
                        
                        TextField("Tell us about yourself", text: $bio, axis: .vertical)
                            .lineLimit(3...6)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            )
                    }
                }
                .listRowBackground(Color.clear)
                .padding(.vertical, 8)
            } header: {
                Text("Basic Info")
                    .textCase(.uppercase)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Interests Section
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(categories, id: \.self) { category in
                        Toggle(isOn: Binding(
                            get: { selectedCategories.contains(category) },
                            set: { isSelected in
                                if isSelected {
                                    selectedCategories.insert(category)
                                } else {
                                    selectedCategories.remove(category)
                                }
                            }
                        )) {
                            Text(category)
                                .font(.subheadline)
                        }
                        .tint(.blue)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Interests")
                    .textCase(.uppercase)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } footer: {
                Text("Select categories that interest you")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    Task {
                        do {
                            let updatedUser = try await profileViewModel.updateProfile(
                                username: username,
                                bio: bio.isEmpty ? nil : bio,
                                preferredCategories: Array(selectedCategories)
                            )
                            onSave(updatedUser)
                        } catch {
                            showError = true
                        }
                    }
                }
                .disabled(profileViewModel.isLoading)
            }
        }
        .overlay {
            if profileViewModel.isLoading {
                LoadingOverlay(message: "Saving changes...")
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(profileViewModel.errorMessage ?? "An error occurred")
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Profile updated successfully")
        }
        .onChange(of: selectedImage) { _, newValue in
            guard let newValue else { return }
            Task {
                do {
                    print("DEBUG: Loading image data")
                    if let data = try await newValue.loadTransferable(type: Data.self) {
                        print("DEBUG: Image data loaded, size: \(data.count) bytes")
                        let imageUrl = try await profileViewModel.uploadProfileImage(data)
                        print("DEBUG: Successfully got image URL: \(imageUrl)")
                        
                        var updatedUser = profileViewModel.user
                        updatedUser.profileImageUrl = imageUrl
                        
                        await MainActor.run {
                            profileViewModel.user = updatedUser
                            onSave(updatedUser)
                        }
                    } else {
                        print("DEBUG: Failed to load image data")
                        showError = true
                        profileViewModel.errorMessage = "Failed to load image data"
                    }
                } catch {
                    print("DEBUG: Image upload error: \(error.localizedDescription)")
                    showError = true
                }
            }
        }
    }
}

// MARK: - Supporting Views
private struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text(message)
                    .font(.headline)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(radius: 8)
            )
        }
    }
} 