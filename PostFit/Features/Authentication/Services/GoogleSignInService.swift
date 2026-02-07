//
//  GoogleSignInService.swift
//  PostFit (MomCare)
//
//  Google Sign-In service using GoogleSignIn SDK
//  Handles Google authentication flow
//

import Foundation
import UIKit
import GoogleSignIn

/// Service for handling Google Sign-In authentication
class GoogleSignInService: ObservableObject {

    // MARK: - Properties

    private let keychainManager: KeychainManager
    private let clientID: String

    // MARK: - Initialization

    init(
        keychainManager: KeychainManager,
        clientID: String = Constants.Google.clientID
    ) {
        self.keychainManager = keychainManager
        self.clientID = clientID

        // Configure Google Sign-In
        configureGoogleSignIn()
    }

    // MARK: - Configuration

    /// Configure Google Sign-In with client ID
    private func configureGoogleSignIn() {
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        #if DEBUG
        print("🔧 [Google Sign-In] Configured with Client ID: \(clientID)")
        #endif
    }

    /// Get email scopes for Google Sign-In
    private var emailScopes: [String] {
        return ["email", "profile"]
    }

    // MARK: - Public Methods

    /// Start Google Sign-In flow
    /// - Parameter viewController: Presenting view controller
    /// - Returns: Google authentication credentials
    /// - Throws: AuthError if sign-in fails
    func signIn(presenting viewController: UIViewController) async throws -> GoogleAuthCredentials {
        #if DEBUG
        print("🔑 [Google Sign-In] Starting sign-in flow...")
        #endif

        do {
            // Sign in with email scope explicitly requested
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: viewController,
                hint: nil,
                additionalScopes: emailScopes
            )

            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.missingToken
            }

            let profile = result.user.profile
            let userID = result.user.userID ?? ""

            // Extract email with fallback if Google doesn't provide it
            let email: String
            if let profileEmail = profile?.email, !profileEmail.isEmpty {
                email = profileEmail
            } else {
                // Fallback: generate email from userID
                email = "\(userID)@google.user"
                #if DEBUG
                print("⚠️ [Google Sign-In] No email provided, using fallback: \(email)")
                #endif
            }

            // Store Google user ID in Keychain
            try await keychainManager.save(userID, forKey: KeychainManager.Keys.googleUserID)

            let credentials = GoogleAuthCredentials(
                userID: userID,
                email: email,
                fullName: profile?.name ?? "Google User",
                profileImageURL: profile?.imageURL(withDimension: 200)?.absoluteString,
                idToken: idToken
            )

            #if DEBUG
            print("✅ [Google Sign-In] Successfully signed in: \(credentials.email)")
            #endif

            return credentials

        } catch let error as NSError {
            #if DEBUG
            print("❌ [Google Sign-In] Failed with error: \(error)")
            #endif

            // Handle user cancellation
            if error.domain == "com.google.GIDSignIn" && error.code == -5 {
                throw AuthError.userCancelled
            }

            throw AuthError.googleSignInFailed(error)
        }
    }

    /// Sign out from Google
    /// - Throws: AuthError if sign-out fails
    func signOut() async throws {
        #if DEBUG
        print("🔑 [Google Sign-In] Signing out...")
        #endif

        GIDSignIn.sharedInstance.signOut()

        // Clear stored Google user ID from Keychain
        try await keychainManager.delete(forKey: KeychainManager.Keys.googleUserID)

        #if DEBUG
        print("✅ [Google Sign-In] Successfully signed out")
        #endif
    }

    /// Restore previous sign-in if available
    /// - Returns: Google credentials if restore successful, nil otherwise
    func restorePreviousSignIn() async -> GoogleAuthCredentials? {
        #if DEBUG
        print("🔑 [Google Sign-In] Attempting to restore previous sign-in...")
        #endif

        do {
            let result = try await GIDSignIn.sharedInstance.restorePreviousSignIn()

            guard let idToken = result.idToken?.tokenString else {
                return nil
            }

            let profile = result.profile
            let userID = result.userID ?? ""

            let credentials = GoogleAuthCredentials(
                userID: userID,
                email: profile?.email ?? "",
                fullName: profile?.name ?? "",
                profileImageURL: profile?.imageURL(withDimension: 200)?.absoluteString,
                idToken: idToken
            )

            #if DEBUG
            print("✅ [Google Sign-In] Restored previous sign-in: \(credentials.email)")
            #endif

            return credentials

        } catch {
            #if DEBUG
            print("ℹ️ [Google Sign-In] No previous sign-in to restore")
            #endif

            return nil
        }
    }

    /// Check if user has previously signed in with Google
    /// - Returns: True if previous sign-in exists
    func hasPreviousSignIn() async -> Bool {
        return GIDSignIn.sharedInstance.hasPreviousSignIn()
    }
}
