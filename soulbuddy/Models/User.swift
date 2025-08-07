import Foundation
import Supabase

// MARK: - User Models
struct AppUser: Codable, Identifiable, Equatable {
    let id: UUID
    let locale: String
    let timezone: String
    let isSubscriber: Bool
    let createdAt: Date
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case locale
        case timezone
        case isSubscriber = "is_subscriber"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Computed properties for convenience
    var displayLocale: Locale {
        return Locale(identifier: locale)
    }
    
    var displayTimeZone: TimeZone {
        return TimeZone(identifier: timezone) ?? TimeZone.current
    }
}

struct AppProfile: Codable, Identifiable, Equatable {
    let userId: UUID
    var name: String?
    var nickname: String?
    var dateOfBirth: Date?
    var birthHour: Int?
    let createdAt: Date?
    let updatedAt: Date?
    
    var id: UUID { userId }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
        case nickname
        case dateOfBirth = "date_of_birth"
        case birthHour = "birth_hour"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Initializer for creating new profiles
    init(
        userId: UUID,
        name: String? = nil,
        nickname: String? = nil,
        dateOfBirth: Date? = nil,
        birthHour: Int? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.userId = userId
        self.name = name
        self.nickname = nickname
        self.dateOfBirth = dateOfBirth
        self.birthHour = birthHour
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Computed properties for display
    var displayName: String {
        return name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "User"
    }
    
    var hasCompleteProfile: Bool {
        return name != nil && !name!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var initials: String {
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return "SP" // SoulPal default
        }
        
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            let first = String(components[0].prefix(1))
            let last = String(components[1].prefix(1))
            return (first + last).uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
    
    var age: Int? {
        guard let dateOfBirth = dateOfBirth else { return nil }
        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: dateOfBirth, to: now)
        return ageComponents.year
    }
    
    var formattedBirthHour: String? {
        guard let birthHour = birthHour else { return nil }
        return String(format: "%02d:00", birthHour)
    }
    
    // Validation
    func isValid() -> Bool {
        // Name is required and must not be empty
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return false
        }
        
        // Birth hour must be valid if provided
        if let birthHour = birthHour {
            guard birthHour >= 0 && birthHour <= 23 else { return false }
        }
        
        // Date of birth must be in the past if provided
        if let dateOfBirth = dateOfBirth {
            guard dateOfBirth <= Date() else { return false }
        }
        
        return true
    }
}

// MARK: - Complete User Profile Response
struct CompleteUserProfile: Codable {
    let user: AppUser?
    let profile: AppProfile?
    let timestamp: TimeInterval
    
    var hasUser: Bool {
        return user != nil
    }
    
    var hasProfile: Bool {
        return profile != nil
    }
    
    var isComplete: Bool {
        return hasUser && hasProfile && (profile?.hasCompleteProfile ?? false)
    }
}

// MARK: - Profile Store Models
struct ProfileUpdateRequest: Codable {
    let name: String?
    let nickname: String?
    let dateOfBirth: Date?
    let birthHour: Int?
    let locale: String?
    let timezone: String?
    
    enum CodingKeys: String, CodingKey {
        case name = "p_name"
        case nickname = "p_nickname"
        case dateOfBirth = "p_date_of_birth"
        case birthHour = "p_birth_hour"
        case locale = "p_locale"
        case timezone = "p_timezone"
    }
    
    init(
        name: String? = nil,
        nickname: String? = nil,
        dateOfBirth: Date? = nil,
        birthHour: Int? = nil,
        locale: String? = nil,
        timezone: String? = nil
    ) {
        self.name = name
        self.nickname = nickname
        self.dateOfBirth = dateOfBirth
        self.birthHour = birthHour
        self.locale = locale
        self.timezone = timezone
    }
}

struct NicknameAvailabilityResponse: Codable {
    let available: Bool
    let nickname: String
    let timestamp: TimeInterval
}

struct AppSubscription: Codable, Identifiable {
    let userId: UUID
    let appleOriginalTransactionId: String?
    let status: SubscriptionStatus
    let renewsAt: Date?
    let revokedAt: Date?
    let lastVerifiedAt: Date
    let reason: String?
    
    var id: UUID { userId }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case appleOriginalTransactionId = "apple_original_transaction_id"
        case status
        case renewsAt = "renews_at"
        case revokedAt = "revoked_at"
        case lastVerifiedAt = "last_verified_at"
        case reason
    }
}

