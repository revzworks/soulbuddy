import SwiftUI

struct MainTabView: View {
    @StateObject private var supabaseService = SupabaseService.shared
    
    var body: some View {
        TabView {
            // Home Tab - Affirmations Feed
            AffirmationsView()
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Home")
                }
                .accessibilityLabel(Text("Home tab"))
            
            // Mood Sessions Tab (Premium)
            MoodSessionsView()
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("Mood Sessions")
                }
                .accessibilityLabel(Text("Mood Sessions tab"))
            
            // Profile Tab
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .accessibilityLabel(Text("Profile tab"))
        }
        .accentColor(.pink)
    }
}

#Preview {
    MainTabView()
} 