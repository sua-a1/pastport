import SwiftUI
import PhotosUI

struct ProfileView: View {
    @State private var profileViewModel: ProfileViewModel
    @State private var username: String
    @State private var bio: String
    @State private var selectedCategories: Set<String> = []
    @State private var showError = false
    @State private var showImagePicker = false
    @State private var selectedImage: PhotosPickerItem?
    
    private let categories = ["History", "Mythology", "Ancient Civilizations", "Folklore", "Legends"]
    
    init(user: User) {
        let viewModel = ProfileViewModel(user: user)
        _profileViewModel = State(initialValue: viewModel)
        _username = State(initialValue: user.username)
        _bio = State(initialValue: user.bio ?? "")
        if !user.preferredCategories.isEmpty {
            _selectedCategories = State(initialValue: Set(user.preferredCategories))
        }
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
            
            Section("Account Info") {
                LabeledContent("Email", value: profileViewModel.user.email)
                LabeledContent("Member Since", value: profileViewModel.user.dateJoined.formatted(date: .abbreviated, time: .omitted))
            }
            
            Section("Stats") {
                LabeledContent("Posts", value: "\(profileViewModel.user.postsCount)")
                LabeledContent("Followers", value: "\(profileViewModel.user.followersCount)")
                LabeledContent("Following", value: "\(profileViewModel.user.followingCount)")
            }
        }
        .navigationTitle("Edit Profile")
        .toolbar {
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
        .onChange(of: selectedImage) { _, newValue in
            guard let newValue else { return }
            Task {
                do {
                    if let data = try await newValue.loadTransferable(type: Data.self) {
                        let _ = try await profileViewModel.uploadProfileImage(data)
                    }
                } catch {
                    showError = true
                }
            }
        }
    }
} 