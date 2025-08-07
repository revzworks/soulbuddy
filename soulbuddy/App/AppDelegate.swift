//
//  AppDelegate.swift
//  SoulBuddy
//
//  Created by SoulBuddy Team on 2024-01-XX.
//

import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Set up notification center delegate
        UNUserNotificationCenter.current().delegate = self
        
        print("🚀 SoulBuddy App launched")
        
        return true
    }
    
    // MARK: - Push Notification Registration
    
    /// Successfully registered for remote notifications
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("✅ APNs device token received: \(tokenString.prefix(8))...")
        
        // Register with backend
        PushRegistrationService.handleTokenRegistration(deviceToken)
    }
    
    /// Failed to register for remote notifications
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ APNs registration failed: \(error.localizedDescription)")
        
        // Handle registration failure
        PushRegistrationService.handleTokenRegistrationFailure(error)
    }
    
    // MARK: - App Lifecycle
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        print("📱 App became active")
        
        // Refresh permission status when app becomes active
        PushRegistrationService.handleAppBecameActive()
        
        // Clear badge count when app becomes active
        application.applicationIconBadgeNumber = 0
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        print("📱 App entering foreground")
        
        // Clear badge count
        application.applicationIconBadgeNumber = 0
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    /// Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        print("📳 Notification received while app in foreground: \(notification.request.content.title)")
        
        // Log notification received event
        Task {
            await logNotificationEvent(
                event: "notification_received_foreground",
                notification: notification
            )
        }
        
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    /// Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        print("👆 Notification tapped: \(response.notification.request.content.title)")
        
        // Log notification tap event
        Task {
            await logNotificationEvent(
                event: "notification_tapped",
                notification: response.notification,
                actionIdentifier: response.actionIdentifier
            )
        }
        
        // Handle notification actions
        handleNotificationAction(response: response)
        
        completionHandler()
    }
    
    // MARK: - Notification Handling
    
    private func handleNotificationAction(response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        
        // Extract custom data from notification payload
        if let category = userInfo["category"] as? String {
            print("📂 Notification category: \(category)")
            
            switch category {
            case "mood_session":
                handleMoodSessionNotification(userInfo: userInfo)
            case "affirmation":
                handleAffirmationNotification(userInfo: userInfo)
            case "reminder":
                handleReminderNotification(userInfo: userInfo)
            default:
                print("⚠️ Unknown notification category: \(category)")
            }
        }
        
        // Handle action identifiers
        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification
            break
        case UNNotificationDismissActionIdentifier:
            // User dismissed the notification
            break
        case "OPEN_APP_ACTION":
            // Custom action to open app
            break
        case "SNOOZE_ACTION":
            // Custom action to snooze
            handleSnoozeAction(userInfo: userInfo)
        default:
            break
        }
    }
    
    private func handleMoodSessionNotification(userInfo: [AnyHashable: Any]) {
        print("🎯 Handling mood session notification")
        
        // Navigate to mood sessions view
        // This would be handled by posting a notification that ContentView listens to
        NotificationCenter.default.post(
            name: .navigateToMoodSessions,
            object: userInfo
        )
    }
    
    private func handleAffirmationNotification(userInfo: [AnyHashable: Any]) {
        print("💭 Handling affirmation notification")
        
        // Navigate to affirmations view
        NotificationCenter.default.post(
            name: .navigateToAffirmations,
            object: userInfo
        )
    }
    
    private func handleReminderNotification(userInfo: [AnyHashable: Any]) {
        print("⏰ Handling reminder notification")
        
        // Handle reminder logic
        NotificationCenter.default.post(
            name: .handleReminder,
            object: userInfo
        )
    }
    
    private func handleSnoozeAction(userInfo: [AnyHashable: Any]) {
        print("😴 Handling snooze action")
        
        // Schedule a new notification for later
        // This would call the backend to reschedule
        Task {
            await scheduleSnoozeNotification(userInfo: userInfo)
        }
    }
    
    private func scheduleSnoozeNotification(userInfo: [AnyHashable: Any]) async {
        // Implementation would call backend API to reschedule notification
        print("📅 Rescheduling notification for snooze")
    }
    
    private func logNotificationEvent(event: String, notification: UNNotification, actionIdentifier: String? = nil) async {
        let content = notification.request.content
        var props: [String: Any] = [
            "title": content.title,
            "body": content.body,
            "identifier": notification.request.identifier,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        // Add custom data
        for (key, value) in content.userInfo {
            if let stringKey = key as? String, stringKey != "aps" {
                props[stringKey] = value
            }
        }
        
        if let actionIdentifier = actionIdentifier {
            props["action_identifier"] = actionIdentifier
        }
        
        // Log to Supabase
        try? await SupabaseClientManager.shared.getClient().rpc(
            "log_analytics_event",
            parameters: [
                "event_name": event,
                "event_props": props
            ]
        ).execute()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let navigateToMoodSessions = Notification.Name("navigateToMoodSessions")
    static let navigateToAffirmations = Notification.Name("navigateToAffirmations")
    static let handleReminder = Notification.Name("handleReminder")
}

// MARK: - Notification Categories and Actions

extension AppDelegate {
    
    /// Set up notification categories and actions
    func setupNotificationCategories() {
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: "Snooze (15 min)",
            options: []
        )
        
        let openAppAction = UNNotificationAction(
            identifier: "OPEN_APP_ACTION",
            title: "Open App",
            options: [.foreground]
        )
        
        // Mood session category
        let moodSessionCategory = UNNotificationCategory(
            identifier: "mood_session",
            actions: [openAppAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Affirmation category
        let affirmationCategory = UNNotificationCategory(
            identifier: "affirmation",
            actions: [openAppAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Reminder category
        let reminderCategory = UNNotificationCategory(
            identifier: "reminder",
            actions: [openAppAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Register categories
        UNUserNotificationCenter.current().setNotificationCategories([
            moodSessionCategory,
            affirmationCategory,
            reminderCategory
        ])
        
        print("📝 Notification categories registered")
    }
} 