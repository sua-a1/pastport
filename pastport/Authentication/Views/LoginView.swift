import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var showError = false
    let authViewModel: AuthenticationViewModel
    
    var body: some View {
        NavigationStack {
            VStack {
                // Logo/Header
                Text("Pastport")
                    .font(.largeTitle)
                    .padding(.top, 32)
                
                // Input fields
                VStack(spacing: 24) {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .textFieldStyle(.roundedBorder)
                        .disabled(authViewModel.isLoading)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .disabled(authViewModel.isLoading)
                }
                .padding(.horizontal)
                .padding(.top, 24)
                
                // Error message
                if let error = authViewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
                // Sign in button
                Button {
                    Task {
                        do {
                            try await authViewModel.signIn(withEmail: email, password: password)
                        } catch {
                            showError = true
                        }
                    }
                } label: {
                    if authViewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Sign In")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding()
                .disabled(authViewModel.isLoading)
                
                // Register link
                NavigationLink {
                    RegistrationView(authViewModel: authViewModel)
                } label: {
                    Text("Don't have an account? Sign up")
                        .foregroundColor(.blue)
                }
                .disabled(authViewModel.isLoading)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(authViewModel.errorMessage ?? "An error occurred")
            }
        }
    }
} 
