import Foundation
import Supabase
import AuthenticationServices
import GoogleSignIn
import Combine

// MARK: - Auth Service
@MainActor
class AuthService: NSObject, ObservableObject {
    
    // MARK: - Singleton
    static let shared = AuthService()
    
    // MARK: - Published Properties
    @Published var currentUser: User?
    @Published var currentSession: Session?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var authError: AuthError?
    
    // MARK: - Private Properties
    private var supabaseClient: SupabaseClient {
        get throws {
            return try SupabaseClientManager.shared.getClient()
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    private let config = SupabaseConfig.shared
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupAuthStateListener()
        
        // Configure Google Sign In
        configureGoogleSignIn()
    }
    
    // MARK: - Auth State Management
    private func setupAuthStateListener() {
        // Listen to auth state changes from SupabaseClientManager
        SupabaseClientManager.shared.$isInitialized
            .sink { [weak self] isInitialized in
                if isInitialized {
                    Task { @MainActor in
                        await self?.setupSupabaseAuthListener()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupSupabaseAuthListener() async {
        do {
            let client = try supabaseClient
            
            // Listen to auth state changes
            client.auth.authStateChanges
                .sink { [weak self] authChangeEvent, session in
                    Task { @MainActor in
                        await self?.handleAuthStateChange(event: authChangeEvent, session: session)
                    }
                }
                .store(in: &cancellables)
            
            // Get current session if available
            if let session = try? await client.auth.session {
                await handleAuthStateChange(event: .signedIn, session: session)
            }
            
        } catch {
            print("❌ Failed to setup auth listener: \(error)")
            await setAuthError(.clientError(error))
        }
    }
    
    private func handleAuthStateChange(event: AuthChangeEvent, session: Session?) async {
        switch event {
        case .signedIn:
            if let session = session {
                self.currentSession = session
                self.currentUser = session.user
                self.isAuthenticated = true
                self.authError = nil
                
                print("✅ User signed in: \(session.user.id)")
                await logAuthEvent("sign_in", provider: getAuthProvider(from: session))
            }
            
        case .signedOut:
            await handleSignOut()
            print("✅ User signed out")
            
        case .tokenRefreshed:
            if let session = session {
                self.currentSession = session
                print("🔄 Token refreshed")
            }
            
        default:
            break
        }
    }
    
    // MARK: - Apple Sign In
    func signInWithApple() async throws {
        await setLoading(true)
        defer { Task { @MainActor in await setLoading(false) } }
        
        do {
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            
            // This will trigger the delegate methods
            authorizationController.performRequests()
            
        } catch {
            print("❌ Apple Sign In failed: \(error)")
            await setAuthError(.appleSignInFailed(error))
            throw error
        }
    }
    
    private func handleAppleSignInSuccess(_ authorization: ASAuthorization) async {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            await setAuthError(.appleSignInFailed(NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Apple ID credential"])))
            return
        }
        
        guard let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            await setAuthError(.appleSignInFailed(NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get identity token"])))
            return
        }
        
        do {
            let client = try supabaseClient
            let session = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: identityToken
                )
            )
            
            print("✅ Apple Sign In successful: \(session.user.id)")
            
        } catch {
            print("❌ Apple token exchange failed: \(error)")
            await setAuthError(.tokenExchangeFailed(error))
        }
    }
    
    // MARK: - Google Sign In
    private func configureGoogleSignIn() {
        // Configure Google Sign In with your client ID
        // This should be set in your .xcconfig files
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let clientId = plist["CLIENT_ID"] as? String {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
        } else {
            print("⚠️ Google Service Info not found - Google Sign In may not work")
        }
    }
    
    func signInWithGoogle() async throws {
        await setLoading(true)
        defer { Task { @MainActor in await setLoading(false) } }
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            await setAuthError(.googleSignInFailed(NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No root view controller found"])))
            return
        }
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            guard let idToken = result.user.idToken?.tokenString else {
                await setAuthError(.googleSignInFailed(NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get ID token"])))
                return
            }
            
            // Exchange Google token with Supabase
            let client = try supabaseClient
            let session = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .google,
                    idToken: idToken
                )
            )
            
            print("✅ Google Sign In successful: \(session.user.id)")
            
        } catch {
            print("❌ Google Sign In failed: \(error)")
            await setAuthError(.googleSignInFailed(error))
            throw error
        }
    }
    
    // MARK: - Email/Password Authentication
    func signInWithEmail(email: String, password: String) async throws {
        await setLoading(true)
        defer { Task { @MainActor in await setLoading(false) } }
        
        do {
            let client = try supabaseClient
            let session = try await client.auth.signIn(email: email, password: password)
            
            print("✅ Email sign in successful: \(session.user.id)")
            
        } catch {
            print("❌ Email sign in failed: \(error)")
            await setAuthError(.emailSignInFailed(error))
            throw error
        }
    }
    
    func signUpWithEmail(email: String, password: String, metadata: [String: Any] = [:]) async throws {
        await setLoading(true)
        defer { Task { @MainActor in await setLoading(false) } }
        
        do {
            let client = try supabaseClient
            let session = try await client.auth.signUp(
                email: email,
                password: password,
                data: metadata
            )
            
            print("✅ Email sign up successful: \(session.user.id)")
            
        } catch {
            print("❌ Email sign up failed: \(error)")
            await setAuthError(.emailSignUpFailed(error))
            throw error
        }
    }
    
    // MARK: - Provider Linking
    func linkProvider(_ provider: AuthProvider) async throws {
        guard isAuthenticated else {
            throw AuthError.notAuthenticated
        }
        
        await setLoading(true)
        defer { Task { @MainActor in await setLoading(false) } }
        
        switch provider {
        case .apple:
            // Implement Apple provider linking
            try await linkAppleProvider()
        case .google:
            // Implement Google provider linking
            try await linkGoogleProvider()
        case .email:
            throw AuthError.providerLinkingNotSupported("Email linking requires separate flow")
        }
    }
    
    private func linkAppleProvider() async throws {
        // Similar to sign in but using linkIdentity
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        // This would need to be implemented with proper linking flow
        throw AuthError.providerLinkingNotSupported("Apple provider linking not yet implemented")
    }
    
    private func linkGoogleProvider() async throws {
        // Similar to sign in but using linkIdentity
        throw AuthError.providerLinkingNotSupported("Google provider linking not yet implemented")
    }
    
    // MARK: - Sign Out
    func signOut() async throws {
        await setLoading(true)
        defer { Task { @MainActor in await setLoading(false) } }
        
        do {
            let client = try supabaseClient
            try await client.auth.signOut()
            
            // Clear Google Sign In session
            GIDSignIn.sharedInstance.signOut()
            
            await handleSignOut()
            
            print("✅ Sign out successful")
            
        } catch {
            print("❌ Sign out failed: \(error)")
            await setAuthError(.signOutFailed(error))
            throw error
        }
    }
    
    private func handleSignOut() async {
        self.currentUser = nil
        self.currentSession = nil
        self.isAuthenticated = false
        self.authError = nil
        
        // Clear any cached data
        await clearCachedData()
        
        await logAuthEvent("sign_out", provider: nil)
    }
    
    // MARK: - Utility Methods
    private func clearCachedData() async {
        // Clear user defaults, keychain, or other cached data
        UserDefaults.standard.removeObject(forKey: "cached_user_data")
        // Add other cleanup as needed
    }
    
    private func getAuthProvider(from session: Session) -> String? {
        // Extract provider from session metadata
        return session.user.appMetadata["provider"] as? String
    }
    
    private func logAuthEvent(_ event: String, provider: String?) async {
        guard config.logLevel.isEnabled else { return }
        
        do {
            let client = try supabaseClient
            let props: [String: Any] = [
                "provider": provider ?? "unknown",
                "user_id": currentUser?.id.uuidString ?? "anonymous",
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
            
            let _: [String: Any] = try await client.database
                .rpc("log_analytics_event", params: [
                    "event_name": "auth_\(event)",
                    "event_props": props
                ])
                .execute()
                .value
            
        } catch {
            if config.logLevel == .debug {
                print("⚠️ Failed to log auth event: \(error)")
            }
        }
    }
    
    @MainActor
    private func setLoading(_ loading: Bool) async {
        self.isLoading = loading
    }
    
    @MainActor
    private func setAuthError(_ error: AuthError?) async {
        self.authError = error
    }
}

// MARK: - Apple Sign In Delegates
extension AuthService: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            await handleAppleSignInSuccess(authorization)
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            print("❌ Apple Sign In delegate error: \(error)")
            await setAuthError(.appleSignInFailed(error))
        }
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window found for Apple Sign In presentation")
        }
        return window
    }
}

// MARK: - Auth Provider Enum
enum AuthProvider: String, CaseIterable {
    case apple = "apple"
    case google = "google"
    case email = "email"
    
    var displayName: String {
        switch self {
        case .apple: return "Apple"
        case .google: return "Google"
        case .email: return "Email"
        }
    }
    
    var iconName: String {
        switch self {
        case .apple: return "applelogo"
        case .google: return "globe"
        case .email: return "envelope"
        }
    }
}

// MARK: - Auth Errors
enum AuthError: LocalizedError, Equatable {
    case notAuthenticated
    case clientError(Error)
    case appleSignInFailed(Error)
    case googleSignInFailed(Error)
    case emailSignInFailed(Error)
    case emailSignUpFailed(Error)
    case tokenExchangeFailed(Error)
    case providerLinkingNotSupported(String)
    case signOutFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .clientError(let error):
            return "Client error: \(error.localizedDescription)"
        case .appleSignInFailed(let error):
            return "Apple Sign In failed: \(error.localizedDescription)"
        case .googleSignInFailed(let error):
            return "Google Sign In failed: \(error.localizedDescription)"
        case .emailSignInFailed(let error):
            return "Email sign in failed: \(error.localizedDescription)"
        case .emailSignUpFailed(let error):
            return "Email sign up failed: \(error.localizedDescription)"
        case .tokenExchangeFailed(let error):
            return "Token exchange failed: \(error.localizedDescription)"
        case .providerLinkingNotSupported(let message):
            return "Provider linking not supported: \(message)"
        case .signOutFailed(let error):
            return "Sign out failed: \(error.localizedDescription)"
        }
    }
    
    static func == (lhs: AuthError, rhs: AuthError) -> Bool {
        switch (lhs, rhs) {
        case (.notAuthenticated, .notAuthenticated):
            return true
        case (.providerLinkingNotSupported(let lhsMessage), .providerLinkingNotSupported(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
} 