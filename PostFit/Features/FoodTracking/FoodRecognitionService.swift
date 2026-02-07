//
//  FoodRecognitionService.swift
//  PostFit (MomCare)
//
//  AI-powered food recognition using OpenAI Vision API
//

import Foundation
import UIKit

// MARK: - Food Recognition Models

struct FoodRecognitionResult {
    let foodName: String
    let calories: Int
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let fiber: Double
    let servingSize: String
    let servingCount: Double
    let confidence: Double
    let isFoodItem: Bool
    let errorMessage: String?
}

struct OpenAIVisionRequest: Codable {
    let model: String
    let messages: [Message]
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model, messages
        case maxTokens = "max_tokens"
    }

    struct Message: Codable {
        let role: String
        let content: [Content]
    }

    struct Content: Codable {
        let type: String
        let text: String?
        let imageUrl: ImageURL?

        enum CodingKeys: String, CodingKey {
            case type, text
            case imageUrl = "image_url"
        }
    }

    struct ImageURL: Codable {
        let url: String
    }
}

struct OpenAIVisionResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message
    }

    struct Message: Codable {
        let content: String
    }
}

struct OpenAIErrorResponse: Codable {
    let error: ErrorDetail

    struct ErrorDetail: Codable {
        let message: String
        let type: String
        let code: String
    }
}

// MARK: - Food Recognition Service

class FoodRecognitionService {

    private let claudeService = ClaudeVisionService()

    func recognizeFood(from image: UIImage) async throws -> FoodRecognitionResult {
        // Check if using mock mode
        if APIConfig.useMockFoodRecognition {
            #if DEBUG
            print("🔍 [Food Recognition] Using MOCK mode - API key not configured for \(APIConfig.selectedProvider.displayName)")
            print("ℹ️ \(APIConfig.apiKeyErrorMessage)")
            #endif

            // Simulate network delay
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            // Return mock response
            return FoodRecognitionResult(
                foodName: "Grilled Chicken Salad",
                calories: 350,
                protein: 35.0,
                carbohydrates: 12.0,
                fat: 18.0,
                fiber: 4.0,
                servingSize: "1 bowl (250g)",
                servingCount: 1.0,
                confidence: 0.85,
                isFoodItem: true,
                errorMessage: nil
            )
        } else {
            #if DEBUG
            print("🔍 [Food Recognition] Using REAL API - Provider: \(APIConfig.selectedProvider.displayName)")
            #endif

            // Use selected provider
            switch APIConfig.selectedProvider {
            case .openAI:
                return try await recognizeFoodWithOpenAI(image: image)
            case .claude:
                return try await claudeService.recognizeFood(from: image)
            }
        }
    }

    private func recognizeFoodWithOpenAI(image: UIImage) async throws -> FoodRecognitionResult {
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw FoodRecognitionError.imageProcessingFailed
        }

        let base64Image = imageData.base64EncodedString()
        let imageUrl = "data:image/jpeg;base64,\(base64Image)"

        // Create request
        let request = OpenAIVisionRequest(
            model: APIConfig.openAIModel,
            messages: [
                OpenAIVisionRequest.Message(
                    role: "user",
                    content: [
                        OpenAIVisionRequest.Content(
                            type: "text",
                            text: """
                            Analyze this image and determine if it contains food. If it's food, provide detailed nutritional information in JSON format:

                            {
                                "isFoodItem": true/false,
                                "foodName": "name of the dish",
                                "calories": number,
                                "protein": number (grams),
                                "carbohydrates": number (grams),
                                "fat": number (grams),
                                "fiber": number (grams),
                                "servingSize": "description",
                                "servingCount": number,
                                "confidence": 0.0-1.0
                            }

                            If not food, set isFoodItem to false and include a brief error message.
                            Focus on accuracy for postpartum nutrition tracking.
                            """,
                            imageUrl: nil
                        ),
                        OpenAIVisionRequest.Content(
                            type: "image_url",
                            text: nil,
                            imageUrl: OpenAIVisionRequest.ImageURL(url: imageUrl)
                        )
                    ]
                )
            ],
            maxTokens: 500
        )

