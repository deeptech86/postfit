//
//  NutritionService.swift
//  PostFit (MomCare)
//
//  Service for fetching nutrition and food tracking data from the backend
//  Handles data aggregation for calorie charts and analytics
//

import Foundation

// MARK: - Nutrition Service Protocol

/// Protocol for nutrition-related API operations
protocol NutritionServiceProtocol {
    /// Fetch food entries for a specific date
    func fetchFoodEntries(for date: Date) async throws -> [FoodEntry]

    /// Fetch food entries for a date range
    func fetchFoodEntries(from startDate: Date, to endDate: Date) async throws -> [FoodEntry]

    /// Fetch aggregated daily calorie data for the chart
    func fetchCalorieChartData(days: Int) async throws -> CalorieChartData

    /// Add a new food entry
    func addFoodEntry(_ entry: FoodEntry) async throws -> FoodEntry
}

// MARK: - Nutrition Service Implementation

/// Service for managing nutrition data and API calls
class NutritionService: NutritionServiceProtocol {

    // MARK: - Properties

    private let apiClient: APIClientProtocol
    private let userDefaultsManager: UserDefaultsManager

    // MARK: - Initialization

    init(
        apiClient: APIClientProtocol = APIClient(),
        userDefaultsManager: UserDefaultsManager = UserDefaultsManager()
    ) {
        self.apiClient = apiClient
        self.userDefaultsManager = userDefaultsManager
    }

    // MARK: - Public Methods

    /// Fetch food entries for a specific date
    func fetchFoodEntries(for date: Date) async throws -> [FoodEntry] {
        do {
            let response: FoodEntriesResponse = try await apiClient.request(
                .getFoodEntries(date),
                body: nil,
                headers: authHeaders()
            )
            return response.entries
        } catch {
            // If unauthorized or network error, return empty array
            // This allows the chart to show estimated values
            #if DEBUG
            print("[NutritionService] Failed to fetch entries: \(error.localizedDescription)")
            print("[NutritionService] Returning empty array for date: \(date)")
            #endif
            return []
        }
    }

    /// Fetch food entries for a date range
    func fetchFoodEntries(from startDate: Date, to endDate: Date) async throws -> [FoodEntry] {
        do {
            // Create a custom endpoint for date range queries
            let entries = try await fetchFoodEntriesInRange(startDate: startDate, endDate: endDate)
            return entries
        } catch {
            // If unauthorized or network error, return empty array
            // This allows the chart to show estimated values for all days
            #if DEBUG
            print("[NutritionService] Failed to fetch entries for range: \(error.localizedDescription)")
            print("[NutritionService] Returning empty array")
            #endif
            return []
        }
    }

    /// Fetch aggregated daily calorie data for the chart
    func fetchCalorieChartData(days: Int = NutritionConstants.chartDayCount) async throws -> CalorieChartData {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: today) else {
            throw NutritionError.invalidDateRange
        }

        // Fetch all entries for the date range
        let entries = try await fetchFoodEntries(from: startDate, to: today)

        // Get user profile for calorie goal and breastfeeding status
        let userProfile = getUserProfile()

        // Aggregate entries by day
        let dailyData = aggregateEntriesByDay(
            entries: entries,
            startDate: startDate,
            endDate: today,
            calorieGoal: userProfile.dailyCalorieTarget,
            breastfeedingAdjustment: userProfile.breastfeedingAdjustment
        )

