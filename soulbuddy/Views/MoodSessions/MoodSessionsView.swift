import SwiftUI

struct MoodSessionsView: View {
    @StateObject private var supabaseService = SupabaseService.shared
    @State private var categories: [AffirmationCategory] = []
    @State private var activeMoodSession: MoodSession?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingCategorySelection = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [.purple.opacity(0.1), .blue.opacity(0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    if !supabaseService.isSubscriber {
                        // Subscription required view
                        SubscriptionRequiredView()
                    } else if isLoading {
                        ProgressView("Loading mood sessions...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .accessibilityLabel(Text("Loading mood sessions"))
                    } else if let errorMessage = errorMessage {
                        ErrorView(message: errorMessage) {
                            Task {
                                await loadData()
                            }
                        }
                    } else if let activeMoodSession = activeMoodSession {
                        // Active session view
                        ActiveMoodSessionView(session: activeMoodSession) {
                            Task {
                                await endCurrentSession()
                            }
                        }
                    } else {
                        // No active session - show category selection
                        CategorySelectionView(categories: categories) { category, frequency in
                            Task {
                                await startMoodSession(categoryId: category.id, frequency: frequency)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Mood Sessions")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadData()
            }
        }
        .task {
            await loadData()
        }
    }
    
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let locale = Locale.current.languageCode ?? "en"
            categories = try await supabaseService.fetchCategories(locale: locale)
            activeMoodSession = try await supabaseService.getActiveMoodSession()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func startMoodSession(categoryId: UUID, frequency: Int) async {
        do {
            activeMoodSession = try await supabaseService.startMoodSession(categoryId: categoryId, frequency: frequency)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func endCurrentSession() async {
        do {
            try await supabaseService.endActiveMoodSession()
            activeMoodSession = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct SubscriptionRequiredView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "crown.fill")
                .font(.system(size: 80))
                .foregroundColor(.yellow)
                .accessibilityLabel(Text("Premium feature"))
            
            VStack(spacing: 16) {
                Text("Premium Feature")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Mood Sessions are available for premium subscribers only.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                FeatureRow(icon: "brain.head.profile", text: "Weekly personalized mood sessions")
                FeatureRow(icon: "bell.fill", text: "1-4 daily scheduled notifications")
                FeatureRow(icon: "heart.text.square", text: "Category-based affirmations")
                FeatureRow(icon: "calendar.badge.clock", text: "Timezone-aware scheduling")
            }
            .padding(.vertical)
            
            Button("Upgrade to Premium") {
                // TODO: Navigate to subscription screen
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.yellow)
            .accessibilityLabel(Text("Upgrade to premium subscription"))
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.yellow)
                .frame(width: 24, height: 24)
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

struct CategorySelectionView: View {
    let categories: [AffirmationCategory]
    let onCategorySelected: (AffirmationCategory, Int) -> Void
    
    @State private var selectedCategory: AffirmationCategory?
    @State private var selectedFrequency = 2
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
                
                Text("Start Your Mood Session")
                    .font(.title)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Choose a category and frequency for your weekly affirmation session.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Select Mood Category")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(categories) { category in
                        CategoryButton(
                            category: category,
                            isSelected: selectedCategory?.id == category.id,
                            onTap: { selectedCategory = category }
                        )
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Notification Frequency")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                
                HStack(spacing: 12) {
                    ForEach(1...4, id: \.self) { frequency in
                        FrequencyButton(
                            frequency: frequency,
                            isSelected: selectedFrequency == frequency,
                            onTap: { selectedFrequency = frequency }
                        )
                    }
                }
            }
            
            Button("Start Session") {
                guard let selectedCategory = selectedCategory else { return }
                onCategorySelected(selectedCategory, selectedFrequency)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.purple)
            .disabled(selectedCategory == nil)
            .accessibilityLabel(Text("Start mood session"))
        }
    }
}

struct CategoryButton: View {
    let category: AffirmationCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: iconForCategory(category.key))
                    .font(.title2)
                
                Text(category.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.purple.opacity(0.2) : Color.gray.opacity(0.1))
                    .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2)
            )
            .foregroundColor(isSelected ? .purple : .primary)
        }
        .accessibilityLabel(Text("Category: \(category.displayName)"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    private func iconForCategory(_ key: String) -> String {
        switch key {
        case "confidence":
            return "hand.raised.fill"
        case "motivation":
            return "bolt.fill"
        case "self_love":
            return "heart.fill"
        case "stress_relief":
            return "leaf.fill"
        case "focus":
            return "target"
        case "gratitude":
            return "hands.sparkles.fill"
        case "sleep":
            return "moon.fill"
        case "energy":
            return "sun.max.fill"
        default:
            return "star.fill"
        }
    }
}

struct FrequencyButton: View {
    let frequency: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(frequency)")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("per day")
                    .font(.caption2)
            }
            .frame(width: 60, height: 60)
            .background(
                Circle()
                    .fill(isSelected ? Color.purple.opacity(0.2) : Color.gray.opacity(0.1))
                    .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2)
            )
            .foregroundColor(isSelected ? .purple : .primary)
        }
        .accessibilityLabel(Text("\(frequency) notifications per day"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct ActiveMoodSessionView: View {
    let session: MoodSession
    let onEndSession: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("Active Mood Session")
                    .font(.title)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Your personalized affirmations are being delivered \(session.frequencyPerDay) times per day.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                InfoRow(label: "Days remaining", value: "\(session.daysRemaining)")
                InfoRow(label: "Frequency", value: "\(session.frequencyPerDay) per day")
                InfoRow(label: "Started", value: session.startedAt.formatted(date: .abbreviated, time: .omitted))
                InfoRow(label: "Ends", value: session.endsAt.formatted(date: .abbreviated, time: .omitted))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.background)
                    .stroke(.purple.opacity(0.3), lineWidth: 1)
            )
            
            Button("End Session Early") {
                onEndSession()
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .accessibilityLabel(Text("End current mood session early"))
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.headline)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again", action: onRetry)
                .buttonStyle(.bordered)
        }
        .padding()
        .accessibilityLabel(Text("Error: \(message)"))
    }
}

#Preview {
    MoodSessionsView()
} 