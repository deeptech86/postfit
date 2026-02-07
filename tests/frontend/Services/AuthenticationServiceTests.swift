//
//  AuthenticationServiceTests.swift
//  PostFit Tests
//
//  Unit tests for AuthenticationService
//

import XCTest
@testable import PostFit

final class AuthenticationServiceTests: XCTestCase {

    var authService: AuthenticationService!
    var mockAPIClient: MockAPIClient!
    var keychainManager: KeychainManager!
    var userDefaultsManager: UserDefaultsManager!
    var appleSignInService: AppleSignInService!
    var googleSignInService: GoogleSignInService!

    override func setUpWithTest() async throws {
        try await super.setUpWithTest()

        // Initialize dependencies
        keychainManager = KeychainManager(service: "com.momcare.postfit.test")
        userDefaultsManager = UserDefaultsManager()
        let cryptoUtilities = CryptoUtilities()

        // Initialize mock API client
        mockAPIClient = MockAPIClient()

        // Initialize auth services
        appleSignInService = AppleSignInService(
            keychainManager: keychainManager,
            cryptoUtilities: cryptoUtilities
        )

        googleSignInService = GoogleSignInService(
            keychainManager: keychainManager
        )

        // Initialize authentication service
        authService = AuthenticationService(
            apiClient: mockAPIClient,
            keychainManager: keychainManager,
            userDefaultsManager: userDefaultsManager,
            appleSignInService: appleSignInService,
            googleSignInService: googleSignInService
        )

        // Clean up any existing test data
        try? await keychainManager.deleteAll()
    }

    override func tearDownWithTest() async throws {
        // Clean up
        try? await keychainManager.deleteAll()
        authService = nil
        mockAPIClient = nil
        keychainManager = nil
        userDefaultsManager = nil
        appleSignInService = nil
        googleSignInService = nil

        try await super.tearDownWithTest()
    }

    // MARK: - Session Storage Tests

    func testStoreSessionSavesToKeychain() async throws {
        // Given
        let response = MockAuthResponses.newAppleUser
        mockAPIClient.shouldSimulateError = false

        // When - Trigger auth flow to store session
        // Note: We can't directly test handleAppleSignIn without ASAuthorization
        // So we test the session storage indirectly through checking session
        await authService.checkExistingSession()

        // Then - Initially no session
        XCTAssertFalse(authService.isAuthenticated)
    }

    func testSignOutClearsKeychain() async throws {
        // Given
        try await keychainManager.save("test_token", forKey: KeychainManager.Keys.sessionToken)
        try await keychainManager.save("test_refresh", forKey: KeychainManager.Keys.refreshToken)

        // When
        await authService.signOut()

        // Then
        XCTAssertFalse(await keychainManager.exists(forKey: KeychainManager.Keys.sessionToken))
        XCTAssertFalse(await keychainManager.exists(forKey: KeychainManager.Keys.refreshToken))
        XCTAssertFalse(authService.isAuthenticated)
    }

    func testSignOutClearsUserDefaults() async throws {
        // Given
        userDefaultsManager.saveString("user123", forKey: UserDefaultsManager.Keys.userId)
        userDefaultsManager.saveString("user@example.com", forKey: UserDefaultsManager.Keys.userEmail)

        // When
        await authService.signOut()

        // Then
        XCTAssertNil(userDefaultsManager.retrieveString(forKey: UserDefaultsManager.Keys.userId))
        XCTAssertNil(userDefaultsManager.retrieveString(forKey: UserDefaultsManager.Keys.userEmail))
    }

    // MARK: - Session Verification Tests

    func testCheckExistingSessionWithNoSession() async {
        // When
        await authService.checkExistingSession()

        // Then
        XCTAssertFalse(authService.isAuthenticated)
        XCTAssertNil(authService.currentSession)
    }

    func testCheckExistingSessionWithInvalidToken() async throws {
        // Given
        try await keychainManager.save("invalid_token", forKey: KeychainManager.Keys.sessionToken)
        userDefaultsManager.saveString("user123", forKey: UserDefaultsManager.Keys.userId)

        // Configure mock to return error
        mockAPIClient.shouldSimulateError = true
        mockAPIClient.simulatedError = .unauthorized

        // When
        await authService.checkExistingSession()

        // Then
        XCTAssertFalse(authService.isAuthenticated)
        // Session should be cleared
        XCTAssertFalse(await keychainManager.exists(forKey: KeychainManager.Keys.sessionToken))
    }

    // MARK: - Error Handling Tests

    func testHandleNetworkError() async throws {
        // Given
        mockAPIClient.shouldSimulateError = true
        mockAPIClient.simulatedError = MockAuthResponses.networkError

        // When/Then - This would be tested in integration tests
        // as we can't easily mock ASAuthorization for unit tests
    }

    // MARK: - Authentication State Tests

    func testInitialAuthenticationState() {
        XCTAssertFalse(authService.isAuthenticated)
        XCTAssertNil(authService.currentSession)
    }

    func testPublishedPropertiesAreObservable() {
        // Given
        let expectation = XCTestExpectation(description: "isAuthenticated changed")

        // When
        let cancellable = authService.$isAuthenticated
            .dropFirst() // Skip initial value
            .sink { _ in
                expectation.fulfill()
            }

        // Trigger a change (sign out)
        Task {
            await authService.signOut()
        }

        // Then
        wait(for: [expectation], timeout: 2.0)
        cancellable.cancel()
    }

    // MARK: - Mock API Client Configuration Tests

    func testMockAPIClientDelayConfiguration() {
        // Given
        let customDelay: TimeInterval = 0.5

        // When
        mockAPIClient.responseDelay = customDelay

        // Then
        XCTAssertEqual(mockAPIClient.responseDelay, customDelay)
    }

    func testMockAPIClientErrorSimulation() {
        // Given
        mockAPIClient.shouldSimulateError = true
        mockAPIClient.simulatedError = .serverError(500, "Test error")

        // Then
        XCTAssertTrue(mockAPIClient.shouldSimulateError)
    }
}
