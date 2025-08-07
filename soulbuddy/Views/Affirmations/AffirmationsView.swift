import SwiftUI

struct AffirmationsView: View {
    @StateObject private var supabaseService = SupabaseService.shared
    @State private var affirmations: [Affirmation] = []
    @State private var currentIndex = 0
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [.pink.opacity(0.1), .purple.opacity(0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    if isLoading {
                        ProgressView("Loading affirmations...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .accessibilityLabel(Text("Loading affirmations"))
                    } else if let errorMessage = errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            
                            Text("Something went wrong")
                                .font(.headline)
                            
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Try Again") {
                                Task {
                                    await loadAffirmations()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                        .accessibilityLabel(Text("Error loading affirmations: \(errorMessage)"))
                    } else if affirmations.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "heart")
                                .font(.largeTitle)
                                .foregroundColor(.pink)
                            
                            Text("No affirmations available")
                                .font(.headline)
                            
                            Text("Check back later for more positive content!")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .accessibilityLabel(Text("No affirmations available"))
                    } else {
                        // Current affirmation card
                        AffirmationCard(
                            affirmation: affirmations[currentIndex],
                            onNext: nextAffirmation
                        )
                        .padding(.horizontal)
                        
                        // Navigation controls
                        HStack(spacing: 32) {
                            Button(action: previousAffirmation) {
                                Image(systemName: "chevron.left.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.pink)
                            }
                            .disabled(currentIndex == 0)
                            .accessibilityLabel(Text("Previous affirmation"))
                            
                            Text("\(currentIndex + 1) of \(affirmations.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .accessibilityLabel(Text("Affirmation \(currentIndex + 1) of \(affirmations.count)"))
                            
                            Button(action: nextAffirmation) {
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.pink)
                            }
                            .disabled(currentIndex == affirmations.count - 1)
                            .accessibilityLabel(Text("Next affirmation"))
                        }
                        .padding(.bottom, 32)
                        
                        // Subscription prompt for non-subscribers
                        if !supabaseService.isSubscriber {
                            SubscriptionPromptCard()
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("Daily Affirmations")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadAffirmations()
            }
        }
        .task {
            await loadAffirmations()
        }
    }
    
    private func loadAffirmations() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let locale = Locale.current.languageCode ?? "en"
            affirmations = try await supabaseService.fetchFreeAffirmations(locale: locale)
            currentIndex = 0
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func nextAffirmation() {
        guard currentIndex < affirmations.count - 1 else { return }
        withAnimation(.easeInOut) {
            currentIndex += 1
        }
    }
    
    private func previousAffirmation() {
        guard currentIndex > 0 else { return }
        withAnimation(.easeInOut) {
            currentIndex -= 1
        }
    }
}

struct AffirmationCard: View {
    let affirmation: Affirmation
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text(affirmation.text)
                .font(.title2)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineSpacing(8)
                .padding(.top, 32)
                .accessibilityLabel(Text("Affirmation: \(affirmation.text)"))
                .accessibilityAddTraits(.isStaticText)
            
            Spacer()
            
            // Intensity indicator
            HStack {
                ForEach(1...3, id: \.self) { level in
                    Circle()
                        .fill(level <= affirmation.intensity ? Color.pink : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .accessibilityLabel(Text("Intensity level: \(affirmation.intensityLevel.localizedDisplayName)"))
            
            Button("Next Affirmation") {
                onNext()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.pink)
            .accessibilityLabel(Text("Show next affirmation"))
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.background)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
}

struct SubscriptionPromptCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.title)
                .foregroundColor(.yellow)
            
            Text("Unlock Personalized Mood Sessions")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("Get weekly personalized affirmations based on your mood and receive scheduled notifications throughout the day.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Upgrade to Premium") {
                // TODO: Navigate to subscription screen
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.yellow)
            .accessibilityLabel(Text("Upgrade to premium subscription"))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .stroke(.yellow.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    AffirmationsView()
} 