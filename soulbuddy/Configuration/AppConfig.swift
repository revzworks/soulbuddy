import Foundation

struct AppConfig {
    // MARK: - Supabase Configuration
    struct Supabase {
        static let url = ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "https://your-project.supabase.co"
        static let anonKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? "your-anon-key"
    }
    
    // MARK: - App Store Configuration
    struct AppStore {
        static let productId = "soul_pal_premium_monthly"
        static let bundleId = Bundle.main.bundleIdentifier ?? "com.soulpal.app"
    }
    
    // MARK: - Notification Configuration
    struct Notifications {
        static let defaultFrequency = 2
        static let maxFrequency = 4
        static let minFrequency = 1
        static let defaultQuietStart = "22:00"
        static let defaultQuietEnd = "08:00"
        static let repeatAvoidanceDays = 30
    }
    
    // MARK: - Session Configuration
    struct Sessions {
        static let weeklyDuration: TimeInterval = 7 * 24 * 60 * 60 // 7 days in seconds
        static let maxActiveSessions = 1
    }
    
    // MARK: - Content Configuration
    struct Content {
        static let supportedLocales = ["en", "tr"]
        static let defaultLocale = "en"
        static let freeContentLimit = 20
    }
    
    // MARK: - API Configuration
    struct API {
        static let requestTimeout: TimeInterval = 30
        static let maxRetryAttempts = 3
    }
    
    // MARK: - Feature Flags
    struct Features {
        static let appleSignInEnabled = true
        static let googleSignInEnabled = true
        static let dataExportEnabled = true
        static let analyticsEnabled = false // Set to true when ready
    }
    
    // MARK: - URLs
    struct URLs {
        static let support = URL(string: "https://soulpal.support")!
        static let privacyPolicy = URL(string: "https://soulpal.com/privacy")!
        static let termsOfService = URL(string: "https://soulpal.com/terms")!
        static let helpCenter = URL(string: "https://soulpal.support")!
    }
    
    // MARK: - Development
    struct Development {
        static let isDebugMode = {
            #if DEBUG
            return true
            #else
            return false
            #endif
        }()
        
        static let enableNetworkLogging = isDebugMode
        static let mockDataEnabled = false // For development/testing
    }
    
    // MARK: - Validation
    static func validateConfiguration() -> [String] {
        var issues: [String] = []
        
        if Supabase.url.contains("your-project") {
            issues.append("Supabase URL not configured")
        }
        
        if Supabase.anonKey.contains("your-anon-key") {
            issues.append("Supabase anon key not configured")
        }
        
        if !Content.supportedLocales.contains(Content.defaultLocale) {
            issues.append("Default locale not in supported locales")
        }
        
        return issues
    }
}

// MARK: - Environment Helper
extension ProcessInfo {
    var isRunningTests: Bool {
        environment["XCTestConfigurationFilePath"] != nil
    }
    
    var isPreview: Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
} 