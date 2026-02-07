//
//  UserSessionManager.swift
//  PostFit (MomCare)
//
//  Shared manager for accessing authenticated user data across the app
//

import Foundation
import SwiftUI

/// Shared manager for accessing authenticated user session data
@MainActor
class UserSessionManager: ObservableObject {
    static let shared = UserSessionManager()

    // MARK: - Published Properties

    @Published var currentSession: AuthSession?
    @Published var isAuthenticated: Bool = false

    // MARK: - User Data Keys (UserDefaults)

    private enum Keys {
        static let userName = "user_name"
        static let userEmail = "user_email"
        static let userProfileImageURL = "user_profile_image_url"
        static let authProvider = "auth_provider"
    }

    // MARK: - Computed Properties

    /// Current user's display name
    var userName: String {
        if let session = currentSession {
            return session.userName
        }
        return UserDefaults.standard.string(forKey: Keys.userName) ?? "User"
    }

    /// Current user's email
    var userEmail: String {
        if let session = currentSession {
            return session.email
        }
        return UserDefaults.standard.string(forKey: Keys.userEmail) ?? ""
    }

    /// Current user's profile image URL
    var profileImageURL: String? {
        if let session = currentSession {
            return session.profileImageURL
        }
        return UserDefaults.standard.string(forKey: Keys.userProfileImageURL)
    }

    /// Current authentication provider
    var authProvider: AuthProvider? {
        if let session = currentSession {
            return session.provider
        }
        if let providerString = UserDefaults.standard.string(forKey: Keys.authProvider) {
            return AuthProvider(rawValue: providerString)
        }
        return nil
    }

    /// First name derived from full name
    var firstName: String {
        let components = userName.split(separator: " ")
        return components.first.map(String.init) ?? userName
    }

    // MARK: - Initialization

    private init() {
        loadStoredUserData()
    }

    // MARK: - Session Management

    /// Update session from AuthResponse
    func updateSession(from response: AuthResponse, provider: AuthProvider) {
        let session = AuthSession.from(response: response, provider: provider)
        currentSession = session
        isAuthenticated = true

        // Persist user data
        persistUserData(
            name: response.user.name,
            email: response.user.email,
            profileImageURL: response.user.profileImageURL,
            provider: provider
        )

        #if DEBUG
        print("✅ [UserSession] Session updated for: \(response.user.name)")
        #endif
    }

    /// Update session directly
    func updateSession(_ session: AuthSession) {
        currentSession = session
        isAuthenticated = true

        // Persist user data
        persistUserData(
            name: session.userName,
            email: session.email,
            profileImageURL: session.profileImageURL,
            provider: session.provider
        )
    }

    /// Clear current session (sign out)
    func clearSession() {
        currentSession = nil
        isAuthenticated = false

        // Clear persisted data
        UserDefaults.standard.removeObject(forKey: Keys.userName)
        UserDefaults.standard.removeObject(forKey: Keys.userEmail)
        UserDefaults.standard.removeObject(forKey: Keys.userProfileImageURL)
        UserDefaults.standard.removeObject(forKey: Keys.authProvider)

        #if DEBUG
        print("🗑️ [UserSession] Session cleared")
        #endif
    }

    // MARK: - Private Methods

    private func persistUserData(name: String, email: String, profileImageURL: String?, provider: AuthProvider) {
        UserDefaults.standard.set(name, forKey: Keys.userName)
        UserDefaults.standard.set(email, forKey: Keys.userEmail)
        UserDefaults.standard.set(provider.rawValue, forKey: Keys.authProvider)

        if let imageURL = profileImageURL {
            UserDefaults.standard.set(imageURL, forKey: Keys.userProfileImageURL)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.userProfileImageURL)
        }
    }

    private func loadStoredUserData() {
        // Check if we have stored user data
        if let _ = UserDefaults.standard.string(forKey: Keys.userName) {
            isAuthenticated = true
            #if DEBUG
            print("✅ [UserSession] Loaded stored user data")
            #endif
        }
    }
}
