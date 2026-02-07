//
//  AuthCredentials.swift
//  PostFit (MomCare)
//
//  Data transfer objects for authentication credentials, requests, and responses
//

import Foundation

// MARK: - Apple Sign-In Credentials

/// Credentials obtained from Apple Sign-In
struct AppleAuthCredentials: Codable {
    let userIdentifier: String
    let email: String?
    let fullName: PersonNameComponents?
    let identityToken: String
    let authorizationCode: String
    let nonce: String

    enum CodingKeys: String, CodingKey {
        case userIdentifier
        case email
        case givenName
        case familyName
        case identityToken
        case authorizationCode
        case nonce
    }

    init(
        userIdentifier: String,
        email: String?,
        fullName: PersonNameComponents?,
        identityToken: String,
        authorizationCode: String,
        nonce: String
    ) {
        self.userIdentifier = userIdentifier
        self.email = email
        self.fullName = fullName
        self.identityToken = identityToken
        self.authorizationCode = authorizationCode
        self.nonce = nonce
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userIdentifier = try container.decode(String.self, forKey: .userIdentifier)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        identityToken = try container.decode(String.self, forKey: .identityToken)
        authorizationCode = try container.decode(String.self, forKey: .authorizationCode)
        nonce = try container.decode(String.self, forKey: .nonce)

        // Decode name components
        let givenName = try container.decodeIfPresent(String.self, forKey: .givenName)
        let familyName = try container.decodeIfPresent(String.self, forKey: .familyName)

        var nameComponents: PersonNameComponents?
        if givenName != nil || familyName != nil {
            var components = PersonNameComponents()
            components.givenName = givenName
            components.familyName = familyName
            nameComponents = components
        }
        fullName = nameComponents
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userIdentifier, forKey: .userIdentifier)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encode(identityToken, forKey: .identityToken)
        try container.encode(authorizationCode, forKey: .authorizationCode)
        try container.encode(nonce, forKey: .nonce)

        // Encode name components
        try container.encodeIfPresent(fullName?.givenName, forKey: .givenName)
        try container.encodeIfPresent(fullName?.familyName, forKey: .familyName)
    }
}

// MARK: - Google Sign-In Credentials

/// Credentials obtained from Google Sign-In
struct GoogleAuthCredentials: Codable {
    let userID: String
    let email: String
    let fullName: String
    let profileImageURL: String?
    let idToken: String
}

// MARK: - Email Sign-In Credentials

/// Credentials for email/password authentication
struct EmailAuthCredentials: Codable {
    let email: String
    let password: String
}

// MARK: - Device Info

/// Device information sent with auth requests
struct DeviceInfo: Codable {
    let deviceID: String
    let deviceModel: String
    let systemVersion: String
    let appVersion: String

    init() {
        self.deviceID = Constants.Device.identifier
        self.deviceModel = Constants.Device.model
        self.systemVersion = Constants.Device.systemVersion
        self.appVersion = Constants.App.version
    }
}

// MARK: - Authentication Request

/// Generic authentication request sent to backend
struct AuthRequest: Codable {
    let provider: AuthProvider
    let credentials: [String: String]
    let deviceInfo: DeviceInfo

    init(provider: AuthProvider, credentials: [String: String]) {
        self.provider = provider
        self.credentials = credentials
        self.deviceInfo = DeviceInfo()
    }
}

// MARK: - User DTO

/// User data transfer object from backend
struct UserDTO: Codable, Equatable {
    let id: String
    let email: String
    let name: String
    let profileImageURL: String?
    let hasCompletedProfile: Bool
}

// MARK: - Authentication Response

/// Response from authentication endpoints
struct AuthResponse: Codable, Equatable {
    let sessionToken: String
    let refreshToken: String
    let user: UserDTO
    let isNewUser: Bool
    let expiresAt: Date
}

// MARK: - Refresh Token Request

/// Request to refresh session token
struct RefreshTokenRequest: Codable {
    let refreshToken: String
    let deviceInfo: DeviceInfo

    init(refreshToken: String) {
        self.refreshToken = refreshToken
        self.deviceInfo = DeviceInfo()
    }
}

// MARK: - Session Verification Response

/// Response from session verification endpoint
struct SessionVerificationResponse: Codable {
    let isValid: Bool
    let user: UserDTO?
    let expiresAt: Date?
}

// MARK: - Helper Extensions

extension AppleAuthCredentials {
    /// Convert to dictionary for API request
    var dictionaryRepresentation: [String: String] {
        var dict: [String: String] = [
            "userIdentifier": userIdentifier,
            "identityToken": identityToken,
            "authorizationCode": authorizationCode,
            "nonce": nonce
        ]

        if let email = email {
            dict["email"] = email
        }

        if let givenName = fullName?.givenName {
            dict["givenName"] = givenName
        }

        if let familyName = fullName?.familyName {
            dict["familyName"] = familyName
        }

        return dict
    }
}

extension GoogleAuthCredentials {
    /// Convert to dictionary for API request
    var dictionaryRepresentation: [String: String] {
        var dict: [String: String] = [
            "userID": userID,
            "email": email,
            "fullName": fullName,
            "idToken": idToken
        ]

        if let profileImageURL = profileImageURL {
            dict["profileImageURL"] = profileImageURL
        }

        return dict
    }
}

extension EmailAuthCredentials {
    /// Convert to dictionary for API request
    var dictionaryRepresentation: [String: String] {
        return [
            "email": email,
            "password": password
        ]
    }
}
