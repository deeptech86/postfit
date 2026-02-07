//
//  APIClient.swift
//  PostFit (MomCare)
//
//  URLSession-based HTTP client for API communication
//  Protocol-based design for easy testing and mocking
//

import Foundation

// MARK: - API Client Protocol

/// Protocol for API client implementations
protocol APIClientProtocol {
    /// Make an API request with generic Codable response
    /// - Parameters:
    ///   - endpoint: API endpoint to call
    ///   - body: Request body (Encodable)
    ///   - headers: Additional headers
    /// - Returns: Decoded response
    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        body: Encodable?,
        headers: [String: String]?
    ) async throws -> T

    /// Make an API request without expecting a response body
    /// - Parameters:
    ///   - endpoint: API endpoint to call
    ///   - body: Request body (Encodable)
    ///   - headers: Additional headers
    func requestWithoutResponse(
        _ endpoint: APIEndpoint,
        body: Encodable?,
        headers: [String: String]?
    ) async throws
}

// MARK: - Backend Response Wrapper

/// Wrapper for backend API responses
private struct APIResponseWrapper<T: Decodable>: Decodable {
    let success: Bool
    let message: String
    let data: T
    let meta: Meta?

    struct Meta: Decodable {
        let timestamp: String
    }
}

// MARK: - API Client Implementation

/// URLSession-based API client
class APIClient: APIClientProtocol {

    // MARK: - Properties

    private let session: URLSession
    private let baseURL: String
    private let timeoutInterval: TimeInterval

    // MARK: - Initialization

    init(
        baseURL: String = Constants.API.currentBaseURL,
        timeoutInterval: TimeInterval = Constants.API.timeoutInterval,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.timeoutInterval = timeoutInterval
        self.session = session
    }

    // MARK: - Public Methods

    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        body: Encodable? = nil,
        headers: [String: String]? = nil
    ) async throws -> T {
        let urlRequest = try buildURLRequest(endpoint: endpoint, body: body, headers: headers)

        #if DEBUG
        logRequest(urlRequest, body: body)
        #endif

        do {
            let (data, response) = try await session.data(for: urlRequest)

            #if DEBUG
            logResponse(response, data: data)
            #endif

            try validateResponse(response, data: data)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            do {
                // Try to decode as wrapped response first
                let wrapper = try decoder.decode(APIResponseWrapper<T>.self, from: data)

                // Check if the response was successful
                guard wrapper.success else {
                    throw APIError.serverError(500, wrapper.message)
                }

                return wrapper.data
            } catch DecodingError.keyNotFound {
                // If wrapper decode fails, try direct decode (for non-wrapped responses)
                do {
                    let decodedResponse = try decoder.decode(T.self, from: data)
                    return decodedResponse
                } catch {
                    throw APIError.decodingError(error)
                }
            } catch let apiError as APIError {
                throw apiError
            } catch {
                throw APIError.decodingError(error)
            }

        } catch let error as APIError {
            throw error
        } catch let urlError as URLError {
            throw APIError.fromURLError(urlError)
        } catch {
            throw APIError.networkError(error)
        }
    }

    func requestWithoutResponse(
        _ endpoint: APIEndpoint,
        body: Encodable? = nil,
        headers: [String: String]? = nil
    ) async throws {
        let urlRequest = try buildURLRequest(endpoint: endpoint, body: body, headers: headers)

        #if DEBUG
        logRequest(urlRequest, body: body)
        #endif

        do {
            let (data, response) = try await session.data(for: urlRequest)

            #if DEBUG
            logResponse(response, data: data)
            #endif

            try validateResponse(response, data: data)

        } catch let error as APIError {
            throw error
        } catch let urlError as URLError {
            throw APIError.fromURLError(urlError)
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Private Methods

    /// Build URLRequest from endpoint configuration
    private func buildURLRequest(
        endpoint: APIEndpoint,
        body: Encodable?,
        headers: [String: String]?
    ) throws -> URLRequest {
        // Construct URL
        guard let url = URL(string: baseURL + endpoint.path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = timeoutInterval

        // Set default headers
        request.setValue(endpoint.contentType, forHTTPHeaderField: Constants.Network.HeaderKey.contentType)
        request.setValue(endpoint.contentType, forHTTPHeaderField: Constants.Network.HeaderKey.accept)
        request.setValue(buildUserAgent(), forHTTPHeaderField: Constants.Network.HeaderKey.userAgent)
        request.setValue(Constants.Device.identifier, forHTTPHeaderField: Constants.Network.HeaderKey.deviceID)
        request.setValue(Constants.App.version, forHTTPHeaderField: Constants.Network.HeaderKey.appVersion)

        // Set custom headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Set request body
        if let body = body {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                request.httpBody = try encoder.encode(AnyEncodable(body))
            } catch {
                throw APIError.encodingError(error)
            }
        }

        return request
    }

    /// Validate HTTP response
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        let statusCode = httpResponse.statusCode

        guard (200...299).contains(statusCode) else {
            throw APIError.fromStatusCode(statusCode, data: data)
        }
    }

    /// Build user agent string
    private func buildUserAgent() -> String {
        let appName = Constants.App.displayName
        let appVersion = Constants.App.version
        let systemVersion = Constants.Device.systemVersion
        let deviceModel = Constants.Device.model

        return "\(appName)/\(appVersion) (iOS \(systemVersion); \(deviceModel))"
    }

    // MARK: - Logging

    #if DEBUG
    private func logRequest(_ request: URLRequest, body: Encodable?) {
        print("🌐 [API Request] \(request.httpMethod ?? "UNKNOWN") \(request.url?.absoluteString ?? "NO URL")")

        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            print("📋 [Headers]")
            headers.forEach { key, value in
                // Don't log sensitive headers
                if key.lowercased() == "authorization" {
                    print("  \(key): [REDACTED]")
                } else {
                    print("  \(key): \(value)")
                }
            }
        }

        if let body = body {
            print("📦 [Body] \(type(of: body))")
            if let jsonData = try? JSONEncoder().encode(AnyEncodable(body)),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print("  \(jsonString)")
            }
        }
    }

    private func logResponse(_ response: URLResponse, data: Data) {
        guard let httpResponse = response as? HTTPURLResponse else { return }

        let statusCode = httpResponse.statusCode
        let emoji = (200...299).contains(statusCode) ? "✅" : "❌"

        print("\(emoji) [API Response] Status: \(statusCode)")

        if let jsonObject = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            print("📥 [Response Data]")
            print(prettyString)
        } else if let responseString = String(data: data, encoding: .utf8) {
            print("📥 [Response Data] \(responseString)")
        }
    }
    #endif
}

// MARK: - AnyEncodable Helper

/// Type-erased Encodable wrapper
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        _encode = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
