//
//  UserProfileManager.swift
//  PostFit (MomCare)
//
//  Manager for persisting and loading complete user profile data
//  Stores User model including HealthProfile to UserDefaults with Firestore cloud sync
//

import Foundation
import SwiftUI

/// Singleton manager for persisting complete user profile data
/// Uses local UserDefaults storage with optional Firestore cloud backup
@MainActor
class UserProfileManager: ObservableObject {
    static let shared = UserProfileManager()

    // MARK: - Published Properties

    @Published var currentUser: User?
    @Published var hasLoadedProfile: Bool = false
    @Published var isSyncingToCloud: Bool = false
    @Published var lastCloudSyncDate: Date?

    // MARK: - Dependencies

    private let firestoreService = FirestoreUserService.shared

    // MARK: - Storage Keys

    private enum Keys {
        static let userProfile = "user_profile_data"
        static let healthProfile = "health_profile_data"
        static let userPreferences = "user_preferences_data"
        static let measurementUnit = "measurement_unit"
        static let lastCloudSync = "last_cloud_sync"
        static let userId = "user_id"
    }

    // MARK: - Initialization

    private init() {
        loadUserProfile()
        loadLastSyncDate()
    }

    private func loadLastSyncDate() {
        if let timestamp = UserDefaults.standard.object(forKey: Keys.lastCloudSync) as? TimeInterval {
            lastCloudSyncDate = Date(timeIntervalSince1970: timestamp)
        }
    }

    // MARK: - Save Methods

    /// Save complete user profile to UserDefaults and sync to cloud
    func saveUser(_ user: User, syncToCloud: Bool = true) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(user)
            UserDefaults.standard.set(data, forKey: Keys.userProfile)
            currentUser = user

            #if DEBUG
            print("✅ [UserProfileManager] User profile saved locally")
            #endif

