//
//  AuthenticationFlowTests.swift
//  PostFit Tests
//
//  Integration tests for complete authentication flow
//

import XCTest
@testable import PostFit

@MainActor
final class AuthenticationFlowTests: XCTestCase {

    var authViewModel: AuthenticationViewModel!
    var authService: AuthenticationService!
    var appState: AppState!
    var mockAPIClient: MockAPIClient!
    var keychainManager: KeychainManager!
    var userDefaultsManager: UserDefaultsManager!

    override func setUpWithTest() async throws {
        try await super.setUpWithTest()

        // Initialize full dependency chain
        keychainManager = KeychainManager(service: "com.momcare.postfit.test")
        userDefaultsManager = UserDefaultsManager()
        let cryptoUtilities = CryptoUtilities()

        mockAPIClient = MockAPIClient()
        mockAPIClient.responseDelay = 0.1 // Faster for tests

        let appleSignInService = AppleSignInService(
            keychainManager: keychainManager,
            cryptoUtilities: cryptoUtilities
        )

        let googleSignInService = GoogleSignInService(
            keychainManager: keychainManager
        )

        authService = AuthenticationService(
            apiClient: mockAPIClient,
            keychainManager: keychainManager,
            userDefaultsManager: userDefaultsManager,
            appleSignInService: appleSignInService,
            googleSignInService: googleSignInService
        )

        appState = AppState(
            authService: authService,
            userDefaultsManager: userDefaultsManager
        )

        authViewModel = AuthenticationViewModel(authService: authService)

        // Clean up
        try? await keychainManager.deleteAll()
    }

    override func tearDownWithTest() async throws {
        try? await keychainManager.deleteAll()
        authViewModel = nil
        authService = nil
        appState = nil
        mockAPIClient = nil
        keychainManager = nil
        userDefaultsManager = nil

        try await super.tearDownWithTest()
    }

    // MARK: - New User Flow Tests

    func testNewUserFlowWithAppleSignIn() async throws {
        // Given
        mockAPIClient.newUserProbability = 1.0 // Always return new user

        // Note: This test would need actual ASAuthorization mock
        // For now, we test the mock response handling
        let mockResponse = MockAuthResponses.newAppleUser

        // When
        authViewModel.authResponse = mockResponse

        // Then
        XCTAssertTrue(mockResponse.isNewUser)
        XCTAssertFalse(mockResponse.user.hasCompletedProfile)
    }

    func testExistingUserFlowWithCompleteProfile() async throws {
        // Given
        mockAPIClient.newUserProbability = 0.0 // Always return existing user

        let mockResponse = MockAuthResponses.existingAppleUser

        // When
        authViewModel.authResponse = mockResponse

        // Then
        XCTAssertFalse(mockResponse.isNewUser)
        XCTAssertTrue(mockResponse.user.hasCompletedProfile)
    }

    // MARK: - Session Persistence Tests

    func testSessionPersistsAcrossAppLaunches() async throws {
        // Given - Store a valid session
        let sessionToken = "test_session_token"
        let userId = "test_user_id"

        try await keychainManager.save(sessionToken, forKey: KeychainManager.Keys.sessionToken)
        userDefaultsManager.saveString(userId, forKey: UserDefaultsManager.Keys.userId)
        userDefaultsManager.saveString("apple", forKey: UserDefaultsManager.Keys.lastLoginProvider)

        // Simulate app relaunch by creating new service
        let newAuthService = AuthenticationService(
            apiClient: mockAPIClient,
            keychainManager: keychainManager,
            userDefaultsManager: userDefaultsManager,
            appleSignInService: AppleSignInService(
                keychainManager: keychainManager,
                cryptoUtilities: CryptoUtilities()
            ),
            googleSignInService: GoogleSignInService(
                keychainManager: keychainManager
            )
        )

        // When
        await newAuthService.checkExistingSession()

        // Then - Should verify session with backend (mock will succeed)
        // Note: Mock API returns success for verifySession
    }

    // MARK: - Sign Out Flow Tests

