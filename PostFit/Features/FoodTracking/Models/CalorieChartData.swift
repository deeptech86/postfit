//
//  CalorieChartData.swift
//  PostFit (MomCare)
//
//  Model for representing daily calorie intake data for chart visualization
//  Includes support for postpartum-specific nutrition indicators
//

import Foundation

// MARK: - Daily Calorie Data Point

/// Represents a single day's calorie intake data for chart visualization
struct DailyCalorieData: Identifiable, Codable {
    let id: UUID
    let date: Date
    let totalCalories: Int
    let calorieGoal: Int
    let breastfeedingAdjustment: Int
    let entriesCount: Int

    /// Whether this day's calorie value is an estimate (no actual food entries logged)
    /// When true, the calories shown are based on the user's daily goal as a placeholder
    let isEstimated: Bool

    /// The actual logged calories before any estimation was applied
    /// This is 0 when isEstimated is true (no entries logged)
    let actualCalories: Int

    /// Whether the user met their minimum calorie requirement (important for postpartum/breastfeeding)
    /// Note: For estimated days, this is based on the estimated value
    var meetsMinimumRequirement: Bool {
        // Minimum 1800 calories recommended for postpartum mothers
        return totalCalories >= NutritionConstants.minimumPostpartumCalories
    }

    /// Progress toward daily calorie goal (0.0 to 1.0+)
    var goalProgress: Double {
        guard calorieGoal > 0 else { return 0 }
        return Double(totalCalories) / Double(calorieGoal)
    }

    /// Progress based on actual logged data (0 for estimated days)
    var actualGoalProgress: Double {
        guard calorieGoal > 0 else { return 0 }
        return Double(actualCalories) / Double(calorieGoal)
    }

    /// Whether this is the current day
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    /// Whether this day has actual logged food entries
    var hasActualData: Bool {
        return !isEstimated && entriesCount > 0
    }

    /// Formatted date string for display
    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    /// Short date for tooltips
    var shortDateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    /// Full date for accessibility
    var fullDateLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    /// Description of data source for accessibility and display
    var dataSourceDescription: String {
        if isEstimated {
            return "Estimated (based on daily goal)"
        } else if entriesCount == 1 {
            return "1 meal logged"
        } else {
            return "\(entriesCount) meals logged"
        }
    }

    init(
        id: UUID = UUID(),
        date: Date,
        totalCalories: Int,
        calorieGoal: Int,
        breastfeedingAdjustment: Int = 0,
        entriesCount: Int = 0,
        isEstimated: Bool = false,
        actualCalories: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.totalCalories = totalCalories
        self.calorieGoal = calorieGoal
        self.breastfeedingAdjustment = breastfeedingAdjustment
        self.entriesCount = entriesCount
        self.isEstimated = isEstimated
        // If actualCalories is not provided, use totalCalories for non-estimated days, 0 for estimated
        self.actualCalories = actualCalories ?? (isEstimated ? 0 : totalCalories)
    }
}

// MARK: - 30-Day Calorie Chart Data

/// Container for 30 days of calorie intake data
struct CalorieChartData {
    let dailyData: [DailyCalorieData]
    let baseCalorieGoal: Int
    let isBreastfeeding: Bool
    let breastfeedingAdjustment: Int

    /// The adjusted calorie goal including breastfeeding adjustment
    var adjustedCalorieGoal: Int {
        baseCalorieGoal + breastfeedingAdjustment
    }

    /// Average daily calories over the period (only from actual logged data)
    var averageCalories: Int {
        let actualData = dailyData.filter { !$0.isEstimated }
        guard !actualData.isEmpty else { return 0 }
        let total = actualData.reduce(0) { $0 + $1.totalCalories }
        return total / actualData.count
    }

    /// Average including estimated days (for display when estimates are shown)
    var averageCaloriesIncludingEstimates: Int {
        guard !dailyData.isEmpty else { return 0 }
        let total = dailyData.reduce(0) { $0 + $1.totalCalories }
        return total / dailyData.count
    }

