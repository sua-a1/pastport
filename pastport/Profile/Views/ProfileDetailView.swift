import SwiftUI

struct ProfileDetailView: View {
    let authViewModel: AuthenticationViewModel
    @StateObject private var viewModel: ProfileViewModel
    @State private var showEditProfile = false
    @State private var showSignOutAlert = false
    
    init(authViewModel: AuthenticationViewModel) {
        self.authViewModel = authViewModel
        self._viewModel = StateObject(wrappedValue: ProfileViewModel(user: authViewModel.currentUser!))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header
                    VStack(spacing: 15) {
                        // Profile Image
                        if let imageUrl = viewModel.user.profileImageUrl,
                           let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.gray)
                        }
                        
                        // Username and Bio
                        VStack(spacing: 8) {
                            Text(viewModel.user.username)
                                .font(.title2)
                                .bold()
                            
                            if let bio = viewModel.user.bio {
                                Text(bio)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        }
                        
                        // Stats
                        HStack(spacing: 40) {
                            VStack {
                                Text("\(viewModel.userPosts.count)")
                                    .font(.headline)
                                Text("Posts")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack {
                                Text("0")
                                    .font(.headline)
                                Text("Followers")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack {
                                Text("0")
                                    .font(.headline)
                                Text("Following")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 8)
                        
                        // Edit Profile Button
                        Button(action: { showEditProfile = true }) {
                            Text("Edit Profile")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(width: 180, height: 32)
                                .foregroundColor(.black)
                                .background(Color(.systemGray5))
                                .cornerRadius(6)
                        }
                    }
                    .padding(.top)
                    
                    // Video Grid
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if viewModel.userPosts.isEmpty {
                        Text("No videos yet")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        ProfileVideoGridView(videos: viewModel.userPosts)
                            .padding(.horizontal, 1)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSignOutAlert = true }) {
                        Text("Sign Out")
                            .foregroundColor(.red)
                    }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                NavigationView {
                    ProfileEditView(user: viewModel.user) { updatedUser in
                        Task {
                            do {
                                try await viewModel.updateProfile(
                                    username: updatedUser.username,
                                    bio: updatedUser.bio,
                                    preferredCategories: updatedUser.preferredCategories
                                )
                                await MainActor.run {
                                    showEditProfile = false
                                }
                            } catch {
                                print("DEBUG: Failed to update profile: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.fetchUserPosts()
            }
            .onChange(of: showEditProfile) { _, isPresented in
                if !isPresented {
                    Task {
                        await viewModel.fetchUserPosts()
                    }
                }
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        await authViewModel.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
} 