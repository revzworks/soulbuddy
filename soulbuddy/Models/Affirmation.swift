import Foundation

// MARK: - Content Models
struct AffirmationCategory: Codable, Identifiable, Hashable {
    let id: UUID
    let key: String
    let locale: String
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case key
        case locale
        case isActive = "is_active"
    }
    
    // Localized display name
    var displayName: String {
        switch key {
        case "confidence":
            return locale == "tr" ? "Özgüven" : "Confidence"
        case "motivation":
            return locale == "tr" ? "Motivasyon" : "Motivation"
        case "self_love":
            return locale == "tr" ? "Özsevgi" : "Self Love"
        case "stress_relief":
            return locale == "tr" ? "Stres Azaltma" : "Stress Relief"
        case "focus":
            return locale == "tr" ? "Odaklanma" : "Focus"
        case "gratitude":
            return locale == "tr" ? "Minnettarlık" : "Gratitude"
        case "sleep":
            return locale == "tr" ? "Uyku" : "Sleep"
        case "energy":
            return locale == "tr" ? "Enerji" : "Energy"
        default:
            return key.capitalized
        }
    }
}

struct Affirmation: Codable, Identifiable, Hashable {
    let id: UUID
    let categoryId: UUID
    let text: String
    let locale: String
    let intensity: Int // 1-3 (gentle, moderate, strong)
    let tags: [String]
    let isActive: Bool
    let lastUsedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case categoryId = "category_id"
        case text
        case locale
        case intensity
        case tags
        case isActive = "is_active"
        case lastUsedAt = "last_used_at"
    }
    
    var intensityLevel: IntensityLevel {
        IntensityLevel(rawValue: intensity) ?? .gentle
    }
}

enum IntensityLevel: Int, CaseIterable {
    case gentle = 1
    case moderate = 2
    case strong = 3
    
    var displayName: String {
        switch self {
        case .gentle:
            return "Gentle"
        case .moderate:
            return "Moderate"
        case .strong:
            return "Strong"
        }
    }
    
    var localizedDisplayName: String {
        switch self {
        case .gentle:
            return NSLocalizedString("intensity.gentle", value: "Gentle", comment: "Gentle intensity level")
        case .moderate:
            return NSLocalizedString("intensity.moderate", value: "Moderate", comment: "Moderate intensity level")
        case .strong:
            return NSLocalizedString("intensity.strong", value: "Strong", comment: "Strong intensity level")
        }
    }
}

// MARK: - Mood Session Models
struct MoodSession: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let categoryId: UUID
    let status: SessionStatus
    let startedAt: Date
    let endsAt: Date
    let frequencyPerDay: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case categoryId = "category_id"
        case status
        case startedAt = "started_at"
        case endsAt = "ends_at"
        case frequencyPerDay = "frequency_per_day"
    }
    
    var isActive: Bool {
        status == .active && endsAt > Date()
    }
    
    var daysRemaining: Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: Date(), to: endsAt).day ?? 0
    }
}

enum SessionStatus: String, Codable, CaseIterable {
    case active
    case completed
    case cancelled
} 