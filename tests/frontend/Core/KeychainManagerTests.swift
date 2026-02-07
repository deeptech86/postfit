//
//  KeychainManagerTests.swift
//  PostFit Tests
//
//  Unit tests for KeychainManager
//

import XCTest
@testable import PostFit

final class KeychainManagerTests: XCTestCase {

    var keychainManager: KeychainManager!
    let testService = "com.momcare.postfit.test"

    override func setUpWithTest() async throws {
        try await super.setUpWithTest()
        keychainManager = KeychainManager(service: testService)
        // Clean up any existing test data
        try? await keychainManager.deleteAll()
    }

    override func tearDownWithTest() async throws {
        // Clean up test data
        try? await keychainManager.deleteAll()
        keychainManager = nil
        try await super.tearDownWithTest()
    }

    // MARK: - Save Tests

    func testSaveString() async throws {
        // Given
        let key = "testKey"
        let value = "testValue"

        // When
        try await keychainManager.save(value, forKey: key)

        // Then
        let retrieved = try await keychainManager.retrieve(forKey: key)
        XCTAssertEqual(retrieved, value)
    }

    func testSaveData() async throws {
        // Given
        let key = "testDataKey"
        let data = "Test Data".data(using: .utf8)!

        // When
        try await keychainManager.save(data, forKey: key)

        // Then
        let retrieved = try await keychainManager.retrieveData(forKey: key)
        XCTAssertEqual(retrieved, data)
    }

    func testSaveOverwritesExistingValue() async throws {
        // Given
        let key = "overwriteKey"
        try await keychainManager.save("oldValue", forKey: key)

        // When
        try await keychainManager.save("newValue", forKey: key)

        // Then
        let retrieved = try await keychainManager.retrieve(forKey: key)
        XCTAssertEqual(retrieved, "newValue")
    }

    // MARK: - Retrieve Tests

    func testRetrieveNonExistentKey() async {
        // Given
        let key = "nonExistentKey"

        // When/Then
        do {
            _ = try await keychainManager.retrieve(forKey: key)
            XCTFail("Expected itemNotFound error")
        } catch {
            XCTAssertTrue(error is StorageError)
            if let storageError = error as? StorageError,
               case .itemNotFound = storageError {
                // Success
            } else {
                XCTFail("Expected StorageError.itemNotFound")
            }
        }
    }

    // MARK: - Delete Tests

    func testDelete() async throws {
        // Given
        let key = "deleteKey"
        try await keychainManager.save("value", forKey: key)

        // When
        try await keychainManager.delete(forKey: key)

        // Then
        let exists = await keychainManager.exists(forKey: key)
        XCTAssertFalse(exists)
    }

    func testDeleteNonExistentKey() async throws {
        // Given
        let key = "nonExistentDeleteKey"

        // When/Then - Should not throw error
        try await keychainManager.delete(forKey: key)
    }

    func testDeleteAll() async throws {
        // Given
        try await keychainManager.save("value1", forKey: "key1")
        try await keychainManager.save("value2", forKey: "key2")
        try await keychainManager.save("value3", forKey: "key3")

        // When
        try await keychainManager.deleteAll()

        // Then
        XCTAssertFalse(await keychainManager.exists(forKey: "key1"))
        XCTAssertFalse(await keychainManager.exists(forKey: "key2"))
        XCTAssertFalse(await keychainManager.exists(forKey: "key3"))
    }

    // MARK: - Update Tests

    func testUpdate() async throws {
        // Given
        let key = "updateKey"
        try await keychainManager.save("oldValue", forKey: key)

        // When
        try await keychainManager.update("newValue", forKey: key)

        // Then
        let retrieved = try await keychainManager.retrieve(forKey: key)
        XCTAssertEqual(retrieved, "newValue")
    }

    func testUpdateNonExistentKeyCreatesIt() async throws {
        // Given
        let key = "newUpdateKey"

        // When
        try await keychainManager.update("value", forKey: key)

        // Then
        let retrieved = try await keychainManager.retrieve(forKey: key)
        XCTAssertEqual(retrieved, "value")
    }

    // MARK: - Exists Tests

    func testExists() async throws {
        // Given
        let key = "existsKey"
        try await keychainManager.save("value", forKey: key)

        // When
        let exists = await keychainManager.exists(forKey: key)

        // Then
        XCTAssertTrue(exists)
    }

    func testExistsReturnsFalseForNonExistent() async {
        // Given
        let key = "nonExistentKey"

        // When
        let exists = await keychainManager.exists(forKey: key)

        // Then
        XCTAssertFalse(exists)
    }

    // MARK: - Standard Keys Tests

    func testSaveAndRetrieveAppleUserID() async throws {
        // Given
        let userID = "apple_user_123"

        // When
        try await keychainManager.save(userID, forKey: KeychainManager.Keys.appleUserID)

        // Then
        let retrieved = try await keychainManager.retrieve(forKey: KeychainManager.Keys.appleUserID)
        XCTAssertEqual(retrieved, userID)
    }

    func testSaveAndRetrieveSessionToken() async throws {
        // Given
        let token = "session_token_abc123"

        // When
        try await keychainManager.save(token, forKey: KeychainManager.Keys.sessionToken)

        // Then
        let retrieved = try await keychainManager.retrieve(forKey: KeychainManager.Keys.sessionToken)
        XCTAssertEqual(retrieved, token)
    }
}
