//
//  ClaudeVisionService.swift
//  PostFit (MomCare)
//
//  Claude (Anthropic) Vision API integration for food recognition
//

import Foundation
import UIKit

// MARK: - Claude API Request Models

struct ClaudeVisionRequest: Codable {
    let model: String
    let maxTokens: Int
    let messages: [ClaudeMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
    }

    struct ClaudeMessage: Codable {
        let role: String
        let content: [ClaudeContent]
    }

    struct ClaudeContent: Codable {
        let type: String
        let text: String?
        let source: ImageSource?

        struct ImageSource: Codable {
            let type: String
            let mediaType: String
            let data: String

            enum CodingKeys: String, CodingKey {
                case type
                case mediaType = "media_type"
                case data
            }
        }
    }
}

// MARK: - Claude API Response Models

struct ClaudeVisionResponse: Codable {
    let content: [ContentBlock]
    let model: String
    let role: String

    struct ContentBlock: Codable {
        let type: String
        let text: String
    }
}

// MARK: - Claude Vision Service

class ClaudeVisionService {

    func recognizeFood(from image: UIImage) async throws -> FoodRecognitionResult {
        #if DEBUG
        print("🤖 [Claude] Starting food recognition...")
        #endif

        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw FoodRecognitionError.imageProcessingFailed
        }

        let base64Image = imageData.base64EncodedString()

        #if DEBUG
        print("🤖 [Claude] Image encoded, size: \(imageData.count) bytes")
        #endif

        // Create Claude API request
        let request = ClaudeVisionRequest(
            model: APIConfig.claudeModel,
            maxTokens: APIConfig.maxTokens,
            messages: [
                ClaudeVisionRequest.ClaudeMessage(
                    role: "user",
                    content: [
                        ClaudeVisionRequest.ClaudeContent(
                            type: "image",
                            text: nil,
                            source: ClaudeVisionRequest.ClaudeContent.ImageSource(
                                type: "base64",
                                mediaType: "image/jpeg",
                                data: base64Image
                            )
                        ),
                        ClaudeVisionRequest.ClaudeContent(
                            type: "text",
                            text: """
                            Analyze this image for postpartum nutrition tracking. Your task:

                            1. Determine if this image contains food
                            2. If it's food, identify the dish and estimate nutritional content
                            3. If it's NOT food, clearly state that

                            Respond ONLY with valid JSON in this exact format:

                            {
                                "isFoodItem": true/false,
                                "foodName": "name of the dish",
                                "calories": number,
                                "protein": number (grams),
                                "carbohydrates": number (grams),
                                "fat": number (grams),
                                "fiber": number (grams),
                                "servingSize": "description (e.g., 1 cup, 200g)",
                                "servingCount": number,
                                "confidence": 0.0-1.0
                            }

                            Guidelines:
                            - Be conservative with portion estimates (better to underestimate)
                            - For postpartum nutrition, focus on accuracy
                            - If not food, set isFoodItem to false and leave other fields at 0
                            - Confidence should reflect your certainty (0.7+ for clear foods)
                            - Consider typical serving sizes

                            Respond with ONLY the JSON, no markdown formatting or extra text.
                            """,
                            source: nil
                        )
                    ]
                )
            ]
        )

        // Make API request
        var urlRequest = URLRequest(url: URL(string: APIConfig.claudeMessagesURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(APIConfig.claudeKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(APIConfig.claudeAPIVersion, forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        #if DEBUG
        print("🤖 [Claude] Sending request to API...")
        #endif

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FoodRecognitionError.apiError
        }

        #if DEBUG
        print("🤖 [Claude] Received response, status: \(httpResponse.statusCode)")
        #endif

        guard httpResponse.statusCode == 200 else {
            #if DEBUG
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ [Claude] API Error: \(errorString)")
            }
            #endif
            throw FoodRecognitionError.apiError
        }

        // Parse Claude response
        let claudeResponse = try JSONDecoder().decode(ClaudeVisionResponse.self, from: data)

        guard let textContent = claudeResponse.content.first?.text else {
            throw FoodRecognitionError.invalidResponse
        }

        #if DEBUG
        print("🤖 [Claude] Parsing AI response...")
        print("📝 [Claude] Raw response: \(textContent)")
        #endif

        // Parse JSON from Claude's response
        return try parseAIResponse(textContent)
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
            #if DEBUG
            print("⚠️ [Claude] Not a food item detected")
            #endif

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

        #if DEBUG
        print("✅ [Claude] Food recognized: \(json?["foodName"] as? String ?? "Unknown")")
        #endif

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
