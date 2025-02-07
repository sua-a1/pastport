import SwiftUI

struct RegistrationView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var showError = false
    @Environment(\.dismiss) var dismiss
    let authViewModel: AuthenticationViewModel
    
    var body: some View {
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
                    // Username field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("Choose a username", text: $username)
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
                        SecureField("Create a password", text: $password)
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
                    // Sign up button
                    Button {
                        Task {
                            do {
                                try await authViewModel.createUser(withEmail: email,
                                                                 password: password,
                                                                 username: username)
                                dismiss()
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
                                Text("Sign Up")
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
                    
                    // Back to sign in
                    Button {
                        dismiss()
                    } label: {
                        Text("Already have an account? Sign in")
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