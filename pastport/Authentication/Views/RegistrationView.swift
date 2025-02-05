import SwiftUI

struct RegistrationView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var showError = false
    @Environment(\.dismiss) private var dismiss
    let authViewModel: AuthenticationViewModel
    
    var body: some View {
        VStack {
            Text("Create Account")
                .font(.largeTitle)
                .padding(.top, 32)
            
            VStack(spacing: 24) {
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .textFieldStyle(.roundedBorder)
                    .disabled(authViewModel.isLoading)
                
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
            
            Button {
                print("DEBUG: Sign up button tapped")
                print("DEBUG: Username: \(username)")
                print("DEBUG: Email: \(email)")
                
                guard !username.isEmpty else {
                    authViewModel.errorMessage = "Username is required"
                    showError = true
                    return
                }
                
                guard !email.isEmpty else {
                    authViewModel.errorMessage = "Email is required"
                    showError = true
                    return
                }
                
                guard !password.isEmpty else {
                    authViewModel.errorMessage = "Password is required"
                    showError = true
                    return
                }
                
                Task {
                    do {
                        try await authViewModel.createUser(
                            withEmail: email,
                            password: password,
                            username: username
                        )
                        print("DEBUG: User created successfully")
                        await MainActor.run {
                            dismiss()
                        }
                    } catch {
                        print("DEBUG: Sign up failed: \(error.localizedDescription)")
                        showError = true
                    }
                }
            } label: {
                if authViewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Sign Up")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding()
            .disabled(authViewModel.isLoading)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(authViewModel.errorMessage ?? "An error occurred")
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(authViewModel.isLoading)
            }
        }
    }
} 