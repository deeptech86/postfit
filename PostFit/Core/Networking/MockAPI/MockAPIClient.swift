//
//  MockAPIClient.swift
//  PostFit (MomCare)
//
//  Mock API client for testing and development without backend
//  Simulates realistic network delays and responses
//

import Foundation

/// Mock implementation of API client for testing
class MockAPIClient: APIClientProtocol {

    // MARK: - Configuration

    /// Enable/disable error simulation
    var shouldSimulateError = false

    /// Error to throw when simulation is enabled
    var simulatedError: APIError = MockAuthResponses.networkError

    /// Simulated network delay (in seconds)
    var responseDelay: TimeInterval = Constants.Mock.networkDelay

    /// Probability of returning a new user (0.0 - 1.0)
    var newUserProbability: Double = 0.3

    // MARK: - API Client Protocol Implementation

    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        body: Encodable? = nil,
        headers: [String: String]? = nil
    ) async throws -> T {

        // Log mock request
        #if DEBUG
        logMockRequest(endpoint, body: body)
        #endif

        // Simulate network delay
        try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))

        // Simulate error if configured
        if shouldSimulateError {
            #if DEBUG
            print("❌ [Mock API] Simulating error: \(simulatedError)")
            #endif
            throw simulatedError
        }

        // Generate mock response based on endpoint
        let response = try generateMockResponse(for: endpoint, body: body)

        #if DEBUG
        logMockResponse(endpoint, response: response)
        #endif

        // Decode and return
        guard let typedResponse = response as? T else {
            throw APIError.decodingError(NSError(domain: "MockAPIClient", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to cast mock response to expected type \(T.self)"
            ]))
        }

        return typedResponse
    }

    func requestWithoutResponse(
        _ endpoint: APIEndpoint,
        body: Encodable? = nil,
        headers: [String: String]? = nil
    ) async throws {

        // Log mock request
        #if DEBUG
        logMockRequest(endpoint, body: body)
        #endif

        // Simulate network delay
        try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))

        // Simulate error if configured
        if shouldSimulateError {
            #if DEBUG
            print("❌ [Mock API] Simulating error: \(simulatedError)")
            #endif
            throw simulatedError
        }

        #if DEBUG
        print("✅ [Mock API] Request completed successfully (no response body)")
        #endif
    }

    // MARK: - Mock Response Generation

    private func generateMockResponse(for endpoint: APIEndpoint, body: Encodable?) throws -> Any {
        switch endpoint {
        case .appleSignIn:
            return generateAppleSignInResponse()

        case .googleSignIn:
            return generateGoogleSignInResponse()

        case .emailSignIn:
            return MockAuthResponses.emailSignIn

        case .verifySession:
            return MockAuthResponses.validSession

        case .refreshToken:
            return MockAuthResponses.validSession

        case .signOut:
            return EmptyResponse()

        default:
            throw APIError.notFound
        }
    }

    private func generateAppleSignInResponse() -> AuthResponse {
        // Randomly decide if this is a new user or existing user
        if Double.random(in: 0...1) < newUserProbability {
            return MockAuthResponses.newAppleUser
        } else {
            return MockAuthResponses.existingAppleUser
        }
    }

    private func generateGoogleSignInResponse() -> AuthResponse {
        // Randomly decide if this is a new user or existing user
        if Double.random(in: 0...1) < newUserProbability {
            return MockAuthResponses.newGoogleUser
        } else {
            return MockAuthResponses.existingGoogleUser
        }
    }

    // MARK: - Logging

    #if DEBUG
    private func logMockRequest(_ endpoint: APIEndpoint, body: Encodable?) {
        print("🎭 [Mock API Request] \(endpoint.method.rawValue) \(endpoint.path)")

        if let body = body {
            print("📦 [Mock Body] \(type(of: body))")
        }

        print("⏱️  [Mock Delay] Simulating \(String(format: "%.1f", responseDelay))s network delay...")
    }

    private func logMockResponse(_ endpoint: APIEndpoint, response: Any) {
        print("✅ [Mock API Response] Success for \(endpoint.path)")

        if let authResponse = response as? AuthResponse {
            print("👤 [Mock User] \(authResponse.user.name) (\(authResponse.user.email))")
            print("🆕 [New User] \(authResponse.isNewUser)")
            print("✏️  [Profile Complete] \(authResponse.user.hasCompletedProfile)")
        }
    }
    #endif
}

// MARK: - Empty Response

/// Empty response for endpoints that don't return data
private struct EmptyResponse: Codable {}
