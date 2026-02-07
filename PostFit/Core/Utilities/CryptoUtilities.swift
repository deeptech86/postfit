//
//  CryptoUtilities.swift
//  PostFit (MomCare)
//
//  Cryptographic utilities for secure operations
//  Used for nonce generation, hashing, and random string generation
//

import Foundation
import CryptoKit

/// Provides cryptographic utility functions
class CryptoUtilities {

    // MARK: - Nonce Generation

    /// Generate a cryptographically secure random nonce string
    /// - Parameter length: Length of the nonce (default: 32)
    /// - Returns: Random nonce string
    func randomNonceString(length: Int = Constants.Apple.nonceLength) -> String {
        precondition(length > 0)

        var randomBytes = [UInt8](repeating: 0, count: length)
        let result = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)

        guard result == errSecSuccess else {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(result)")
        }

        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    // MARK: - Hashing

    /// Compute SHA256 hash of a string
    /// - Parameter input: String to hash
    /// - Returns: Hexadecimal string representation of the hash
    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }

    /// Compute SHA256 hash and return as Data
    /// - Parameter input: String to hash
    /// - Returns: Hashed data
    func sha256Data(_ input: String) -> Data {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return Data(hashedData)
    }

    // MARK: - Random Generation

    /// Generate a random string of specified length
    /// - Parameters:
    ///   - length: Length of the string
    ///   - charset: Characters to use (default: alphanumeric)
    /// - Returns: Random string
    func randomString(length: Int, charset: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789") -> String {
        return String((0..<length).map { _ in charset.randomElement()! })
    }

    /// Generate a random UUID string
    /// - Returns: UUID string
    func randomUUID() -> String {
        return UUID().uuidString
    }

    // MARK: - Base64 Encoding/Decoding

    /// Encode string to Base64
    /// - Parameter input: String to encode
    /// - Returns: Base64 encoded string
    func base64Encode(_ input: String) -> String {
        let data = Data(input.utf8)
        return data.base64EncodedString()
    }

    /// Decode Base64 string
    /// - Parameter input: Base64 encoded string
    /// - Returns: Decoded string, or nil if decoding fails
    func base64Decode(_ input: String) -> String? {
        guard let data = Data(base64Encoded: input) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - HMAC

    /// Compute HMAC-SHA256
    /// - Parameters:
    ///   - message: Message to authenticate
    ///   - key: Secret key
    /// - Returns: HMAC as hexadecimal string
    func hmacSHA256(message: String, key: String) -> String {
        let messageData = Data(message.utf8)
        let keyData = Data(key.utf8)

        let symmetricKey = SymmetricKey(data: keyData)
        let hmac = HMAC<SHA256>.authenticationCode(for: messageData, using: symmetricKey)

        return hmac.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Extension for Secure Password Hashing

extension CryptoUtilities {

    /// Hash a password with salt (for storage - NOT for transmission)
    /// Note: In production, passwords should be hashed server-side
    /// - Parameters:
    ///   - password: Password to hash
    ///   - salt: Salt value (optional, will be generated if not provided)
    /// - Returns: Tuple of (hashedPassword, salt)
    func hashPassword(_ password: String, salt: String? = nil) -> (hash: String, salt: String) {
        let saltValue = salt ?? randomString(length: 16)
        let saltedPassword = password + saltValue
        let hashed = sha256(saltedPassword)
        return (hashed, saltValue)
    }

    /// Verify a password against a hash
    /// - Parameters:
    ///   - password: Password to verify
    ///   - hash: Stored hash
    ///   - salt: Salt used during hashing
    /// - Returns: True if password matches, false otherwise
    func verifyPassword(_ password: String, hash: String, salt: String) -> Bool {
        let (computedHash, _) = hashPassword(password, salt: salt)
        return computedHash == hash
    }
}