            // Sync to cloud in background
            if syncToCloud {
                Task {
                    await syncUserToCloud(user)
                }
            }
        } catch {
            #if DEBUG
            print("❌ [UserProfileManager] Failed to save user profile: \(error)")
            #endif
        }
    }

    /// Sync user profile to Firestore cloud
    private func syncUserToCloud(_ user: User) async {
        guard let userId = getUserId() else {
            #if DEBUG
            print("⚠️ [UserProfileManager] No user ID for cloud sync")
            #endif
            return
        }

        isSyncingToCloud = true
        defer { isSyncingToCloud = false }

        do {
            try await firestoreService.saveUserProfile(user, userId: userId)
            lastCloudSyncDate = Date()
            UserDefaults.standard.set(lastCloudSyncDate?.timeIntervalSince1970, forKey: Keys.lastCloudSync)

            #if DEBUG
            print("☁️ [UserProfileManager] Profile synced to cloud")
            #endif
        } catch {
            #if DEBUG
            print("⚠️ [UserProfileManager] Cloud sync failed: \(error)")
            #endif
        }
    }

    /// Get current user ID from session
    private func getUserId() -> String? {
        return UserDefaults.standard.string(forKey: Keys.userId)
            ?? UserDefaults.standard.string(forKey: "user_id")
    }

    /// Save only health profile (updates existing user or creates placeholder)
    func saveHealthProfile(_ healthProfile: HealthProfile) {
        if var user = currentUser {
            user.healthProfile = healthProfile
            saveUser(user)
        } else {
            // Store health profile separately if no user exists yet
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(healthProfile)
                UserDefaults.standard.set(data, forKey: Keys.healthProfile)

                #if DEBUG
                print("✅ [UserProfileManager] Health profile saved separately")
                #endif
            } catch {
                #if DEBUG
                print("❌ [UserProfileManager] Failed to save health profile: \(error)")
                #endif
            }
        }
    }

    /// Save user preferences
    func savePreferences(_ preferences: UserPreferences) {
        if var user = currentUser {
            user.preferences = preferences
            saveUser(user)
        } else {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(preferences)
                UserDefaults.standard.set(data, forKey: Keys.userPreferences)

                #if DEBUG
                print("✅ [UserProfileManager] Preferences saved separately")
                #endif
            } catch {
                #if DEBUG
                print("❌ [UserProfileManager] Failed to save preferences: \(error)")
                #endif
            }
        }
    }

    /// Update user's name
    func updateName(_ name: String) {
        if var user = currentUser {
            user.name = name
            saveUser(user)

            // Also update UserSessionManager
            UserSessionManager.shared.updateUserName(name)
        }
    }

    /// Update user's email
    func updateEmail(_ email: String) {
        if var user = currentUser {
            user.email = email
            saveUser(user)

            // Also update UserSessionManager
            UserSessionManager.shared.updateUserEmail(email)
        }
    }

    /// Update measurement unit preference
    func updateMeasurementUnit(_ unit: MeasurementUnit) {
        if var user = currentUser {
            user.preferences.measurementUnit = unit
            saveUser(user)
        }
        UserDefaults.standard.set(unit.rawValue, forKey: Keys.measurementUnit)
    }

    // MARK: - Load Methods

    /// Load user profile from UserDefaults
    func loadUserProfile() {
        // Try to load complete user profile
        if let data = UserDefaults.standard.data(forKey: Keys.userProfile) {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let user = try decoder.decode(User.self, from: data)
                currentUser = user
                hasLoadedProfile = true

                #if DEBUG
                print("✅ [UserProfileManager] User profile loaded: \(user.name)")
                #endif
                return
            } catch {
                #if DEBUG
                print("❌ [UserProfileManager] Failed to decode user profile: \(error)")
                #endif
            }
        }

        // If no complete user profile, try to construct from session data
        createUserFromSession()
    }

    /// Create a User object from session data and any saved health profile
    private func createUserFromSession() {
        let sessionManager = UserSessionManager.shared

        // Only create if we have session data
        guard sessionManager.isAuthenticated else {
            hasLoadedProfile = true
            return
        }

        let name = sessionManager.userName
        let email = sessionManager.userEmail
        let profileImageURL = sessionManager.profileImageURL

        // Try to load saved health profile
        var healthProfile = HealthProfile()
        if let healthData = UserDefaults.standard.data(forKey: Keys.healthProfile) {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                healthProfile = try decoder.decode(HealthProfile.self, from: healthData)
            } catch {
                #if DEBUG
                print("⚠️ [UserProfileManager] Could not load saved health profile")
                #endif
            }
        }

        // Try to load saved preferences
        var preferences = UserPreferences()
        if let prefsData = UserDefaults.standard.data(forKey: Keys.userPreferences) {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                preferences = try decoder.decode(UserPreferences.self, from: prefsData)
            } catch {
                #if DEBUG
                print("⚠️ [UserProfileManager] Could not load saved preferences")
                #endif
            }
        }

        // Load measurement unit preference
        if let unitString = UserDefaults.standard.string(forKey: Keys.measurementUnit),
           let unit = MeasurementUnit(rawValue: unitString) {
            preferences.measurementUnit = unit
        }

        let user = User(
            email: email,
            name: name,
            profileImageURL: profileImageURL,
            healthProfile: healthProfile,
            preferences: preferences
        )

        currentUser = user
        hasLoadedProfile = true

        // Save the complete user for future loads
        saveUser(user)

        #if DEBUG
        print("✅ [UserProfileManager] Created user from session: \(name)")
        #endif
    }

    /// Get current measurement unit
    var measurementUnit: MeasurementUnit {
        currentUser?.preferences.measurementUnit ?? .metric
    }

    // MARK: - Cloud Sync Methods

    /// Load profile from cloud on login
    /// Call this after successful authentication to restore user data
    /// Only restores essential data: name, email, subscription, basic health info
    func loadProfileFromCloud() async {
        guard let userId = getUserId() else {
            #if DEBUG
            print("⚠️ [UserProfileManager] No user ID for cloud load")
            #endif
            return
        }

        #if DEBUG
        print("☁️ [UserProfileManager] Attempting to load essential data from cloud...")
        #endif

        // Get cloud profile (minimal data)
        if let cloudProfile = await firestoreService.syncFromCloud(userId: userId) {
            // Merge cloud data with existing local profile or create new
            await mergeCloudProfile(cloudProfile)
        } else {
            #if DEBUG
            print("ℹ️ [UserProfileManager] No cloud profile found, using local data")
            #endif
        }
    }

    /// Merge cloud profile data into local user
    /// Cloud data takes precedence for identification fields
    private func mergeCloudProfile(_ cloudProfile: CloudUserProfile) async {
        var user = currentUser ?? User(email: cloudProfile.email, name: cloudProfile.name)

        // Update identification fields from cloud
        user.name = cloudProfile.name
        user.email = cloudProfile.email

        // Update subscription status
        if let status = SubscriptionStatus(rawValue: cloudProfile.subscriptionStatus) {
            user.subscriptionStatus = status
        }

        // Update basic health info from cloud
        let healthInfo = cloudProfile.healthBasicInfo
        user.healthProfile.deliveryDate = healthInfo.deliveryDate
        if let deliveryTypeString = healthInfo.deliveryType,
           let deliveryType = DeliveryType(rawValue: deliveryTypeString) {
            user.healthProfile.deliveryType = deliveryType
        }
        user.healthProfile.currentWeight = healthInfo.currentWeight
        user.healthProfile.height = healthInfo.height
        user.healthProfile.isBreastfeeding = healthInfo.isBreastfeeding
        if let level = ActivityLevel(rawValue: healthInfo.activityLevel) {
            user.healthProfile.activityLevel = level
        }

        // Update dietary restrictions from cloud
        user.healthProfile.dietaryRestrictions = healthInfo.dietaryRestrictions.compactMap {
            DietaryRestriction(rawValue: $0)
        }

        // Update medical conditions from cloud
        user.healthProfile.medicalConditions = healthInfo.medicalConditions.compactMap {
            MedicalCondition(rawValue: $0)
        }

        // Save merged profile locally (don't re-sync to cloud)
        saveUser(user, syncToCloud: false)

        #if DEBUG
        print("✅ [UserProfileManager] Merged cloud profile:")
        print("   - Name: \(user.name)")
        print("   - Email: \(user.email)")
        print("   - Subscription: \(user.subscriptionStatus.rawValue)")
        print("   - Dietary Restrictions: \(user.healthProfile.dietaryRestrictions.count)")
        print("   - Medical Conditions: \(user.healthProfile.medicalConditions.count)")
        #endif
    }

    /// Force sync current profile to cloud
    func forceSyncToCloud() async {
        guard let user = currentUser else { return }
        await syncUserToCloud(user)
    }

    /// Check if cloud sync is available
    var isCloudSyncAvailable: Bool {
        return getUserId() != nil
    }

    // MARK: - Clear Data

    /// Clear all stored profile data (local and optionally cloud)
    func clearAllData(includeCloud: Bool = false) {
        UserDefaults.standard.removeObject(forKey: Keys.userProfile)
        UserDefaults.standard.removeObject(forKey: Keys.healthProfile)
        UserDefaults.standard.removeObject(forKey: Keys.userPreferences)
        UserDefaults.standard.removeObject(forKey: Keys.measurementUnit)
        UserDefaults.standard.removeObject(forKey: Keys.lastCloudSync)
        currentUser = nil
        hasLoadedProfile = false
        lastCloudSyncDate = nil

        if includeCloud, let userId = getUserId() {
            Task {
                try? await firestoreService.deleteUserProfile(userId: userId)
            }
        }

        #if DEBUG
        print("🗑️ [UserProfileManager] All profile data cleared")
        #endif
    }
}

// MARK: - UserSessionManager Extension

extension UserSessionManager {
    /// Update stored user name
    func updateUserName(_ name: String) {
        UserDefaults.standard.set(name, forKey: "user_name")
        objectWillChange.send()
    }

    /// Update stored user email
    func updateUserEmail(_ email: String) {
        UserDefaults.standard.set(email, forKey: "user_email")
        objectWillChange.send()
    }
}
