//
//  PushRegistrationService.swift
//  SoulBuddy
//
//  Created by SoulBuddy Team on 2024-01-XX.
//

import Foundation
import UIKit
import UserNotifications
import Supabase

// MARK: - Device Registration Models

struct DeviceRegistrationRequest: Codable {
    let token: String
    let bundleId: String
    let platform: String
    let deviceInfo: DeviceInfo?
    
    enum CodingKeys: String, CodingKey {
        case token
        case bundleId = "bundle_id"
        case platform
        case deviceInfo = "device_info"
    }
}

struct DeviceInfo: Codable {
    let model: String?
    let systemVersion: String?
    let appVersion: String?
    
    enum CodingKeys: String, CodingKey {
        case model
        case systemVersion = "system_version"
        case appVersion = "app_version"
    }
}

struct DeviceRegistrationResponse: Codable {
    let success: Bool
    let deviceId: String?
    let message: String?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case deviceId = "device_id"
        case message
        case error
    }
}

// MARK: - Push Registration Service

@MainActor
class PushRegistrationService: ObservableObject {
    static let shared = PushRegistrationService()
    
    @Published var isRegistering = false
    @Published var lastRegistrationError: Error?
    @Published var lastRegistrationDate: Date?
    @Published var currentDeviceToken: String?
    
    private let supabaseClient: SupabaseClient
    private let permissionManager = PermissionManager.shared
    
    private init() {
        self.supabaseClient = SupabaseClientManager.shared.getClient()
        
        // Listen for permission changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePermissionChange),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    /// Register device token with Supabase backend
    func registerDeviceToken(_ token: Data) async {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        await registerDeviceToken(tokenString)
    }
    
    /// Register device token with Supabase backend (string version)
    func registerDeviceToken(_ tokenString: String) async {
        guard !isRegistering else {
            print("🔄 Device registration already in progress")
            return
        }
        
        isRegistering = true
        lastRegistrationError = nil
        
        do {
            print("📱 Registering device token: \(tokenString.prefix(8))...")
            
            let request = DeviceRegistrationRequest(
                token: tokenString,
                bundleId: getBundleId(),
                platform: "ios",
                deviceInfo: getDeviceInfo()
            )
            
            let response: DeviceRegistrationResponse = try await supabaseClient.functions
                .invoke("device_register", options: FunctionInvokeOptions(
                    body: request
                ))
            
            if response.success {
                print("✅ Device token registered successfully: \(response.message ?? "")")
                currentDeviceToken = tokenString
                lastRegistrationDate = Date()
                
                // Update notification preferences if needed
                await updateNotificationPreferences()
                
                // Log success analytics
                await logRegistrationEvent(success: true, deviceId: response.deviceId)
                
            } else {
                let error = PushRegistrationError.registrationFailed(response.error ?? "Unknown error")
                print("❌ Device registration failed: \(error.localizedDescription)")
                lastRegistrationError = error
                
                await logRegistrationEvent(success: false, error: error.localizedDescription)
            }
            
        } catch {
            print("❌ Device registration error: \(error)")
            lastRegistrationError = error
            await logRegistrationEvent(success: false, error: error.localizedDescription)
        }
        
        isRegistering = false
    }
    
    /// Handle device token registration failure
    func handleRegistrationFailure(_ error: Error) async {
        print("❌ APNs registration failed: \(error)")
        lastRegistrationError = error
        
        await logRegistrationEvent(success: false, error: error.localizedDescription)
    }
    
    /// Update notification preferences based on current permission status
    func updateNotificationPreferences() async {
        await permissionManager.checkInitialPermissionStatus()
        
        guard let settings = permissionManager.notificationSettings else {
            print("⚠️ No notification settings available")
            return
        }
        
        let allowPush = settings.authorizationStatus == .authorized
        
        do {
            let _: EmptyResponse = try await supabaseClient
                .from("app_notification_preferences")
                .upsert([
                    "user_id": AuthService.shared.currentUser?.id ?? "",
                    "allow_push": allowPush,
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ], onConflict: "user_id")
                .execute()
            
            print("✅ Notification preferences updated: allow_push = \(allowPush)")
            
        } catch {
            print("❌ Failed to update notification preferences: \(error)")
        }
    }
    
    /// Check and update permission status
    func refreshPermissionStatus() async {
        await permissionManager.handlePermissionChange()
        await updateNotificationPreferences()
    }
    
    // MARK: - Private Methods
    
    @objc private func handlePermissionChange() {
        Task {
            await refreshPermissionStatus()
        }
    }
    
    private func getBundleId() -> String {
        return Bundle.main.bundleIdentifier ?? "unknown.bundle.id"
    }
    
    private func getDeviceInfo() -> DeviceInfo {
        let device = UIDevice.current
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        
        return DeviceInfo(
            model: device.model,
            systemVersion: device.systemVersion,
            appVersion: appVersion
        )
    }
    
    private func logRegistrationEvent(success: Bool, deviceId: String? = nil, error: String? = nil) async {
        var props: [String: Any] = [
            "success": success,
            "platform": "ios",
            "bundle_id": getBundleId(),
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        if let deviceId = deviceId {
            props["device_id"] = deviceId
        }
        
        if let error = error {
            props["error"] = error
        }
        
        try? await supabaseClient.rpc(
            "log_analytics_event",
            parameters: [
                "event_name": "device_token_registration",
                "event_props": props
            ]
        ).execute()
    }
}

// MARK: - Push Registration Errors

enum PushRegistrationError: LocalizedError {
    case registrationFailed(String)
    case networkError(Error)
    case authenticationRequired
    case invalidToken
    
    var errorDescription: String? {
        switch self {
        case .registrationFailed(let message):
            return "Registration failed: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .authenticationRequired:
            return "User must be authenticated to register device"
        case .invalidToken:
            return "Invalid device token format"
        }
    }
}

// MARK: - Empty Response Helper

struct EmptyResponse: Codable {
    // Empty struct for operations that don't return data
}

// MARK: - App Delegate Integration Helper

extension PushRegistrationService {
    
    /// Handle successful APNs token registration from AppDelegate
    static func handleTokenRegistration(_ deviceToken: Data) {
        Task {
            await PushRegistrationService.shared.registerDeviceToken(deviceToken)
        }
    }
    
    /// Handle APNs token registration failure from AppDelegate
    static func handleTokenRegistrationFailure(_ error: Error) {
        Task {
            await PushRegistrationService.shared.handleRegistrationFailure(error)
        }
    }
    
    /// Handle app becoming active - refresh permission status
    static func handleAppBecameActive() {
        Task {
            await PushRegistrationService.shared.refreshPermissionStatus()
        }
    }
}

// MARK: - Notification Methods

extension PushRegistrationService {
    
    /// Check if push notifications are enabled and token is registered
    var isPushEnabled: Bool {
        return permissionManager.isNotificationPermissionGranted && currentDeviceToken != nil
    }
    
    /// Get current notification authorization status
    var authorizationStatus: UNAuthorizationStatus {
        return permissionManager.notificationSettings?.authorizationStatus ?? .notDetermined
    }
    
    /// Check if we should show permission flow
    var shouldShowPermissionFlow: Bool {
        return authorizationStatus == .notDetermined
    }
    
    /// Check if user denied permissions (show settings prompt)
    var isPermissionDenied: Bool {
        return authorizationStatus == .denied
    }
} 