import Foundation
import Supabase
import Combine

// MARK: - Supabase Client Manager
@MainActor
class SupabaseClientManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SupabaseClientManager()
    
    // MARK: - Properties
    @Published var isInitialized = false
    @Published var isConnected = false
    @Published var connectionError: Error?
    
    private(set) var client: SupabaseClient?
    private var cancellables = Set<AnyCancellable>()
    private let config = SupabaseConfig.shared
    
    // MARK: - Initialization
    private init() {
        Task {
            await initialize()
        }
    }
    
    // MARK: - Public Methods
    func initialize() async {
        do {
            // Validate configuration
            try config.validate()
            
            // Create Supabase client
            let supabaseClient = SupabaseClient(
                supabaseURL: config.url,
                supabaseKey: config.anonKey,
                options: SupabaseClientOptions(
                    db: SupabaseClientOptions.DatabaseOptions(
                        schema: "public"
                    ),
                    auth: SupabaseClientOptions.AuthOptions(
                        storage: UserDefaults.standard,
                        autoRefreshToken: true,
                        persistSession: true,
                        detectSessionInUrl: false
                    ),
                    global: SupabaseClientOptions.GlobalOptions(
                        headers: [
                            "X-Client-Info": "soulbuddy-ios/1.0.0",
                            "X-Environment": config.environment
                        ]
                    )
                )
            )
            
            self.client = supabaseClient
            
            // Initialize auth
            try await supabaseClient.auth.initialize()
            
            self.isInitialized = true
            
            print("✅ Supabase client initialized successfully")
            
            // Test connection
            await testConnection()
            
            // Log app open event
            await logAppOpenEvent()
            
        } catch {
            print("❌ Failed to initialize Supabase client: \(error)")
            self.connectionError = error
            self.isInitialized = false
        }
    }
    
    func getClient() throws -> SupabaseClient {
        guard let client = client else {
            throw SupabaseClientError.notInitialized
        }
        return client
    }
    
    // MARK: - Connection Testing
    private func testConnection() async {
        guard let client = client else { return }
        
        do {
            // Test anonymous request - ping health endpoint or simple query
            let response: [String: Any] = try await client.database
                .rpc("get_server_time")
                .execute()
                .value
            
            self.isConnected = true
            self.connectionError = nil
            
            if config.logLevel == .debug {
                print("✅ Supabase connection test successful")
                print("   Server response: \(response)")
            }
            
        } catch {
            // If RPC doesn't exist, try a simple query
            await fallbackConnectionTest()
        }
    }
    
    private func fallbackConnectionTest() async {
        guard let client = client else { return }
        
        do {
            // Try a simple query to test connection
            let _: [String: Any] = try await client.database
                .from("app_affirmation_categories")
                .select("count")
                .limit(1)
                .execute()
                .value
            
            self.isConnected = true
            self.connectionError = nil
            
            print("✅ Supabase connection test successful (fallback)")
            
        } catch {
            print("⚠️ Supabase connection test failed: \(error)")
            self.connectionError = error
            self.isConnected = false
        }
    }
    
    // MARK: - Analytics
    private func logAppOpenEvent() async {
        guard let client = client, config.logLevel.isEnabled else { return }
        
        do {
            let eventProps: [String: Any] = [
                "environment": config.environment,
                "platform": "ios",
                "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
                "device_model": await UIDevice.current.model,
                "ios_version": await UIDevice.current.systemVersion,
                "app_launch_time": ISO8601DateFormatter().string(from: Date())
            ]
            
            // Log to analytics_events table via RPC
            let response: [String: Any] = try await client.database
                .rpc("log_analytics_event", params: [
                    "event_name": "app_open",
                    "event_props": eventProps
                ])
                .execute()
                .value
            
            if config.logLevel == .debug {
                print("📊 App open event logged successfully: \(response)")
            } else {
                print("📊 App open event logged successfully")
            }
            
        } catch {
            // Don't fail the app if analytics logging fails
            if config.logLevel == .debug {
                print("⚠️ Failed to log app open event: \(error)")
            }
        }
    }
    
    // MARK: - Health Check
    func performHealthCheck() async -> HealthCheckResult {
        guard let client = client else {
            return HealthCheckResult(
                isHealthy: false,
                checks: [
                    "client": .failure("Client not initialized")
                ]
            )
        }
        
        var checks: [String: HealthCheck] = [:]
        
        // Test database connection
        do {
            let _: [String: Any] = try await client.database
                .from("app_affirmation_categories")
                .select("count")
                .limit(1)
                .execute()
                .value
            
            checks["database"] = .success("Connected")
        } catch {
            checks["database"] = .failure(error.localizedDescription)
        }
        
        // Test auth
        do {
            let session = try await client.auth.session
            if session != nil {
                checks["auth"] = .success("Session active")
            } else {
                checks["auth"] = .success("No active session")
            }
        } catch {
            checks["auth"] = .failure(error.localizedDescription)
        }
        
        let isHealthy = checks.values.allSatisfy { check in
            if case .success = check { return true }
            return false
        }
        
        return HealthCheckResult(isHealthy: isHealthy, checks: checks)
    }
}

// MARK: - Errors
enum SupabaseClientError: LocalizedError {
    case notInitialized
    case configurationError(String)
    case connectionFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Supabase client is not initialized"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .connectionFailed(let error):
            return "Connection failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Health Check Models
struct HealthCheckResult {
    let isHealthy: Bool
    let checks: [String: HealthCheck]
    let timestamp = Date()
}

enum HealthCheck {
    case success(String)
    case failure(String)
    
    var isHealthy: Bool {
        if case .success = self { return true }
        return false
    }
    
    var message: String {
        switch self {
        case .success(let message), .failure(let message):
            return message
        }
    }
}

// MARK: - DI Container Extension
extension SupabaseClientManager {
    
    // Convenience methods for common operations
    var database: Database {
        get throws {
            return try getClient().database
        }
    }
    
    var auth: GoTrueClient {
        get throws {
            return try getClient().auth
        }
    }
    
    var storage: StorageClient {
        get throws {
            return try getClient().storage
        }
    }
    
    var realtime: RealtimeClient {
        get throws {
            return try getClient().realtime
        }
    }
} 