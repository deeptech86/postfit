//
//  APIConfig.swift
//  PostFit (MomCare)
//
//  Secure API key configuration
//  IMPORTANT: Never commit API keys to version control
//

import Foundation

// MARK: - AI Provider Selection

enum AIProvider: String, CaseIterable {
    case openAI = "OpenAI"
    case claude = "Claude"

    var displayName: String { rawValue }
}

struct APIConfig {

    // MARK: - Provider Selection

    /// Choose which AI provider to use for food recognition
    /// Options: .openAI (GPT-4o) or .claude (Claude 3.5 Sonnet)
    static let selectedProvider: AIProvider = .openAI  // Using OpenAI

    // MARK: - OpenAI Configuration

    /// OpenAI API Key for food recognition
    /// Get your key from: https://platform.openai.com/api-keys
    ///
    /// STEPS TO ADD YOUR API KEY:
    /// 1. Go to https://platform.openai.com/api-keys
    /// 2. Create a new secret key (starts with 'sk-')
    /// 3. Replace the value below with your key
    /// 4. NEVER commit this file with your real key to version control!
    ///
    /// For production, use:
    /// - Environment variables
    /// - Backend proxy (recommended)
    /// - Secure key management service
    static let openAIKey: String = {
        // Option 1: Read from environment variable (recommended for production)
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !envKey.isEmpty {
            return envKey
        }

        // Option 2: Read from Info.plist (better than hardcoding)
        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "OpenAIAPIKey") as? String, !plistKey.isEmpty {
            return plistKey
        }

        // Option 3: Hardcoded (DEVELOPMENT ONLY - replace with your key)
        // ⚠️ WARNING: Remove before committing to Git!
        return "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"
    }()

    // MARK: - Claude (Anthropic) Configuration

    /// Claude API Key for food recognition
    /// Get your key from: https://console.anthropic.com/settings/keys
    ///
    /// STEPS TO ADD YOUR API KEY:
    /// 1. Go to https://console.anthropic.com/settings/keys
    /// 2. Create a new API key (starts with 'sk-ant-')
    /// 3. Replace the value below with your key
    /// 4. NEVER commit this file with your real key to version control!
    static let claudeKey: String = {
        // Option 1: Read from environment variable (recommended for production)
        if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envKey.isEmpty {
            return envKey
        }

        // Option 2: Read from Info.plist (better than hardcoding)
        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "AnthropicAPIKey") as? String, !plistKey.isEmpty {
            return plistKey
        }

        // Option 3: Hardcoded (DEVELOPMENT ONLY - replace with your key)
        // ⚠️ WARNING: Remove before committing to Git!
        return "sk-ant-YOUR_ACTUAL_CLAUDE_API_KEY_HERE"
    }()

    // MARK: - API Endpoints

    static let openAICompletionsURL = "https://api.openai.com/v1/chat/completions"
    static let claudeMessagesURL = "https://api.anthropic.com/v1/messages"

    // MARK: - Model Configuration

    /// OpenAI: GPT-4 Vision model for image analysis
    static let openAIModel = "gpt-4o"  // gpt-4o or gpt-4-vision-preview

    /// Claude: Vision model for image analysis
    static let claudeModel = "claude-3-5-sonnet-20241022"  // Latest Claude 3.5 Sonnet with vision

    /// Claude API Version
    static let claudeAPIVersion = "2023-06-01"

    /// Max tokens for API response
    static let maxTokens = 1024

    // MARK: - Feature Flags

    /// Enable/disable mock mode for testing without API calls
    static var useMockFoodRecognition: Bool {
        #if DEBUG
        // In debug mode, check if the selected provider's API key is configured
        switch selectedProvider {
        case .openAI:
            return openAIKey.contains("YOUR_ACTUAL") || openAIKey.isEmpty
        case .claude:
            return claudeKey.contains("YOUR_ACTUAL") || claudeKey.isEmpty
        }
        #else
        // In production, always use real API if key is configured
        switch selectedProvider {
        case .openAI:
            return openAIKey.contains("YOUR_ACTUAL") || openAIKey.isEmpty
        case .claude:
            return claudeKey.contains("YOUR_ACTUAL") || claudeKey.isEmpty
        }
        #endif
    }

    // MARK: - Validation

    /// Check if OpenAI API key is configured
    static var isOpenAIConfigured: Bool {
        !openAIKey.isEmpty && !openAIKey.contains("YOUR_ACTUAL")
    }

    /// Check if Claude API key is configured
    static var isClaudeConfigured: Bool {
        !claudeKey.isEmpty && !claudeKey.contains("YOUR_ACTUAL")
    }

    /// Check if the selected provider is configured
    static var isSelectedProviderConfigured: Bool {
        switch selectedProvider {
        case .openAI:
            return isOpenAIConfigured
        case .claude:
            return isClaudeConfigured
        }
    }

    /// Get user-friendly error message for missing API key
    static var apiKeyErrorMessage: String {
        switch selectedProvider {
        case .openAI:
            return """
            OpenAI API key not configured.

            To enable AI food recognition:
            1. Get API key from https://platform.openai.com/api-keys
            2. Add key to APIConfig.swift
            3. Rebuild the app

            Currently using mock data for demonstration.
            """
        case .claude:
            return """
            Claude API key not configured.

            To enable AI food recognition:
            1. Get API key from https://console.anthropic.com/settings/keys
            2. Add key to APIConfig.swift
            3. Rebuild the app

            Currently using mock data for demonstration.
            """
        }
    }
}

// MARK: - Usage Example
/*

 // In FoodRecognitionService.swift:

 private let apiKey = APIConfig.openAIKey

 func recognizeFood(from image: UIImage) async throws -> FoodRecognitionResult {
     if APIConfig.useMockFoodRecognition {
         // Return mock data
     } else {
         // Call real OpenAI API
     }
 }

 */
