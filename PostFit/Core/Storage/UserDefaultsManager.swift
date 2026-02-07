//
//  UserDefaultsManager.swift
//  PostFit (MomCare)
//
//  Type-safe wrapper for UserDefaults
//  Used for non-sensitive data storage: user preferences, flags, cached data
//

import Foundation

/// Manages non-sensitive data storage using UserDefaults
class UserDefaultsManager {

    // MARK: - Properties

    private let userDefaults: UserDefaults

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Generic Methods

    /// Save a value to UserDefaults
    /// - Parameters:
    ///   - value: The value to save (must be a property list type)
    ///   - key: The key to associate with the value
    func save<T>(_ value: T, forKey key: String) where T: Any {
        userDefaults.set(value, forKey: key)
        userDefaults.synchronize()
    }

    /// Retrieve a value from UserDefaults
    /// - Parameter key: The key associated with the value
    /// - Returns: The stored value, or nil if not found
    func retrieve<T>(forKey key: String) -> T? {
        return userDefaults.object(forKey: key) as? T
    }

    /// Remove a value from UserDefaults
    /// - Parameter key: The key of the value to remove
    func remove(forKey key: String) {
        userDefaults.removeObject(forKey: key)
        userDefaults.synchronize()
    }

    /// Check if a value exists in UserDefaults
    /// - Parameter key: The key to check
    /// - Returns: True if the key exists, false otherwise
    func exists(forKey key: String) -> Bool {
        return userDefaults.object(forKey: key) != nil
    }

    // MARK: - Typed Methods

    /// Save a string value
    func saveString(_ value: String, forKey key: String) {
        save(value, forKey: key)
    }

    /// Retrieve a string value
    func retrieveString(forKey key: String) -> String? {
        return retrieve(forKey: key)
    }

    /// Save a boolean value
    func saveBool(_ value: Bool, forKey key: String) {
        userDefaults.set(value, forKey: key)
        userDefaults.synchronize()
    }

    /// Retrieve a boolean value
    func retrieveBool(forKey key: String) -> Bool {
        return userDefaults.bool(forKey: key)
    }

    /// Save an integer value
    func saveInt(_ value: Int, forKey key: String) {
        userDefaults.set(value, forKey: key)
        userDefaults.synchronize()
    }

    /// Retrieve an integer value
    func retrieveInt(forKey key: String) -> Int {
        return userDefaults.integer(forKey: key)
    }

    /// Save a double value
    func saveDouble(_ value: Double, forKey key: String) {
        userDefaults.set(value, forKey: key)
        userDefaults.synchronize()
    }

    /// Retrieve a double value
    func retrieveDouble(forKey key: String) -> Double {
        return userDefaults.double(forKey: key)
    }

    /// Save a Codable object
    func saveCodable<T: Codable>(_ value: T, forKey key: String) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        userDefaults.set(data, forKey: key)
        userDefaults.synchronize()
    }

    /// Retrieve a Codable object
    func retrieveCodable<T: Codable>(forKey key: String, as type: T.Type) throws -> T? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }

        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }

    /// Clear all UserDefaults for the app
    func clearAll() {
        if let bundleID = Bundle.main.bundleIdentifier {
            userDefaults.removePersistentDomain(forName: bundleID)
            userDefaults.synchronize()
        }
    }
}

// MARK: - UserDefaults Keys

extension UserDefaultsManager {
    /// Standard keys for app data
    enum Keys {
        static let userId = "userId"
        static let userEmail = "userEmail"
        static let lastLoginProvider = "lastLoginProvider"
        static let lastSyncDate = "lastSyncDate"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let isAuthenticated = "isAuthenticated"
        static let hasCompletedProfileSetup = "hasCompletedProfileSetup"
        static let hasAcceptedDisclaimer = "hasAcceptedDisclaimer"
    }
}