enum SubscriptionStatus: String, Codable, CaseIterable {
    case active
    case grace
    case lapsed
    case revoked
}

struct NotificationPreferences: Codable, Identifiable {
    let userId: UUID
    var frequency: Int // 1-4 notifications per day
    var quietStart: String? // HH:mm format
    var quietEnd: String? // HH:mm format
    var allowPush: Bool
    
    var id: UUID { userId }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case frequency
        case quietStart = "quiet_start"
        case quietEnd = "quiet_end"
        case allowPush = "allow_push"
    }
    
    var quietStartTime: Date? {
        guard let quietStart = quietStart else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.date(from: quietStart)
    }
    
    var quietEndTime: Date? {
        guard let quietEnd = quietEnd else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.date(from: quietEnd)
    }
    
    func isInQuietHours(_ date: Date = Date()) -> Bool {
        guard let start = quietStartTime, let end = quietEndTime else { return false }
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let currentMinutes = hour * 60 + minute
        
        let startMinutes = calendar.component(.hour, from: start) * 60 + calendar.component(.minute, from: start)
        let endMinutes = calendar.component(.hour, from: end) * 60 + calendar.component(.minute, from: end)
        
        if startMinutes <= endMinutes {
            // Same day range (e.g., 9:00 to 17:00)
            return currentMinutes >= startMinutes && currentMinutes <= endMinutes
        } else {
            // Overnight range (e.g., 22:00 to 6:00)
            return currentMinutes >= startMinutes || currentMinutes <= endMinutes
        }
    }
}

// MARK: - Profile Validation Errors
enum ProfileValidationError: LocalizedError, Equatable {
    case nameRequired
    case nameEmpty
    case nameTooLong
    case nicknameTooLong
    case nicknameInvalid
    case nicknameTaken
    case birthHourInvalid
    case dateOfBirthInFuture
    case dateOfBirthTooOld
    
    var errorDescription: String? {
        switch self {
        case .nameRequired:
            return "Name is required"
        case .nameEmpty:
            return "Name cannot be empty"
        case .nameTooLong:
            return "Name is too long (maximum 100 characters)"
        case .nicknameTooLong:
            return "Nickname is too long (maximum 50 characters)"
        case .nicknameInvalid:
            return "Nickname contains invalid characters"
        case .nicknameTaken:
            return "Nickname is already taken"
        case .birthHourInvalid:
            return "Birth hour must be between 0 and 23"
        case .dateOfBirthInFuture:
            return "Date of birth cannot be in the future"
        case .dateOfBirthTooOld:
            return "Date of birth is too far in the past"
        }
    }
}

// MARK: - Profile Validation Extensions
extension AppProfile {
    func validate() throws {
        // Validate name
        if let name = name {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedName.isEmpty {
                throw ProfileValidationError.nameEmpty
            }
            if trimmedName.count > 100 {
                throw ProfileValidationError.nameTooLong
            }
        }
        
        // Validate nickname
        if let nickname = nickname {
            let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedNickname.count > 50 {
                throw ProfileValidationError.nicknameTooLong
            }
            
            // Check for invalid characters (allow alphanumeric, underscore, hyphen)
            let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
            if trimmedNickname.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
                throw ProfileValidationError.nicknameInvalid
            }
        }
        
        // Validate birth hour
        if let birthHour = birthHour {
            if birthHour < 0 || birthHour > 23 {
                throw ProfileValidationError.birthHourInvalid
            }
        }
        
        // Validate date of birth
        if let dateOfBirth = dateOfBirth {
            if dateOfBirth > Date() {
                throw ProfileValidationError.dateOfBirthInFuture
            }
            
            // Check if date is too old (more than 120 years ago)
            let calendar = Calendar.current
            if let maxDate = calendar.date(byAdding: .year, value: -120, to: Date()),
               dateOfBirth < maxDate {
                throw ProfileValidationError.dateOfBirthTooOld
            }
        }
    }
}

struct DeviceToken: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let token: String
    let bundleId: String
    let platform: String
    let isActive: Bool
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case token
        case bundleId = "bundle_id"
        case platform
        case isActive = "is_active"
        case updatedAt = "updated_at"
    }
} 