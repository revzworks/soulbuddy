//
//  PermissionFlow.swift
//  SoulBuddy
//
//  Created by SoulBuddy Team on 2024-01-XX.
//

import SwiftUI
import UserNotifications

// MARK: - Permission Flow View

struct PermissionFlow: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var permissionManager = PermissionManager.shared
    @State private var currentStep: PermissionStep = .prePermission
    @State private var showSystemPrompt = false
    
    let onComplete: (Bool) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: Theme.Spacing.medium) {
                    // Close button
                    HStack {
                        Spacer()
                        Button("Skip") {
                            handleSkip()
                        }
                        .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .padding(.horizontal, Theme.Spacing.large)
                    
                    // Permission step content
                    switch currentStep {
                    case .prePermission:
                        PrePermissionView(onContinue: handlePrePermissionContinue)
                    case .systemPrompt:
                        SystemPromptView(onSystemPromptShown: handleSystemPromptShown)
                    case .completed:
                        CompletedView(granted: permissionManager.isNotificationPermissionGranted)
                    }
                }
                .padding(.vertical, Theme.Spacing.large)
                
                Spacer()
            }
            .background(Theme.Colors.background)
            .onChange(of: permissionManager.isNotificationPermissionGranted) { granted in
                handlePermissionResult(granted: granted)
            }
            .task {
                await permissionManager.checkInitialPermissionStatus()
            }
        }
    }
    
    // MARK: - Event Handlers
    
    private func handlePrePermissionContinue() {
        currentStep = .systemPrompt
        showSystemPrompt = true
    }
    
    private func handleSystemPromptShown() {
        Task {
            await permissionManager.requestNotificationPermission()
        }
    }
    
    private func handlePermissionResult(granted: Bool) {
        if currentStep == .systemPrompt {
            currentStep = .completed
            
            // Auto-dismiss after a delay if granted
            if granted {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    onComplete(granted)
                    dismiss()
                }
            }
        }
    }
    
    private func handleSkip() {
        onComplete(false)
        dismiss()
    }
}

// MARK: - Permission Steps

enum PermissionStep {
    case prePermission
    case systemPrompt
    case completed
}

// MARK: - Pre-Permission View

struct PrePermissionView: View {
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: Theme.Spacing.large) {
            // Icon
            Image(systemName: "bell.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(Theme.Colors.accent)
                .padding(.top, Theme.Spacing.xlarge)
            
            // Title
            Text("Stay Connected with Your Journey")
                .font(Theme.Typography.title)
                .foregroundColor(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.large)
            
            // Description
            VStack(spacing: Theme.Spacing.medium) {
                PermissionBenefitRow(
                    icon: "heart.fill",
                    title: "Daily Affirmations",
                    description: "Receive gentle reminders for your mood sessions"
                )
                
                PermissionBenefitRow(
                    icon: "moon.stars.fill",
                    title: "Mindful Timing",
                    description: "Notifications respect your quiet hours"
                )
                
                PermissionBenefitRow(
                    icon: "hand.raised.fill",
                    title: "Your Control",
                    description: "Easily adjust frequency or turn off anytime"
                )
            }
            .padding(.horizontal, Theme.Spacing.large)
            
            Spacer()
            
            // Continue button
            VStack(spacing: Theme.Spacing.medium) {
                Button(action: onContinue) {
                    HStack {
                        Text("Continue")
                            .font(Theme.Typography.buttonLabel)
                            .foregroundColor(.white)
                        
                        Image(systemName: "arrow.right")
                            .font(.body.weight(.medium))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Theme.Colors.accent)
                    .cornerRadius(Theme.CornerRadius.button)
                }
                .padding(.horizontal, Theme.Spacing.large)
                
                Text("We'll ask for your permission next")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - System Prompt View

struct SystemPromptView: View {
    let onSystemPromptShown: () -> Void
    @State private var hasShownPrompt = false
    
    var body: some View {
        VStack(spacing: Theme.Spacing.large) {
            // Loading indicator
            VStack(spacing: Theme.Spacing.medium) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.accent))
                    .scaleEffect(1.2)
                
                Text("Requesting Permission...")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(.top, Theme.Spacing.xxlarge * 2)
            
            Spacer()
            
            // Instructions
            VStack(spacing: Theme.Spacing.small) {
                Text("Please select \"Allow\" when prompted")
                    .font(Theme.Typography.bodyMedium)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("This helps us send you meaningful affirmations")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Spacing.large)
            .padding(.bottom, Theme.Spacing.xxlarge)
        }
        .onAppear {
            if !hasShownPrompt {
                hasShownPrompt = true
                // Small delay to show the loading state
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onSystemPromptShown()
                }
            }
        }
    }
}

// MARK: - Completed View

struct CompletedView: View {
    let granted: Bool
    
    var body: some View {
        VStack(spacing: Theme.Spacing.large) {
            // Result icon
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(granted ? Theme.Colors.success : Theme.Colors.error)
                .padding(.top, Theme.Spacing.xlarge)
            
            // Result message
            VStack(spacing: Theme.Spacing.small) {
                Text(granted ? "Perfect!" : "No Worries")
                    .font(Theme.Typography.title)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text(granted ? 
                     "You'll receive gentle affirmations during your mood sessions." :
                     "You can always enable notifications later in Settings."
                )
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.large)
            }
            
            Spacer()
            
            if !granted {
                // Settings button for denied permission
                Button("Open Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                .font(Theme.Typography.buttonLabel)
                .foregroundColor(Theme.Colors.accent)
                .padding(.bottom, Theme.Spacing.large)
            }
        }
    }
}

// MARK: - Permission Benefit Row

struct PermissionBenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.medium) {
            // Icon
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Theme.Colors.accent)
                .frame(width: 24, height: 24)
            
            // Content
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                Text(title)
                    .font(Theme.Typography.bodyMedium)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text(description)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Permission Manager

@MainActor
class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    @Published var isNotificationPermissionGranted = false
    @Published var notificationSettings: UNNotificationSettings?
    
    private init() {}
    
    func checkInitialPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        self.notificationSettings = settings
        self.isNotificationPermissionGranted = settings.authorizationStatus == .authorized
    }
    
    func requestNotificationPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            
            // Always check settings after request to get the actual status
            await checkInitialPermissionStatus()
            
            // Register for remote notifications if granted
            if granted {
                await registerForRemoteNotifications()
            }
            
        } catch {
            print("Error requesting notification permission: \(error)")
            await checkInitialPermissionStatus()
        }
    }
    
    private func registerForRemoteNotifications() async {
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    func handlePermissionChange() async {
        await checkInitialPermissionStatus()
        
        // Update notification preferences in database
        if let settings = notificationSettings {
            await updateNotificationPreferences(settings: settings)
        }
    }
    
    private func updateNotificationPreferences(settings: UNNotificationSettings) async {
        // This will be called by PushRegistrationService
        let allowPush = settings.authorizationStatus == .authorized
        
        // Log the permission change
        try? await SupabaseClientManager.shared.getClient().rpc(
            "log_analytics_event",
            parameters: [
                "event_name": "notification_permission_changed",
                "event_props": [
                    "granted": allowPush,
                    "authorization_status": settings.authorizationStatus.rawValue,
                    "timestamp": ISO8601DateFormatter().string(from: Date())
                ] as [String: Any]
            ]
        ).execute()
    }
}

// MARK: - Preview

#Preview {
    PermissionFlow { granted in
        print("Permission flow completed with result: \(granted)")
    }
} 