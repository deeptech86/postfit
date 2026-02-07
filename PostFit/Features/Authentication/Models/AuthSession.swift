//
//  AuthSession.swift
//  PostFit (MomCare)
//
//  Authentication session model for managing user sessions
//

import Foundation

/// Represents an active authentication session
struct AuthSession: Codable {
    let sessionToken: String
    let refreshToken: String
    let userId: String
    let email: String
    let userName: String
    let profileImageURL: String?
    let provider: AuthProvider
    let expiresAt: Date
    let createdAt: Date

    init(
        sessionToken: String,
        refreshToken: String,
        userId: String,
        email: String,
        userName: String,
        profileImageURL: String? = nil,
        provider: AuthProvider,
        expiresAt: Date
    ) {
        self.sessionToken = sessionToken
        self.refreshToken = refreshToken
        self.userId = userId
        self.email = email
        self.userName = userName
        self.profileImageURL = profileImageURL
        self.provider = provider
        self.expiresAt = expiresAt
        self.createdAt = Date()
    }

    // MARK: - Session Validation

    /// Check if the session is currently valid (not expired)
    var isValid: Bool {
        return Date() < expiresAt
    }

    /// Check if the session is about to expire (within threshold)
    var isNearExpiration: Bool {
        let timeUntilExpiration = expiresAt.timeIntervalSinceNow
        return timeUntilExpiration > 0 && timeUntilExpiration < Constants.Session.tokenRefreshThreshold
    }

    /// Time remaining until session expires (in seconds)
    var timeUntilExpiration: TimeInterval {
        return expiresAt.timeIntervalSinceNow
    }

    /// Check if session has expired
    var isExpired: Bool {
        return Date() >= expiresAt
    }

    /// Age of the session (in seconds)
    var age: TimeInterval {
        return Date().timeIntervalSince(createdAt)
    }

    // MARK: - Authorization Header

    /// Generate authorization header value for API requests
    var authorizationHeader: String {
        return "Bearer \(sessionToken)"
    }
}

// MARK: - Session Creation Helper

extension AuthSession {
    /// Create session from AuthResponse
    /// - Parameters:
    ///   - response: Authentication response from backend
    ///   - provider: Authentication provider used
    /// - Returns: AuthSession instance
    static func from(response: AuthResponse, provider: AuthProvider) -> AuthSession {
        return AuthSession(
            sessionToken: response.sessionToken,
            refreshToken: response.refreshToken,
            userId: response.user.id,
            email: response.user.email,
            userName: response.user.name,
            profileImageURL: response.user.profileImageURL,
            provider: provider,
            expiresAt: response.expiresAt
        )
    }
}

// MARK: - Session Update

extension AuthSession {
    /// Create updated session with new tokens
    /// - Parameters:
    ///   - sessionToken: New session token
    ///   - refreshToken: New refresh token
    ///   - expiresAt: New expiration date
    /// - Returns: Updated AuthSession instance
    func updated(
        sessionToken: String,
        refreshToken: String,
        expiresAt: Date
    ) -> AuthSession {
        return AuthSession(
            sessionToken: sessionToken,
            refreshToken: refreshToken,
            userId: self.userId,
            email: self.email,
            userName: self.userName,
            profileImageURL: self.profileImageURL,
            provider: self.provider,
            expiresAt: expiresAt
        )
    }

    /// Create updated session with new profile information
    /// - Parameters:
    ///   - userName: New user name (nil to keep current)
    ///   - email: New email (nil to keep current)
    /// - Returns: Updated AuthSession instance
    func withUpdatedProfile(
        userName: String? = nil,
        email: String? = nil
    ) -> AuthSession {
        return AuthSession(
            sessionToken: self.sessionToken,
            refreshToken: self.refreshToken,
            userId: self.userId,
            email: email ?? self.email,
            userName: userName ?? self.userName,
            profileImageURL: self.profileImageURL,
            provider: self.provider,
            expiresAt: self.expiresAt
        )
    }
}
