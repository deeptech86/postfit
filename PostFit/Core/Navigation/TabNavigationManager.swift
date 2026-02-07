//
//  TabNavigationManager.swift
//  PostFit (MomCare)
//
//  Manages tab navigation from anywhere in the app
//  Allows Dashboard to navigate to specific tabs
//

import Foundation
import SwiftUI

/// Manages tab navigation across the app
@MainActor
class TabNavigationManager: ObservableObject {
    static let shared = TabNavigationManager()

    // MARK: - Tab Enum (matches MainTabView.Tab)

    enum Tab: String, CaseIterable {
        case dashboard = "Dashboard"
        case nutrition = "Nutrition"
        case exercise = "Exercise"
        case hydration = "Hydration"
        case profile = "Profile"
    }

    // MARK: - Published Properties

    /// Currently selected tab
    @Published var selectedTab: Tab = .dashboard

    /// Whether to scroll to Add Food section in Nutrition
    @Published var shouldScrollToAddFood = false

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Navigate to a specific tab
    func navigateTo(_ tab: Tab) {
        selectedTab = tab

        #if DEBUG
        print("🧭 [Navigation] Navigating to \(tab.rawValue)")
        #endif
    }

    /// Navigate to Nutrition tab and scroll to Add Food
    func navigateToAddFood() {
        shouldScrollToAddFood = true
        selectedTab = .nutrition

        #if DEBUG
        print("🧭 [Navigation] Navigating to Add Food section")
        #endif
    }

    /// Navigate to Hydration tab
    func navigateToHydration() {
        selectedTab = .hydration

        #if DEBUG
        print("🧭 [Navigation] Navigating to Hydration")
        #endif
    }

    /// Navigate to Exercise tab
    func navigateToExercise() {
        selectedTab = .exercise

        #if DEBUG
        print("🧭 [Navigation] Navigating to Exercise")
        #endif
    }

    /// Clear scroll request after handling
    func clearScrollRequest() {
        shouldScrollToAddFood = false
    }
}
