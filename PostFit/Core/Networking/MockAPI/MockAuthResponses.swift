//
//  MockAuthResponses.swift
//  PostFit (MomCare)
//
//  Mock authentication responses for testing and development
//

import Foundation

/// Pre-defined mock responses for authentication flows
struct MockAuthResponses {

    // MARK: - Success Responses

    /// Mock response for new Apple Sign-In user
    static let newAppleUser = AuthResponse(
        sessionToken: "mock_session_apple_new_\(UUID().uuidString.prefix(8))",
        refreshToken: "mock_refresh_apple_new_\(UUID().uuidString.prefix(8))",
        user: UserDTO(
            id: "user_apple_new_001",
            email: "sarah.apple@example.com",
            name: "Sarah Johnson",
            profileImageURL: nil,
            hasCompletedProfile: false
        ),
        isNewUser: true,
        expiresAt: Date().addingTimeInterval(Constants.Session.tokenExpirationDuration)
    )

    /// Mock response for existing Apple Sign-In user with complete profile
    static let existingAppleUser = AuthResponse(
        sessionToken: "mock_session_apple_existing_\(UUID().uuidString.prefix(8))",
        refreshToken: "mock_refresh_apple_existing_\(UUID().uuidString.prefix(8))",
        user: UserDTO(
            id: "user_apple_existing_002",
            email: "emily.apple@example.com",
            name: "Emily Davis",
            profileImageURL: "https://example.com/profiles/emily.jpg",
            hasCompletedProfile: true
        ),
        isNewUser: false,
        expiresAt: Date().addingTimeInterval(Constants.Session.tokenExpirationDuration)
    )

    /// Mock response for new Google Sign-In user
    static let newGoogleUser = AuthResponse(
        sessionToken: "mock_session_google_new_\(UUID().uuidString.prefix(8))",
        refreshToken: "mock_refresh_google_new_\(UUID().uuidString.prefix(8))",
        user: UserDTO(
            id: "user_google_new_003",
            email: "jessica.google@example.com",
            name: "Jessica Martinez",
            profileImageURL: "https://lh3.googleusercontent.com/a/default-user",
            hasCompletedProfile: false
        ),
        isNewUser: true,
        expiresAt: Date().addingTimeInterval(Constants.Session.tokenExpirationDuration)
    )

    /// Mock response for existing Google Sign-In user with complete profile
    static let existingGoogleUser = AuthResponse(
        sessionToken: "mock_session_google_existing_\(UUID().uuidString.prefix(8))",
        refreshToken: "mock_refresh_google_existing_\(UUID().uuidString.prefix(8))",
        user: UserDTO(
            id: "user_google_existing_004",
            email: "amanda.google@example.com",
            name: "Amanda Wilson",
            profileImageURL: "https://lh3.googleusercontent.com/a/amanda-profile",
            hasCompletedProfile: true
        ),
        isNewUser: false,
        expiresAt: Date().addingTimeInterval(Constants.Session.tokenExpirationDuration)
    )

    /// Mock response for email sign-in
    static let emailSignIn = AuthResponse(
        sessionToken: "mock_session_email_\(UUID().uuidString.prefix(8))",
        refreshToken: "mock_refresh_email_\(UUID().uuidString.prefix(8))",
        user: UserDTO(
            id: "user_email_005",
            email: "user@example.com",
            name: "Email User",
            profileImageURL: nil,
            hasCompletedProfile: true
        ),
        isNewUser: false,
        expiresAt: Date().addingTimeInterval(Constants.Session.tokenExpirationDuration)
    )

    /// Mock response for session verification
    static let validSession = AuthResponse(
        sessionToken: "mock_session_verified_\(UUID().uuidString.prefix(8))",
        refreshToken: "mock_refresh_verified_\(UUID().uuidString.prefix(8))",
        user: UserDTO(
            id: "user_verified_006",
            email: "verified@example.com",
            name: "Verified User",
            profileImageURL: nil,
            hasCompletedProfile: true
        ),
        isNewUser: false,
        expiresAt: Date().addingTimeInterval(Constants.Session.tokenExpirationDuration)
    )

    // MARK: - Error Scenarios

    /// Simulate network error
    static let networkError = APIError.networkError(
        URLError(.notConnectedToInternet)
    )

    /// Simulate unauthorized error (invalid credentials)
    static let unauthorizedError = APIError.unauthorized

    /// Simulate server error
    static let serverError = APIError.serverError(500, "Internal server error")

    /// Simulate session expired error
    static let sessionExpiredError = APIError.unauthorized

    /// Simulate invalid token error
    static let invalidTokenError = APIError.unauthorized

    // MARK: - Helper Methods

    /// Get random success response for Apple Sign-In
    static func randomAppleResponse() -> AuthResponse {
        return Bool.random() ? newAppleUser : existingAppleUser
    }

    /// Get random success response for Google Sign-In
    static func randomGoogleResponse() -> AuthResponse {
        return Bool.random() ? newGoogleUser : existingGoogleUser
    }

    /// Simulate random error (for testing error handling)
    static func randomError() -> APIError {
        let errors: [APIError] = [
            networkError,
            unauthorizedError,
            serverError
        ]
        return errors.randomElement() ?? networkError
    }
}

// MARK: - Note
// AuthResponse and UserDTO models are defined in Features/Authentication/Models/AuthCredentials.swift
// This file uses those models for creating mock responses
