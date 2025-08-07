import SwiftUI

struct ProfileSetupView: View {
    @StateObject private var profileStore = ProfileStore.shared
    @Environment(\.dismiss) private var dismiss
    
    // Form state
    @State private var name = ""
    @State private var nickname = ""
    @State private var dateOfBirth: Date?
    @State private var birthHour: Int?
    @State private var isShowingDatePicker = false
    @State private var isShowingBirthHourPicker = false
    
    // UI state
    @State private var isNicknameAvailable: Bool?
    @State private var isCheckingNickname = false
    @State private var validationErrors: [ProfileValidationError] = []
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var hasAttemptedSubmit = false
    
    // Configuration
    let isOnboarding: Bool
    let onComplete: ((CompleteUserProfile) -> Void)?
    
    init(isOnboarding: Bool = false, onComplete: ((CompleteUserProfile) -> Void)? = nil) {
        self.isOnboarding = isOnboarding
        self.onComplete = onComplete
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    headerSection
                    
                    formSection
                    
                    if !validationErrors.isEmpty && hasAttemptedSubmit {
                        errorSection
                    }
                    
                    actionButtons
                }
                .screenPadding()
            }
            .background(Theme.Colors.background)
            .navigationTitle(isOnboarding ? "Welcome to SoulBuddy" : "Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: cancelButton,
                trailing: saveButton
            )
            .sheet(isPresented: $isShowingDatePicker) {
                DatePickerSheet(
                    selectedDate: dateOfBirth ?? Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date(),
                    onSave: { date in
                        dateOfBirth = date
                        isShowingDatePicker = false
                    },
                    onCancel: {
                        isShowingDatePicker = false
                    }
                )
            }
            .sheet(isPresented: $isShowingBirthHourPicker) {
                BirthHourPickerSheet(
                    selectedHour: birthHour,
                    onSave: { hour in
                        birthHour = hour
                        isShowingBirthHourPicker = false
                    },
                    onCancel: {
                        isShowingBirthHourPicker = false
                    }
                )
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            loadExistingProfile()
        }
        .onChange(of: nickname) { _ in
            Task {
                await checkNicknameAvailability()
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(Theme.Colors.primary)
            
            VStack(spacing: Theme.Spacing.sm) {
                Text(isOnboarding ? "Set up your profile" : "Edit your profile")
                    .font(Theme.Typography.title2)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text(isOnboarding ? 
                     "Let's personalize your SoulBuddy experience" : 
                     "Update your profile information")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, isOnboarding ? Theme.Spacing.xl : Theme.Spacing.md)
    }
    
    // MARK: - Form Section
    private var formSection: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Name Field
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Text("Full Name")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    Spacer()
                    
                    Text("Required")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.statusWarning)
                }
                
                TextField("Enter your full name", text: $name)
                    .textFieldStyle(ProfileTextFieldStyle())
                    .textContentType(.name)
                    .autocapitalization(.words)
                    .onSubmit {
                        validateForm()
                    }
            }
            
            // Nickname Field
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Text("Nickname")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    Spacer()
                    
                    nicknameStatusIndicator
                }
                
                TextField("Choose a unique nickname", text: $nickname)
                    .textFieldStyle(ProfileTextFieldStyle())
                    .textContentType(.nickname)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onSubmit {
                        Task {
                            await checkNicknameAvailability()
                        }
                    }
                
                if !nickname.isEmpty {
                    Text("Your nickname will be @\(nickname)")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
            
            // Date of Birth Field
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Date of Birth")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                
                Button(action: {
                    isShowingDatePicker = true
                }) {
                    HStack {
                        Text(dateOfBirth?.formatted(date: .abbreviated, time: .omitted) ?? "Select your birth date")
                            .foregroundColor(dateOfBirth != nil ? Theme.Colors.textPrimary : Theme.Colors.textTertiary)
                        
                        Spacer()
                        
                        Image(systemName: "calendar")
                            .foregroundColor(Theme.Colors.primary)
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.surface)
                    .cornerRadius(Theme.CornerRadius.textField)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.textField)
                            .stroke(Theme.Colors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Text("Optional - helps us provide personalized content")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            
            // Birth Hour Field
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Birth Hour")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                
                Button(action: {
                    isShowingBirthHourPicker = true
                }) {
                    HStack {
                        Text(birthHour != nil ? "\(birthHour!)h (24-hour format)" : "Select your birth hour")
                            .foregroundColor(birthHour != nil ? Theme.Colors.textPrimary : Theme.Colors.textTertiary)
                        
                        Spacer()
                        
                        Image(systemName: "clock")
                            .foregroundColor(Theme.Colors.primary)
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.surface)
                    .cornerRadius(Theme.CornerRadius.textField)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.textField)
                            .stroke(Theme.Colors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Text("Optional - for more precise astrological insights")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)
            }
        }
    }
    
    // MARK: - Nickname Status Indicator
    private var nicknameStatusIndicator: some View {
        Group {
            if isCheckingNickname {
                HStack(spacing: Theme.Spacing.xs) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Checking...")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            } else if let isAvailable = isNicknameAvailable, !nickname.isEmpty {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isAvailable ? Theme.Colors.statusSuccess : Theme.Colors.statusError)
                    Text(isAvailable ? "Available" : "Taken")
                        .font(Theme.Typography.caption)
                        .foregroundColor(isAvailable ? Theme.Colors.statusSuccess : Theme.Colors.statusError)
                }
            }
        }
    }
    
    // MARK: - Error Section
    private var errorSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            ForEach(validationErrors, id: \.localizedDescription) { error in
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Theme.Colors.statusError)
                        .font(.caption)
                    
                    Text(error.localizedDescription)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.statusError)
                    
                    Spacer()
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.statusError.opacity(0.1))
        .cornerRadius(Theme.CornerRadius.sm)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Primary Action Button
            Button(action: saveProfile) {
                HStack {
                    if profileStore.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    }
                    
                    Text(isOnboarding ? "Complete Setup" : "Save Changes")
                        .font(Theme.Typography.body)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundColor(.white)
                .background(isFormValid ? Theme.Colors.primary : Theme.Colors.buttonDisabled)
                .cornerRadius(Theme.CornerRadius.button)
            }
            .disabled(!isFormValid || profileStore.isLoading || isCheckingNickname)
            
            // Skip Button (Onboarding only)
            if isOnboarding {
                Button(action: skipSetup) {
                    Text("Skip for now")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .padding(.top, Theme.Spacing.sm)
            }
        }
    }
    
    // MARK: - Navigation Bar Buttons
    private var cancelButton: some View {
        Group {
            if !isOnboarding {
                Button("Cancel") {
                    dismiss()
                }
            } else {
                EmptyView()
            }
        }
    }
    
    private var saveButton: some View {
        Group {
            if !profileStore.isLoading {
                Button("Save") {
                    saveProfile()
                }
                .disabled(!isFormValid || isCheckingNickname)
            } else {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
    }
    
    // MARK: - Computed Properties
    private var isFormValid: Bool {
        let nameValid = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let nicknameValid = nickname.isEmpty || (isNicknameAvailable == true)
        
        return nameValid && nicknameValid && validationErrors.isEmpty
    }
    
    // MARK: - Actions
    private func loadExistingProfile() {
        guard let profile = profileStore.userProfile else { return }
        
        name = profile.name ?? ""
        nickname = profile.nickname ?? ""
        dateOfBirth = profile.dateOfBirth
        birthHour = profile.birthHour
    }
    
    private func validateForm() {
        validationErrors.removeAll()
        
        // Create a temporary profile for validation
        let tempProfile = AppProfile(
            userId: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            dateOfBirth: dateOfBirth,
            birthHour: birthHour
        )
        
        do {
            try tempProfile.validate()
        } catch let error as ProfileValidationError {
            validationErrors.append(error)
        } catch {
            // Handle other validation errors
        }
        
        // Check if name is required
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationErrors.append(.nameRequired)
        }
        
        // Check nickname availability
        if !nickname.isEmpty && isNicknameAvailable == false {
            validationErrors.append(.nicknameTaken)
        }
    }
    
    private func checkNicknameAvailability() async {
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedNickname.isEmpty else {
            isNicknameAvailable = nil
            return
        }
        
        // Reset state
        isCheckingNickname = true
        isNicknameAvailable = nil
        
        // Add delay to prevent too many API calls
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Check if nickname changed while we were waiting
        guard nickname.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedNickname else {
            isCheckingNickname = false
            return
        }
        
        do {
            let isAvailable = try await profileStore.checkNicknameAvailability(trimmedNickname)
            await MainActor.run {
                isNicknameAvailable = isAvailable
                isCheckingNickname = false
                validateForm()
            }
        } catch {
            await MainActor.run {
                isNicknameAvailable = false
                isCheckingNickname = false
                print("❌ Error checking nickname availability: \(error)")
            }
        }
    }
    
    private func saveProfile() {
        hasAttemptedSubmit = true
        validateForm()
        
        guard isFormValid else {
            return
        }
        
        Task {
            do {
                let updatedProfile = try await profileStore.updateProfile(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : nickname.trimmingCharacters(in: .whitespacesAndNewlines),
                    dateOfBirth: dateOfBirth,
                    birthHour: birthHour
                )
                
                await MainActor.run {
                    onComplete?(updatedProfile)
                    
                    if !isOnboarding {
                        dismiss()
                    }
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                }
            }
        }
    }
    
    private func skipSetup() {
        // Initialize with minimal profile
        Task {
            do {
                let profile = try await profileStore.initializeProfile()
                onComplete?(profile)
            } catch {
                print("❌ Failed to initialize profile: \(error)")
                // Still continue to main app
                onComplete?(CompleteUserProfile(user: nil, profile: nil, timestamp: Date().timeIntervalSince1970))
            }
        }
    }
}