        // Make API request
        var urlRequest = URLRequest(url: URL(string: APIConfig.openAICompletionsURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(APIConfig.openAIKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        #if DEBUG
        print("🌐 [OpenAI] Sending request to: \(APIConfig.openAICompletionsURL)")
        print("🔑 [OpenAI] API Key prefix: \(String(APIConfig.openAIKey.prefix(20)))...")
        #endif

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch {
            #if DEBUG
            print("❌ [OpenAI] Network error: \(error.localizedDescription)")
            print("❌ [OpenAI] Error details: \(error)")
            #endif
            throw FoodRecognitionError.apiError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            #if DEBUG
            print("❌ [OpenAI] Invalid HTTP response")
            #endif
            throw FoodRecognitionError.apiError
        }

        #if DEBUG
        print("📡 [OpenAI] Response status code: \(httpResponse.statusCode)")
        #endif

        guard httpResponse.statusCode == 200 else {
            #if DEBUG
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ [OpenAI] API Error Response: \(errorString)")
            }
            print("❌ [OpenAI] Status code: \(httpResponse.statusCode)")
            #endif

            // Check for quota exceeded error
            if let errorData = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data),
               errorData.error.code == "insufficient_quota" {
                throw FoodRecognitionError.quotaExceeded
            }

            throw FoodRecognitionError.apiError
        }

        // Parse response
        let visionResponse: OpenAIVisionResponse
        do {
            visionResponse = try JSONDecoder().decode(OpenAIVisionResponse.self, from: data)
        } catch {
            #if DEBUG
            print("❌ [OpenAI] Failed to decode response: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("📝 [OpenAI] Raw response: \(responseString)")
            }
            #endif
            throw FoodRecognitionError.parsingFailed
        }

        guard let content = visionResponse.choices.first?.message.content else {
            throw FoodRecognitionError.invalidResponse
        }

        // Parse JSON from AI response
        return try parseAIResponse(content)
    }

    private func parseAIResponse(_ jsonString: String) throws -> FoodRecognitionResult {
        // Extract JSON from potential markdown code blocks
        let cleanedJSON = jsonString
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleanedJSON.data(using: .utf8) else {
            throw FoodRecognitionError.parsingFailed
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let isFoodItem = json?["isFoodItem"] as? Bool else {
            throw FoodRecognitionError.parsingFailed
        }

        if !isFoodItem {
            return FoodRecognitionResult(
                foodName: "",
                calories: 0,
                protein: 0,
                carbohydrates: 0,
                fat: 0,
                fiber: 0,
                servingSize: "",
                servingCount: 0,
                confidence: 0,
                isFoodItem: false,
                errorMessage: "The picture is not a known food item. Please manually log the calories."
            )
        }

        return FoodRecognitionResult(
            foodName: json?["foodName"] as? String ?? "Unknown Food",
            calories: json?["calories"] as? Int ?? 0,
            protein: json?["protein"] as? Double ?? 0,
            carbohydrates: json?["carbohydrates"] as? Double ?? 0,
            fat: json?["fat"] as? Double ?? 0,
            fiber: json?["fiber"] as? Double ?? 0,
            servingSize: json?["servingSize"] as? String ?? "1 serving",
            servingCount: json?["servingCount"] as? Double ?? 1.0,
            confidence: json?["confidence"] as? Double ?? 0.5,
            isFoodItem: true,
            errorMessage: nil
        )
    }
}

// MARK: - Errors

enum FoodRecognitionError: Error, LocalizedError {
    case imageProcessingFailed
    case apiError
    case invalidResponse
    case parsingFailed
    case notAFoodItem
    case quotaExceeded

    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return "Failed to process the image. Please try again."
        case .apiError:
            return "Failed to connect to recognition service. Please check your internet connection."
        case .invalidResponse:
            return "Received invalid response from recognition service."
        case .parsingFailed:
            return "Failed to analyze the image. Please try again."
        case .notAFoodItem:
            return "The picture is not a known food item. Please manually log the calories."
        case .quotaExceeded:
            return "AI service quota exceeded. Please add credits to your OpenAI account at platform.openai.com/account/billing or switch to Claude in APIConfig.swift"
        }
    }
}
