//
//  AuthenticationService.swift
//  PostFit (MomCare)
//
//  Main authentication service that orchestrates the complete auth flow
//  Coordinates Apple Sign-In, Google Sign-In, session management, and backend communication
//

import Foundation
import AuthenticationServices
import UIKit

/// Main authentication service
class AuthenticationService: ObservableObject {

    // MARK: - Properties

    private let apiClient: APIClientProtocol
    private let keychainManager: KeychainManager
    private let userDefaultsManager: UserDefaultsManager
    private let appleSignInService: AppleSignInService
    private let googleSignInService: GoogleSignInService

    @Published var currentSession: AuthSession?
    @Published var isAuthenticated = false

    // MARK: - Initialization

    init(
        apiClient: APIClientProtocol,
        keychainManager: KeychainManager,
        userDefaultsManager: UserDefaultsManager,
        appleSignInService: AppleSignInService,
        googleSignInService: GoogleSignInService
    ) {
        self.apiClient = apiClient
        self.keychainManager = keychainManager
        self.userDefaultsManager = userDefaultsManager
        self.appleSignInService = appleSignInService
        self.googleSignInService = googleSignInService

        // Check for existing session on initialization
        Task {
            await checkExistingSession()
        }
    }

    // MARK: - Apple Sign-In Flow

    /// Prepare nonce for Apple Sign-In request
    /// Call this in SignInWithAppleButton's onRequest to get the hashed nonce
    /// - Returns: SHA256 hashed nonce to set on the request
    func prepareAppleSignInNonce() -> String {
        return appleSignInService.prepareNonce()
    }

