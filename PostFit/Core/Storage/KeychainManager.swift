//
//  KeychainManager.swift
//  PostFit (MomCare)
//
//  Secure credential storage wrapper around Keychain Services
//  Used for storing sensitive data: tokens, user IDs, credentials
//

import Foundation
import Security

/// Manages secure storage of sensitive data using iOS Keychain
class KeychainManager {

    // MARK: - Properties

    /// Service identifier for Keychain items (uses app bundle ID)
    private let service: String

    /// Access group for shared keychain access (optional)
    private let accessGroup: String?

    // MARK: - Initialization

    init(service: String? = nil, accessGroup: String? = nil) {
        self.service = service ?? Bundle.main.bundleIdentifier ?? "com.momcare.postfit"
        self.accessGroup = accessGroup
    }

    // MARK: - Public Methods

    /// Save a string value to Keychain
    /// - Parameters:
    ///   - value: The string to save
    ///   - key: The key to associate with the value
    /// - Throws: StorageError if save fails
    func save(_ value: String, forKey key: String) async throws {
        guard let data = value.data(using: .utf8) else {
            throw StorageError.invalidData
        }

        try await save(data, forKey: key)
    }

    /// Save data to Keychain
    /// - Parameters:
    ///   - data: The data to save
    ///   - key: The key to associate with the data
    /// - Throws: StorageError if save fails
    func save(_ data: Data, forKey key: String) async throws {
        // Build query dictionary
        var query = buildBaseQuery(forKey: key)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked

        // Try to delete existing item first
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw mapKeychainError(status)
        }
    }

    /// Retrieve a string value from Keychain
    /// - Parameter key: The key associated with the value
    /// - Returns: The stored string value
    /// - Throws: StorageError if retrieval fails
    func retrieve(forKey key: String) async throws -> String {
        let data = try await retrieveData(forKey: key)

        guard let string = String(data: data, encoding: .utf8) else {
            throw StorageError.invalidData
        }

        return string
    }

    /// Retrieve data from Keychain
    /// - Parameter key: The key associated with the data
    /// - Returns: The stored data
    /// - Throws: StorageError if retrieval fails
    func retrieveData(forKey key: String) async throws -> Data {
        var query = buildBaseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            throw mapKeychainError(status)
        }

        guard let data = result as? Data else {
            throw StorageError.invalidData
        }

        return data
    }

    /// Delete an item from Keychain
    /// - Parameter key: The key of the item to delete
    /// - Throws: StorageError if deletion fails
    func delete(forKey key: String) async throws {
        let query = buildBaseQuery(forKey: key)
        let status = SecItemDelete(query as CFDictionary)

        // errSecItemNotFound is acceptable (item already deleted)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw mapKeychainError(status)
        }
    }

    /// Update an existing item in Keychain
    /// - Parameters:
    ///   - value: The new string value
    ///   - key: The key of the item to update
    /// - Throws: StorageError if update fails
    func update(_ value: String, forKey key: String) async throws {
        guard let data = value.data(using: .utf8) else {
            throw StorageError.invalidData
        }

        let query = buildBaseQuery(forKey: key)
        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)

        guard status == errSecSuccess else {
            // If item doesn't exist, create it
            if status == errSecItemNotFound {
                try await save(value, forKey: key)
                return
            } else {
                throw mapKeychainError(status)
            }
        }
    }

    /// Check if an item exists in Keychain
    /// - Parameter key: The key to check
    /// - Returns: True if the item exists, false otherwise
    func exists(forKey key: String) async -> Bool {
        var query = buildBaseQuery(forKey: key)
        query[kSecReturnData as String] = false
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Delete all items for this service
    /// - Throws: StorageError if deletion fails
    func deleteAll() async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)

        // errSecItemNotFound is acceptable (nothing to delete)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw mapKeychainError(status)
        }
    }

    // MARK: - Private Methods

    /// Build base query dictionary for Keychain operations
    private func buildBaseQuery(forKey key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }

    /// Map Keychain status code to StorageError
    private func mapKeychainError(_ status: OSStatus) -> StorageError {
        switch status {
        case errSecItemNotFound:
            return .itemNotFound
        case errSecDuplicateItem:
            return .duplicateItem
        case errSecAuthFailed:
            return .unauthorized
        case errSecParam, errSecBadReq:
            return .invalidData
        default:
            return .unexpectedError("Keychain error code: \(status)")
        }
    }
}

// MARK: - Keychain Keys

extension KeychainManager {
    /// Standard keys for authentication data
    enum Keys {
        static let appleUserID = "appleUserID"
        static let googleUserID = "googleUserID"
        static let sessionToken = "sessionToken"
        static let refreshToken = "refreshToken"
    }
}
