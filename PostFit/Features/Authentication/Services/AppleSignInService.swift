//
//  AppleSignInService.swift
//  PostFit (MomCare)
//
//  Apple Sign-In service with nonce security
//  Handles Apple authentication flow with security best practices
//

import Foundation
import AuthenticationServices
import CryptoKit

/// Service for handling Apple Sign-In authentication
class AppleSignInService: NSObject, ObservableObject {

    // MARK: - Properties

    private let keychainManager: KeychainManager
    private let cryptoUtilities: CryptoUtilities

    @Published var currentNonce: String?

    // MARK: - Initialization

    init(
        keychainManager: KeychainManager,
        cryptoUtilities: CryptoUtilities
    ) {
        self.keychainManager = keychainManager
        self.cryptoUtilities = cryptoUtilities
    }

    // MARK: - Public Methods

    /// Prepare a nonce for Apple Sign-In and return the hashed version
    /// Call this in SignInWithAppleButton's onRequest to set request.nonce
    /// - Returns: SHA256 hashed nonce string to set on the request
    func prepareNonce() -> String {
        // Generate cryptographically secure nonce
        let nonce = cryptoUtilities.randomNonceString()
        currentNonce = nonce

        // Return hashed nonce to set on the request
        return cryptoUtilities.sha256(nonce)
    }

    /// Start Apple Sign-In flow
    /// - Returns: ASAuthorizationAppleIDRequest configured with nonce
    func startSignInFlow() -> ASAuthorizationAppleIDRequest {
        // Generate cryptographically secure nonce
        let nonce = cryptoUtilities.randomNonceString()
        currentNonce = nonce

        // Create Apple ID request
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()

        // Request scopes
        request.requestedScopes = [.fullName, .email]

        // Set nonce (SHA256 hashed)
        request.nonce = cryptoUtilities.sha256(nonce)

        return request
    }

    /// Handle authorization result from Apple Sign-In
    /// - Parameter result: Result from ASAuthorizationController
    /// - Returns: Apple authentication credentials
    /// - Throws: AuthError if processing fails
    func handleAuthorizationResult(
        _ result: Result<ASAuthorization, Error>
    ) async throws -> AppleAuthCredentials {
        switch result {
        case .success(let authorization):
            return try await processSuccessfulAuthorization(authorization)

        case .failure(let error):
            throw processAuthorizationError(error)
        }
    }

    // MARK: - Private Methods

    /// Process successful authorization
    private func processSuccessfulAuthorization(
        _ authorization: ASAuthorization
    ) async throws -> AppleAuthCredentials {
        // Extract Apple ID credential
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError.invalidCredentials
        }

        // Extract identity token
        guard let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            throw AuthError.missingToken
        }

        // Extract authorization code
        guard let authorizationCodeData = appleIDCredential.authorizationCode,
              let authorizationCode = String(data: authorizationCodeData, encoding: .utf8) else {
            throw AuthError.missingAuthorizationCode
        }

        // Validate nonce
        guard let nonce = currentNonce else {
            throw AuthError.invalidNonce
        }

        // Store Apple user identifier in Keychain for future use
        try await keychainManager.save(
            appleIDCredential.user,
            forKey: KeychainManager.Keys.appleUserID
        )

        // Create credentials object
        let credentials = AppleAuthCredentials(
            userIdentifier: appleIDCredential.user,
            email: appleIDCredential.email,
            fullName: appleIDCredential.fullName,
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            nonce: nonce
        )

        // Clear nonce after use (one-time use)
        self.currentNonce = nil

        return credentials
    }

    /// Process authorization error
    private func processAuthorizationError(_ error: Error) -> AuthError {
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                return .userCancelled
            case .failed:
                return .appleSignInFailed(error)
            case .invalidResponse:
                return .invalidCredentials
            case .notHandled:
                return .appleSignInFailed(error)
            case .unknown:
                return .appleSignInFailed(error)
            @unknown default:
                return .appleSignInFailed(error)
            }
        }

        return .appleSignInFailed(error)
    }

    // MARK: - Credential Status Check

    /// Check credential state for a user ID
    /// - Parameter userID: Apple user identifier
    /// - Returns: Credential state
    func checkCredentialState(for userID: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        return await withCheckedContinuation { continuation in
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            appleIDProvider.getCredentialState(forUserID: userID) { credentialState, error in
                if let error = error {
                    print("Error checking credential state: \(error)")
                }
                continuation.resume(returning: credentialState)
            }
        }
    }

    /// Verify stored Apple user ID is still valid
    /// - Returns: True if credential is authorized, false otherwise
    func verifyStoredCredential() async -> Bool {
        do {
            let userID = try await keychainManager.retrieve(forKey: KeychainManager.Keys.appleUserID)
            let credentialState = await checkCredentialState(for: userID)

            return credentialState == .authorized
        } catch {
            return false
        }
    }
}

// MARK: - Authentication Error

/// Authentication-specific errors
enum AuthError: Error, LocalizedError {
    case invalidCredentials
    case missingToken
    case missingAuthorizationCode
    case invalidNonce
    case appleSignInFailed(Error)
    case googleSignInFailed(Error)
    case networkError(APIError)
    case storageError(StorageError)
    case sessionExpired
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid credentials received from sign-in provider."
        case .missingToken:
            return "Authentication token is missing."
        case .missingAuthorizationCode:
            return "Authorization code is missing."
        case .invalidNonce:
            return "Security verification failed. Please try again."
        case .appleSignInFailed(let error):
            return "Apple Sign-In failed: \(error.localizedDescription)"
        case .googleSignInFailed(let error):
            return "Google Sign-In failed: \(error.localizedDescription)"
        case .networkError(let apiError):
            return apiError.localizedDescription
        case .storageError(let storageError):
            return storageError.localizedDescription
        case .sessionExpired:
            return "Your session has expired. Please sign in again."
        case .userCancelled:
            return "Sign-in was cancelled."
        }
    }

    /// Whether the error is user-initiated (cancellation)
    var isUserInitiated: Bool {
        if case .userCancelled = self {
            return true
        }
        return false
    }
}
