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
            if authViewModel.userSession != nil && authViewModel.currentUser != nil {
                MainTabView(authViewModel: authViewModel)
            } else {
                LoginView(authViewModel: authViewModel)
            }
        }
        .preferredColorScheme(.light) // Forces light mode
        .onAppear {
            print("DEBUG: Session: \(String(describing: authViewModel.userSession?.uid))")
            print("DEBUG: Current User: \(String(describing: authViewModel.currentUser?.username))")
        }
    }
}

#Preview {
    ContentView()
}
