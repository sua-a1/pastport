import SwiftUI
import PhotosUI
import FirebaseFirestore

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var profileViewModel: ProfileViewModel
    @State private var username: String
    @State private var bio: String
    @State private var selectedCategories: Set<String>
    @State private var showError = false
    @State private var showSuccess = false
    @State private var selectedImage: PhotosPickerItem?
    let user: User
    let onSave: (User) -> Void
    
    private let categories = ["History", "Mythology", "Ancient Civilizations", "Folklore", "Legends"]
    
    var body: some View {
        ProfileEditContent(
            profileViewModel: profileViewModel,
            username: $username,
            bio: $bio,
            selectedCategories: $selectedCategories,
            selectedImage: $selectedImage,
            showError: $showError,
            showSuccess: $showSuccess,
            categories: categories,
            onSave: onSave,
            dismiss: dismiss
        )
    }
    
    init(user: User, onSave: @escaping (User) -> Void) {
        self.user = user
        self.onSave = onSave
        let viewModel = ProfileViewModel(user: user)
        _profileViewModel = StateObject(wrappedValue: viewModel)
        _username = State(initialValue: user.username)
        _bio = State(initialValue: user.bio ?? "")
        _selectedCategories = State(initialValue: Set(user.preferredCategories))
    }
}

private struct ProfileEditContent: View {
    @ObservedObject var profileViewModel: ProfileViewModel
    @Binding var username: String
    @Binding var bio: String
    @Binding var selectedCategories: Set<String>
    @Binding var selectedImage: PhotosPickerItem?
    @Binding var showError: Bool
    @Binding var showSuccess: Bool
    let categories: [String]
    let onSave: (User) -> Void
    let dismiss: DismissAction
    
    var body: some View {
        ProfileEditMainContent(
            profileViewModel: profileViewModel,
            username: $username,
            bio: $bio,
            selectedCategories: $selectedCategories,
            selectedImage: $selectedImage,
            showError: $showError,
            showSuccess: $showSuccess,
            categories: categories,
            onSave: onSave,
            dismiss: dismiss
        )
    }
}

private struct ProfileEditMainContent: View {
    let profileViewModel: ProfileViewModel
    @Binding var username: String
    @Binding var bio: String
    @Binding var selectedCategories: Set<String>
    @Binding var selectedImage: PhotosPickerItem?
    @Binding var showError: Bool
    @Binding var showSuccess: Bool
    let categories: [String]
    let onSave: (User) -> Void
    let dismiss: DismissAction
    
    var body: some View {
        mainList
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    cancelButton
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    saveButton
                }
            }
            .overlay(loadingOverlay)
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(profileViewModel.errorMessage ?? "An error occurred")
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Profile updated successfully")
            }
            .onChange(of: selectedImage) { _, newValue in
                handleImageChange(newValue)
            }
    }
    
    private var mainList: some View {
        List {
            ProfilePhotoSection(viewModel: profileViewModel, selectedImage: $selectedImage)
            BasicInfoSection(username: $username, bio: $bio)
            InterestsSection(categories: categories, selectedCategories: $selectedCategories)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var cancelButton: some View {
        Button("Cancel") { dismiss() }
    }
    
    private var saveButton: some View {
        SaveButton(
            profileViewModel: profileViewModel,
            username: username,
            bio: bio,
            selectedCategories: selectedCategories,
            onSave: onSave,
            showError: $showError,
            showSuccess: $showSuccess
        )
    }
    
    private var loadingOverlay: some View {
        Group {
            if profileViewModel.isLoading {
                LoadingOverlay(message: "Saving changes...")
            }
        }
    }
    
    private func handleImageChange(_ newValue: PhotosPickerItem?) {
        guard let newValue else { return }
        Task {
            do {
                if let data = try await newValue.loadTransferable(type: Data.self) {
                    let imageUrl = try await profileViewModel.uploadProfileImage(data)
                    var updatedUser = profileViewModel.user
                    updatedUser.profileImageUrl = imageUrl
                    await MainActor.run {
                        profileViewModel.user = updatedUser
                        onSave(updatedUser)
                    }
                } else {
                    showError = true
                    profileViewModel.errorMessage = "Failed to load image data"
                }
            } catch {
                showError = true
            }
        }
    }
}

private struct SaveButton: View {
    let profileViewModel: ProfileViewModel
    let username: String
    let bio: String
    let selectedCategories: Set<String>
    let onSave: (User) -> Void
    @Binding var showError: Bool
    @Binding var showSuccess: Bool
    
    var body: some View {
        Button("Save") {
            print("[DEBUG] Save button tapped, starting profile update task.")
            
            Task {
                print("[DEBUG] Updating profile with username: \(username), bio: \(bio), categories: \(selectedCategories)")
                
                do {
                    try await profileViewModel.updateProfile(
                        username: username,
                        bio: bio.isEmpty ? nil : bio,
                        preferredCategories: Array(selectedCategories)
                    )
                    
                    print("[DEBUG] Profile updated successfully")
                    showSuccess = true
                    onSave(profileViewModel.user)
                } catch {
                    print("[DEBUG] Error updating profile: \(error.localizedDescription)")
                    showError = true
                }
            }
        }
        .disabled(profileViewModel.isLoading)
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