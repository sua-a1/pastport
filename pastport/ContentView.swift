//
//  ContentView.swift
//  pastport
//
//  Created by Sude Almus on 2/3/25.
//

import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @State private var showError = false
    @State private var errorMessage: String?
    
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
            print("DEBUG: ContentView appeared")
            print("DEBUG: Session: \(String(describing: authViewModel.userSession?.uid))")
            print("DEBUG: Current User: \(String(describing: authViewModel.currentUser?.username))")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationViewModel())
}
