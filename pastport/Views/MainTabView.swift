import SwiftUI

struct MainTabView: View {
    let authViewModel: AuthenticationViewModel
    @State private var selectedTab = 0
    @State private var showVideoCreation = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Text("Home")
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }
                .tag(0)
            
            Text("Discover")
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Discover")
                }
                .tag(1)
            
            Button(action: { showVideoCreation = true }) {
                Image(systemName: "plus.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 45, height: 45)
                    .foregroundStyle(.white, .blue)
            }
            .tabItem {
                Image(systemName: "plus")
                Text("Create")
            }
            .tag(2)
            
            Text("Inbox")
                .tabItem {
                    Image(systemName: "message")
                    Text("Inbox")
                }
                .tag(3)
            
            if let user = authViewModel.currentUser {
                ProfileDetailView(authViewModel: authViewModel)
                    .tabItem {
                        Image(systemName: "person")
                        Text("Profile")
                    }
                    .tag(4)
            }
        }
        .sheet(isPresented: $showVideoCreation) {
            VideoRecordingView()
        }
    }
}

struct CreateButtonView: View {
    @Binding var showVideoCreation: Bool
    
    var body: some View {
        Button {
            showVideoCreation = true
        } label: {
            Image(systemName: "plus.circle.fill")
                .resizable()
                .frame(width: 45, height: 45)
                .foregroundStyle(.white, .blue)
        }
        .frame(height: 50)
    }
} 