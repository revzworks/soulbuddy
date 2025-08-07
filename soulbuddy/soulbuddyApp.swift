//
//  soulbuddyApp.swift
//  soulbuddy
//
//  Created by Umut Danışman on 7.08.2025.
//

import SwiftUI
import UserNotifications

@main
struct soulbuddyApp: App {
    @StateObject private var supabaseService = SupabaseService.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(supabaseService)
                .onAppear {
                    setupNotifications()
                }
        }
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
}
