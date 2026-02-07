//
//  AuthProvider.swift
//  PostFit (MomCare)
//
//  Authentication provider types
//

import Foundation

/// Authentication provider options
enum AuthProvider: String, Codable, CaseIterable {
    case apple = "apple"
    case google = "google"
    case email = "email"

    var displayName: String {
        switch self {
        case .apple:
            return "Apple"
        case .google:
            return "Google"
        case .email:
            return "Email"
        }
    }

    var icon: String {
        switch self {
        case .apple:
            return "apple.logo"
        case .google:
            return "g.circle.fill" // Note: Use custom Google logo in production
        case .email:
            return "envelope.fill"
        }
    }
}
