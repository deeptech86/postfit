//
//  NutritionDataManager.swift
//  PostFit (MomCare)
//
//  Shared manager for nutrition data across the app
//  Allows Dashboard to display calorie data from Nutrition page
//

import Foundation
import SwiftUI

/// Shared manager for nutrition data across views
@MainActor
class NutritionDataManager: ObservableObject {
    static let shared = NutritionDataManager()

    // MARK: - Published Properties

    /// Current daily nutrition data
    @Published var dailyNutrition = DailyNutrition()

    /// Whether to show the Add Food section when navigating to Nutrition
    @Published var showAddFoodOnNavigation = false

    // MARK: - Computed Properties

    /// Total calories consumed today
    var totalCalories: Int {
        dailyNutrition.totalCalories
    }

    /// Total protein consumed today
    var totalProtein: Double {
        dailyNutrition.totalProtein
    }

    /// Total carbohydrates consumed today
    var totalCarbs: Double {
        dailyNutrition.totalCarbs
    }

    /// Total fat consumed today
    var totalFat: Double {
        dailyNutrition.totalFat
    }

    // MARK: - Initialization

    private init() {
        #if DEBUG
        print("📊 [NutritionData] Manager initialized")
        #endif
    }

    // MARK: - Public Methods

    /// Add a food entry to daily nutrition
    func addEntry(_ entry: FoodEntry) {
        dailyNutrition.addEntry(entry)

        #if DEBUG
        print("📊 [NutritionData] Entry added: \(entry.name) - \(entry.calories) kcal")
        print("📊 [NutritionData] Total calories: \(totalCalories)")
        #endif
    }

    /// Reset daily nutrition (for new day)
    func resetDaily() {
        dailyNutrition = DailyNutrition()

        #if DEBUG
        print("🔄 [NutritionData] Daily nutrition reset")
        #endif
    }

    /// Request navigation to Nutrition tab with Add Food section visible
    func navigateToAddFood() {
        showAddFoodOnNavigation = true

        #if DEBUG
        print("🧭 [NutritionData] Navigation to Add Food requested")
        #endif
    }

    /// Clear navigation request after handling
    func clearNavigationRequest() {
        showAddFoodOnNavigation = false
    }
}
