import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    @StateObject private var supabaseService = SupabaseService.shared
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // App Logo and Title
                VStack(spacing: 16) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.pink)
                        .accessibilityLabel(Text("Soul-Pal Logo"))
                    
                    Text("Soul-Pal")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text(isSignUp ? "Create your account" : "Welcome back")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                VStack(spacing: 20) {
                    // Email and Password Fields
                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .accessibilityLabel(Text("Email address"))
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(isSignUp ? .newPassword : .password)
                            .accessibilityLabel(Text("Password"))
                    }
                    
                    // Sign In/Up Button
                    Button(action: handleEmailAuth) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            }
                            Text(isSignUp ? "Create Account" : "Sign In")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.pink)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                    .accessibilityLabel(Text(isSignUp ? "Create new account" : "Sign in to your account"))
                    
                    // Toggle Sign In/Up
                    Button(action: { isSignUp.toggle() }) {
                        Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .font(.footnote)
                            .foregroundColor(.pink)
                    }
                    .accessibilityLabel(Text(isSignUp ? "Switch to sign in" : "Switch to sign up"))
                }
                
                // Divider
                HStack {
                    VStack { Divider() }
                    Text("or")
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    VStack { Divider() }
                }
                
                // Social Authentication
                VStack(spacing: 12) {
                    // Sign in with Apple
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { result in
                        Task {
                            await handleAppleSignIn(result)
                        }
                    }
                    .frame(height: 50)
                    .cornerRadius(12)
                    .accessibilityLabel(Text("Sign in with Apple"))
                    
                    // Sign in with Google (placeholder)
                    Button(action: handleGoogleSignIn) {
                        HStack {
                            Image(systemName: "globe")
                            Text("Continue with Google")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .accessibilityLabel(Text("Sign in with Google"))
                }
                
                Spacer()
                
                // Error Message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .accessibilityLabel(Text("Error: \(errorMessage)"))
                }
            }
            .padding(.horizontal, 32)
            .navigationBarHidden(true)
        }
    }
    
    private func handleEmailAuth() {
        guard !email.isEmpty, !password.isEmpty else { return }
        
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                if isSignUp {
                    try await supabaseService.signUpWithEmail(email: email, password: password)
                } else {
                    try await supabaseService.signInWithEmail(email: email, password: password)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            
            isLoading = false
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        Task {
            do {
                try await supabaseService.signInWithApple()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func handleGoogleSignIn() {
        Task {
            do {
                try await supabaseService.signInWithGoogle()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    AuthenticationView()
} 