    /// Number of days where minimum calories were met (actual data only)
    var daysMetMinimum: Int {
        dailyData.filter { !$0.isEstimated && $0.meetsMinimumRequirement }.count
    }

    /// Number of days where calorie goal was met (actual data only)
    var daysMetGoal: Int {
        dailyData.filter { !$0.isEstimated && $0.goalProgress >= 1.0 }.count
    }

    /// Days with logged entries (actual data)
    var daysWithData: Int {
        dailyData.filter { $0.entriesCount > 0 && !$0.isEstimated }.count
    }

    /// Days with estimated data (no actual entries)
    var daysWithEstimatedData: Int {
        dailyData.filter { $0.isEstimated }.count
    }

    /// Total days in the chart
    var totalDays: Int {
        dailyData.count
    }

    /// Maximum calories for chart scaling
    var maxCalories: Int {
        let maxFromData = dailyData.map { $0.totalCalories }.max() ?? 0
        return max(maxFromData, adjustedCalorieGoal)
    }

    /// Minimum calories for chart scaling (for highlighting undereating)
    var minRecommendedCalories: Int {
        NutritionConstants.minimumPostpartumCalories
    }

    /// Whether any estimated data is present in the chart
    var hasEstimatedData: Bool {
        dailyData.contains { $0.isEstimated }
    }

    init(
        dailyData: [DailyCalorieData] = [],
        baseCalorieGoal: Int = NutritionConstants.defaultCalorieGoal,
        isBreastfeeding: Bool = false,
        breastfeedingAdjustment: Int = 0
    ) {
        self.dailyData = dailyData
        self.baseCalorieGoal = baseCalorieGoal
        self.isBreastfeeding = isBreastfeeding
        self.breastfeedingAdjustment = breastfeedingAdjustment
    }
}

// MARK: - Chart Display Options

/// Options for customizing the calorie chart display
struct CalorieChartOptions {
    var showGoalLine: Bool = true
    var showMinimumLine: Bool = true
    var showBreastfeedingAdjustment: Bool = true
    var highlightToday: Bool = true
    var showTrendLine: Bool = false
    var animateOnAppear: Bool = true

    /// Whether to show estimated data for days with no food entries
    /// When enabled, days without logged meals will show the user's daily calorie goal
    /// as an estimated value with visual distinction
    var showEstimatedData: Bool = true

    /// Whether to include estimated data in average calculations
    var includeEstimatesInAverage: Bool = false
}

// MARK: - Chart State

/// State management for the calorie chart
enum CalorieChartState {
    case loading
    case loaded(CalorieChartData)
    case empty
    case error(Error)
}

// MARK: - Nutrition Constants

/// Nutrition-related constants for the calorie chart and food tracking
enum NutritionConstants {
    /// Minimum recommended daily calories for postpartum mothers
    static let minimumPostpartumCalories = 1800

    /// Default calorie goal for non-breastfeeding mothers
    static let defaultCalorieGoal = 1800

    /// Base postpartum calorie recommendation used for estimated data
    /// when no user goal is set
    static let basePostpartumCalories = 2100

    /// Additional calories for exclusive breastfeeding
    static let exclusiveBreastfeedingCalories = 500

    /// Additional calories for mixed feeding
    static let mixedFeedingCalories = 300

    /// Chart animation duration in seconds
    static let chartAnimationDuration = 0.8

    /// Number of days to display in the chart
    static let chartDayCount = 30

    /// Calculate default estimated calories for a day with no entries
    /// Uses the user's daily goal if available, otherwise base recommendation + breastfeeding adjustment
    static func defaultEstimatedCalories(
        userGoal: Int?,
        isBreastfeeding: Bool,
        breastfeedingAdjustment: Int = 0
    ) -> Int {
        if let goal = userGoal, goal > 0 {
            return goal
        }
        // Use base postpartum recommendation + breastfeeding adjustment
        return basePostpartumCalories + (isBreastfeeding ? breastfeedingAdjustment : 0)
    }
}