// MARK: - Custom Text Field Style
struct ProfileTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.surface)
            .cornerRadius(Theme.CornerRadius.textField)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.textField)
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )
    }
}

// MARK: - Date Picker Sheet
struct DatePickerSheet: View {
    let selectedDate: Date
    let onSave: (Date) -> Void
    let onCancel: () -> Void
    
    @State private var date: Date
    
    init(selectedDate: Date, onSave: @escaping (Date) -> Void, onCancel: @escaping () -> Void) {
        self.selectedDate = selectedDate
        self.onSave = onSave
        self.onCancel = onCancel
        self._date = State(initialValue: selectedDate)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: Theme.Spacing.lg) {
                DatePicker(
                    "Date of Birth",
                    selection: $date,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                
                Spacer()
            }
            .screenPadding()
            .background(Theme.Colors.background)
            .navigationTitle("Date of Birth")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel", action: onCancel),
                trailing: Button("Save") { onSave(date) }
                    .fontWeight(.semibold)
            )
        }
    }
}

// MARK: - Birth Hour Picker Sheet
struct BirthHourPickerSheet: View {
    let selectedHour: Int?
    let onSave: (Int?) -> Void
    let onCancel: () -> Void
    
    @State private var hour: Int
    @State private var isEnabled: Bool
    
