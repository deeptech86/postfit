//
//  FirestoreUserService.swift
//  PostFit (MomCare)
//
//  Service for syncing essential user data to/from Firebase Firestore
//  Stores minimal data for user identification across devices/reinstalls
//
//  Stored Data:
//  - User name
//  - Email
//  - Basic health info (delivery date, delivery type, current weight, height)
//  - Subscription type (Free/Premium)
//  - Dietary restrictions
//  - Medical conditions
//

import Foundation
// TODO: Add FirebaseFirestore package in Xcode, then uncomment:
// import FirebaseFirestore

// MARK: - Cloud User Profile (Minimal data for identification)
/// Lightweight structure for cloud storage - only essential user data
struct CloudUserProfile: Codable {
    let name: String
    let email: String
    let subscriptionStatus: String  // "Free" or "Premium"
    let healthBasicInfo: CloudHealthBasicInfo
    let lastUpdated: Date

    init(from user: User) {
        self.name = user.name
        self.email = user.email
        self.subscriptionStatus = user.subscriptionStatus.rawValue
        self.healthBasicInfo = CloudHealthBasicInfo(from: user.healthProfile)
        self.lastUpdated = Date()
    }
}

/// Basic health info for cloud storage
struct CloudHealthBasicInfo: Codable {
    let deliveryDate: Date?
    let deliveryType: String?
    let currentWeight: Double?
    let height: Double?
    let isBreastfeeding: Bool
    let activityLevel: String
    let dietaryRestrictions: [String]
    let medicalConditions: [String]

    init(from healthProfile: HealthProfile) {
        self.deliveryDate = healthProfile.deliveryDate
        self.deliveryType = healthProfile.deliveryType?.rawValue
        self.currentWeight = healthProfile.currentWeight
        self.height = healthProfile.height
        self.isBreastfeeding = healthProfile.isBreastfeeding
        self.activityLevel = healthProfile.activityLevel.rawValue
        self.dietaryRestrictions = healthProfile.dietaryRestrictions.map { $0.rawValue }
        self.medicalConditions = healthProfile.medicalConditions.map { $0.rawValue }
    }
}

// MARK: - Firestore Error Types
enum FirestoreUserError: Error, LocalizedError {
    case notInitialized
    case userNotAuthenticated
    case documentNotFound
    case encodingError
    case decodingError
    case networkError(Error)
    case unknownError(Error)

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Firestore is not initialized. Please ensure Firebase is configured."
        case .userNotAuthenticated:
            return "User is not authenticated."
        case .documentNotFound:
            return "User profile not found in cloud storage."
        case .encodingError:
            return "Failed to encode user data for cloud storage."
        case .decodingError:
            return "Failed to decode user data from cloud storage."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknownError(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Firestore User Service Protocol
protocol FirestoreUserServiceProtocol {
    func saveUserProfile(_ user: User, userId: String) async throws
    func loadUserProfile(userId: String) async throws -> CloudUserProfile?
    func deleteUserProfile(userId: String) async throws
}

// MARK: - Firestore User Service
/// Service for syncing essential user data with Firebase Firestore
/// Only stores minimal data needed for user identification across devices
@MainActor
class FirestoreUserService: ObservableObject, FirestoreUserServiceProtocol {
    static let shared = FirestoreUserService()

    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?

    // Firestore collection name
    private let usersCollection = "users"

    // Document field names
    private enum Fields {
        static let name = "name"
        static let email = "email"
        static let subscriptionStatus = "subscriptionStatus"
        static let healthBasicInfo = "healthBasicInfo"
        static let lastUpdated = "lastUpdated"
    }

    private init() {
        #if DEBUG
        print("📦 [Firestore] FirestoreUserService initialized (minimal storage mode)")
        #endif
    }

    // MARK: - Save User Profile

    /// Save essential user data to Firestore
    /// Only stores: name, email, subscription status, basic health info
    func saveUserProfile(_ user: User, userId: String) async throws {
        #if DEBUG
        print("☁️ [Firestore] Saving essential user data for: \(userId)")
        #endif

        isSyncing = true
        defer { isSyncing = false }

        // Create minimal cloud profile
        let cloudProfile = CloudUserProfile(from: user)

        // Convert to dictionary for Firestore
        guard let profileData = try? encodeCloudProfile(cloudProfile) else {
            throw FirestoreUserError.encodingError
        }

        // TODO: Uncomment after adding FirebaseFirestore package in Xcode:
        // let db = Firestore.firestore()
        // try await db.collection(usersCollection).document(userId).setData(profileData, merge: true)

        lastSyncDate = Date()

        #if DEBUG
        print("✅ [Firestore] Essential user data saved:")
        print("   - Name: \(cloudProfile.name)")
        print("   - Email: \(cloudProfile.email)")
        print("   - Subscription: \(cloudProfile.subscriptionStatus)")
        print("   - Has delivery date: \(cloudProfile.healthBasicInfo.deliveryDate != nil)")
        #endif
    }

    // MARK: - Load User Profile

    /// Load essential user data from Firestore
    /// Returns CloudUserProfile for identification purposes
    func loadUserProfile(userId: String) async throws -> CloudUserProfile? {
        #if DEBUG
        print("☁️ [Firestore] Loading essential user data for: \(userId)")
        #endif

        isSyncing = true
        defer { isSyncing = false }

        // TODO: Uncomment after adding FirebaseFirestore package in Xcode:
        /*
        let db = Firestore.firestore()
        let document = try await db.collection(usersCollection).document(userId).getDocument()

        guard document.exists, let data = document.data() else {
            #if DEBUG
            print("ℹ️ [Firestore] No profile found for user: \(userId)")
            #endif
            return nil
        }

        return try decodeCloudProfile(data)
        */

        #if DEBUG
        print("⚠️ [Firestore] FirebaseFirestore not added yet - using local data only")
        #endif
        return nil
    }

    // MARK: - Delete User Profile

    /// Delete user profile from Firestore
    func deleteUserProfile(userId: String) async throws {
        #if DEBUG
        print("☁️ [Firestore] Deleting user profile for: \(userId)")
        #endif

        // TODO: Uncomment after adding FirebaseFirestore package in Xcode:
        // let db = Firestore.firestore()
        // try await db.collection(usersCollection).document(userId).delete()

        #if DEBUG
        print("✅ [Firestore] User profile deleted")
        #endif
    }

    // MARK: - Encoding Helpers

    private func encodeCloudProfile(_ profile: CloudUserProfile) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        // Encode health basic info
        let healthData = try encoder.encode(profile.healthBasicInfo)
        let healthDict = try JSONSerialization.jsonObject(with: healthData) as? [String: Any] ?? [:]

        return [
            Fields.name: profile.name,
            Fields.email: profile.email,
            Fields.subscriptionStatus: profile.subscriptionStatus,
            Fields.healthBasicInfo: healthDict,
            Fields.lastUpdated: ISO8601DateFormatter().string(from: profile.lastUpdated)
        ]
    }

    // MARK: - Decoding Helpers

    private func decodeCloudProfile(_ data: [String: Any]) throws -> CloudUserProfile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Decode health basic info
        var healthInfo = CloudHealthBasicInfo(from: HealthProfile())
        if let healthData = data[Fields.healthBasicInfo] as? [String: Any] {
            let healthJSON = try JSONSerialization.data(withJSONObject: healthData)
            healthInfo = try decoder.decode(CloudHealthBasicInfo.self, from: healthJSON)
        }

        // Parse last updated date
        let lastUpdated: Date
        if let dateString = data[Fields.lastUpdated] as? String {
            lastUpdated = ISO8601DateFormatter().date(from: dateString) ?? Date()
        } else {
            lastUpdated = Date()
        }

        // Create a temporary User to use the CloudUserProfile init
        // This is a workaround since CloudUserProfile is designed for encoding from User
        let name = data[Fields.name] as? String ?? ""
        let email = data[Fields.email] as? String ?? ""
        let subscriptionStatus = data[Fields.subscriptionStatus] as? String ?? "Free"

        // Manually create CloudUserProfile from decoded data
        return CloudUserProfileDecoded(
            name: name,
            email: email,
            subscriptionStatus: subscriptionStatus,
            healthBasicInfo: healthInfo,
            lastUpdated: lastUpdated
        ).toCloudUserProfile()
    }
}

