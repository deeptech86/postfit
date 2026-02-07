//
//  CryptoUtilitiesTests.swift
//  PostFit Tests
//
//  Unit tests for CryptoUtilities
//

import XCTest
@testable import PostFit

final class CryptoUtilitiesTests: XCTestCase {

    var cryptoUtilities: CryptoUtilities!

    override func setUp() {
        super.setUp()
        cryptoUtilities = CryptoUtilities()
    }

    override func tearDown() {
        cryptoUtilities = nil
        super.tearDown()
    }

    // MARK: - Nonce Generation Tests

    func testRandomNonceStringGeneratesCorrectLength() {
        // Given
        let expectedLength = 32

        // When
        let nonce = cryptoUtilities.randomNonceString(length: expectedLength)

        // Then
        XCTAssertEqual(nonce.count, expectedLength)
    }

    func testRandomNonceStringGeneratesDifferentValues() {
        // When
        let nonce1 = cryptoUtilities.randomNonceString()
        let nonce2 = cryptoUtilities.randomNonceString()

        // Then
        XCTAssertNotEqual(nonce1, nonce2)
    }

    func testRandomNonceStringUsesValidCharacterSet() {
        // When
        let nonce = cryptoUtilities.randomNonceString()

        // Then
        let validCharacterSet = CharacterSet(charactersIn: "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        for character in nonce {
            XCTAssertTrue(validCharacterSet.contains(character.unicodeScalars.first!))
        }
    }

    // MARK: - SHA256 Hashing Tests

    func testSHA256ProducesConsistentHash() {
        // Given
        let input = "test string"

        // When
        let hash1 = cryptoUtilities.sha256(input)
        let hash2 = cryptoUtilities.sha256(input)

        // Then
        XCTAssertEqual(hash1, hash2)
    }

    func testSHA256ProducesDifferentHashesForDifferentInputs() {
        // When
        let hash1 = cryptoUtilities.sha256("input1")
        let hash2 = cryptoUtilities.sha256("input2")

        // Then
        XCTAssertNotEqual(hash1, hash2)
    }

    func testSHA256ProducesCorrectLength() {
        // When
        let hash = cryptoUtilities.sha256("test")

        // Then
        // SHA256 produces 64 character hex string
        XCTAssertEqual(hash.count, 64)
    }

    func testSHA256KnownValue() {
        // Given
        let input = "hello"
        let expectedHash = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"

        // When
        let hash = cryptoUtilities.sha256(input)

        // Then
        XCTAssertEqual(hash, expectedHash)
    }

    // MARK: - Random String Tests

    func testRandomStringGeneratesCorrectLength() {
        // Given
        let lengths = [10, 20, 50, 100]

        for length in lengths {
            // When
            let randomString = cryptoUtilities.randomString(length: length)

            // Then
            XCTAssertEqual(randomString.count, length)
        }
    }

    func testRandomStringGeneratesDifferentValues() {
        // When
        let string1 = cryptoUtilities.randomString(length: 20)
        let string2 = cryptoUtilities.randomString(length: 20)

        // Then
        XCTAssertNotEqual(string1, string2)
    }

    func testRandomStringUsesCustomCharset() {
        // Given
        let charset = "ABC123"
        let length = 50

        // When
        let randomString = cryptoUtilities.randomString(length: length, charset: charset)

        // Then
        for character in randomString {
            XCTAssertTrue(charset.contains(character))
        }
    }

    // MARK: - UUID Tests

    func testRandomUUIDGeneratesValidFormat() {
        // When
        let uuid = cryptoUtilities.randomUUID()

        // Then
        XCTAssertNotNil(UUID(uuidString: uuid))
    }

    func testRandomUUIDGeneratesDifferentValues() {
        // When
        let uuid1 = cryptoUtilities.randomUUID()
        let uuid2 = cryptoUtilities.randomUUID()

        // Then
        XCTAssertNotEqual(uuid1, uuid2)
    }

    // MARK: - Base64 Tests

    func testBase64EncodeAndDecode() {
        // Given
        let input = "Hello, World!"

        // When
        let encoded = cryptoUtilities.base64Encode(input)
        let decoded = cryptoUtilities.base64Decode(encoded)

        // Then
        XCTAssertEqual(decoded, input)
    }

    func testBase64DecodeInvalidString() {
        // Given
        let invalidBase64 = "not valid base64!!!"

        // When
        let decoded = cryptoUtilities.base64Decode(invalidBase64)

        // Then
        XCTAssertNil(decoded)
    }

    // MARK: - HMAC Tests

    func testHMACSHA256ProducesConsistentResult() {
        // Given
        let message = "test message"
        let key = "secret key"

        // When
        let hmac1 = cryptoUtilities.hmacSHA256(message: message, key: key)
        let hmac2 = cryptoUtilities.hmacSHA256(message: message, key: key)

        // Then
        XCTAssertEqual(hmac1, hmac2)
    }

    func testHMACSHA256ProducesDifferentResultsForDifferentKeys() {
        // Given
        let message = "test message"

        // When
        let hmac1 = cryptoUtilities.hmacSHA256(message: message, key: "key1")
        let hmac2 = cryptoUtilities.hmacSHA256(message: message, key: "key2")

        // Then
        XCTAssertNotEqual(hmac1, hmac2)
    }

    // MARK: - Password Hashing Tests

    func testHashPasswordGeneratesSaltIfNotProvided() {
        // When
        let (hash1, salt1) = cryptoUtilities.hashPassword("password")
        let (hash2, salt2) = cryptoUtilities.hashPassword("password")

        // Then
        XCTAssertNotEqual(salt1, salt2)
        XCTAssertNotEqual(hash1, hash2)
    }

    func testHashPasswordUsesProvidedSalt() {
        // Given
        let password = "password"
        let salt = "fixedSalt"

        // When
        let (hash1, _) = cryptoUtilities.hashPassword(password, salt: salt)
        let (hash2, _) = cryptoUtilities.hashPassword(password, salt: salt)

        // Then
        XCTAssertEqual(hash1, hash2)
    }

    func testVerifyPasswordWithCorrectPassword() {
        // Given
        let password = "correctPassword"
        let (hash, salt) = cryptoUtilities.hashPassword(password)

        // When
        let isValid = cryptoUtilities.verifyPassword(password, hash: hash, salt: salt)

        // Then
        XCTAssertTrue(isValid)
    }

    func testVerifyPasswordWithIncorrectPassword() {
        // Given
        let correctPassword = "correctPassword"
        let incorrectPassword = "wrongPassword"
        let (hash, salt) = cryptoUtilities.hashPassword(correctPassword)

        // When
        let isValid = cryptoUtilities.verifyPassword(incorrectPassword, hash: hash, salt: salt)

        // Then
        XCTAssertFalse(isValid)
    }
}
