//
//  soulbuddyTests.swift
//  soulbuddyTests
//
//  Created by Umut Danışman on 7.08.2025.
//

import XCTest
@testable import soulbuddy

final class soulbuddyTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // MARK: - Model Tests
    
    func testAffirmationModel() throws {
        let affirmation = Affirmation(
            id: UUID(),
            categoryId: UUID(),
            text: "I am confident and capable",
            locale: "en",
            intensity: 2,
            tags: ["confidence", "self-esteem"],
            isActive: true,
            lastUsedAt: nil
        )
        
        XCTAssertEqual(affirmation.intensity, 2)
        XCTAssertEqual(affirmation.intensityLevel, .moderate)
        XCTAssertEqual(affirmation.locale, "en")
        XCTAssertTrue(affirmation.isActive)
        XCTAssertEqual(affirmation.tags.count, 2)
    }
    
    func testAffirmationCategoryDisplayName() throws {
        let confidenceCategory = AffirmationCategory(
            id: UUID(),
            key: "confidence",
            locale: "en",
            isActive: true
        )
        
        let confidenceCategoryTR = AffirmationCategory(
            id: UUID(),
            key: "confidence",
            locale: "tr",
            isActive: true
        )
        
        XCTAssertEqual(confidenceCategory.displayName, "Confidence")
        XCTAssertEqual(confidenceCategoryTR.displayName, "Özgüven")
    }
    
    func testMoodSessionValidation() throws {
        let session = MoodSession(
            id: UUID(),
            userId: UUID(),
            categoryId: UUID(),
            status: .active,
            startedAt: Date(),
            endsAt: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
            frequencyPerDay: 2
        )
        
        XCTAssertTrue(session.isActive)
        XCTAssertEqual(session.frequencyPerDay, 2)
        XCTAssertTrue(session.daysRemaining >= 6) // Should be around 7 days
    }
    
    func testSubscriptionStatus() throws {
        let activeSubscription = AppSubscription(
            userId: UUID(),
            appleOriginalTransactionId: "12345",
            status: .active,
            renewsAt: Calendar.current.date(byAdding: .month, value: 1, to: Date()),
            revokedAt: nil,
            lastVerifiedAt: Date(),
            reason: nil
        )
        
        XCTAssertEqual(activeSubscription.status, .active)
        XCTAssertNotNil(activeSubscription.renewsAt)
        XCTAssertNil(activeSubscription.revokedAt)
    }
    
    func testNotificationPreferencesTimeConversion() throws {
        let preferences = NotificationPreferences(
            userId: UUID(),
            frequency: 3,
            quietStart: "22:00",
            quietEnd: "08:00",
            allowPush: true
        )
        
        XCTAssertEqual(preferences.frequency, 3)
        XCTAssertNotNil(preferences.quietStartTime)
        XCTAssertNotNil(preferences.quietEndTime)
        XCTAssertTrue(preferences.allowPush)
    }
    
    // MARK: - IntensityLevel Tests
    
    func testIntensityLevelValues() throws {
        XCTAssertEqual(IntensityLevel.gentle.rawValue, 1)
        XCTAssertEqual(IntensityLevel.moderate.rawValue, 2)
        XCTAssertEqual(IntensityLevel.strong.rawValue, 3)
    }
    
    func testIntensityLevelFromRawValue() throws {
        XCTAssertEqual(IntensityLevel(rawValue: 1), .gentle)
        XCTAssertEqual(IntensityLevel(rawValue: 2), .moderate)
        XCTAssertEqual(IntensityLevel(rawValue: 3), .strong)
        XCTAssertNil(IntensityLevel(rawValue: 4))
    }
    
    // MARK: - SessionStatus Tests
    
    func testSessionStatusValues() throws {
        XCTAssertEqual(SessionStatus.active.rawValue, "active")
        XCTAssertEqual(SessionStatus.completed.rawValue, "completed")
        XCTAssertEqual(SessionStatus.cancelled.rawValue, "cancelled")
    }
    
    // MARK: - Profile Tests
    
    func testAppProfileInitialization() throws {
        let userId = UUID()
        let profile = AppProfile(
            userId: userId,
            name: "John Doe",
            nickname: "johnny",
            dateOfBirth: Date(),
            birthHour: 14
        )
        
        XCTAssertEqual(profile.userId, userId)
        XCTAssertEqual(profile.id, userId) // id should be the same as userId
        XCTAssertEqual(profile.name, "John Doe")
        XCTAssertEqual(profile.nickname, "johnny")
        XCTAssertEqual(profile.birthHour, 14)
    }
    
    func testAppProfileOptionalFields() throws {
        let userId = UUID()
        let profile = AppProfile(
            userId: userId,
            name: nil,
            nickname: nil,
            dateOfBirth: nil,
            birthHour: nil
        )
        
        XCTAssertEqual(profile.userId, userId)
        XCTAssertNil(profile.name)
        XCTAssertNil(profile.nickname)
        XCTAssertNil(profile.dateOfBirth)
        XCTAssertNil(profile.birthHour)
    }
    
    // MARK: - DeviceToken Tests
    
    func testDeviceTokenModel() throws {
        let deviceToken = DeviceToken(
            id: UUID(),
            userId: UUID(),
            token: "abc123token",
            bundleId: "com.soulpal.app",
            platform: "ios",
            isActive: true,
            updatedAt: Date()
        )
        
        XCTAssertEqual(deviceToken.platform, "ios")
        XCTAssertTrue(deviceToken.isActive)
        XCTAssertEqual(deviceToken.bundleId, "com.soulpal.app")
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
            let categories = (1...1000).map { i in
                AffirmationCategory(
                    id: UUID(),
                    key: "category_\(i)",
                    locale: "en",
                    isActive: true
                )
            }
            
            let filteredCategories = categories.filter { $0.isActive }
            XCTAssertEqual(filteredCategories.count, 1000)
        }
    }
    
    // MARK: - Date and Calendar Tests
    
    func testMoodSessionDaysRemaining() throws {
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 5, to: startDate)!
        
        let session = MoodSession(
            id: UUID(),
            userId: UUID(),
            categoryId: UUID(),
            status: .active,
            startedAt: startDate,
            endsAt: endDate,
            frequencyPerDay: 2
        )
        
        // Should be approximately 5 days remaining
        XCTAssertTrue(session.daysRemaining >= 4 && session.daysRemaining <= 5)
    }
    
    func testExpiredMoodSession() throws {
        let startDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let endDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        
        let session = MoodSession(
            id: UUID(),
            userId: UUID(),
            categoryId: UUID(),
            status: .active,
            startedAt: startDate,
            endsAt: endDate,
            frequencyPerDay: 2
        )
        
        // Session should not be active since end date is in the past
        XCTAssertFalse(session.isActive)
    }
    
    // MARK: - Error Handling Tests
    
    func testSubscriptionStatusCodingKeys() throws {
        let jsonData = """
        {
            "user_id": "123e4567-e89b-12d3-a456-426614174000",
            "apple_original_transaction_id": "12345",
            "status": "active",
            "renews_at": "2024-12-31T23:59:59Z",
            "revoked_at": null,
            "last_verified_at": "2024-01-01T00:00:00Z",
            "reason": null
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        XCTAssertNoThrow(try decoder.decode(AppSubscription.self, from: jsonData))
    }
}

// MARK: - UI Tests Helper Extensions

extension soulbuddyTests {
    
    func testAccessibilityLabels() throws {
        // Test that accessibility labels are properly set
        let affirmation = Affirmation(
            id: UUID(),
            categoryId: UUID(),
            text: "I am awesome",
            locale: "en",
            intensity: 1,
            tags: [],
            isActive: true,
            lastUsedAt: nil
        )
        
        XCTAssertEqual(affirmation.intensityLevel.localizedDisplayName, "Gentle")
    }
    
    func testCategoryIconMapping() throws {
        // This would test the icon mapping logic if moved to a testable location
        let categories = ["confidence", "motivation", "self_love", "stress_relief", "focus", "gratitude", "sleep", "energy"]
        
        for categoryKey in categories {
            let category = AffirmationCategory(
                id: UUID(),
                key: categoryKey,
                locale: "en",
                isActive: true
            )
            
            // Each category should have a non-empty display name
            XCTAssertFalse(category.displayName.isEmpty)
        }
    }
}
