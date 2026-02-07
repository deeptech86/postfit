//
//  AuthenticationViewModelTests.swift
//  PostFit Tests
//
//  Unit tests for AuthenticationViewModel
//

import XCTest
@testable import PostFit

@MainActor
final class AuthenticationViewModelTests: XCTestCase {

    var viewModel: AuthenticationViewModel!
    var authService: AuthenticationService!
    var mockAPIClient: MockAPIClient!
    var keychainManager: KeychainManager!
    var userDefaultsManager: UserDefaultsManager!

    override func setUpWithTest() async throws {
        try await super.setUpWithTest()

        // Initialize dependencies
        keychainManager = KeychainManager(service: "com.momcare.postfit.test")
        userDefaultsManager = UserDefaultsManager()
        let cryptoUtilities = CryptoUtilities()

        mockAPIClient = MockAPIClient()

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

        viewModel = AuthenticationViewModel(authService: authService)

        // Clean up
        try? await keychainManager.deleteAll()
    }

    override func tearDownWithTest() async throws {
        try? await keychainManager.deleteAll()
        viewModel = nil
        authService = nil
        mockAPIClient = nil
        keychainManager = nil
        userDefaultsManager = nil

        try await super.tearDownWithTest()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showError)
        XCTAssertNil(viewModel.authResponse)
    }

    func testIsAuthenticatedDelegatesToService() {
        XCTAssertEqual(viewModel.isAuthenticated, authService.isAuthenticated)
    }

    func testCurrentSessionDelegatesToService() {
        XCTAssertEqual(viewModel.currentSession?.userId, authService.currentSession?.userId)
    }

    // MARK: - Loading State Tests

    func testLoadingStateDuringAuthentication() async {
        // Given
        mockAPIClient.responseDelay = 1.0
        mockAPIClient.shouldSimulateError = false

        // Note: Can't directly test handleAppleSignIn without ASAuthorization
        // This would be tested in integration tests
    }

    // MARK: - Error Handling Tests

    func testClearError() {
        // Given
        viewModel.errorMessage = "Test error"
        viewModel.showError = true

        // When
        viewModel.clearError()

        // Then
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showError)
    }

    func testReset() {
        // Given
        viewModel.isLoading = true
        viewModel.errorMessage = "Error"
        viewModel.showError = true
        viewModel.authResponse = MockAuthResponses.newAppleUser

        // When
        viewModel.reset()

        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showError)
        XCTAssertNil(viewModel.authResponse)
    }

    // MARK: - Sign Out Tests

    func testSignOut() async {
        // Given - Set up some session data
        try? await keychainManager.save("test_token", forKey: KeychainManager.Keys.sessionToken)

        // When
        await viewModel.signOut()

        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.authResponse)
        XCTAssertFalse(await keychainManager.exists(forKey: KeychainManager.Keys.sessionToken))
    }

    // MARK: - Published Properties Tests

    func testIsLoadingIsPublished() {
        // Given
        let expectation = XCTestExpectation(description: "isLoading published")

        // When
        let cancellable = viewModel.$isLoading
            .dropFirst()
            .sink { _ in
                expectation.fulfill()
            }

        viewModel.isLoading = true

        // Then
        wait(for: [expectation], timeout: 1.0)
        cancellable.cancel()
    }

    func testShowErrorIsPublished() {
        // Given
        let expectation = XCTestExpectation(description: "showError published")

        // When
        let cancellable = viewModel.$showError
            .dropFirst()
            .sink { _ in
                expectation.fulfill()
            }

        viewModel.showError = true

        // Then
        wait(for: [expectation], timeout: 1.0)
        cancellable.cancel()
    }

    func testAuthResponseIsPublished() {
        // Given
        let expectation = XCTestExpectation(description: "authResponse published")

        // When
        let cancellable = viewModel.$authResponse
            .dropFirst()
            .sink { _ in
                expectation.fulfill()
            }

        viewModel.authResponse = MockAuthResponses.newAppleUser

        // Then
        wait(for: [expectation], timeout: 1.0)
        cancellable.cancel()
    }
}