    /// Handle Apple Sign-In authorization result
    /// - Parameter result: Result from ASAuthorizationController
    /// - Returns: Authentication response from backend
    /// - Throws: AuthError if authentication fails
    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async throws -> AuthResponse {
        #if DEBUG
        print("🍎 [Auth] Processing Apple Sign-In...")
        #endif

        // 1. Extract credentials from Apple (using real Apple Sign-In SDK)
        let credentials = try await appleSignInService.handleAuthorizationResult(result)

        #if DEBUG
        print("✅ [Auth] Apple credentials received: \(credentials.email ?? "no email")")
        #endif

        // 2. Create local session from Apple credentials (no backend required for now)
        let userName: String
        if let fullName = credentials.fullName {
            let givenName = fullName.givenName ?? ""
            let familyName = fullName.familyName ?? ""
            userName = [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")
        } else {
            userName = "Apple User"
        }

        let response = AuthResponse(
            sessionToken: "local_session_\(credentials.userIdentifier)",
            refreshToken: "local_refresh_\(credentials.userIdentifier)",
            user: UserDTO(
                id: credentials.userIdentifier,
                email: credentials.email ?? "\(credentials.userIdentifier)@apple.user",
                name: userName.isEmpty ? "Apple User" : userName,
                profileImageURL: nil,
                hasCompletedProfile: false
            ),
            isNewUser: true,
            expiresAt: Date().addingTimeInterval(Constants.Session.tokenExpirationDuration)
        )

        // 3. Store session (handle errors gracefully)
        do {
            try await storeSession(response, provider: .apple)
        } catch {
            #if DEBUG
            print("⚠️ [Auth] Failed to store session in Keychain, continuing anyway: \(error)")
            #endif
        }

        // 4. Update authentication state
        await updateAuthState(response, provider: .apple)

        #if DEBUG
        print("✅ [Auth] Apple Sign-In successful: \(response.user.email)")
        print("   New User: \(response.isNewUser)")
        print("   Profile Complete: \(response.user.hasCompletedProfile)")
        #endif

        return response
    }

    // MARK: - Google Sign-In Flow

    /// Handle Google Sign-In
    /// - Parameter viewController: Presenting view controller
    /// - Returns: Authentication response from backend
    /// - Throws: AuthError if authentication fails
    func handleGoogleSignIn(presenting viewController: UIViewController) async throws -> AuthResponse {
        #if DEBUG
        print("🔵 [Auth] Processing Google Sign-In...")
        #endif

        // 1. Trigger Google Sign-In (using real Google SDK)
        let credentials = try await googleSignInService.signIn(presenting: viewController)

        #if DEBUG
        print("✅ [Auth] Google credentials received: \(credentials.email)")
        #endif

        // 2. Create local session from Google credentials (no backend required for now)
        // This allows the app to work without a running backend server
        let response = AuthResponse(
            sessionToken: "local_session_\(credentials.userID)",
            refreshToken: "local_refresh_\(credentials.userID)",
            user: UserDTO(
                id: credentials.userID,
                email: credentials.email,
                name: credentials.fullName,
                profileImageURL: credentials.profileImageURL,
                hasCompletedProfile: false
            ),
            isNewUser: true,
            expiresAt: Date().addingTimeInterval(Constants.Session.tokenExpirationDuration)
        )

        // 3. Store session (handle errors gracefully)
        do {
            try await storeSession(response, provider: .google)
        } catch {
            #if DEBUG
            print("⚠️ [Auth] Failed to store session in Keychain, continuing anyway: \(error)")
            #endif
            // Still update state even if Keychain storage fails
        }

        // 4. Update authentication state
        await updateAuthState(response, provider: .google)

        #if DEBUG
        print("✅ [Auth] Google Sign-In successful: \(response.user.email)")
        print("   New User: \(response.isNewUser)")
        print("   Profile Complete: \(response.user.hasCompletedProfile)")
        #endif

        return response
    }

    // MARK: - Session Management

    /// Store authentication session
    private func storeSession(_ response: AuthResponse, provider: AuthProvider) async throws {
        #if DEBUG
        print("💾 [Auth] Storing session...")
        #endif

        // Store session token in Keychain
        do {
            try await keychainManager.save(
                response.sessionToken,
                forKey: KeychainManager.Keys.sessionToken
            )
            try await keychainManager.save(
                response.refreshToken,
                forKey: KeychainManager.Keys.refreshToken
            )
        } catch {
            throw AuthError.storageError(error as? StorageError ?? .unableToSave)
        }

        // Store non-sensitive user data in UserDefaults
        userDefaultsManager.saveString(response.user.id, forKey: UserDefaultsManager.Keys.userId)
        userDefaultsManager.saveString(response.user.email, forKey: UserDefaultsManager.Keys.userEmail)
        userDefaultsManager.saveString(provider.rawValue, forKey: UserDefaultsManager.Keys.lastLoginProvider)

        // Create and store session object
        let session = AuthSession.from(response: response, provider: provider)
        currentSession = session

        #if DEBUG
        print("✅ [Auth] Session stored successfully")
        print("   Token expires: \(response.expiresAt)")
        #endif
    }

    /// Store mock authentication session (for development/testing)
    func storeMockSession(_ response: AuthResponse) async {
        #if DEBUG
        print("💾 [Auth] Storing MOCK session (bypassing backend)...")
        #endif

        // Store mock session token in Keychain
        do {
            try await keychainManager.save(
                response.sessionToken,
                forKey: KeychainManager.Keys.sessionToken
            )
            try await keychainManager.save(
                response.refreshToken,
                forKey: KeychainManager.Keys.refreshToken
            )
        } catch {
            #if DEBUG
            print("⚠️ [Auth] Failed to store mock session in Keychain: \(error)")
            #endif
        }

        // Store non-sensitive user data in UserDefaults
        userDefaultsManager.saveString(response.user.id, forKey: UserDefaultsManager.Keys.userId)
        userDefaultsManager.saveString(response.user.email, forKey: UserDefaultsManager.Keys.userEmail)
        userDefaultsManager.saveString("mock", forKey: UserDefaultsManager.Keys.lastLoginProvider)

        // Create and store session object
        let session = AuthSession.from(response: response, provider: .apple)  // Use any provider
        await MainActor.run {
            currentSession = session
            isAuthenticated = true
        }

        #if DEBUG
        print("✅ [Auth] MOCK session stored - User authenticated without backend")
        print("   User: \(response.user.name) (\(response.user.email))")
        print("   Has completed profile: \(response.user.hasCompletedProfile)")
        #endif
    }

    /// Check for existing session on app launch
    func checkExistingSession() async {
        #if DEBUG
        print("🔍 [Auth] Checking for existing session...")
        #endif

        // Retrieve session token from Keychain
        guard let sessionToken = try? await keychainManager.retrieve(forKey: KeychainManager.Keys.sessionToken),
              let userId = userDefaultsManager.retrieveString(forKey: UserDefaultsManager.Keys.userId) else {
            #if DEBUG
            print("ℹ️ [Auth] No existing session found")
            #endif
            await MainActor.run {
                isAuthenticated = false
            }
            return
        }

        // Verify session with backend
        do {
            let response: AuthResponse = try await apiClient.request(
                .verifySession,
                body: nil,
                headers: [Constants.Network.HeaderKey.authorization: "Bearer \(sessionToken)"]
            )

            // Session is valid, update state
            if let providerString = userDefaultsManager.retrieveString(forKey: UserDefaultsManager.Keys.lastLoginProvider),
               let provider = AuthProvider(rawValue: providerString) {
                let session = AuthSession.from(response: response, provider: provider)
                await MainActor.run {
                    currentSession = session
                    isAuthenticated = true
                }

                #if DEBUG
                print("✅ [Auth] Existing session verified")
                #endif
            }
        } catch {
            #if DEBUG
            print("⚠️ [Auth] Session verification failed, signing out")
            #endif
            await signOut()
        }
    }

    /// Refresh authentication session
    func refreshSession() async throws {
        #if DEBUG
        print("🔄 [Auth] Refreshing session...")
        #endif

        guard let refreshToken = try? await keychainManager.retrieve(forKey: KeychainManager.Keys.refreshToken) else {
            throw AuthError.sessionExpired
        }

        let refreshRequest = RefreshTokenRequest(refreshToken: refreshToken)

        do {
            let response: AuthResponse = try await apiClient.request(
                .refreshToken,
                body: refreshRequest,
                headers: nil
            )

            // Update session with new tokens
            if let currentSession = currentSession {
                let updatedSession = currentSession.updated(
                    sessionToken: response.sessionToken,
                    refreshToken: response.refreshToken,
                    expiresAt: response.expiresAt
                )

                try await keychainManager.update(
                    response.sessionToken,
                    forKey: KeychainManager.Keys.sessionToken
                )
                try await keychainManager.update(
                    response.refreshToken,
                    forKey: KeychainManager.Keys.refreshToken
                )

                await MainActor.run {
                    self.currentSession = updatedSession
                }

                #if DEBUG
                print("✅ [Auth] Session refreshed successfully")
                #endif
            }
        } catch let error as APIError {
            throw AuthError.networkError(error)
        }
    }

    /// Sign out user
    func signOut() async {
        #if DEBUG
        print("👋 [Auth] Signing out...")
        #endif

        // Notify backend (optional, don't fail if this errors)
        if let sessionToken = try? await keychainManager.retrieve(forKey: KeychainManager.Keys.sessionToken) {
            try? await apiClient.requestWithoutResponse(
                .signOut,
                body: nil,
                headers: [Constants.Network.HeaderKey.authorization: "Bearer \(sessionToken)"]
            )
        }

        // Clear Keychain
        try? await keychainManager.delete(forKey: KeychainManager.Keys.sessionToken)
        try? await keychainManager.delete(forKey: KeychainManager.Keys.refreshToken)
        try? await keychainManager.delete(forKey: KeychainManager.Keys.appleUserID)
        try? await keychainManager.delete(forKey: KeychainManager.Keys.googleUserID)

        // Clear UserDefaults
        userDefaultsManager.remove(forKey: UserDefaultsManager.Keys.userId)
        userDefaultsManager.remove(forKey: UserDefaultsManager.Keys.userEmail)
        userDefaultsManager.remove(forKey: UserDefaultsManager.Keys.lastLoginProvider)

        // Sign out from Google
        try? await googleSignInService.signOut()

        // Clear session state
        await MainActor.run {
            currentSession = nil
            isAuthenticated = false
        }

        #if DEBUG
        print("✅ [Auth] Signed out successfully")
        #endif
    }

    // MARK: - Private Helpers

    /// Update authentication state
    private func updateAuthState(_ response: AuthResponse, provider: AuthProvider) async {
        await MainActor.run {
            isAuthenticated = true
            // Update shared UserSessionManager
            UserSessionManager.shared.updateSession(from: response, provider: provider)
        }

        // Load profile from cloud (restore data after reinstall)
        await loadProfileFromCloud()
    }

    /// Load user profile from cloud storage
    /// This restores profile data when user logs in on new device or after reinstall
    private func loadProfileFromCloud() async {
        #if DEBUG
        print("☁️ [Auth] Attempting to restore profile from cloud...")
        #endif

        await UserProfileManager.shared.loadProfileFromCloud()
    }

    /// Get authorization header for authenticated requests
    func getAuthorizationHeader() async throws -> String {
        guard let session = currentSession else {
            throw AuthError.sessionExpired
        }

        // Check if session is expired
        if session.isExpired {
            throw AuthError.sessionExpired
        }

        // Check if session is near expiration and refresh if needed
        if session.isNearExpiration {
            try await refreshSession()
        }

        return session.authorizationHeader
    }
}