        return CalorieChartData(
            dailyData: dailyData,
            baseCalorieGoal: userProfile.baseCalorieGoal,
            isBreastfeeding: userProfile.isBreastfeeding,
            breastfeedingAdjustment: userProfile.breastfeedingAdjustment
        )
    }

    /// Add a new food entry
    func addFoodEntry(_ entry: FoodEntry) async throws -> FoodEntry {
        let response: FoodEntryResponse = try await apiClient.request(
            .addFoodEntry,
            body: entry,
            headers: authHeaders()
        )
        return response.entry
    }

    // MARK: - Private Methods

    /// Fetch food entries for a date range using the API
    private func fetchFoodEntriesInRange(startDate: Date, endDate: Date) async throws -> [FoodEntry] {
        // Use the date range endpoint for efficient batch fetching
        let response: FoodEntriesResponse = try await apiClient.request(
            .getFoodEntriesRange(startDate: startDate, endDate: endDate),
            body: nil,
            headers: authHeaders()
        )
        return response.entries
    }

    /// Aggregate food entries by day
    private func aggregateEntriesByDay(
        entries: [FoodEntry],
        startDate: Date,
        endDate: Date,
        calorieGoal: Int,
        breastfeedingAdjustment: Int
    ) -> [DailyCalorieData] {
        let calendar = Calendar.current
        var dailyData: [DailyCalorieData] = []

        // Group entries by day
        let groupedEntries = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.timestamp)
        }

        // Create data points for each day in the range
        var currentDate = startDate
        while currentDate <= endDate {
            let dayStart = calendar.startOfDay(for: currentDate)
            let dayEntries = groupedEntries[dayStart] ?? []

            let hasEntries = !dayEntries.isEmpty
            let actualCalories = dayEntries.reduce(0) { $0 + $1.calories }

            // If no entries for this day, use the calorie goal as an estimated value
            let displayCalories: Int
            let isEstimated: Bool

            if hasEntries {
                displayCalories = actualCalories
                isEstimated = false
            } else {
                // Use calorie goal as default/estimated value for days with no data
                displayCalories = calorieGoal
                isEstimated = true
            }

            dailyData.append(DailyCalorieData(
                date: currentDate,
                totalCalories: displayCalories,
                calorieGoal: calorieGoal,
                breastfeedingAdjustment: breastfeedingAdjustment,
                entriesCount: dayEntries.count,
                isEstimated: isEstimated,
                actualCalories: actualCalories
            ))

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return dailyData
    }

    /// Get user profile from storage
    private func getUserProfile() -> UserNutritionProfile {
        // Read from UserProfileManager for actual user data
        guard let user = UserProfileManager.shared.currentUser else {
            // Default values if no user is logged in
            return UserNutritionProfile(
                baseCalorieGoal: 1800,
                isBreastfeeding: false,
                breastfeedingAdjustment: 0
            )
        }

        let healthProfile = user.healthProfile
        let isBreastfeeding = healthProfile.isBreastfeeding
        let breastfeedingAdjustment = isBreastfeeding
            ? (healthProfile.breastfeedingIntensity?.additionalCalories ?? 400)
            : 0

        // Calculate base calorie goal (total target minus breastfeeding adjustment)
        let totalTarget = healthProfile.dailyCalorieTarget
        let baseCalorieGoal = totalTarget - breastfeedingAdjustment

        return UserNutritionProfile(
            baseCalorieGoal: baseCalorieGoal,
            isBreastfeeding: isBreastfeeding,
            breastfeedingAdjustment: breastfeedingAdjustment
        )
    }

    /// Get authentication headers
    private func authHeaders() -> [String: String]? {
        // Retrieve auth token from UserDefaults
        // In production, this should use KeychainManager to retrieve the session token
        // For testing, you can manually set: UserDefaults.standard.set("your_token", forKey: "authToken")

        if let token = UserDefaults.standard.string(forKey: "authToken") {
            return [
                "Authorization": "Bearer \(token)"
            ]
        }

        // TODO: Implement proper token management with KeychainManager
        // This requires refactoring to async/await pattern
        return nil
    }
}

// MARK: - Mock Nutrition Service for Previews

/// Mock service for SwiftUI previews and testing
class MockNutritionService: NutritionServiceProtocol {

    var shouldFail = false
    var mockDelay: TimeInterval = 0.5

    func fetchFoodEntries(for date: Date) async throws -> [FoodEntry] {
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))

        if shouldFail {
            throw NutritionError.networkError
        }

        return generateMockEntries(for: date)
    }

    func fetchFoodEntries(from startDate: Date, to endDate: Date) async throws -> [FoodEntry] {
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))

        if shouldFail {
            throw NutritionError.networkError
        }

        var entries: [FoodEntry] = []
        let calendar = Calendar.current
        var currentDate = startDate

        while currentDate <= endDate {
            entries.append(contentsOf: generateMockEntries(for: currentDate))
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return entries
    }

    func fetchCalorieChartData(days: Int) async throws -> CalorieChartData {
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))

        if shouldFail {
            throw NutritionError.networkError
        }

        return CalorieChartData.sampleData
    }

    func addFoodEntry(_ entry: FoodEntry) async throws -> FoodEntry {
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))

        if shouldFail {
            throw NutritionError.networkError
        }

        return entry
    }

    private func generateMockEntries(for date: Date) -> [FoodEntry] {
        let entriesCount = Int.random(in: 0...4)

        guard entriesCount > 0 else { return [] }

        let mealTypes: [MealType] = [.breakfast, .lunch, .dinner, .snack]
        let foodNames = [
            "Oatmeal with Berries",
            "Grilled Chicken Salad",
            "Salmon with Vegetables",
            "Greek Yogurt",
            "Whole Grain Toast",
            "Quinoa Bowl",
            "Fruit Smoothie"
        ]

        return (0..<entriesCount).map { index in
            FoodEntry(
                name: foodNames.randomElement() ?? "Food Item",
                mealType: mealTypes[min(index, mealTypes.count - 1)],
                calories: Int.random(in: 200...600),
                protein: Double.random(in: 10...30),
                carbohydrates: Double.random(in: 20...60),
                fat: Double.random(in: 5...25),
                iron: Double.random(in: 1...5),
                calcium: Double.random(in: 50...200),
                timestamp: date
            )
        }
    }
}

// MARK: - Response Models

/// Response wrapper for fetching multiple food entries
struct FoodEntriesResponse: Codable {
    let entries: [FoodEntry]
}

/// Response wrapper for a single food entry
struct FoodEntryResponse: Codable {
    let entry: FoodEntry
}

/// User nutrition profile for calorie calculations
struct UserNutritionProfile {
    let baseCalorieGoal: Int
    let isBreastfeeding: Bool
    let breastfeedingAdjustment: Int

    var dailyCalorieTarget: Int {
        baseCalorieGoal + breastfeedingAdjustment
    }
}

// MARK: - Nutrition Errors

/// Errors that can occur in the nutrition service
enum NutritionError: LocalizedError {
    case invalidDateRange
    case networkError
    case decodingError
    case noData
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidDateRange:
            return "Invalid date range specified"
        case .networkError:
            return "Unable to connect to the server. Please check your internet connection."
        case .decodingError:
            return "Unable to process the response from the server"
        case .noData:
            return "No nutrition data available for the selected period"
        case .unauthorized:
            return "Please sign in to view your nutrition data"
        }
    }
}