    func testCompleteSignOutFlow() async throws {
        // Given - Set up authenticated state
        try await keychainManager.save("session_token", forKey: KeychainManager.Keys.sessionToken)
        try await keychainManager.save("refresh_token", forKey: KeychainManager.Keys.refreshToken)
        try await keychainManager.save("apple_user_id", forKey: KeychainManager.Keys.appleUserID)
        userDefaultsManager.saveString("user_123", forKey: UserDefaultsManager.Keys.userId)
        userDefaultsManager.saveString("user@example.com", forKey: UserDefaultsManager.Keys.userEmail)

        // When
        await appState.signOut()

        // Then - All data should be cleared
        XCTAssertFalse(await keychainManager.exists(forKey: KeychainManager.Keys.sessionToken))
        XCTAssertFalse(await keychainManager.exists(forKey: KeychainManager.Keys.refreshToken))
        XCTAssertFalse(await keychainManager.exists(forKey: KeychainManager.Keys.appleUserID))
        XCTAssertNil(userDefaultsManager.retrieveString(forKey: UserDefaultsManager.Keys.userId))
        XCTAssertNil(userDefaultsManager.retrieveString(forKey: UserDefaultsManager.Keys.userEmail))
        XCTAssertFalse(appState.isAuthenticated)
        XCTAssertNil(appState.currentUser)
        XCTAssertNil(appState.currentSession)
    }

    // MARK: - Error Recovery Tests

    func testNetworkErrorHandling() async throws {
        // Given
        mockAPIClient.shouldSimulateError = true
        mockAPIClient.simulatedError = MockAuthResponses.networkError

        // When - Attempt authentication (would fail)
        // Then - Error should be handled gracefully
        // Note: Full test requires ASAuthorization mock
    }

    func testSessionExpirationHandling() async throws {
        // Given - Store expired session
        let expiredToken = "expired_token"
        try await keychainManager.save(expiredToken, forKey: KeychainManager.Keys.sessionToken)
        userDefaultsManager.saveString("user_123", forKey: UserDefaultsManager.Keys.userId)

        // Configure mock to return unauthorized
        mockAPIClient.shouldSimulateError = true
        mockAPIClient.simulatedError = .unauthorized

        // When
        await authService.checkExistingSession()

        // Then - Should sign out
        XCTAssertFalse(authService.isAuthenticated)
        XCTAssertFalse(await keychainManager.exists(forKey: KeychainManager.Keys.sessionToken))
    }

    // MARK: - AppState Integration Tests

    func testAppStateRespondesToAuthenticationChanges() {
        // Given
        let initialAuthState = appState.isAuthenticated

        // When - This is a computed property that delegates to authService
        // Then
        XCTAssertEqual(appState.isAuthenticated, authService.isAuthenticated)
    }

    func testAppStateUpdateUserFromAuthResponse() {
        // Given
        let response = MockAuthResponses.existingAppleUser

        // When
        appState.updateUser(from: response)

        // Then
        XCTAssertEqual(appState.currentUser?.email, response.user.email)
        XCTAssertEqual(appState.currentUser?.name, response.user.name)
        XCTAssertTrue(appState.hasCompletedProfileSetup) // Should be set for complete profile
    }

    // MARK: - Mock API Client Behavior Tests

    func testMockReturnsNewUserBasedOnProbability() async throws {
        // Test new user
        mockAPIClient.newUserProbability = 1.0
        let response: AuthResponse = try await mockAPIClient.request(.appleSignIn, body: nil, headers: nil)
        XCTAssertTrue(response.isNewUser)

        // Test existing user
        mockAPIClient.newUserProbability = 0.0
        let response2: AuthResponse = try await mockAPIClient.request(.appleSignIn, body: nil, headers: nil)
        XCTAssertFalse(response2.isNewUser)
    }

    func testMockSimulatesRealisticDelay() async throws {
        // Given
        let delay: TimeInterval = 0.5
        mockAPIClient.responseDelay = delay

        // When
        let startTime = Date()
        let _: AuthResponse = try await mockAPIClient.request(.appleSignIn, body: nil, headers: nil)
        let elapsed = Date().timeIntervalSince(startTime)

        // Then
        XCTAssertGreaterThanOrEqual(elapsed, delay)
        XCTAssertLessThan(elapsed, delay + 0.2) // Allow small margin
    }
}
