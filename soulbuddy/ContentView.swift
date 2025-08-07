//
//  ContentView.swift
//  soulbuddy
//
//  Created by Umut Danışman on 7.08.2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var supabaseService: SupabaseService
    @EnvironmentObject private var supabaseClientManager: SupabaseClientManager
    @StateObject private var authService = AuthService.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var showDebugMenu = false
    
    var body: some View {
        NavigationStack {
            Group {
                if authService.isAuthenticated {
                    MainTabView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                } else {
                    AuthenticationView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal: .move(edge: .trailing)
                        ))
                }
            }
            .animation(Theme.Animation.pageTransition, value: authService.isAuthenticated)
            .toolbar {
                if SupabaseConfig.shared.isDevelopment {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Debug") {
                            showDebugMenu = true
                        }
                        .font(Theme.Typography.caption)
                    }
                }
            }
            .sheet(isPresented: $showDebugMenu) {
                SupabaseTestView()
                    .environmentObject(supabaseClientManager)
            }
        }
        .background(Theme.Colors.background)
        .preferredColorScheme(nil) // Allow system to control
        .onAppear {
            print("🎨 Current color scheme: \(colorScheme)")
            print("🔐 Authentication state: \(authService.isAuthenticated)")
            print("🔗 Supabase connection: \(supabaseClientManager.isConnected ? "✅" : "❌")")
        }
    }
}

// MARK: - Previews
#Preview("Light Mode") {
    ContentView()
        .environmentObject(SupabaseService.shared)
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    ContentView()
        .environmentObject(SupabaseService.shared)
        .preferredColorScheme(.dark)
}

#Preview("Theme Demo") {
    ThemePreviewView()
}

// MARK: - Theme Preview Helper
struct ThemePreviewView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Typography Examples
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("Typography")
                            .font(Theme.Typography.title1)
                            .foregroundColor(Theme.Colors.textPrimary)
                        
                        Text("Large Title")
                            .font(Theme.Typography.largeTitle)
                            .foregroundColor(Theme.Colors.textPrimary)
                        
                        Text("Headline Text")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.textSecondary)
                        
                        Text("Body text with regular weight and readable size.")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.textSecondary)
                        
                        Text("Caption text for additional information.")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                    .cardStyle()
                    .padding(Theme.Spacing.md)
                    
                    // Color Examples
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("Colors")
                            .font(Theme.Typography.title2)
                            .foregroundColor(Theme.Colors.textPrimary)
                        
                        HStack(spacing: Theme.Spacing.sm) {
                            ColorSwatch(color: Theme.Colors.Fallback.primary, name: "Primary")
                            ColorSwatch(color: Theme.Colors.Fallback.secondary, name: "Secondary")
                            ColorSwatch(color: Theme.Colors.Fallback.success, name: "Success")
                            ColorSwatch(color: Theme.Colors.Fallback.error, name: "Error")
                        }
                    }
                    .cardStyle()
                    .padding(Theme.Spacing.md)
                    
                    // Button Examples
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("Buttons")
                            .font(Theme.Typography.title2)
                            .foregroundColor(Theme.Colors.textPrimary)
                        
                        Button("Theme Demo Button") {
                            print("Theme demo button tapped")
                        }
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.Fallback.primary)
                        .foregroundColor(.white)
                        .cornerRadius(Theme.CornerRadius.button)
                        
                        Button("Secondary Button") {
                            print("Secondary button tapped")
                        }
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.Fallback.surface)
                        .foregroundColor(Theme.Colors.Fallback.textPrimary)
                        .cornerRadius(Theme.CornerRadius.button)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.button)
                                .stroke(Theme.Colors.Fallback.primary, lineWidth: 1)
                        )
                    }
                    .cardStyle()
                    .padding(Theme.Spacing.md)
                }
                .screenPadding()
            }
            .background(Theme.Colors.Fallback.background)
            .navigationTitle("Theme Preview")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct ColorSwatch: View {
    let color: Color
    let name: String
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Rectangle()
                .fill(color)
                .frame(width: 60, height: 40)
                .cornerRadius(Theme.CornerRadius.sm)
            
            Text(name)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.Fallback.textSecondary)
        }
    }
}