// MARK: - Sample Data for Previews

extension CalorieChartData {
    static var sampleData: CalorieChartData {
        let calendar = Calendar.current
        let today = Date()
        let calorieGoal = 1900
        let breastfeedingAdj = 400

        var dailyData: [DailyCalorieData] = []

        for dayOffset in (0..<30).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }

            // Generate realistic sample data - some days have entries, some don't
            let hasEntries = dayOffset == 0 || Bool.random() // Today always has entries for demo
            let entriesCount = hasEntries ? Int.random(in: 1...5) : 0

            if hasEntries {
                // Actual logged data
                let actualCalories = Int.random(in: 1400...2200)
                dailyData.append(DailyCalorieData(
                    date: date,
                    totalCalories: actualCalories,
                    calorieGoal: calorieGoal,
                    breastfeedingAdjustment: breastfeedingAdj,
                    entriesCount: entriesCount,
                    isEstimated: false,
                    actualCalories: actualCalories
                ))
            } else {
                // Estimated data - use the calorie goal as the estimate
                dailyData.append(DailyCalorieData(
                    date: date,
                    totalCalories: calorieGoal, // Shows goal as estimated value
                    calorieGoal: calorieGoal,
                    breastfeedingAdjustment: breastfeedingAdj,
                    entriesCount: 0,
                    isEstimated: true,
                    actualCalories: 0
                ))
            }
        }

        return CalorieChartData(
            dailyData: dailyData,
            baseCalorieGoal: 1500,
            isBreastfeeding: true,
            breastfeedingAdjustment: breastfeedingAdj
        )
    }

    /// Sample data with estimated days for preview
    static var sampleDataWithEstimates: CalorieChartData {
        let calendar = Calendar.current
        let today = Date()
        let calorieGoal = 1900

        var dailyData: [DailyCalorieData] = []

        for dayOffset in (0..<30).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }

            // Alternate between actual and estimated for clear preview
            let isEstimated = dayOffset % 3 == 0 && dayOffset != 0

            if isEstimated {
                dailyData.append(DailyCalorieData(
                    date: date,
                    totalCalories: calorieGoal,
                    calorieGoal: calorieGoal,
                    breastfeedingAdjustment: 400,
                    entriesCount: 0,
                    isEstimated: true,
                    actualCalories: 0
                ))
            } else {
                let actualCalories = Int.random(in: 1500...2100)
                dailyData.append(DailyCalorieData(
                    date: date,
                    totalCalories: actualCalories,
                    calorieGoal: calorieGoal,
                    breastfeedingAdjustment: 400,
                    entriesCount: Int.random(in: 2...5),
                    isEstimated: false,
                    actualCalories: actualCalories
                ))
            }
        }

        return CalorieChartData(
            dailyData: dailyData,
            baseCalorieGoal: 1500,
            isBreastfeeding: true,
            breastfeedingAdjustment: 400
        )
    }

    static var emptyData: CalorieChartData {
        CalorieChartData(
            dailyData: [],
            baseCalorieGoal: 1800,
            isBreastfeeding: false
        )
    }
}

extension DailyCalorieData {
    /// Sample data for today with actual logged entries
    static var sampleToday: DailyCalorieData {
        DailyCalorieData(
            date: Date(),
            totalCalories: 1650,
            calorieGoal: 1900,
            breastfeedingAdjustment: 400,
            entriesCount: 3,
            isEstimated: false,
            actualCalories: 1650
        )
    }

    /// Sample data for an estimated day (no entries logged)
    static var sampleEstimated: DailyCalorieData {
        DailyCalorieData(
            date: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
            totalCalories: 1900, // Uses goal as estimate
            calorieGoal: 1900,
            breastfeedingAdjustment: 400,
            entriesCount: 0,
            isEstimated: true,
            actualCalories: 0
        )
    }
}
