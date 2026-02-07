//
//  APIEndpoint.swift
//  PostFit (MomCare)
//
//  API endpoint definitions for all backend routes
//

import Foundation

/// API endpoints for the MomCare backend
enum APIEndpoint {
    // MARK: - Authentication
    case appleSignIn
    case googleSignIn
    case emailSignIn
    case emailSignUp
    case refreshToken
    case signOut
    case verifySession

    // MARK: - User Profile
    case getProfile
    case updateProfile
    case deleteAccount

    // MARK: - Health Data
    case syncHealthData
    case getFoodEntries(Date)
    case getFoodEntriesRange(startDate: Date, endDate: Date)
    case addFoodEntry
    case getHydration(Date)
    case addHydrationEntry
    case getExercises
    case logWorkout

    // MARK: - Path

    var path: String {
        switch self {
        // Authentication
        case .appleSignIn:
            return "/auth/apple"
        case .googleSignIn:
            return "/auth/google"
        case .emailSignIn:
            return "/auth/email/signin"
        case .emailSignUp:
            return "/auth/email/signup"
        case .refreshToken:
            return "/auth/refresh"
        case .signOut:
            return "/auth/signout"
        case .verifySession:
            return "/auth/verify"

        // User Profile
        case .getProfile:
            return "/user/profile"
        case .updateProfile:
            return "/user/profile"
        case .deleteAccount:
            return "/user/account"

        // Health Data
        case .syncHealthData:
            return "/health/sync"
        case .getFoodEntries(let date):
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dateString = formatter.string(from: date)
            return "/food/date/\(dateString)"
        case .getFoodEntriesRange(let startDate, let endDate):
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let startString = formatter.string(from: startDate)
            let endString = formatter.string(from: endDate)
            return "/food/range?startDate=\(startString)&endDate=\(endString)"
        case .addFoodEntry:
            return "/food"
        case .getHydration(let date):
            let dateString = ISO8601DateFormatter().string(from: date)
            return "/health/hydration?date=\(dateString)"
        case .addHydrationEntry:
            return "/health/hydration"
        case .getExercises:
            return "/health/exercises"
        case .logWorkout:
            return "/health/workout"
        }
    }

    // MARK: - HTTP Method

    var method: Constants.Network.HTTPMethod {
        switch self {
        // Authentication - POST
        case .appleSignIn, .googleSignIn, .emailSignIn, .emailSignUp,
             .refreshToken, .signOut:
            return .post

        // Verification - GET
        case .verifySession:
            return .get

        // User Profile
        case .getProfile:
            return .get
        case .updateProfile:
            return .put
        case .deleteAccount:
            return .delete

        // Health Data
        case .syncHealthData, .addFoodEntry, .addHydrationEntry, .logWorkout:
            return .post
        case .getFoodEntries, .getFoodEntriesRange, .getHydration, .getExercises:
            return .get
        }
    }

    // MARK: - Requires Authentication

    var requiresAuth: Bool {
        switch self {
        case .appleSignIn, .googleSignIn, .emailSignIn, .emailSignUp:
            return false
        default:
            return true
        }
    }

    // MARK: - Content Type

    var contentType: String {
        return Constants.Network.ContentType.json
    }
}
