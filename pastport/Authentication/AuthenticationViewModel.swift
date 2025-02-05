import Foundation
import FirebaseAuth
import FirebaseFirestore

class AuthenticationViewModel: ObservableObject {
    // User session state
    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: User?
    
    // Loading and error states
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init() {
        // Set initial user session
        self.userSession = Auth.auth().currentUser
        
        // Debug log for initialization
        print("DEBUG: AuthViewModel initialized. User session: \(String(describing: userSession?.uid))")
        
        // Fetch user data if logged in
        Task {
            await fetchUser()
        }
    }
    
    // MARK: - User Session Management
    
    func signIn(withEmail email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.userSession = result.user
            await fetchUser()
            print("DEBUG: User signed in successfully: \(result.user.uid)")
        } catch {
            print("DEBUG: Failed to sign in: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func createUser(withEmail email: String, password: String, username: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            self.userSession = result.user
            
            // Create user profile with required fields and default values
            let user = User(
                id: result.user.uid,
                username: username,
                email: email,
                dateJoined: Date(),
                lastActive: Date()
            )
            
            // Convert to dictionary and store in Firestore
            let encodedUser = try Firestore.Encoder().encode(user)
            try await Firestore.firestore().collection("users").document(user.id).setData(encodedUser)
            
            self.currentUser = user
            print("DEBUG: Created user \(result.user.uid) and profile")
        } catch {
            print("DEBUG: Failed to create user: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.userSession = nil
            self.currentUser = nil
            print("DEBUG: User signed out successfully")
        } catch {
            print("DEBUG: Failed to sign out: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func fetchUser() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        do {
            let snapshot = try await Firestore.firestore().collection("users").document(uid).getDocument()
            self.currentUser = try snapshot.data(as: User.self)
            print("DEBUG: Fetched user data for \(uid)")
        } catch {
            print("DEBUG: Failed to fetch user: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    func migrateExistingUserToFirestore() async throws {
        guard let currentAuthUser = Auth.auth().currentUser else {
            print("DEBUG: No authenticated user found to migrate")
            return
        }
        
        // Check if user document already exists
        let userDoc = Firestore.firestore().collection("users").document(currentAuthUser.uid)
        let snapshot = try await userDoc.getDocument()
        
        if !snapshot.exists {
            // Create new user profile
            let user = User(
                id: currentAuthUser.uid,
                username: currentAuthUser.email?.components(separatedBy: "@").first ?? "user",
                email: currentAuthUser.email ?? "",
                dateJoined: Date(),
                lastActive: Date()
            )
            
            // Save to Firestore
            let encodedUser = try Firestore.Encoder().encode(user)
            try await userDoc.setData(encodedUser)
            
            self.currentUser = user
            print("DEBUG: Migrated existing user \(currentAuthUser.uid) to Firestore")
        } else {
            print("DEBUG: User document already exists in Firestore")
        }
    }
} 