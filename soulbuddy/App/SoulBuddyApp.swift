import SwiftUI
import Supabase
import UserNotifications

@main
struct SoulBuddyApp: App {
    @StateObject private var supabaseService = SupabaseService.shared
    @StateObject private var supabaseClientManager = SupabaseClientManager.shared
    @StateObject private var profileStore = ProfileStore.shared
    @StateObject private var pushRegistrationService = PushRegistrationService.shared
    
    // App Delegate for push notifications
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(supabaseService)
                .environmentObject(supabaseClientManager)
                .environmentObject(profileStore)
                .environmentObject(pushRegistrationService)
                .preferredColorScheme(nil) // Allow system to control light/dark mode
                .onAppear {
                    setupApp()
                }
                .task {
                    await initializeSupabase()
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
    
    @MainActor
    private func initializeSupabase() async {
        // Supabase client manager initializes automatically
        // But we can perform additional setup here if needed
        
        // Wait for initialization
        while !supabaseClientManager.isInitialized {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        if supabaseClientManager.isConnected {
            print("✅ Supabase fully initialized and connected")
        } else if let error = supabaseClientManager.connectionError {
            print("⚠️ Supabase initialized but connection issue: \(error)")
        }
        
        // Perform health check in development
        if SupabaseConfig.shared.isDevelopment {
            let healthResult = await supabaseClientManager.performHealthCheck()
            print("🏥 Health Check: \(healthResult.isHealthy ? "✅ Healthy" : "❌ Issues detected")")
            
            for (service, check) in healthResult.checks {
                print("   \(service): \(check.message)")
            }
        }
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