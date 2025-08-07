//
//  ContentView.swift
//  soulbuddy
//
//  Created by Umut Danışman on 7.08.2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var supabaseService: SupabaseService
    
    var body: some View {
        Group {
            if supabaseService.isAuthenticated {
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
        .animation(.easeInOut(duration: 0.3), value: supabaseService.isAuthenticated)
    }
}

#Preview {
    ContentView()
        .environmentObject(SupabaseService.shared)
}
