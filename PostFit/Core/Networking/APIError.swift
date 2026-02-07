//
//  APIError.swift
//  PostFit (MomCare)
//
//  API error types for network operations
//

import Foundation

/// Errors that can occur during API operations
enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidRequest
    case networkError(Error)
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case serverError(Int, String?)
    case decodingError(Error)
    case encodingError(Error)
    case noData
    case timeout
    case cancelled
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL is invalid."
        case .invalidRequest:
            return "The request is invalid."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "The server response is invalid."
        case .unauthorized:
            return "Unauthorized. Please sign in again."
        case .forbidden:
            return "You don't have permission to access this resource."
        case .notFound:
            return "The requested resource was not found."
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message ?? "Unknown error")"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .noData:
            return "No data received from server."
        case .timeout:
            return "The request timed out. Please try again."
        case .cancelled:
            return "The request was cancelled."
        case .unknown(let message):
            return "An unknown error occurred: \(message)"
        }
    }

    /// HTTP status code associated with the error (if applicable)
    var statusCode: Int? {
        switch self {
        case .unauthorized:
            return 401
        case .forbidden:
            return 403
        case .notFound:
            return 404
        case .serverError(let code, _):
            return code
        default:
            return nil
        }
    }

    /// Whether the error is recoverable (user can retry)
    var isRecoverable: Bool {
        switch self {
        case .networkError, .timeout, .serverError:
            return true
        case .unauthorized, .forbidden:
            return false
        default:
            return false
        }
    }
}

// MARK: - Error Mapping

extension APIError {

    /// Create APIError from HTTP status code
    /// - Parameters:
    ///   - statusCode: HTTP status code
    ///   - data: Response data (optional)
    /// - Returns: Appropriate APIError
    static func fromStatusCode(_ statusCode: Int, data: Data?) -> APIError {
        var errorMessage: String?

        if let data = data,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = json["message"] as? String {
            errorMessage = message
        }

        switch statusCode {
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404:
            return .notFound
        case 400...499:
            return .serverError(statusCode, errorMessage ?? "Client error")
        case 500...599:
            return .serverError(statusCode, errorMessage ?? "Server error")
        default:
            return .invalidResponse
        }
    }

    /// Create APIError from URLError
    /// - Parameter error: URLError
    /// - Returns: Appropriate APIError
    static func fromURLError(_ error: URLError) -> APIError {
        switch error.code {
        case .cancelled:
            return .cancelled
        case .timedOut:
            return .timeout
        case .cannotFindHost, .cannotConnectToHost, .networkConnectionLost:
            return .networkError(error)
        case .notConnectedToInternet:
            return .networkError(error)
        default:
            return .networkError(error)
        }
    }
}
