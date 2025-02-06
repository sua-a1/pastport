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
        Form {
            Section("Profile Photo") {
                HStack {
                    if let imageUrl = profileViewModel.user.profileImageUrl,
                       let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.gray)
                    }
                    
                    PhotosPicker(selection: $selectedImage,
                                matching: .images) {
                        Text("Change Photo")
                            .foregroundColor(.blue)
                    }
                    .disabled(profileViewModel.isLoading)
                    
                    if profileViewModel.isLoading {
                        ProgressView()
                            .padding(.leading)
                    }
                }
            }
            
            Section("Basic Info") {
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                TextField("Bio", text: $bio, axis: .vertical)
                    .lineLimit(3...6)
            }
            
            Section("Interests") {
                ForEach(categories, id: \.self) { category in
                    Toggle(category, isOn: Binding(
                        get: { selectedCategories.contains(category) },
                        set: { isSelected in
                            if isSelected {
                                selectedCategories.insert(category)
                            } else {
                                selectedCategories.remove(category)
                            }
                        }
                    ))
                }
            }
        }
        .navigationTitle("Edit Profile")
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
                        // Get the updated URL from the upload
                        let imageUrl = try await profileViewModel.uploadProfileImage(data)
                        print("DEBUG: Successfully got image URL: \(imageUrl)")
                        
                        // Immediately update the current user and notify parent
                        var updatedUser = profileViewModel.user
                        updatedUser.profileImageUrl = imageUrl
                        
                        await MainActor.run {
                            profileViewModel.user = updatedUser
                            onSave(updatedUser) // Notify parent view immediately
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