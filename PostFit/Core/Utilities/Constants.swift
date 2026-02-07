//
//  Constants.swift
//  PostFit (MomCare)
//
//  App-wide constants for configuration, API URLs, and keys
//

import Foundation
import UIKit

enum Constants {

    // MARK: - API Configuration

    enum API {
        /// Base URL for production API
        static let baseURL = "https://api.momcare.app/v1"

        /// Base URL for staging/development API
        static let stagingURL = "https://staging-api.momcare.app/v1"

        /// Local development API
        static let localURL = "http://localhost:3000/api/v1"

        /// Current environment
        static var currentBaseURL: String {
            #if DEBUG
            return localURL  // Use local backend in debug mode
            #else
            return baseURL
            #endif
        }

        /// API timeout interval (in seconds)
        static let timeoutInterval: TimeInterval = 30

        /// Maximum retry attempts for failed requests
        static let maxRetryAttempts = 3
    }

    // MARK: - Google Sign-In

    enum Google {
        /// Google OAuth 2.0 Client ID for iOS
        /// TODO: Replace with your actual Client ID from Google Cloud Console
        static let clientID = "771017036108-0mqnklnpha1a6sus0jo8imm59aql3n92.apps.googleusercontent.com"

        /// Google OAuth scopes
        static let scopes = ["profile", "email"]

        /// Reversed client ID for URL scheme (auto-generated from clientID)
        static var reversedClientID: String {
            clientID.components(separatedBy: ".").reversed().joined(separator: ".")
        }
    }

    // MARK: - Apple Sign-In

    enum Apple {
        /// Nonce character length for security
        static let nonceLength = 32

        /// Requested scopes
        static let scopes: [String] = ["fullName", "email"]
    }

    // MARK: - Session Configuration

    enum Session {
        /// Session token expiration (in seconds) - 2 hours
        static let tokenExpirationDuration: TimeInterval = 2 * 60 * 60

        /// Refresh token expiration (in seconds) - 30 days
        static let refreshTokenExpirationDuration: TimeInterval = 30 * 24 * 60 * 60

        /// Minimum time before expiration to trigger refresh (in seconds) - 15 minutes
        static let tokenRefreshThreshold: TimeInterval = 15 * 60
    }

    // MARK: - App Configuration

    enum App {
        /// App bundle identifier
        static let bundleID = Bundle.main.bundleIdentifier ?? "com.momcare.postfit"

        /// App version
        static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

        /// Build number
        static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

        /// App display name
        static let displayName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "MomCare"
    }

    // MARK: - Device Info

    enum Device {
        /// Device model (e.g., "iPhone14,2")
        static let model = UIDevice.current.model

        /// System version (e.g., "17.0")
        static let systemVersion = UIDevice.current.systemVersion

        /// Device identifier (UUID)
        static let identifier = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"

        /// Device name (e.g., "Sarah's iPhone")
        static let name = UIDevice.current.name
    }

    // MARK: - Network

    enum Network {
        /// HTTP Methods
        enum HTTPMethod: String {
            case get = "GET"
            case post = "POST"
            case put = "PUT"
            case patch = "PATCH"
            case delete = "DELETE"
        }

        /// Content Types
        enum ContentType {
            static let json = "application/json"
            static let formEncoded = "application/x-www-form-urlencoded"
        }

        /// Header Keys
        enum HeaderKey {
            static let authorization = "Authorization"
            static let contentType = "Content-Type"
            static let accept = "Accept"
            static let userAgent = "User-Agent"
            static let deviceID = "X-Device-ID"
            static let appVersion = "X-App-Version"
        }
    }

    // MARK: - Validation

    enum Validation {
        /// Minimum password length
        static let minPasswordLength = 8

        /// Maximum password length
        static let maxPasswordLength = 128

        /// Email regex pattern
        static let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    }

    // MARK: - Mock Data

    enum Mock {
        /// Simulated network delay (in seconds)
        static let networkDelay: TimeInterval = 1.5

        /// Mock user ID for new users
        static let newUserID = "mock_user_new_001"

        /// Mock user ID for existing users
        static let existingUserID = "mock_user_existing_002"

        /// Mock session token
        static let sessionToken = "mock_session_token_abc123"

        /// Mock refresh token
        static let refreshToken = "mock_refresh_token_xyz789"
    }
}
