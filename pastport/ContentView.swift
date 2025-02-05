//
//  ContentView.swift
//  pastport
//
//  Created by Sude Almus on 2/3/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthenticationViewModel()
    
    var body: some View {
        Group {
            if authViewModel.userSession != nil {
                NavigationStack {
                    if let user = authViewModel.currentUser {
                        ProfileDetailView(
                            user: .constant(user),
                            authViewModel: authViewModel
                        )
                    }
                }
            } else {
                LoginView(authViewModel: authViewModel)
            }
        }
        .preferredColorScheme(.light) // Forces light mode
    }
}

#Preview {
    ContentView()
}
