import SwiftUI
import PhotosUI

struct ProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @State private var showingEditProfile = false
    
    var body: some View {
        NavigationStack {
            ProfileFormView(viewModel: viewModel)
                .navigationTitle("Edit Profile")
                .sheet(isPresented: $showingEditProfile) {
                    ProfileEditView(user: viewModel.user) { updatedUser in
                        Task {
                            try? await viewModel.updateProfile(
                                username: updatedUser.username,
                                bio: updatedUser.bio,
                                preferredCategories: updatedUser.preferredCategories
                            )
                        }
                        showingEditProfile = false
                    }
                }
        }
        .task {
            await viewModel.fetchUserDrafts()
        }
        .onAppear {
            // Add observers for draft updates
            NotificationCenter.default.addObserver(
                forName: .draftDeleted,
                object: nil,
                queue: .main
            ) { _ in
                Task {
                    await viewModel.fetchUserDrafts()
                }
            }
            
            NotificationCenter.default.addObserver(
                forName: .draftUpdated,
                object: nil,
                queue: .main
            ) { _ in
                Task {
                    await viewModel.fetchUserDrafts()
                }
            }
            
            NotificationCenter.default.addObserver(
                forName: .draftCreated,
                object: nil,
                queue: .main
            ) { _ in
                Task {
                    await viewModel.fetchUserDrafts()
                }
            }
        }
        .onDisappear {
            // Remove observers
            NotificationCenter.default.removeObserver(self, name: .draftDeleted, object: nil)
            NotificationCenter.default.removeObserver(self, name: .draftUpdated, object: nil)
            NotificationCenter.default.removeObserver(self, name: .draftCreated, object: nil)
        }
    }
}

// MARK: - Profile Form View
struct ProfileFormView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @State private var username: String
    @State private var bio: String
    @State private var selectedCategories: Set<String> = []
    @State private var showError = false
    @State private var selectedImage: PhotosPickerItem?
    
    private let categories = ["History", "Mythology", "Ancient Civilizations", "Folklore", "Legends"]
    
    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
        _username = State(initialValue: viewModel.user.username)
        _bio = State(initialValue: viewModel.user.bio ?? "")
        _selectedCategories = State(initialValue: Set(viewModel.user.preferredCategories))
    }
    
    var body: some View {
        Form {
            ProfilePhotoSection(viewModel: viewModel, selectedImage: $selectedImage)
            BasicInfoSection(username: $username, bio: $bio)
            InterestsSection(categories: categories, selectedCategories: $selectedCategories)
            AccountInfoSection(user: viewModel.user)
            StatsSection(user: viewModel.user)
        }
        .onChange(of: selectedImage) { _, newValue in
            handleImageSelection(newValue)
        }
    }
    
    private func handleImageSelection(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    let _ = try await viewModel.uploadProfileImage(data)
                }
            } catch {
                showError = true
            }
        }
    }
}

// MARK: - Profile Sections
struct ProfilePhotoSection: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Binding var selectedImage: PhotosPickerItem?
    
    var body: some View {
        Section("Profile Photo") {
            HStack {
                ProfileImageView(imageUrl: viewModel.user.profileImageUrl)
                PhotosPicker(selection: $selectedImage, matching: .images) {
                    Text("Change Photo")
                }
            }
        }
    }
}

struct BasicInfoSection: View {
    @Binding var username: String
    @Binding var bio: String
    
    var body: some View {
        Section("Basic Info") {
            TextField("Username", text: $username)
                .textInputAutocapitalization(.never)
            TextField("Bio", text: $bio, axis: .vertical)
                .lineLimit(3...6)
        }
    }
}

struct InterestsSection: View {
    let categories: [String]
    @Binding var selectedCategories: Set<String>
    
    var body: some View {
        Section("Interests") {
            ForEach(categories, id: \.self) { category in
                Toggle(category, isOn: .init(
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
}

struct AccountInfoSection: View {
    let user: User
    
    var body: some View {
        Section("Account Info") {
            LabeledContent("Email", value: user.email)
            LabeledContent("Member Since", value: user.dateJoined.formatted(date: .abbreviated, time: .omitted))
        }
    }
}

struct StatsSection: View {
    let user: User
    
    var body: some View {
        Section("Stats") {
            LabeledContent("Posts", value: "\(user.postsCount)")
            LabeledContent("Followers", value: "\(user.followersCount)")
            LabeledContent("Following", value: "\(user.followingCount)")
        }
    }
}

struct ProfileImageView: View {
    let imageUrl: String?
    
    var body: some View {
        if let imageUrl = imageUrl,
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
    }
} 