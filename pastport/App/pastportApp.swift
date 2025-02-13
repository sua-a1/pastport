import SwiftUI
import Firebase

@main
struct pastportApp: App {
    @StateObject private var authViewModel = AuthenticationViewModel()
    
    init() {
        // Initialize Firebase
        FirebaseApp.configure()
        
        // Load environment variables
        if let path = Bundle.main.path(forResource: ".env", ofType: nil),
           let contents = try? String(contentsOfFile: path, encoding: .utf8) {
            let lines = contents.components(separatedBy: .newlines)
            for line in lines {
                let parts = line.components(separatedBy: "=")
                if parts.count == 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                        .replacingOccurrences(of: "\"", with: "")
                    setenv(key, value, 1)
                }
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
        }
    }
} 