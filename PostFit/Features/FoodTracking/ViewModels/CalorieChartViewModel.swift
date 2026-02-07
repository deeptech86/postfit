//
//  CalorieChartViewModel.swift
//  PostFit (MomCare)
//
//  ViewModel for managing calorie chart data and user interactions
//  Handles data fetching, state management, and chart selection
//

import Foundation
import Combine
import SwiftUI

// MARK: - Calorie Chart ViewModel

/// ViewModel for the 30-day calorie intake chart
@MainActor
class CalorieChartViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Current state of the chart data
    @Published private(set) var state: CalorieChartState = .loading

    /// Currently selected day (for tap interaction)
    @Published var selectedDay: DailyCalorieData?

    /// Whether the detail popover is shown
    @Published var showDetailPopover = false

    /// Chart display options
    @Published var chartOptions = CalorieChartOptions()

    /// Animation trigger
    @Published private(set) var isAnimating = false

    // MARK: - Computed Properties

    /// The chart data when loaded
    var chartData: CalorieChartData? {
        if case .loaded(let data) = state {
            return data
        }
        return nil
    }

    /// Whether data is currently loading
    var isLoading: Bool {
        if case .loading = state {
            return true
        }
        return false
    }

    /// Whether there's an error
    var hasError: Bool {
        if case .error = state {
            return true
        }
        return false
    }

    /// Error message if any
    var errorMessage: String? {
        if case .error(let error) = state {
            return error.localizedDescription
        }
        return nil
    }

    /// Whether there's no data to display
    var isEmpty: Bool {
        if case .empty = state {
            return true
        }
        if case .loaded(let data) = state {
            return data.dailyData.isEmpty
        }
        return false
    }

    /// Summary statistics for display
    var summary: ChartSummary? {
        guard let data = chartData else { return nil }
        return ChartSummary(
            averageCalories: data.averageCalories,
            daysMetGoal: data.daysMetGoal,
            daysWithData: data.daysWithData,
            totalDays: data.dailyData.count,
            calorieGoal: data.adjustedCalorieGoal,
            isBreastfeeding: data.isBreastfeeding
        )
    }

    // MARK: - Private Properties

    private let nutritionService: NutritionServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(nutritionService: NutritionServiceProtocol = NutritionService()) {
        self.nutritionService = nutritionService
    }

    // MARK: - Public Methods

    /// Load calorie chart data
    func loadChartData() async {
        state = .loading
        isAnimating = false

        do {
            let data = try await nutritionService.fetchCalorieChartData(days: NutritionConstants.chartDayCount)

            if data.dailyData.isEmpty {
                state = .empty
            } else {
                state = .loaded(data)

                // Trigger animation after a short delay
                if chartOptions.animateOnAppear {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    isAnimating = true
                }
            }

            #if DEBUG
            print("[CalorieChartVM] Loaded \(data.dailyData.count) days of data")
            print("[CalorieChartVM] Average: \(data.averageCalories) cal, Goal: \(data.adjustedCalorieGoal)")
            #endif
        } catch {
            state = .error(error)

            #if DEBUG
            print("[CalorieChartVM] Error loading data: \(error)")
            #endif
        }
    }

    /// Refresh data
    func refresh() async {
        await loadChartData()
    }

    /// Select a specific day
    func selectDay(_ day: DailyCalorieData) {
        selectedDay = day
        showDetailPopover = true

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        #if DEBUG
        print("[CalorieChartVM] Selected: \(day.shortDateLabel) - \(day.totalCalories) cal")
        #endif
    }

    /// Clear selection
    func clearSelection() {
        selectedDay = nil
        showDetailPopover = false
    }

    /// Toggle goal line visibility
    func toggleGoalLine() {
        chartOptions.showGoalLine.toggle()
    }

    /// Toggle minimum line visibility
    func toggleMinimumLine() {
        chartOptions.showMinimumLine.toggle()
    }
}

// MARK: - Chart Summary

/// Summary statistics for the calorie chart
struct ChartSummary {
    let averageCalories: Int
    let daysMetGoal: Int
    let daysWithData: Int
    let totalDays: Int
    let calorieGoal: Int
    let isBreastfeeding: Bool

    /// Percentage of days that met the goal
    var goalAchievementRate: Double {
        guard daysWithData > 0 else { return 0 }
        return Double(daysMetGoal) / Double(daysWithData)
    }

    /// Formatted goal achievement percentage
    var goalAchievementText: String {
        let percentage = Int(goalAchievementRate * 100)
        return "\(percentage)%"
    }

    /// Whether the average meets the minimum requirement
    var meetsMinimum: Bool {
        averageCalories >= NutritionConstants.minimumPostpartumCalories
    }

    /// Encouragement message based on performance
    var encouragementMessage: String {
        if daysWithData == 0 {
            return "Start logging your meals to see your progress!"
        }

        if !meetsMinimum {
            if isBreastfeeding {
                return "Remember, breastfeeding mothers need at least 1,800 calories daily. You're doing great - try to nourish yourself more!"
            } else {
                return "Try to reach at least 1,800 calories daily for healthy postpartum recovery."
            }
        }

        if goalAchievementRate >= 0.8 {
            return "Fantastic! You're consistently meeting your nutrition goals."
        } else if goalAchievementRate >= 0.5 {
            return "Good progress! Keep focusing on balanced meals."
        } else {
            return "Every day is a fresh start. Focus on nutrient-rich foods."
        }
    }
}

// MARK: - Preview Helper

extension CalorieChartViewModel {
    /// Create a preview instance with sample data
    static var preview: CalorieChartViewModel {
        let viewModel = CalorieChartViewModel(nutritionService: MockNutritionService())
        viewModel.state = .loaded(CalorieChartData.sampleData)
        viewModel.isAnimating = true
        return viewModel
    }

    /// Create a preview instance with loading state
    static var loadingPreview: CalorieChartViewModel {
        let viewModel = CalorieChartViewModel(nutritionService: MockNutritionService())
        viewModel.state = .loading
        return viewModel
    }

    /// Create a preview instance with empty state
    static var emptyPreview: CalorieChartViewModel {
        let viewModel = CalorieChartViewModel(nutritionService: MockNutritionService())
        viewModel.state = .empty
        return viewModel
    }

    /// Create a preview instance with error state
    static var errorPreview: CalorieChartViewModel {
        let viewModel = CalorieChartViewModel(nutritionService: MockNutritionService())
        viewModel.state = .error(NutritionError.networkError)
        return viewModel
    }
}
