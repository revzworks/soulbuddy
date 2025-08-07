import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @StateObject private var authService = AuthService.shared
    @State private var showEmailSignIn = false
    @State private var showEmailSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSignUp = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    headerSection
                    
                    if authService.isLoading {
                        loadingSection
                    } else {
                        authOptionsSection
                    }
                    
                    if let error = authService.authError {
                        errorSection(error)
                    }
                    
                    Spacer(minLength: Theme.Spacing.xl)
                }
                .screenPadding()
            }
            .background(Theme.Colors.background)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showEmailSignIn) {
            EmailAuthSheet(
                isSignUp: $isSignUp,
                email: $email,
                password: $password,
                confirmPassword: $confirmPassword,
                authService: authService
            )
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // App Logo/Icon
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(Theme.Colors.primary)
            
            VStack(spacing: Theme.Spacing.sm) {
                Text("Welcome to SoulBuddy")
                    .font(Theme.Typography.largeTitle)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Your personal companion for daily affirmations and mindfulness")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, Theme.Spacing.xxl)
    }
    
    // MARK: - Loading Section
    private var loadingSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Signing you in...")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .padding(.vertical, Theme.Spacing.xl)
    }
    
    // MARK: - Auth Options Section
    private var authOptionsSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Apple Sign In
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                // Handle result in AuthService
                Task {
                    do {
                        try await authService.signInWithApple()
                    } catch {
                        print("Apple Sign In error in button completion: \(error)")
                    }
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(Theme.CornerRadius.button)
            
            // Google Sign In Button
            Button(action: {
                Task {
                    do {
                        try await authService.signInWithGoogle()
                    } catch {
                        // Error is handled in AuthService
                    }
                }
            }) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "globe")
                        .font(.system(size: Theme.IconSize.md))
                    
                    Text("Continue with Google")
                        .font(Theme.Typography.body)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundColor(.white)
                .background(Color.blue)
                .cornerRadius(Theme.CornerRadius.button)
            }
            .disabled(authService.isLoading)
            
            // Email Sign In Button
            Button(action: {
                isSignUp = false
                showEmailSignIn = true
            }) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "envelope")
                        .font(.system(size: Theme.IconSize.md))
                    
                    Text("Continue with Email")
                        .font(Theme.Typography.body)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundColor(.white)
                .background(Theme.Colors.buttonSecondary)
                .cornerRadius(Theme.CornerRadius.button)
            }
            .disabled(authService.isLoading)
            
            // Divider
            HStack {
                Rectangle()
                    .fill(Theme.Colors.divider)
                    .frame(height: 1)
                
                Text("or")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)
                    .padding(.horizontal, Theme.Spacing.md)
                
                Rectangle()
                    .fill(Theme.Colors.divider)
                    .frame(height: 1)
            }
            .padding(.vertical, Theme.Spacing.sm)
            
            // Sign Up Button
            Button(action: {
                isSignUp = true
                showEmailSignIn = true
            }) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text("Create Account")
                        .font(Theme.Typography.body)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundColor(Theme.Colors.textPrimary)
                .background(Theme.Colors.surface)
                .cornerRadius(Theme.CornerRadius.button)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.button)
                        .stroke(Theme.Colors.border, lineWidth: 1)
                )
            }
            .disabled(authService.isLoading)
        }
    }
    
    // MARK: - Error Section
    private func errorSection(_ error: AuthError) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(error.localizedDescription)
                .font(Theme.Typography.caption)
                .foregroundColor(.red)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            Button("Dismiss") {
                Task { @MainActor in
                    authService.authError = nil
                }
            }
            .font(Theme.Typography.caption)
            .foregroundColor(.red)
        }
        .padding(Theme.Spacing.md)
        .background(Color.red.opacity(0.1))
        .cornerRadius(Theme.CornerRadius.sm)
    }
}

// MARK: - Email Auth Sheet
struct EmailAuthSheet: View {
    @Binding var isSignUp: Bool
    @Binding var email: String
    @Binding var password: String
    @Binding var confirmPassword: String
    let authService: AuthService
    
    @Environment(\.presentationMode) var presentationMode
    @State private var isLoading = false
    @State private var localError: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    headerSection
                    formSection
                    
                    if let error = localError {
                        errorSection(error)
                    }
                    
                    actionButton
                    
                    toggleModeButton
                }
                .screenPadding()
            }
            .background(Theme.Colors.background)
            .navigationTitle(isSignUp ? "Create Account" : "Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text(isSignUp ? "Create your account" : "Welcome back")
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.textPrimary)
            
            Text(isSignUp ? "Enter your details to get started" : "Sign in to continue")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .padding(.top, Theme.Spacing.lg)
    }
    
    private var formSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Email Field
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Email")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                
                TextField("Enter your email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            // Password Field
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Password")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                
                SecureField("Enter your password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(isSignUp ? .newPassword : .password)
            }
            
            // Confirm Password Field (Sign Up only)
            if isSignUp {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Confirm Password")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    SecureField("Confirm your password", text: $confirmPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.newPassword)
                }
            }
        }
    }
    
    private func errorSection(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(error)
                .font(Theme.Typography.caption)
                .foregroundColor(.red)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(Theme.Spacing.sm)
        .background(Color.red.opacity(0.1))
        .cornerRadius(Theme.CornerRadius.sm)
    }
    
    private var actionButton: some View {
        Button(action: handleAuth) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                }
                
                Text(isSignUp ? "Create Account" : "Sign In")
                    .font(Theme.Typography.body)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundColor(.white)
            .background(isFormValid ? Theme.Colors.primary : Theme.Colors.buttonDisabled)
            .cornerRadius(Theme.CornerRadius.button)
        }
        .disabled(!isFormValid || isLoading)
    }
    
    private var toggleModeButton: some View {
        Button(action: {
            isSignUp.toggle()
            localError = nil
        }) {
            HStack(spacing: Theme.Spacing.xs) {
                Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                
                Text(isSignUp ? "Sign In" : "Sign Up")
                    .font(Theme.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.Colors.primary)
            }
        }
        .padding(.top, Theme.Spacing.md)
    }
    
    private var isFormValid: Bool {
        let emailValid = !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && email.contains("@")
        let passwordValid = password.count >= 6
        
        if isSignUp {
            return emailValid && passwordValid && (password == confirmPassword)
        } else {
            return emailValid && passwordValid
        }
    }
    
    private func handleAuth() {
        localError = nil
        isLoading = true
        
        Task {
            do {
                if isSignUp {
                    try await authService.signUpWithEmail(
                        email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                        password: password
                    )
                } else {
                    try await authService.signInWithEmail(
                        email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                        password: password
                    )
                }
                
                await MainActor.run {
                    presentationMode.wrappedValue.dismiss()
                }
                
            } catch {
                await MainActor.run {
                    localError = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Preview
#Preview("Auth View") {
    AuthView()
}

#Preview("Email Sign In") {
    EmailAuthSheet(
        isSignUp: .constant(false),
        email: .constant(""),
        password: .constant(""),
        confirmPassword: .constant(""),
        authService: AuthService.shared
    )
}

#Preview("Email Sign Up") {
    EmailAuthSheet(
        isSignUp: .constant(true),
        email: .constant(""),
        password: .constant(""),
        confirmPassword: .constant(""),
        authService: AuthService.shared
    )
} 