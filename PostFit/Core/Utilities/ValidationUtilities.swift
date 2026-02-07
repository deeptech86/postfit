//
//  ValidationUtilities.swift
//  PostFit (MomCare)
//
//  Input validation utilities for email, password, and general data sanitization
//

import Foundation

/// Provides input validation functions
class ValidationUtilities {

    // MARK: - Email Validation

    /// Validate email format using regex
    /// - Parameter email: Email string to validate
    /// - Returns: True if email is valid, false otherwise
    func isValidEmail(_ email: String) -> Bool {
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", Constants.Validation.emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    /// Sanitize email (trim whitespace, lowercase)
    /// - Parameter email: Email to sanitize
    /// - Returns: Sanitized email
    func sanitizeEmail(_ email: String) -> String {
        return email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - Password Validation

    /// Validate password strength
    /// - Parameter password: Password to validate
    /// - Returns: Validation result with strength level and messages
    func validatePassword(_ password: String) -> PasswordValidationResult {
        var issues: [String] = []
        var strength: PasswordStrength = .weak

        // Check length
        if password.count < Constants.Validation.minPasswordLength {
            issues.append("Password must be at least \(Constants.Validation.minPasswordLength) characters")
        }

        if password.count > Constants.Validation.maxPasswordLength {
            issues.append("Password must be less than \(Constants.Validation.maxPasswordLength) characters")
        }

        // Calculate strength
        var score = 0

        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.rangeOfCharacter(from: .lowercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
        if password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")) != nil { score += 1 }

        switch score {
        case 0...2:
            strength = .weak
            issues.append("Password is too weak. Add uppercase, numbers, and special characters.")
        case 3...4:
            strength = .fair
        case 5:
            strength = .good
        case 6...:
            strength = .strong
        default:
            strength = .weak
        }

        let isValid = issues.isEmpty && password.count >= Constants.Validation.minPasswordLength

        return PasswordValidationResult(isValid: isValid, strength: strength, issues: issues)
    }

    // MARK: - Name Validation

    /// Validate name (letters, spaces, hyphens, apostrophes only)
    /// - Parameter name: Name to validate
    /// - Returns: True if name is valid, false otherwise
    func isValidName(_ name: String) -> Bool {
        let nameRegex = "^[a-zA-Z '-]+$"
        let namePredicate = NSPredicate(format: "SELF MATCHES %@", nameRegex)
        return namePredicate.evaluate(with: name) && name.count >= 2 && name.count <= 50
    }

    /// Sanitize name (trim whitespace, capitalize properly)
    /// - Parameter name: Name to sanitize
    /// - Returns: Sanitized name
    func sanitizeName(_ name: String) -> String {
        return name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    // MARK: - General Sanitization

    /// Remove potentially dangerous characters from input
    /// - Parameter input: String to sanitize
    /// - Returns: Sanitized string
    func sanitizeInput(_ input: String) -> String {
        // Remove control characters
        var sanitized = input.components(separatedBy: .controlCharacters).joined()

        // Remove line breaks if not needed
        sanitized = sanitized.replacingOccurrences(of: "\n", with: " ")
        sanitized = sanitized.replacingOccurrences(of: "\r", with: " ")

        // Trim whitespace
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)

        return sanitized
    }

    /// Check if string contains only alphanumeric characters
    /// - Parameter input: String to check
    /// - Returns: True if alphanumeric, false otherwise
    func isAlphanumeric(_ input: String) -> Bool {
        return input.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) == nil
    }

    // MARK: - URL Validation

    /// Validate URL format
    /// - Parameter urlString: URL string to validate
    /// - Returns: True if URL is valid, false otherwise
    func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            return false
        }

        return url.scheme != nil && url.host != nil
    }

    // MARK: - Phone Number Validation

    /// Validate phone number (basic validation)
    /// - Parameter phone: Phone number to validate
    /// - Returns: True if phone is valid, false otherwise
    func isValidPhoneNumber(_ phone: String) -> Bool {
        // Remove formatting characters
        let cleaned = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()

        // Check length (10-15 digits)
        return cleaned.count >= 10 && cleaned.count <= 15
    }

    /// Format phone number (US format)
    /// - Parameter phone: Phone number to format
    /// - Returns: Formatted phone number
    func formatPhoneNumber(_ phone: String) -> String {
        let cleaned = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()

        if cleaned.count == 10 {
            let areaCode = cleaned.prefix(3)
            let middle = cleaned.dropFirst(3).prefix(3)
            let last = cleaned.dropFirst(6)
            return "(\(areaCode)) \(middle)-\(last)"
        }

        return phone
    }
}

// MARK: - Supporting Types

/// Password validation result
struct PasswordValidationResult {
    let isValid: Bool
    let strength: PasswordStrength
    let issues: [String]
}

/// Password strength levels
enum PasswordStrength: String {
    case weak = "Weak"
    case fair = "Fair"
    case good = "Good"
    case strong = "Strong"

    var color: String {
        switch self {
        case .weak: return "red"
        case .fair: return "orange"
        case .good: return "blue"
        case .strong: return "green"
        }
    }

    var progress: Double {
        switch self {
        case .weak: return 0.25
        case .fair: return 0.5
        case .good: return 0.75
        case .strong: return 1.0
        }
    }
}
