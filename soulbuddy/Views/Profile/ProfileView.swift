import SwiftUI

struct ProfileView: View {
    @StateObject private var supabaseService = SupabaseService.shared
    @State private var profile: AppProfile?
    @State private var notificationPreferences: NotificationPreferences?
    @State private var isLoading = true
    @State private var isEditing = false
    @State private var showingSettings = false
    @State private var errorMessage: String?
    
    // Form fields
    @State private var name = ""
    @State private var nickname = ""
    @State private var dateOfBirth: Date?
    @State private var birthHour: Int?
    
    var body: some View {
        NavigationView {
            List {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Loading profile...")
                        Spacer()
                    }
                    .accessibilityLabel(Text("Loading profile"))
                } else {
                    // Profile Header
                    ProfileHeaderSection(
                        profile: profile,
                        isSubscriber: supabaseService.isSubscriber,
                        onEditTap: { isEditing = true }
                    )
                    
                    // Account Section
                    Section("Account") {
                        NavigationLink("Notification Settings") {
                            NotificationSettingsView()
                        }
                        .accessibilityLabel(Text("Open notification settings"))
                        
                        if supabaseService.isSubscriber {
                            NavigationLink("Subscription Management") {
                                SubscriptionManagementView()
                            }
                            .accessibilityLabel(Text("Open subscription management"))
                        } else {
                            Button("Upgrade to Premium") {
                                // TODO: Navigate to subscription screen
                            }
                            .foregroundColor(.yellow)
                            .accessibilityLabel(Text("Upgrade to premium subscription"))
                        }
                    }
                    
                    // Privacy & Data Section
                    Section("Privacy & Data") {
                        NavigationLink("Export My Data") {
                            DataExportView()
                        }
                        .accessibilityLabel(Text("Export personal data"))
                        
                        Button("Delete Account") {
                            // TODO: Show confirmation dialog
                        }
                        .foregroundColor(.red)
                        .accessibilityLabel(Text("Delete account - destructive action"))
                    }
                    
                    // Support Section
                    Section("Support") {
                        Link("Help Center", destination: URL(string: "https://soulpal.support")!)
                            .accessibilityLabel(Text("Open help center"))
                        
                        Link("Privacy Policy", destination: URL(string: "https://soulpal.com/privacy")!)
                            .accessibilityLabel(Text("Open privacy policy"))
                        
                        Link("Terms of Service", destination: URL(string: "https://soulpal.com/terms")!)
                            .accessibilityLabel(Text("Open terms of service"))
                    }
                    
                    // Sign Out
                    Section {
                        Button("Sign Out") {
                            Task {
                                try? await supabaseService.signOut()
                            }
                        }
                        .foregroundColor(.red)
                        .accessibilityLabel(Text("Sign out of account"))
                    }
                }
                
                // Error Message
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Profile")
            .refreshable {
                await loadProfile()
            }
            .sheet(isPresented: $isEditing) {
                ProfileEditView(
                    profile: profile,
                    onSave: { updatedProfile in
                        Task {
                            await saveProfile(updatedProfile)
                        }
                    },
                    onCancel: { isEditing = false }
                )
            }
        }
        .task {
            await loadProfile()
        }
    }
    
    private func loadProfile() async {
        isLoading = true
        errorMessage = nil
        
        // Profile data is automatically loaded via SupabaseService
        profile = supabaseService.currentProfile
        
        isLoading = false
    }
    
    private func saveProfile(_ updatedProfile: AppProfile) async {
        do {
            try await supabaseService.updateProfile(updatedProfile)
            profile = updatedProfile
            isEditing = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ProfileHeaderSection: View {
    let profile: AppProfile?
    let isSubscriber: Bool
    let onEditTap: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [.pink, .purple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)
                
                Text(initials)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .accessibilityLabel(Text("Profile avatar with initials \(initials)"))
            
            VStack(spacing: 4) {
                Text(displayName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)
                
                if let nickname = profile?.nickname, !nickname.isEmpty {
                    Text("@\(nickname)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Subscription badge
                if isSubscriber {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                        Text("Premium")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.yellow.opacity(0.2))
                    )
                    .accessibilityLabel(Text("Premium subscriber"))
                }
            }
            
            Button("Edit Profile") {
                onEditTap()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel(Text("Edit profile information"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }
    
    private var displayName: String {
        if let name = profile?.name, !name.isEmpty {
            return name
        }
        return "Welcome!"
    }
    
    private var initials: String {
        let name = profile?.name ?? ""
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if !name.isEmpty {
            return String(name.prefix(2)).uppercased()
        }
        return "SP"
    }
}

struct ProfileEditView: View {
    let profile: AppProfile?
    let onSave: (AppProfile) -> Void
    let onCancel: () -> Void
    
    @State private var name: String
    @State private var nickname: String
    @State private var dateOfBirth: Date?
    @State private var birthHour: Int?
    @State private var showingDatePicker = false
    @State private var showingHourPicker = false
    
    init(profile: AppProfile?, onSave: @escaping (AppProfile) -> Void, onCancel: @escaping () -> Void) {
        self.profile = profile
        self.onSave = onSave
        self.onCancel = onCancel
        
        _name = State(initialValue: profile?.name ?? "")
        _nickname = State(initialValue: profile?.nickname ?? "")
        _dateOfBirth = State(initialValue: profile?.dateOfBirth)
        _birthHour = State(initialValue: profile?.birthHour)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Personal Information") {
                    TextField("Full Name", text: $name)
                        .textContentType(.name)
                        .accessibilityLabel(Text("Full name"))
                    
                    TextField("Nickname", text: $nickname)
                        .textContentType(.nickname)
                        .accessibilityLabel(Text("Nickname"))
                }
                
                Section("Birth Information") {
                    HStack {
                        Text("Date of Birth")
                        Spacer()
                        Button(dateOfBirth?.formatted(date: .abbreviated, time: .omitted) ?? "Not set") {
                            showingDatePicker = true
                        }
                        .foregroundColor(.blue)
                    }
                    .accessibilityLabel(Text("Date of birth: \(dateOfBirth?.formatted(date: .abbreviated, time: .omitted) ?? "Not set")"))
                    
                    HStack {
                        Text("Birth Hour (Optional)")
                        Spacer()
                        Button(birthHour != nil ? "\(birthHour!)h" : "Not set") {
                            showingHourPicker = true
                        }
                        .foregroundColor(.blue)
                    }
                    .accessibilityLabel(Text("Birth hour: \(birthHour != nil ? "\(birthHour!) hours" : "Not set")"))
                }
                
                Section {
                    Text("This information helps us provide more personalized content and is kept completely private.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                        .accessibilityLabel(Text("Cancel editing"))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty)
                    .accessibilityLabel(Text("Save profile changes"))
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerSheet(
                    title: "Date of Birth",
                    date: dateOfBirth ?? Date(),
                    onSave: { date in
                        dateOfBirth = date
                        showingDatePicker = false
                    },
                    onCancel: { showingDatePicker = false }
                )
            }
            .sheet(isPresented: $showingHourPicker) {
                HourPickerSheet(
                    selectedHour: birthHour,
                    onSave: { hour in
                        birthHour = hour
                        showingHourPicker = false
                    },
                    onCancel: { showingHourPicker = false }
                )
            }
        }
    }
    
    private func saveProfile() {
        guard let userId = SupabaseService.shared.supabaseService.auth.currentUser?.id else { return }
        
        let updatedProfile = AppProfile(
            userId: userId,
            name: name.isEmpty ? nil : name,
            nickname: nickname.isEmpty ? nil : nickname,
            dateOfBirth: dateOfBirth,
            birthHour: birthHour
        )
        
        onSave(updatedProfile)
    }
}

struct DatePickerSheet: View {
    let title: String
    let date: Date
    let onSave: (Date) -> Void
    let onCancel: () -> Void
    
    @State private var selectedDate: Date
    
    init(title: String, date: Date, onSave: @escaping (Date) -> Void, onCancel: @escaping () -> Void) {
        self.title = title
        self.date = date
        self.onSave = onSave
        self.onCancel = onCancel
        _selectedDate = State(initialValue: date)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    title,
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                
                Spacer()
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(selectedDate)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct HourPickerSheet: View {
    let selectedHour: Int?
    let onSave: (Int?) -> Void
    let onCancel: () -> Void
    
    @State private var hour: Int
    @State private var isSet: Bool
    
    init(selectedHour: Int?, onSave: @escaping (Int?) -> Void, onCancel: @escaping () -> Void) {
        self.selectedHour = selectedHour
        self.onSave = onSave
        self.onCancel = onCancel
        
        _hour = State(initialValue: selectedHour ?? 12)
        _isSet = State(initialValue: selectedHour != nil)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Toggle("Set birth hour", isOn: $isSet)
                    .padding()
                
                if isSet {
                    Picker("Hour", selection: $hour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text("\(hour)h").tag(hour)
                        }
                    }
                    .pickerStyle(.wheel)
                }
                
                Spacer()
            }
            .navigationTitle("Birth Hour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(isSet ? hour : nil)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// Placeholder views for navigation links
struct NotificationSettingsView: View {
    var body: some View {
        Text("Notification Settings")
            .navigationTitle("Notifications")
    }
}

struct SubscriptionManagementView: View {
    var body: some View {
        Text("Subscription Management")
            .navigationTitle("Subscription")
    }
}

struct DataExportView: View {
    var body: some View {
        Text("Data Export")
            .navigationTitle("Export Data")
    }
}

#Preview {
    ProfileView()
} 