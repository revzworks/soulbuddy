import Foundation
import Supabase

// MARK: - User Models
struct AppUser: Codable, Identifiable {
    let id: UUID
    let locale: String
    let timezone: String
    let isSubscriber: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case locale
        case timezone
        case isSubscriber = "is_subscriber"
        case createdAt = "created_at"
    }
}

struct AppProfile: Codable, Identifiable {
    let userId: UUID
    var name: String?
    var nickname: String?
    var dateOfBirth: Date?
    var birthHour: Int?
    
    var id: UUID { userId }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
        case nickname
        case dateOfBirth = "date_of_birth"
        case birthHour = "birth_hour"
    }
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

struct NotificationPreferences: Codable {
    let userId: UUID
    var frequency: Int // 1-4 notifications per day
    var quietStart: String? // HH:mm format
    var quietEnd: String? // HH:mm format
    var allowPush: Bool
    
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