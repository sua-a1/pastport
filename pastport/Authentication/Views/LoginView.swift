import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var showError = false
    let authViewModel: AuthenticationViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background color
                Color.pastportBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Logo
                    Image("pastport logo with name")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200)
                        .padding(.top, 32)
                    
                    // Input fields
                    VStack(spacing: 20) {
                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            TextField("Enter your email", text: $email)
                                .textInputAutocapitalization(.never)
                                .padding()
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                                .disabled(authViewModel.isLoading)
                        }
                        
                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            SecureField("Enter your password", text: $password)
                                .padding()
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                                .disabled(authViewModel.isLoading)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Error message
                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }
                    
                    VStack(spacing: 16) {
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
                            HStack {
                                if authViewModel.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Sign In")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue)
                                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                            )
                            .foregroundColor(.white)
                        }
                        .disabled(authViewModel.isLoading)
                        
                        // Register link
                        NavigationLink {
                            RegistrationView(authViewModel: authViewModel)
                        } label: {
                            Text("Don't have an account? Sign up")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                        .disabled(authViewModel.isLoading)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(authViewModel.errorMessage ?? "An error occurred")
            }
        }
    }
} 
