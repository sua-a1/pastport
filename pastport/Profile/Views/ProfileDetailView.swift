import SwiftUI
import FirebaseFirestore

struct ProfileDetailView: View {
    let authViewModel: AuthenticationViewModel
    @StateObject private var viewModel: ProfileViewModel
    @State private var showEditProfile = false
    @State private var showSignOutAlert = false
    @State private var showVideoFeed = false
    @State private var selectedTab = ContentTab.videos
    @State private var scrollOffset: CGFloat = 0
    @State private var selectedVideoIndex: Int = 0
    @Namespace private var animation
    
    init(authViewModel: AuthenticationViewModel) {
        self.authViewModel = authViewModel
        self._viewModel = StateObject(wrappedValue: ProfileViewModel(user: authViewModel.currentUser!))
    }
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Header
                        ProfileHeaderView(
                            user: viewModel.user,
                            showEditProfile: $showEditProfile,
                            userPosts: viewModel.userPosts
                        )
                        
                        CategoriesSection(categories: viewModel.user.preferredCategories)
                        
                        // Custom Tab Bar
                        HStack(spacing: 0) {
                            ForEach(ContentTab.allCases) { tab in
                                TabButton(
                                    tab: tab,
                                    selectedTab: selectedTab,
                                    namespace: animation
                                ) {
                                    withAnimation {
                                        selectedTab = tab
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Tab Content
                        TabView(selection: $selectedTab) {
                            // Videos Tab
                            ScrollView {
                                VideoContentView(
                                    isLoading: viewModel.isLoadingVideos,
                                    videos: viewModel.userPosts,
                                    showVideoFeed: $showVideoFeed,
                                    selectedVideoIndex: $selectedVideoIndex
                                )
                            }
                            .tag(ContentTab.videos)
                            
                            // Drafts Tab
                            DraftContentView(
                                isLoading: viewModel.isLoadingDrafts,
                                drafts: viewModel.userDrafts,
                                onRefresh: {
                                    Task {
                                        await viewModel.fetchUserDrafts()
                                    }
                                }
                            )
                            .padding(.horizontal)
                            .tag(ContentTab.drafts)
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .frame(minHeight: UIScreen.main.bounds.width * 1.5) // Increase minimum height to show all content
                    }
                    .padding(.bottom)
                }
                .refreshable {
                    Task {
                        switch selectedTab {
                        case .videos:
                            await viewModel.fetchUserPosts()
                        case .drafts:
                            await viewModel.fetchUserDrafts()
                        }
                    }
                }
                .onChange(of: selectedTab) { _, newTab in
                    VideoPlayerManager.shared.pause()
                    
                    Task { @MainActor in
                        switch newTab {
                        case .videos:
                            if viewModel.userPosts.isEmpty {
                                await viewModel.fetchUserPosts()
                            }
                        case .drafts:
                            if viewModel.userDrafts.isEmpty {
                                await viewModel.fetchUserDrafts()
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSignOutAlert = true }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.red)
                    }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                NavigationView {
                    ProfileEditView(user: viewModel.user) { updatedUser in
                        Task {
                            await MainActor.run {
                                viewModel.user = updatedUser
                                showEditProfile = false
                            }
                        }
                    }
                }
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
                    authViewModel.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .fullScreenCover(isPresented: $showVideoFeed) {
                ProfileVideoFeedView(posts: viewModel.userPosts, initialIndex: selectedVideoIndex)
            }
            .onChange(of: showVideoFeed) { _, isPresented in
                if !isPresented {
                    // Ensure cleanup when dismissing video feed
                    VideoPlayerManager.shared.pause()
                    Task {
                        print("DEBUG: Refreshing posts after video feed dismissal")
                        try? await Task.sleep(for: .milliseconds(500))
                        await viewModel.fetchUserPosts()
                    }
                }
            }
        }
        .onAppear {
            // Set up notification observer for draft deletion
            NotificationCenter.default.addObserver(
                forName: .draftDeleted,
                object: nil,
                queue: .main
            ) { _ in
                Task {
                    await viewModel.fetchUserDrafts()
                }
            }
        }
        .onDisappear {
            // Remove observer when view disappears
            NotificationCenter.default.removeObserver(
                self,
                name: .draftDeleted,
                object: nil
            )
        }
    }
}

// MARK: - Supporting Views
private struct VideoContentView: View {
    let isLoading: Bool
    let videos: [Post]
    @Binding var showVideoFeed: Bool
    @Binding var selectedVideoIndex: Int
    private let playerManager = VideoPlayerManager.shared
    
    var body: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding()
        } else if videos.isEmpty {
            Text("No videos yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                )
                .padding(.horizontal)
        } else {
            ProfileVideoGridView(videos: videos, showVideoFeed: $showVideoFeed, selectedVideoIndex: $selectedVideoIndex)
                .padding(.vertical, 1)
        }
    }
}

private struct DraftContentView: View {
    let isLoading: Bool
    let drafts: [Draft]
    let onRefresh: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if drafts.isEmpty {
                Text("No drafts yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    )
                    .padding(.horizontal)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(drafts) { draft in
                            DraftRowView(draft: draft, onRefresh: onRefresh)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

private struct DraftRowView: View {
    let draft: Draft
    let onRefresh: () -> Void
    @State private var showDraftDetail = false
    
    var body: some View {
        Button {
            showDraftDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Title and Category
                HStack {
                    Text(draft.title)
                        .font(.headline)
                    Spacer()
                    Text(draft.category.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(.systemGray6))
                        )
                }
                
                // Preview Content
                if !draft.content.isEmpty {
                    Text(draft.content)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                // Attachments and Date
                HStack {
                    // Attachments
                    HStack(spacing: 12) {
                        if !draft.imageUrls.isEmpty {
                            Label("\(draft.imageUrls.count)", systemImage: "photo")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if !draft.videoUrls.isEmpty {
                            Label("\(draft.videoUrls.count)", systemImage: "video")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Date
                    Text(draft.updatedAt.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDraftDetail) {
            NavigationStack {
                DraftDetailView(draft: draft) {
                    onRefresh()
                }
            }
        }
    }
}

// MARK: - Supporting Types
private enum ContentTab: Int, CaseIterable, Identifiable {
    case videos
    case drafts
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .videos: "Videos"
        case .drafts: "Drafts"
        }
    }
}

// MARK: - Supporting Views
private struct StatView: View {
    let value: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct TabButton: View {
    let tab: ContentTab
    let selectedTab: ContentTab
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Text(tab.title)
                .font(.subheadline.weight(selectedTab == tab ? .semibold : .regular))
                .foregroundStyle(selectedTab == tab ? .primary : .secondary)
            
            if selectedTab == tab {
                Rectangle()
                    .fill(.blue)
                    .frame(height: 2)
                    .matchedGeometryEffect(id: "activeTab", in: namespace)
            } else {
                Rectangle()
                    .fill(.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }
}

private struct ProfileHeaderView: View {
    let user: User
    let showEditProfile: Binding<Bool>
    let userPosts: [Post]
    
    var body: some View {
        VStack(spacing: 20) {
            // Profile Image
            if let imageUrl = user.profileImageUrl,
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
                .overlay(Circle().stroke(Color(.systemGray5), lineWidth: 1))
                .shadow(color: .black.opacity(0.1), radius: 4)
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 120, height: 120)
                    .foregroundStyle(.gray)
            }
            
            // Username and Bio
            VStack(spacing: 12) {
                Text(user.username)
                    .font(.title2.weight(.semibold))
                
                if let bio = user.bio {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            // Stats
            HStack(spacing: 40) {
                StatView(value: userPosts.count, label: "Posts")
                StatView(value: user.followersCount, label: "Followers")
                StatView(value: user.followingCount, label: "Following")
            }
            .padding(.vertical, 8)
            
            // Edit Profile Button
            Button(action: { showEditProfile.wrappedValue = true }) {
                Text("Edit Profile")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
        }
        .id("header")
        .padding(.top)
    }
}

private struct CategoriesSection: View {
    let categories: [String]
    
    var body: some View {
        if !categories.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Interests")
                    .font(.headline)
                    .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { category in
                            Text(category)
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemGray6))
                                )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
} 