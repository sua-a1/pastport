//
//  pastportApp.swift
//  pastport
//
//  Created by Sude Almus on 2/3/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import UIKit
import Foundation

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("DEBUG: Starting AppDelegate initialization")
        FirebaseApp.configure()
        print("DEBUG: Firebase initialized")
        return true
    }
}

@main
struct pastportApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authViewModel = AuthenticationViewModel()
    @State private var isLoading = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Background color
                Color.pastportBackground
                    .ignoresSafeArea()
                
                if isLoading {
                    AppLoadingView()
                } else {
                    ContentView()
                        .environmentObject(authViewModel)
                }
            }
            .task {
                // Simulate a brief loading time for smooth transition
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.easeInOut(duration: 0.5)) {
                    isLoading = false
                }
            }
        }
    }
}
