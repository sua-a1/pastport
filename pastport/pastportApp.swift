//
//  pastportApp.swift
//  pastport
//
//  Created by Sude Almus on 2/3/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

@main
struct pastportApp: App {
    // Initialize Firebase
    init() {
        FirebaseApp.configure()
        print("DEBUG: Firebase initialized")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
