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
    
    init() {
        print("DEBUG: Starting app initialization")
        print("DEBUG: App initialization complete")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
        }
    }
}
