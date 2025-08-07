import Foundation
import Supabase
import Combine

// MARK: - Profile Store
@MainActor
class ProfileStore: ObservableObject {
    
    // MARK: - Singleton
    static let shared = ProfileStore()
    
    // MARK: - Published Properties
    @Published var currentProfile: CompleteUserProfile?
    @Published var isLoading = false
    @Published var error: ProfileStoreError?
    @Published var lastUpdated: Date?
    
    // MARK: - Private Properties
    private var supabaseClient: SupabaseClient {
        get throws {
            return try SupabaseClientManager.shared.getClient()
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    private let config = SupabaseConfig.shared
    
    // MARK: - Initialization
    private init() {
        setupAuthStateListener()
    }
    
    // MARK: - Auth State Listener
    private func setupAuthStateListener() {
        // Listen to auth state changes and reload profile when user signs in
        AuthService.shared.$isAuthenticated
            .dropFirst() // Skip initial value
            .sink { [weak self] isAuthenticated in
                Task { @MainActor in
                    if isAuthenticated {
                        await self?.loadProfile()
                    } else {
                        await self?.clearProfile()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Profile Loading
    func loadProfile(force: Bool = false) async {
        // Skip if already loading or recently loaded (unless forced)
        if isLoading && !force {
            return
        }
        
        // Skip if not authenticated
        guard AuthService.shared.isAuthenticated else {
            await clearProfile()
            return
        }
        
        // Skip if recently loaded (within 30 seconds) unless forced
        if !force, let lastUpdated = lastUpdated,
           Date().timeIntervalSince(lastUpdated) < 30 {
            return
        }
        
        await setLoading(true)
        
        do {
            let client = try supabaseClient
            
            // Call the get_user_profile RPC function
            let response: CompleteUserProfile = try await client.database
                .rpc("get_user_profile")
                .execute()
                .value
            
            await updateProfile(response)
            
            if config.logLevel == .debug {
                print("✅ Profile loaded successfully")
            }
            
        } catch {
            print("❌ Failed to load profile: \(error)")
            await setError(.loadFailed(error))
        }
        
        await setLoading(false)
    }
    
    // MARK: - Profile Initialization
    func initializeProfile() async throws -> CompleteUserProfile {
        await setLoading(true)
        defer { Task { @MainActor in await setLoading(false) } }
        
        do {
            let client = try supabaseClient
            
            // Call the initialize_user_profile RPC function
            let response: CompleteUserProfile = try await client.database
                .rpc("initialize_user_profile")
                .execute()
                .value
            
            await updateProfile(response)
            
            print("✅ Profile initialized successfully")
            return response
            
        } catch {
            print("❌ Failed to initialize profile: \(error)")
            await setError(.initializationFailed(error))
            throw error
        }
    }
    
    // MARK: - Profile Updates
    func updateProfile(
        name: String? = nil,
        nickname: String? = nil,
        dateOfBirth: Date? = nil,
        birthHour: Int? = nil,
        locale: String? = nil,
        timezone: String? = nil
    ) async throws -> CompleteUserProfile {
        
        await setLoading(true)
        defer { Task { @MainActor in await setLoading(false) } }
        
        // Validate inputs
        let tempProfile = AppProfile(
            userId: UUID(), // Temporary UUID for validation
            name: name,
            nickname: nickname,
            dateOfBirth: dateOfBirth,
            birthHour: birthHour
        )
        
        do {
            try tempProfile.validate()
        } catch {
            await setError(.validationFailed(error))
            throw error
        }
        
        // Check nickname availability if provided
        if let nickname = nickname, !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let isAvailable = try await checkNicknameAvailability(nickname)
            if !isAvailable {
                let error = ProfileValidationError.nicknameTaken
                await setError(.validationFailed(error))
                throw error
            }
        }
        
        do {
            let client = try supabaseClient
            
            // Prepare parameters for RPC call
            var params: [String: Any] = [:]
            if let name = name { params["p_name"] = name }
            if let nickname = nickname { params["p_nickname"] = nickname }
            if let dateOfBirth = dateOfBirth { params["p_date_of_birth"] = ISO8601DateFormatter().string(from: dateOfBirth) }
            if let birthHour = birthHour { params["p_birth_hour"] = birthHour }
            if let locale = locale { params["p_locale"] = locale }
            if let timezone = timezone { params["p_timezone"] = timezone }
            
            // Call the upsert_profile RPC function
            let response: CompleteUserProfile = try await client.database
                .rpc("upsert_profile", params: params)
                .execute()
                .value
            
            await updateProfile(response)
            
            // Log analytics event
            await logProfileUpdateEvent(updatedFields: Array(params.keys))
            
            print("✅ Profile updated successfully")
            return response
            
        } catch {
            print("❌ Failed to update profile: \(error)")
            await setError(.updateFailed(error))
            throw error
        }
    }
    
    // MARK: - Nickname Availability
    func checkNicknameAvailability(_ nickname: String) async throws -> Bool {
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedNickname.isEmpty else {
            throw ProfileValidationError.nameEmpty
        }
        
        do {
            let client = try supabaseClient
            
            let response: NicknameAvailabilityResponse = try await client.database
                .rpc("check_nickname_availability", params: ["p_nickname": trimmedNickname])
                .execute()
                .value
            
            return response.available
            
        } catch {
            print("❌ Failed to check nickname availability: \(error)")
            throw ProfileStoreError.nicknameCheckFailed(error)
        }
    }
    
    // MARK: - Profile Deletion
    func deleteProfile() async throws {
        await setLoading(true)
        defer { Task { @MainActor in await setLoading(false) } }
        
        do {
            let client = try supabaseClient
            
            let _: [String: Any] = try await client.database
                .rpc("delete_user_profile")
                .execute()
                .value
            
            await clearProfile()
            
            print("✅ Profile deleted successfully")
            
        } catch {
            print("❌ Failed to delete profile: \(error)")
            await setError(.deletionFailed(error))
            throw error
        }
    }
    
    // MARK: - Utility Methods
    private func updateProfile(_ profile: CompleteUserProfile) async {
        self.currentProfile = profile
        self.lastUpdated = Date()
        self.error = nil
    }
    
    private func clearProfile() async {
        self.currentProfile = nil
        self.lastUpdated = nil
        self.error = nil
    }
    
    private func setLoading(_ loading: Bool) async {
        self.isLoading = loading
    }
    
    private func setError(_ error: ProfileStoreError?) async {
        self.error = error
    }
    
    // MARK: - Analytics
    private func logProfileUpdateEvent(updatedFields: [String]) async {
        guard config.logLevel.isEnabled else { return }
        
        do {
            let client = try supabaseClient
            let props: [String: Any] = [
                "updated_fields": updatedFields,
                "field_count": updatedFields.count,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
            
            let _: [String: Any] = try await client.database
                .rpc("log_analytics_event", params: [
                    "event_name": "profile_updated",
                    "event_props": props
                ])
                .execute()
                .value
            
        } catch {
            if config.logLevel == .debug {
                print("⚠️ Failed to log profile update event: \(error)")
            }
        }
    }
    
    // MARK: - Convenience Methods
    var hasProfile: Bool {
        return currentProfile?.hasProfile ?? false
    }
    
    var isProfileComplete: Bool {
        return currentProfile?.isComplete ?? false
    }
    
    var userProfile: AppProfile? {
        return currentProfile?.profile
    }
    
    var appUser: AppUser? {
        return currentProfile?.user
    }
    
    // Force refresh profile data
    func refresh() async {
        await loadProfile(force: true)
    }
}

// MARK: - Profile Store Errors
enum ProfileStoreError: LocalizedError, Equatable {
    case notAuthenticated
    case loadFailed(Error)
    case updateFailed(Error)
    case initializationFailed(Error)
    case deletionFailed(Error)
    case validationFailed(Error)
    case nicknameCheckFailed(Error)
    case networkError
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .loadFailed(let error):
            return "Failed to load profile: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "Failed to update profile: \(error.localizedDescription)"
        case .initializationFailed(let error):
            return "Failed to initialize profile: \(error.localizedDescription)"
        case .deletionFailed(let error):
            return "Failed to delete profile: \(error.localizedDescription)"
        case .validationFailed(let error):
            return "Profile validation failed: \(error.localizedDescription)"
        case .nicknameCheckFailed(let error):
            return "Failed to check nickname availability: \(error.localizedDescription)"
        case .networkError:
            return "Network connection error"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
    
    static func == (lhs: ProfileStoreError, rhs: ProfileStoreError) -> Bool {
        switch (lhs, rhs) {
        case (.notAuthenticated, .notAuthenticated),
             (.networkError, .networkError),
             (.unknownError, .unknownError):
            return true
        case (.validationFailed(let lhsError), .validationFailed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - Profile Store Extensions
extension ProfileStore {
    
    // Async convenience methods for common operations
    func updateName(_ name: String) async throws -> CompleteUserProfile {
        return try await updateProfile(name: name)
    }
    
    func updateNickname(_ nickname: String) async throws -> CompleteUserProfile {
        return try await updateProfile(nickname: nickname)
    }
    
    func updateDateOfBirth(_ dateOfBirth: Date) async throws -> CompleteUserProfile {
        return try await updateProfile(dateOfBirth: dateOfBirth)
    }
    
    func updateBirthHour(_ birthHour: Int) async throws -> CompleteUserProfile {
        return try await updateProfile(birthHour: birthHour)
    }
    
    func updateLocale(_ locale: String) async throws -> CompleteUserProfile {
        return try await updateProfile(locale: locale)
    }
    
    func updateTimezone(_ timezone: String) async throws -> CompleteUserProfile {
        return try await updateProfile(timezone: timezone)
    }
    
    // Check if profile needs initialization
    var needsInitialization: Bool {
        return !hasProfile && AuthService.shared.isAuthenticated
    }
    
    // Get formatted profile information
    var profileSummary: String {
        guard let profile = userProfile else { return "No profile" }
        
        var summary = "Name: \(profile.displayName)"
        
        if let nickname = profile.nickname {
            summary += "\nNickname: @\(nickname)"
        }
        
        if let age = profile.age {
            summary += "\nAge: \(age)"
        }
        
        if let birthHour = profile.formattedBirthHour {
            summary += "\nBirth Hour: \(birthHour)"
        }
        
        return summary
    }
}

// MARK: - Profile Store Test Helpers
#if DEBUG
extension ProfileStore {
    
    // For testing purposes
    func setMockProfile(_ profile: CompleteUserProfile) async {
        await updateProfile(profile)
    }
    
    func clearForTesting() async {
        await clearProfile()
        await setLoading(false)
        await setError(nil)
    }
    
    // Create a sample profile for previews
    static func sampleProfile() -> CompleteUserProfile {
        let userId = UUID()
        
        let user = AppUser(
            id: userId,
            locale: "en",
            timezone: "UTC",
            isSubscriber: false,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let profile = AppProfile(
            userId: userId,
            name: "John Doe",
            nickname: "johndoe",
            dateOfBirth: Calendar.current.date(byAdding: .year, value: -25, to: Date()),
            birthHour: 9,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        return CompleteUserProfile(
            user: user,
            profile: profile,
            timestamp: Date().timeIntervalSince1970
        )
    }
}
#endif 