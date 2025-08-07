import Foundation

// MARK: - Supabase Configuration
struct SupabaseConfig {
    let url: URL
    let anonKey: String
    let environment: String
    
    // MARK: - Singleton
    static let shared: SupabaseConfig = {
        do {
            return try SupabaseConfig()
        } catch {
            fatalError("❌ Failed to initialize Supabase configuration: \(error)")
        }
    }()
    
    // MARK: - Initialization
    private init() throws {
        // Load configuration from Info.plist (populated by .xcconfig files)
        guard let infoPlist = Bundle.main.infoDictionary else {
            throw SupabaseConfigError.missingInfoPlist
        }
        
        guard let urlString = infoPlist["SUPABASE_URL"] as? String,
              !urlString.isEmpty else {
            throw SupabaseConfigError.missingURL
        }
        
        guard let url = URL(string: urlString) else {
            throw SupabaseConfigError.invalidURL(urlString)
        }
        
        guard let anonKey = infoPlist["SUPABASE_ANON_KEY"] as? String,
              !anonKey.isEmpty else {
            throw SupabaseConfigError.missingAnonKey
        }
        
        let environment = infoPlist["ENVIRONMENT"] as? String ?? "Unknown"
        
        self.url = url
        self.anonKey = anonKey
        self.environment = environment
        
        // Log configuration (safely)
        print("✅ Supabase Configuration Loaded:")
        print("   Environment: \(environment)")
        print("   URL: \(urlString)")
        print("   Anon Key: \(anonKey.prefix(20))..." + String(anonKey.suffix(10)))
    }
    
    // MARK: - Validation
    func validate() throws {
        // Validate URL is reachable format
        guard url.scheme == "https" else {
            throw SupabaseConfigError.insecureURL
        }
        
        // Validate anon key format (JWT-like)
        let components = anonKey.components(separatedBy: ".")
        guard components.count == 3 else {
            throw SupabaseConfigError.invalidAnonKeyFormat
        }
        
        print("✅ Supabase configuration validation passed")
    }
    
    // MARK: - Helper Properties
    var isProduction: Bool {
        return environment.lowercased() == "production"
    }
    
    var isDevelopment: Bool {
        return environment.lowercased() == "development"
    }
    
    var isStaging: Bool {
        return environment.lowercased() == "staging"
    }
    
    var logLevel: LogLevel {
        switch environment.lowercased() {
        case "production":
            return .error
        case "staging":
            return .warning
        default:
            return .debug
        }
    }
}

// MARK: - Configuration Errors
enum SupabaseConfigError: LocalizedError {
    case missingInfoPlist
    case missingURL
    case invalidURL(String)
    case missingAnonKey
    case insecureURL
    case invalidAnonKeyFormat
    
    var errorDescription: String? {
        switch self {
        case .missingInfoPlist:
            return "Info.plist not found"
        case .missingURL:
            return "SUPABASE_URL not found in configuration"
        case .invalidURL(let url):
            return "Invalid SUPABASE_URL: \(url)"
        case .missingAnonKey:
            return "SUPABASE_ANON_KEY not found in configuration"
        case .insecureURL:
            return "Supabase URL must use HTTPS"
        case .invalidAnonKeyFormat:
            return "Invalid anon key format (should be JWT)"
        }
    }
}

// MARK: - Log Level
enum LogLevel: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    
    var isEnabled: Bool {
        let currentLevel = SupabaseConfig.shared.logLevel
        return self.rawValue >= currentLevel.rawValue
    }
}

// MARK: - String Comparison for LogLevel
extension String {
    static func >=(lhs: String, rhs: String) -> Bool {
        let levels = ["DEBUG", "INFO", "WARNING", "ERROR"]
        let lhsIndex = levels.firstIndex(of: lhs) ?? 0
        let rhsIndex = levels.firstIndex(of: rhs) ?? 0
        return lhsIndex >= rhsIndex
    }
} 