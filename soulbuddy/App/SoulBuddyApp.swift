import SwiftUI
import Supabase

@main
struct SoulBuddyApp: App {
    @StateObject private var supabaseService = SupabaseService.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(supabaseService)
                .preferredColorScheme(nil) // Allow system to control light/dark mode
                .onAppear {
                    setupApp()
                }
        }
    }
    
    private func setupApp() {
        // Initialize any app-wide configurations
        print("🚀 SoulBuddy App Started")
        print("📱 Environment: \(AppConfig.environment)")
        
        // Log Supabase connection (without sensitive data)
        print("🔗 Supabase URL configured: \(AppConfig.supabaseURL.isEmpty ? "❌ Missing" : "✅ Set")")
    }
}

// MARK: - App Configuration
struct AppConfig {
    static let environment = Bundle.main.infoDictionary?["ENVIRONMENT"] as? String ?? "Development"
    static let supabaseURL = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
    static let supabaseAnonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""
    static let bundleID = Bundle.main.bundleIdentifier ?? "deneme.soulbuddy"
    
    // Development flags
    static let isDebug = Bundle.main.infoDictionary?["DEBUG"] as? Bool ?? false
    static let isDevelopment = environment == "Development"
    static let isStaging = environment == "Staging"
    static let isProduction = environment == "Production"
} 