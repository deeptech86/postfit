//
//  AIUsageManager.swift
//  PostFit (MomCare)
//
//  Manages AI food recognition usage limits for free users
//
//  IMPORTANT: Usage tracking is DEVICE-BASED, not account-based.
//  Uses iOS Keychain which persists data even after app uninstall/reinstall.
//  This means:
//  - Each device has its own independent usage count
//  - Signing into a different account on the same device keeps the same count
//  - The same account on a different device starts fresh
//  - Uninstalling and reinstalling the app does NOT reset the counter
//

import Foundation
import SwiftUI

/// Manages AI food recognition usage for free tier users
/// Note: Usage is tracked per-device using Keychain storage (persists across reinstalls)
@MainActor
class AIUsageManager: ObservableObject {
    static let shared = AIUsageManager()

    // MARK: - Constants

    /// Maximum free AI recognition uses
    static let freeUsageLimit = 10

    /// Warning threshold (show warning at this usage count)
    static let warningThreshold = 8

    // MARK: - Keychain Keys

    private enum Keys {
        static let aiUsageCount = "ai_food_recognition_usage_count"
        static let isPremiumUser = "ai_is_premium_user"
    }

    // MARK: - Properties

    private let keychainManager = KeychainManager()

    // MARK: - Published Properties

    @Published var usageCount: Int = 0
    @Published var isPremiumUser: Bool = false

    // MARK: - Computed Properties

    /// Remaining free uses
    var remainingUses: Int {
        max(0, Self.freeUsageLimit - usageCount)
    }

    /// Whether user has reached the free limit
    var hasReachedLimit: Bool {
        !isPremiumUser && usageCount >= Self.freeUsageLimit
    }

    /// Whether to show usage warning (at 8 uses)
    var shouldShowWarning: Bool {
        !isPremiumUser && usageCount >= Self.warningThreshold && usageCount < Self.freeUsageLimit
    }

    /// Whether user can use AI recognition
    var canUseAIRecognition: Bool {
        isPremiumUser || usageCount < Self.freeUsageLimit
    }

    // MARK: - Initialization

    private init() {
        // Load data synchronously on init using Task
        Task {
            await loadUsageData()
        }
    }

    // MARK: - Public Methods

    /// Increment usage count after successful AI recognition
    func recordUsage() {
        guard !isPremiumUser else { return }

        usageCount += 1

        // Save to Keychain asynchronously
        Task {
            await saveUsageCount()
        }

        #if DEBUG
        print("📊 [AI Usage] Usage count: \(usageCount)/\(Self.freeUsageLimit)")
        #endif
    }

    /// Check if user should be warned about approaching limit
    func getUsageStatus() -> UsageStatus {
        if isPremiumUser {
            return .premium
        } else if hasReachedLimit {
            return .limitReached
        } else if shouldShowWarning {
            return .warningThreshold(remaining: remainingUses)
        } else {
            return .normal(remaining: remainingUses)
        }
    }

    /// Set premium status
    func setPremiumStatus(_ isPremium: Bool) {
        isPremiumUser = isPremium

        // Save to Keychain asynchronously
        Task {
            await savePremiumStatus()
        }
    }

    /// Reset usage count (for testing or subscription changes)
    func resetUsage() {
        usageCount = 0

        // Save to Keychain asynchronously
        Task {
            await saveUsageCount()
        }

        #if DEBUG
        print("🔄 [AI Usage] Usage count reset")
        #endif
    }

    // MARK: - Private Methods

    private func loadUsageData() async {
        // Load usage count from Keychain
        if let countString = try? await keychainManager.retrieve(forKey: Keys.aiUsageCount),
           let count = Int(countString) {
            usageCount = count
        } else {
            usageCount = 0
        }

        // Load premium status from Keychain
        if let premiumString = try? await keychainManager.retrieve(forKey: Keys.isPremiumUser) {
            isPremiumUser = premiumString == "true"
        } else {
            isPremiumUser = false
        }

        #if DEBUG
        print("📊 [AI Usage] Loaded from Keychain - Count: \(usageCount), Premium: \(isPremiumUser)")
        #endif
    }

    private func saveUsageCount() async {
        do {
            try await keychainManager.save(String(usageCount), forKey: Keys.aiUsageCount)
            #if DEBUG
            print("💾 [AI Usage] Saved usage count to Keychain: \(usageCount)")
            #endif
        } catch {
            #if DEBUG
            print("❌ [AI Usage] Failed to save usage count: \(error)")
            #endif
        }
    }

    private func savePremiumStatus() async {
        do {
            try await keychainManager.save(isPremiumUser ? "true" : "false", forKey: Keys.isPremiumUser)
            #if DEBUG
            print("💾 [AI Usage] Saved premium status to Keychain: \(isPremiumUser)")
            #endif
        } catch {
            #if DEBUG
            print("❌ [AI Usage] Failed to save premium status: \(error)")
            #endif
        }
    }
}

// MARK: - Usage Status Enum

enum UsageStatus {
    case normal(remaining: Int)
    case warningThreshold(remaining: Int)
    case limitReached
    case premium

    var message: String {
        switch self {
        case .normal(let remaining):
            return "\(remaining) free AI scans remaining"
        case .warningThreshold(let remaining):
            return "Only \(remaining) free AI scans remaining! Upgrade to Premium for unlimited scans."
        case .limitReached:
            return "You've used all 10 free AI food scans. Upgrade to Premium for unlimited scans."
        case .premium:
            return "Unlimited AI scans (Premium)"
        }
    }

    var isWarning: Bool {
        switch self {
        case .warningThreshold, .limitReached:
            return true
        default:
            return false
        }
    }
}
