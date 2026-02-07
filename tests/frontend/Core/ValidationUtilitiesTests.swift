//
//  ValidationUtilitiesTests.swift
//  PostFit Tests
//
//  Unit tests for ValidationUtilities
//

import XCTest
@testable import PostFit

final class ValidationUtilitiesTests: XCTestCase {

    var validationUtilities: ValidationUtilities!

    override func setUp() {
        super.setUp()
        validationUtilities = ValidationUtilities()
    }

    override func tearDown() {
        validationUtilities = nil
        super.tearDown()
    }

    // MARK: - Email Validation Tests

    func testValidEmails() {
        let validEmails = [
            "user@example.com",
            "test.user@example.com",
            "user+tag@example.co.uk",
            "user123@test-domain.com",
            "user_name@example.org"
        ]

        for email in validEmails {
            XCTAssertTrue(
                validationUtilities.isValidEmail(email),
                "\(email) should be valid"
            )
        }
    }

    func testInvalidEmails() {
        let invalidEmails = [
            "notanemail",
            "@example.com",
            "user@",
            "user @example.com",
            "user@.com",
            "user@domain",
            ""
        ]

        for email in invalidEmails {
            XCTAssertFalse(
                validationUtilities.isValidEmail(email),
                "\(email) should be invalid"
            )
        }
    }

    func testSanitizeEmail() {
        // Test trimming whitespace
        XCTAssertEqual(
            validationUtilities.sanitizeEmail("  user@example.com  "),
            "user@example.com"
        )

        // Test lowercase conversion
        XCTAssertEqual(
            validationUtilities.sanitizeEmail("User@Example.COM"),
            "user@example.com"
        )

        // Test both
        XCTAssertEqual(
            validationUtilities.sanitizeEmail("  User@Example.COM  "),
            "user@example.com"
        )
    }

    // MARK: - Password Validation Tests

    func testWeakPasswords() {
        let weakPasswords = [
            "123",           // Too short
            "pass",          // Too short
            "password",      // Weak (no uppercase, numbers, symbols)
            "12345678"       // Only numbers
        ]

        for password in weakPasswords {
            let result = validationUtilities.validatePassword(password)
            XCTAssertTrue(
                result.strength == .weak || !result.isValid,
                "\(password) should be weak or invalid"
            )
        }
    }

    func testStrongPasswords() {
        let strongPasswords = [
            "Password123!",
            "MyP@ssw0rd2023",
            "Str0ng!Pass#Word",
            "C0mplex&Secure!123"
        ]

        for password in strongPasswords {
            let result = validationUtilities.validatePassword(password)
            XCTAssertTrue(
                result.strength == .strong || result.strength == .good,
                "\(password) should be strong or good"
            )
            XCTAssertTrue(result.isValid)
        }
    }

    func testPasswordTooShort() {
        let result = validationUtilities.validatePassword("Pass1!")
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.issues.contains { $0.contains("at least") })
    }

    func testPasswordTooLong() {
        let longPassword = String(repeating: "a", count: 130)
        let result = validationUtilities.validatePassword(longPassword)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.issues.contains { $0.contains("less than") })
    }

    // MARK: - Name Validation Tests

    func testValidNames() {
        let validNames = [
            "John Doe",
            "Mary-Jane",
            "O'Brien",
            "Jean-Claude",
            "Sarah Johnson"
        ]

        for name in validNames {
            XCTAssertTrue(
                validationUtilities.isValidName(name),
                "\(name) should be valid"
            )
        }
    }

    func testInvalidNames() {
        let invalidNames = [
            "J",              // Too short
            "Name123",        // Contains numbers
            "User@Name",      // Contains symbols
            "",               // Empty
            String(repeating: "a", count: 51)  // Too long
        ]

        for name in invalidNames {
            XCTAssertFalse(
                validationUtilities.isValidName(name),
                "\(name) should be invalid"
            )
        }
    }

    func testSanitizeName() {
        XCTAssertEqual(
            validationUtilities.sanitizeName("  john doe  "),
            "John Doe"
        )

        XCTAssertEqual(
            validationUtilities.sanitizeName("mary jane smith"),
            "Mary Jane Smith"
        )
    }

    // MARK: - Input Sanitization Tests

    func testSanitizeInput() {
        // Test control character removal
        let input = "Hello\nWorld\r\nTest"
        let sanitized = validationUtilities.sanitizeInput(input)
        XCTAssertFalse(sanitized.contains("\n"))
        XCTAssertFalse(sanitized.contains("\r"))

        // Test whitespace trimming
        let input2 = "  trimmed  "
        let sanitized2 = validationUtilities.sanitizeInput(input2)
        XCTAssertEqual(sanitized2, "trimmed")
    }

    func testIsAlphanumeric() {
        XCTAssertTrue(validationUtilities.isAlphanumeric("abc123"))
        XCTAssertTrue(validationUtilities.isAlphanumeric("ABC"))
        XCTAssertTrue(validationUtilities.isAlphanumeric("123"))
        XCTAssertFalse(validationUtilities.isAlphanumeric("abc-123"))
        XCTAssertFalse(validationUtilities.isAlphanumeric("abc 123"))
        XCTAssertFalse(validationUtilities.isAlphanumeric("abc@123"))
    }

    // MARK: - URL Validation Tests

    func testValidURLs() {
        let validURLs = [
            "https://www.example.com",
            "http://example.com",
            "https://example.com/path?query=value",
            "https://subdomain.example.com"
        ]

        for url in validURLs {
            XCTAssertTrue(
                validationUtilities.isValidURL(url),
                "\(url) should be valid"
            )
        }
    }

    func testInvalidURLs() {
        let invalidURLs = [
            "not a url",
            "example.com",        // No scheme
            "http://",            // No host
            "",
            "ftp://example"       // Missing TLD
        ]

        for url in invalidURLs {
            XCTAssertFalse(
                validationUtilities.isValidURL(url),
                "\(url) should be invalid"
            )
        }
    }

    // MARK: - Phone Number Tests

    func testValidPhoneNumbers() {
        let validNumbers = [
            "1234567890",
            "123-456-7890",
            "(123) 456-7890",
            "+1 234 567 8900"
        ]

        for number in validNumbers {
            XCTAssertTrue(
                validationUtilities.isValidPhoneNumber(number),
                "\(number) should be valid"
            )
        }
    }

    func testInvalidPhoneNumbers() {
        let invalidNumbers = [
            "123",            // Too short
            "abc",            // Not numbers
            "",               // Empty
            "12345678901234567"  // Too long
        ]

        for number in invalidNumbers {
            XCTAssertFalse(
                validationUtilities.isValidPhoneNumber(number),
                "\(number) should be invalid"
            )
        }
    }

    func testFormatPhoneNumber() {
        XCTAssertEqual(
            validationUtilities.formatPhoneNumber("1234567890"),
            "(123) 456-7890"
        )

        // Already formatted
        XCTAssertEqual(
            validationUtilities.formatPhoneNumber("(123) 456-7890"),
            "(123) 456-7890"
        )

        // Invalid length - returns as-is
        XCTAssertEqual(
            validationUtilities.formatPhoneNumber("123"),
            "123"
        )
    }
}
