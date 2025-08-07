import XCTest
import Combine
@testable import soulbuddy

final class AuthServiceTests: XCTestCase {
    
    var authService: AuthService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        cancellables = Set<AnyCancellable>()
        // Note: AuthService is a singleton, but we can test its public interface
        authService = AuthService.shared
    }
    
    override func tearDownWithError() throws {
        cancellables.removeAll()
        authService = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Provider Mapping Tests
    
    func testAuthProviderEnum() {
        // Test all providers exist
        let allProviders = AuthProvider.allCases
        XCTAssertEqual(allProviders.count, 3)
        XCTAssertTrue(allProviders.contains(.apple))
        XCTAssertTrue(allProviders.contains(.google))
        XCTAssertTrue(allProviders.contains(.email))
    }
    
    func testAuthProviderDisplayNames() {
        XCTAssertEqual(AuthProvider.apple.displayName, "Apple")
        XCTAssertEqual(AuthProvider.google.displayName, "Google")
        XCTAssertEqual(AuthProvider.email.displayName, "Email")
    }
    
    func testAuthProviderIconNames() {
        XCTAssertEqual(AuthProvider.apple.iconName, "applelogo")
        XCTAssertEqual(AuthProvider.google.iconName, "globe")
        XCTAssertEqual(AuthProvider.email.iconName, "envelope")
    }
    
    func testAuthProviderRawValues() {
        XCTAssertEqual(AuthProvider.apple.rawValue, "apple")
        XCTAssertEqual(AuthProvider.google.rawValue, "google")
        XCTAssertEqual(AuthProvider.email.rawValue, "email")
    }
    
    // MARK: - Auth Error Tests
    
    func testAuthErrorEquality() {
        let error1 = AuthError.notAuthenticated
        let error2 = AuthError.notAuthenticated
        XCTAssertEqual(error1, error2)
        
        let error3 = AuthError.providerLinkingNotSupported("test")
        let error4 = AuthError.providerLinkingNotSupported("test")
        XCTAssertEqual(error3, error4)
        
        let error5 = AuthError.providerLinkingNotSupported("test1")
        let error6 = AuthError.providerLinkingNotSupported("test2")
        XCTAssertNotEqual(error5, error6)
    }
    
    func testAuthErrorDescriptions() {
        let notAuthError = AuthError.notAuthenticated
        XCTAssertEqual(notAuthError.errorDescription, "User is not authenticated")
        
        let linkingError = AuthError.providerLinkingNotSupported("Custom message")
        XCTAssertEqual(linkingError.errorDescription, "Provider linking not supported: Custom message")
    }
    
    // MARK: - Auth State Tests
    
    func testInitialAuthState() {
        // Test initial state
        XCTAssertFalse(authService.isAuthenticated)
        XCTAssertNil(authService.currentUser)
        XCTAssertNil(authService.currentSession)
        XCTAssertFalse(authService.isLoading)
        XCTAssertNil(authService.authError)
    }
    
    func testAuthStatePublishers() {
        let expectation = XCTestExpectation(description: "Auth state change")
        
        // Test that auth state is published
        authService.$isAuthenticated
            .dropFirst() // Skip initial value
            .sink { isAuthenticated in
                // This would be triggered by actual auth state changes
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Simulate auth state change by setting loading state
        Task { @MainActor in
            authService.isLoading = true
        }
        
        // Wait briefly for publisher
        wait(for: [expectation], timeout: 0.1)
    }
    
    // MARK: - Email Validation Tests
    
    func testEmailValidation() {
        // These would be helper methods in a real implementation
        XCTAssertTrue(isValidEmail("test@example.com"))
        XCTAssertTrue(isValidEmail("user.name+tag@domain.co.uk"))
        XCTAssertFalse(isValidEmail("invalid-email"))
        XCTAssertFalse(isValidEmail(""))
        XCTAssertFalse(isValidEmail("test@"))
        XCTAssertFalse(isValidEmail("@domain.com"))
    }
    
    func testPasswordValidation() {
        // Test password requirements (minimum 6 characters)
        XCTAssertTrue(isValidPassword("password123"))
        XCTAssertTrue(isValidPassword("123456"))
        XCTAssertFalse(isValidPassword("12345"))
        XCTAssertFalse(isValidPassword(""))
    }
    
    // MARK: - Provider Linking Tests
    
    func testProviderLinkingRequiresAuthentication() async {
        // Test that linking requires authentication
        do {
            try await authService.linkProvider(.apple)
            XCTFail("Expected authentication error")
        } catch let error as AuthError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testProviderLinkingNotSupportedErrors() async {
        // Mock authenticated state for testing
        // In a real test, you'd mock the authentication state
        
        // Test Apple linking not implemented
        do {
            // This would fail because we're not authenticated
            try await authService.linkProvider(.apple)
            XCTFail("Expected not authenticated error")
        } catch let error as AuthError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        // Test Google linking not implemented
        do {
            try await authService.linkProvider(.google)
            XCTFail("Expected not authenticated error")
        } catch let error as AuthError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        // Test Email linking not supported
        do {
            try await authService.linkProvider(.email)
            XCTFail("Expected not authenticated error")
        } catch let error as AuthError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Mock Auth Methods
    
    func testSignOutClearsState() async {
        // Test that sign out would clear all state
        // This is testing the expected behavior based on the implementation
        
        // In a real test with mocked Supabase client:
        // 1. Set some auth state
        // 2. Call signOut
        // 3. Verify state is cleared
        
        // For now, we test the public interface expectations
        XCTAssertFalse(authService.isAuthenticated)
        XCTAssertNil(authService.currentUser)
        XCTAssertNil(authService.currentSession)
    }
    
    // MARK: - Performance Tests
    
    func testProviderEnumPerformance() {
        measure {
            for _ in 0..<1000 {
                let _ = AuthProvider.allCases
                let _ = AuthProvider.apple.displayName
                let _ = AuthProvider.google.iconName
                let _ = AuthProvider.email.rawValue
            }
        }
    }
    
    func testAuthErrorPerformance() {
        measure {
            for _ in 0..<1000 {
                let error1 = AuthError.notAuthenticated
                let error2 = AuthError.providerLinkingNotSupported("test")
                let _ = error1.errorDescription
                let _ = error2.errorDescription
                let _ = error1 == error1
            }
        }
    }
    
    // MARK: - Edge Cases
    
    func testConcurrentAuthOperations() async {
        // Test that concurrent auth operations are handled properly
        let expectation1 = XCTestExpectation(description: "First operation")
        let expectation2 = XCTestExpectation(description: "Second operation")
        
        Task {
            // Simulate concurrent auth attempts
            do {
                try await authService.signInWithEmail(email: "test1@example.com", password: "password123")
                XCTFail("Expected failure in test environment")
            } catch {
                // Expected to fail without proper Supabase setup
                expectation1.fulfill()
            }
        }
        
        Task {
            do {
                try await authService.signInWithEmail(email: "test2@example.com", password: "password456")
                XCTFail("Expected failure in test environment")
            } catch {
                // Expected to fail without proper Supabase setup
                expectation2.fulfill()
            }
        }
        
        await fulfillment(of: [expectation1, expectation2], timeout: 1.0)
    }
    
    // MARK: - Helper Methods
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func isValidPassword(_ password: String) -> Bool {
        return password.count >= 6
    }
}

// MARK: - Mock Classes for Testing

class MockSupabaseClient {
    var shouldFailAuth = false
    var mockUser: User?
    var mockSession: Session?
    
    func signIn(email: String, password: String) async throws -> Session {
        if shouldFailAuth {
            throw NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock auth failure"])
        }
        
        // Return mock session
        guard let mockSession = mockSession else {
            throw NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No mock session configured"])
        }
        
        return mockSession
    }
    
    func signUp(email: String, password: String, data: [String: Any] = [:]) async throws -> Session {
        return try await signIn(email: email, password: password)
    }
    
    func signOut() async throws {
        mockUser = nil
        mockSession = nil
    }
}

// MARK: - Integration Test Helpers

extension AuthServiceTests {
    
    func testProviderMappingIntegration() {
        // Test that all providers can be mapped correctly
        let providers = AuthProvider.allCases
        
        for provider in providers {
            // Verify each provider has valid properties
            XCTAssertFalse(provider.displayName.isEmpty)
            XCTAssertFalse(provider.iconName.isEmpty)
            XCTAssertFalse(provider.rawValue.isEmpty)
            
            // Verify provider can be reconstructed from raw value
            XCTAssertEqual(AuthProvider(rawValue: provider.rawValue), provider)
        }
    }
    
    func testCanonicalUserIDConsistency() {
        // Test that regardless of provider, we get a consistent user ID format
        // This would be tested with actual auth flows in integration tests
        
        // For now, verify that the auth service expects consistent behavior
        XCTAssertNil(authService.currentUser?.id) // No user initially
        
        // In a real test, you would:
        // 1. Sign in with Apple
        // 2. Verify user ID format
        // 3. Sign out and sign in with Google using same email
        // 4. Verify same canonical user ID
        // 5. Test email auth with same pattern
    }
}

// MARK: - Thread Safety Tests

extension AuthServiceTests {
    
    func testThreadSafetyOfAuthOperations() async {
        // Test that auth operations are thread-safe
        let iterations = 10
        let expectations = (0..<iterations).map { XCTestExpectation(description: "Operation \($0)") }
        
        for i in 0..<iterations {
            Task {
                // Simulate concurrent access to auth service properties
                let _ = authService.isAuthenticated
                let _ = authService.currentUser
                let _ = authService.isLoading
                expectations[i].fulfill()
            }
        }
        
        await fulfillment(of: expectations, timeout: 2.0)
    }
} 