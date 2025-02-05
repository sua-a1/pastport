import SwiftUI

struct ProfileDetailView: View {
    @ObservedObject var authViewModel: AuthenticationViewModel
    @State private var showEditProfile = false
    @State private var showSignOutAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Header
                VStack(spacing: 16) {
                    if let imageUrl = authViewModel.currentUser?.profileImageUrl,
                       let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 120, height: 120)
                            .foregroundColor(.gray)
                    }
                    
                    if let user = authViewModel.currentUser {
                        Text(user.username)
                            .font(.title2)
                            .bold()
                        
                        if let bio = user.bio {
                            Text(bio)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                        }
                        
                        // Stats
                        HStack(spacing: 40) {
                            VStack {
                                Text("\(user.postsCount)")
                                    .font(.headline)
                                Text("Posts")
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack {
                                Text("\(user.followersCount)")
                                    .font(.headline)
                                Text("Followers")
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack {
                                Text("\(user.followingCount)")
                                    .font(.headline)
                                Text("Following")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        
                        // Categories
                        if !user.preferredCategories.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(user.preferredCategories, id: \.self) { category in
                                        Text(category)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(20)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Edit Profile Button
                    Button {
                        showEditProfile = true
                    } label: {
                        Text("Edit Profile")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(width: 150)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
        }
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Sign Out", role: .destructive) {
                        showSignOutAlert = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $showEditProfile) {
            NavigationStack {
                if let user = authViewModel.currentUser {
                    ProfileEditView(user: user) { updatedUser in
                        Task {
                            await authViewModel.updateCurrentUser(updatedUser)
                            showEditProfile = false
                        }
                    }
                }
            }
        }
        .refreshable {
            await authViewModel.fetchUser()
        }
        .onChange(of: showEditProfile) { _, isPresented in
            if !isPresented {
                Task {
                    await authViewModel.fetchUser()
                }
            }
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                authViewModel.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
} 