    init(selectedHour: Int?, onSave: @escaping (Int?) -> Void, onCancel: @escaping () -> Void) {
        self.selectedHour = selectedHour
        self.onSave = onSave
        self.onCancel = onCancel
        self._hour = State(initialValue: selectedHour ?? 12)
        self._isEnabled = State(initialValue: selectedHour != nil)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: Theme.Spacing.lg) {
                Toggle("Include birth hour", isOn: $isEnabled)
                    .padding()
                
                if isEnabled {
                    Picker("Hour", selection: $hour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text("\(hour)h").tag(hour)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                }
                
                Spacer()
                
                VStack(spacing: Theme.Spacing.sm) {
                    Text("Birth Hour Information")
                        .font(Theme.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    Text("Your birth hour helps provide more accurate astrological insights. This information is completely optional and remains private.")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Theme.Colors.surface)
                .cornerRadius(Theme.CornerRadius.sm)
            }
            .screenPadding()
            .background(Theme.Colors.background)
            .navigationTitle("Birth Hour")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel", action: onCancel),
                trailing: Button("Save") { 
                    onSave(isEnabled ? hour : nil) 
                }
                .fontWeight(.semibold)
            )
        }
    }
}

// MARK: - Previews
#Preview("Profile Setup - Onboarding") {
    ProfileSetupView(isOnboarding: true) { profile in
        print("Profile completed: \(profile)")
    }
}

#Preview("Profile Setup - Edit") {
    ProfileSetupView(isOnboarding: false) { profile in
        print("Profile updated: \(profile)")
    }
}

#Preview("Date Picker") {
    DatePickerSheet(
        selectedDate: Date(),
        onSave: { _ in },
        onCancel: { }
    )
}

#Preview("Birth Hour Picker") {
    BirthHourPickerSheet(
        selectedHour: nil,
        onSave: { _ in },
        onCancel: { }
    )
} 