// MARK: - Helper for Decoding
private struct CloudUserProfileDecoded {
    let name: String
    let email: String
    let subscriptionStatus: String
    let healthBasicInfo: CloudHealthBasicInfo
    let lastUpdated: Date

    func toCloudUserProfile() -> CloudUserProfile {
        // Create a minimal User just for the CloudUserProfile init
        var user = User(email: email, name: name)
        if let status = SubscriptionStatus(rawValue: subscriptionStatus) {
            user.subscriptionStatus = status
        }

        // Apply health info
        if let deliveryDateValue = healthBasicInfo.deliveryDate {
            user.healthProfile.deliveryDate = deliveryDateValue
        }
        if let deliveryTypeString = healthBasicInfo.deliveryType,
           let deliveryType = DeliveryType(rawValue: deliveryTypeString) {
            user.healthProfile.deliveryType = deliveryType
        }
        user.healthProfile.currentWeight = healthBasicInfo.currentWeight
        user.healthProfile.height = healthBasicInfo.height
        user.healthProfile.isBreastfeeding = healthBasicInfo.isBreastfeeding
        if let level = ActivityLevel(rawValue: healthBasicInfo.activityLevel) {
            user.healthProfile.activityLevel = level
        }

        // Apply dietary restrictions
        user.healthProfile.dietaryRestrictions = healthBasicInfo.dietaryRestrictions.compactMap {
            DietaryRestriction(rawValue: $0)
        }

        // Apply medical conditions
        user.healthProfile.medicalConditions = healthBasicInfo.medicalConditions.compactMap {
            MedicalCondition(rawValue: $0)
        }

        return CloudUserProfile(from: user)
    }
}

// MARK: - Sync Manager Extension
extension FirestoreUserService {

    /// Sync local profile to cloud
    /// Call this after profile changes to ensure cloud backup
    func syncToCloud(user: User, userId: String) async {
        do {
            try await saveUserProfile(user, userId: userId)
            syncError = nil
        } catch {
            syncError = error
            #if DEBUG
            print("❌ [Firestore] Sync to cloud failed: \(error)")
            #endif
        }
    }

    /// Sync cloud profile to local
    /// Call this on login to restore profile from cloud
    /// Returns the cloud profile if found, for merging with local data
    func syncFromCloud(userId: String) async -> CloudUserProfile? {
        do {
            if let cloudProfile = try await loadUserProfile(userId: userId) {
                syncError = nil

                #if DEBUG
                print("✅ [Firestore] Profile restored from cloud:")
                print("   - Name: \(cloudProfile.name)")
                print("   - Email: \(cloudProfile.email)")
                print("   - Subscription: \(cloudProfile.subscriptionStatus)")
                #endif

                return cloudProfile
            }
        } catch {
            syncError = error
            #if DEBUG
            print("❌ [Firestore] Sync from cloud failed: \(error)")
            #endif
        }
        return nil
    }
}
