import Foundation
import Supabase
import Combine

@MainActor
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    @Published var isAuthenticated = false
    @Published var currentUser: AppUser?
    @Published var currentProfile: AppProfile?
    @Published var isSubscriber = false
    
    private let supabase: SupabaseClient
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Get configuration from Info.plist (populated by .xcconfig files)
        guard let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              let url = URL(string: urlString),
              let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String else {
            fatalError("❌ Supabase configuration missing. Please check your .xcconfig files and ensure SUPABASE_URL and SUPABASE_ANON_KEY are set.")
        }
        
        self.supabase = SupabaseClient(
            supabaseURL: url,
            supabaseKey: key
        )
        
        print("✅ Supabase initialized for environment: \(AppConfig.environment)")
        print("🔗 Connected to: \(urlString)")
        
        setupAuthStateListener()
    }
    
    private func setupAuthStateListener() {
        supabase.auth.authStateChanges.sink { [weak self] event, session in
            Task { @MainActor in
                switch event {
                case .signedIn:
                    if let userId = session?.user.id {
                        await self?.loadUserData(userId: userId)
                        self?.isAuthenticated = true
                    }
                case .signedOut:
                    self?.clearUserData()
                    self?.isAuthenticated = false
                default:
                    break
                }
            }
        }
        .store(in: &cancellables)
    }
    
    private func clearUserData() {
        currentUser = nil
        currentProfile = nil
        isSubscriber = false
    }
    
    private func loadUserData(userId: UUID) async {
        do {
            // Load user data
            let user: AppUser = try await supabase.database
                .from("app_users")
                .select()
                .eq("user_id", value: userId)
                .single()
                .execute()
                .value
            
            // Load profile data
            let profile: AppProfile? = try? await supabase.database
                .from("app_profiles")
                .select()
                .eq("user_id", value: userId)
                .single()
                .execute()
                .value
            
            self.currentUser = user
            self.currentProfile = profile
            self.isSubscriber = user.isSubscriber
            
        } catch {
            print("Error loading user data: \(error)")
        }
    }
    
    // MARK: - Authentication
    func signInWithApple() async throws {
        // TODO: Implement Apple Sign In
        throw NSError(domain: "NotImplemented", code: 0, userInfo: [NSLocalizedDescriptionKey: "Apple Sign In not implemented yet"])
    }
    
    func signInWithGoogle() async throws {
        // TODO: Implement Google Sign In
        throw NSError(domain: "NotImplemented", code: 0, userInfo: [NSLocalizedDescriptionKey: "Google Sign In not implemented yet"])
    }
    
    func signInWithEmail(email: String, password: String) async throws {
        let session = try await supabase.auth.signIn(email: email, password: password)
        // User data will be loaded automatically via auth state change
    }
    
    func signUpWithEmail(email: String, password: String) async throws {
        let session = try await supabase.auth.signUp(email: email, password: password)
        // User data will be loaded automatically via auth state change
    }
    
    func signOut() async throws {
        try await supabase.auth.signOut()
        // Clear data will happen automatically via auth state change
    }
    
    // MARK: - Profile Management
    func updateProfile(_ profile: AppProfile) async throws {
        guard let userId = supabase.auth.currentUser?.id else {
            throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        try await supabase.database
            .from("app_profiles")
            .upsert(profile)
            .execute()
        
        self.currentProfile = profile
    }
    
    func updateNotificationPreferences(_ preferences: NotificationPreferences) async throws {
        try await supabase.database
            .from("app_notification_preferences")
            .upsert(preferences)
            .execute()
    }
    
    // MARK: - Content
    func fetchCategories(locale: String = Locale.current.languageCode ?? "en") async throws -> [AffirmationCategory] {
        let categories: [AffirmationCategory] = try await supabase.database
            .from("app_affirmation_categories")
            .select()
            .eq("locale", value: locale)
            .eq("is_active", value: true)
            .execute()
            .value
        
        return categories
    }
    
    func fetchFreeAffirmations(locale: String = Locale.current.languageCode ?? "en", limit: Int = 20) async throws -> [Affirmation] {
        let affirmations: [Affirmation] = try await supabase.database
            .from("app_affirmations")
            .select("*, app_affirmation_categories!inner(*)")
            .eq("locale", value: locale)
            .eq("is_active", value: true)
            .limit(limit)
            .execute()
            .value
        
        return affirmations
    }
    
    // MARK: - Mood Sessions
    func startMoodSession(categoryId: UUID, frequency: Int) async throws -> MoodSession {
        guard isSubscriber else {
            throw NSError(domain: "SubscriptionError", code: 403, userInfo: [NSLocalizedDescriptionKey: "Subscription required"])
        }
        
        guard let userId = supabase.auth.currentUser?.id else {
            throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // End any existing active session first
        try await endActiveMoodSession()
        
        let endsAt = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        
        let session = MoodSession(
            id: UUID(),
            userId: userId,
            categoryId: categoryId,
            status: .active,
            startedAt: Date(),
            endsAt: endsAt,
            frequencyPerDay: frequency
        )
        
        try await supabase.database
            .from("app_mood_sessions")
            .insert(session)
            .execute()
        
        return session
    }
    
    func getActiveMoodSession() async throws -> MoodSession? {
        guard let userId = supabase.auth.currentUser?.id else { return nil }
        
        let session: MoodSession? = try? await supabase.database
            .from("app_mood_sessions")
            .select()
            .eq("user_id", value: userId)
            .eq("status", value: "active")
            .single()
            .execute()
            .value
        
        return session
    }
    
    func endActiveMoodSession() async throws {
        guard let userId = supabase.auth.currentUser?.id else { return }
        
        try await supabase.database
            .from("app_mood_sessions")
            .update(["status": "completed"])
            .eq("user_id", value: userId)
            .eq("status", value: "active")
            .execute()
    }
    
    // MARK: - Device Token Registration
    func registerDeviceToken(_ token: String) async throws {
        guard let userId = supabase.auth.currentUser?.id else { return }
        
        let deviceToken = DeviceToken(
            id: UUID(),
            userId: userId,
            token: token,
            bundleId: Bundle.main.bundleIdentifier ?? "",
            platform: "ios",
            isActive: true,
            updatedAt: Date()
        )
        
        try await supabase.database
            .from("app_device_tokens")
            .upsert(deviceToken)
            .execute()
    }
} 