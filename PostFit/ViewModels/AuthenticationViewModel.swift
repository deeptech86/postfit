//
//  AuthenticationViewModel.swift
//  PostFit (MomCare)
//
//  ViewModel for authentication UI state management
//  Bridges AuthenticationService with SignInView
//

import Foundation
import AuthenticationServices
import UIKit

@MainActor
class AuthenticationViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var authResponse: AuthResponse?

    // MARK: - Dependencies

    private let authService: AuthenticationService

    // MARK: - Computed Properties

    var isAuthenticated: Bool {
        authService.isAuthenticated
    }

    var currentSession: AuthSession? {
        authService.currentSession
    }

    // MARK: - Initialization

    init(authService: AuthenticationService) {
        self.authService = authService
    }

    // MARK: - Apple Sign-In

    /// Prepare nonce for Apple Sign-In request
    /// Call this in SignInWithAppleButton's onRequest callback
    /// - Returns: SHA256 hashed nonce to set on request.nonce
    func prepareAppleSignInNonce() -> String {
        return authService.prepareAppleSignInNonce()
    }

    /// Handle Apple Sign-In authorization result
    /// - Parameter result: Result from ASAuthorizationController
    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = nil
        authResponse = nil

        do {
            let response = try await authService.handleAppleSignIn(result)
            authResponse = response

            #if DEBUG
            print("✅ [ViewModel] Apple Sign-In successful")
            #endif

        } catch let error as AuthError {
            // Don't show error for user cancellation
            if !error.isUserInitiated {
                handleError(error)
            }
        } catch {
            handleError(error)
        }

        isLoading = false
    }

    // MARK: - Google Sign-In

    /// Handle Google Sign-In
    /// - Parameter viewController: Presenting view controller
    func handleGoogleSignIn(presenting viewController: UIViewController) async {
        isLoading = true
        errorMessage = nil
        authResponse = nil

        do {
            let response = try await authService.handleGoogleSignIn(presenting: viewController)
            authResponse = response

            #if DEBUG
            print("✅ [ViewModel] Google Sign-In successful")
            #endif

        } catch let error as AuthError {
            // Don't show error for user cancellation
            if !error.isUserInitiated {
                handleError(error)
            }
        } catch {
            handleError(error)
        }

        isLoading = false
    }

    // MARK: - Sign Out

    /// Sign out current user
    func signOut() async {
        isLoading = true
        await authService.signOut()
        authResponse = nil
        isLoading = false

        #if DEBUG
        print("✅ [ViewModel] Signed out")
        #endif
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error) {
        if let authError = error as? AuthError {
            errorMessage = authError.localizedDescription
        } else if let apiError = error as? APIError {
            errorMessage = apiError.localizedDescription
        } else {
            errorMessage = "An unexpected error occurred. Please try again."
        }

        showError = true

        #if DEBUG
        print("❌ [ViewModel] Error: \(errorMessage ?? "Unknown error")")
        #endif
    }

    // MARK: - Helper Methods

    /// Clear error state
    func clearError() {
        errorMessage = nil
        showError = false
    }

    /// Reset authentication state
    func reset() {
        isLoading = false
        errorMessage = nil
        showError = false
        authResponse = nil
    }

    // MARK: - Mock Authentication (Development Only)

    /// Set loading state manually (for mock authentication)
    func setLoading(_ loading: Bool) {
        isLoading = loading
    }

    /// Set mock auth response and update service state (for mock authentication)
    func setMockAuthResponse(_ response: AuthResponse) {
        authResponse = response

        // Also store the mock session in the auth service for state consistency
        Task {
            await authService.storeMockSession(response)
        }

        #if DEBUG
        print("✅ [ViewModel] Mock authentication successful - User: \(response.user.name)")
        #endif
    }
}
