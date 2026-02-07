//
//  FoodTrackingView.swift
//  PostFit (MomCare)
//
//  Food tracking with AI recognition and manual entry
//  Optimized for postpartum nutrition needs
//

import SwiftUI

// MARK: - Food Tracking View
struct FoodTrackingView: View {
    @State private var selectedDate = Date()
    @State private var showCamera = false
    @State private var showManualEntry = false
    @State private var showBarcodeScanner = false
    @State private var selectedMealType: MealType = .breakfast
    @State private var showCalorieChart = false
    @State private var showSyncStatus = false

    // Shared nutrition data manager
    @StateObject private var nutritionDataManager = NutritionDataManager.shared

    // iCloud sync managers
    @StateObject private var cloudKit = CloudKitManager.shared
    private let retentionManager = DataRetentionManager.shared

    private let calorieGoal = 1900 // Adjusted for breastfeeding


    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Date selector
                    DateSelectorRow(selectedDate: $selectedDate)

                    // 30-Day Calorie Chart Section (moved to top)
                    CalorieChartSection(showFullChart: $showCalorieChart)

                    // Nutrition summary card (today's calories)
                    NutritionSummaryCard(
                        nutrition: nutritionDataManager.dailyNutrition,
                        calorieGoal: calorieGoal
                    )

                    // Macro breakdown
                    MacroBreakdownCard(nutrition: nutritionDataManager.dailyNutrition)

                    // Add food buttons (without barcode)
                    AddFoodSection(
                        onCameraTap: { showCamera = true },
                        onManualTap: { showManualEntry = true }
                    )

                    // Meal sections
                    ForEach(MealType.allCases, id: \.self) { mealType in
                        MealSection(
                            mealType: mealType,
                            entries: nutritionDataManager.dailyNutrition.entries.filter { $0.mealType == mealType }
                        ) {
                            selectedMealType = mealType
                            showManualEntry = true
                        }
                    }

                    // Nutrition tips
                    NutritionTipsCard()

                    Spacer()
                        .frame(height: 100)
                }
                .padding(.horizontal, 20)
            }
            .background(Color.momCareBackground)
            .navigationTitle("Nutrition")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSyncStatus = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: cloudKit.syncStatus.icon)
                                .font(.system(size: 14))
                            if cloudKit.isSyncing {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }
                        .foregroundColor(syncIconColor)
                    }
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            FoodCameraView(dailyNutrition: $nutritionDataManager.dailyNutrition, onEntrySaved: { entry in
                Task {
                    await retentionManager.syncNewEntry(entry)
                }
            })
        }
        .sheet(isPresented: $showManualEntry) {
            ManualFoodEntryView(mealType: selectedMealType) { entry in
                nutritionDataManager.addEntry(entry)
                Task {
                    await retentionManager.syncNewEntry(entry)
                }
            }
        }
        .sheet(isPresented: $showBarcodeScanner) {
            BarcodeScannerView()
        }
        .sheet(isPresented: $showCalorieChart) {
            CalorieChartFullScreenView()
        }
        .sheet(isPresented: $showSyncStatus) {
            SyncStatusView()
        }
        .task {
            // Run cleanup on app launch
            await performDataMaintenance()
        }
    }

    private var syncIconColor: Color {
        switch cloudKit.syncStatus {
        case .idle:
            return .momCareTextSecondary
        case .syncing:
            return .momCarePrimary
        case .success:
            return .momCareSuccess
        case .error:
            return .momCareWarning
        }
    }

    private func performDataMaintenance() async {
        // Check and run cleanup if needed
        if retentionManager.shouldRunCleanup() {
            var nutritions = [nutritionDataManager.dailyNutrition]
            retentionManager.cleanupLocalData(from: &nutritions)
            if !nutritions.isEmpty {
                nutritionDataManager.dailyNutrition = nutritions[0]
            }
        }

        // Cloud cleanup (runs weekly)
        if retentionManager.shouldRunCloudCleanup() {
            await retentionManager.cleanupCloudData()
        }
    }
}

// MARK: - Calorie Chart Section
/// Compact section showing 30-day calorie trend with option to expand
struct CalorieChartSection: View {
    @Binding var showFullChart: Bool
    @StateObject private var viewModel = CalorieChartViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("30-Day Calorie Trend")
                        .font(.momCareHeading3)
                        .foregroundColor(.momCareTextPrimary)

                    if let summary = viewModel.summary {
                        Text("Avg: \(summary.averageCalories) cal/day")
                            .font(.momCareCaption)
                            .foregroundColor(.momCareTextSecondary)
                    }
                }

                Spacer()

                Button {
                    showFullChart = true
                } label: {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.momCareCaptionBold)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.momCarePrimary)
                }
            }
            .padding(.bottom, 12)

            // Compact chart preview
            CalorieIntakeChartView()
        }
        .task {
            await viewModel.loadChartData()
        }
    }
}

// MARK: - Full Screen Chart View
/// Full screen view for detailed calorie chart analysis
struct CalorieChartFullScreenView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CalorieChartViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Main chart
                    CalorieIntakeChartView()

                    // Additional insights
                    if let summary = viewModel.summary {
                        InsightsSection(summary: summary)
                    }

                    // Tips section
                    NutritionChartTipsCard()

                    Spacer()
                        .frame(height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color.momCareBackground)
            .navigationTitle("Calorie Trends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.momCarePrimary)
                }
            }
        }
        .task {
            await viewModel.loadChartData()
        }
    }
}

// MARK: - Insights Section
struct InsightsSection: View {
    let summary: ChartSummary

    var body: some View {
        MomCareCard(padding: 16, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.momCareAccent)

                    Text("Nutrition Insights")
                        .font(.momCareHeading3)
                        .foregroundColor(.momCareTextPrimary)
                }

                // Stats grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    InsightCard(
                        title: "Average Intake",
                        value: "\(summary.averageCalories)",
                        unit: "cal/day",
                        icon: "chart.bar.fill",
                        color: summary.meetsMinimum ? .momCareSuccess : .momCareWarning
                    )

                    InsightCard(
                        title: "Goal Achievement",
                        value: summary.goalAchievementText,
                        unit: "success rate",
                        icon: "target",
                        color: summary.goalAchievementRate >= 0.7 ? .momCareSuccess : .momCareAccent
                    )

                    InsightCard(
                        title: "Days Logged",
                        value: "\(summary.daysWithData)",
                        unit: "of \(summary.totalDays) days",
                        icon: "calendar",
                        color: .momCareNutrition
                    )

                    InsightCard(
                        title: "Goals Met",
                        value: "\(summary.daysMetGoal)",
                        unit: "days",
                        icon: "checkmark.circle.fill",
                        color: .momCareSuccess
                    )
                }

                // Personalized tip
                HStack(spacing: 12) {
                    Image(systemName: summary.meetsMinimum ? "hand.thumbsup.fill" : "info.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(summary.meetsMinimum ? .momCareSuccess : .momCareInfo)

                    Text(summary.encouragementMessage)
                        .font(.momCareBody)
                        .foregroundColor(.momCareTextSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(summary.meetsMinimum ? Color.momCareSuccess.opacity(0.1) : Color.momCareInfo.opacity(0.1))
                )
            }
        }
    }
}

// MARK: - Insight Card
struct InsightCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)

                Text(title)
                    .font(.momCareCaption)
                    .foregroundColor(.momCareTextTertiary)
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.momCareNumberSmall)
                    .foregroundColor(.momCareTextPrimary)

                Text(unit)
                    .font(.system(size: 10))
                    .foregroundColor(.momCareTextTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.momCareSecondaryBackground)
        )
    }
}

// MARK: - Nutrition Chart Tips Card
struct NutritionChartTipsCard: View {
    var body: some View {
        MomCareCard(padding: 16, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "heart.text.square.fill")
                        .foregroundColor(.momCarePrimary)

                    Text("Postpartum Nutrition Tips")
                        .font(.momCareHeading3)
                        .foregroundColor(.momCareTextPrimary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    NutritionTipRow(
                        icon: "drop.fill",
                        text: "If breastfeeding, aim for 300-500 extra calories daily",
                        color: .momCareHydration
                    )

                    NutritionTipRow(
                        icon: "leaf.fill",
                        text: "Never go below 1,800 calories for healthy milk production",
                        color: .momCareNutrition
                    )

                    NutritionTipRow(
                        icon: "clock.fill",
                        text: "Eat regular meals even when sleep-deprived",
                        color: .momCareAccent
                    )

                    NutritionTipRow(
                        icon: "fish.fill",
                        text: "Focus on iron and calcium-rich foods for recovery",
                        color: .momCareExercise
                    )
                }
            }
        }
    }
}

struct NutritionTipRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 20)

            Text(text)
                .font(.momCareBody)
                .foregroundColor(.momCareTextSecondary)
        }
    }
}

// MARK: - Date Selector
struct DateSelectorRow: View {
    @Binding var selectedDate: Date

    // Static DateFormatter to avoid recreating on every access (performance optimization)
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    private var dateString: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(selectedDate) {
            return "Yesterday"
        }
        return Self.dateFormatter.string(from: selectedDate)
    }

    var body: some View {
        HStack {
            Button(action: {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.momCareTextSecondary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.momCareCardBackground))
            }

            Spacer()

            Text(dateString)
                .font(.momCareHeading3)
                .foregroundColor(.momCareTextPrimary)

            Spacer()

            Button(action: {
                if !Calendar.current.isDateInToday(selectedDate) {
                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Calendar.current.isDateInToday(selectedDate) ? .momCareTextTertiary : .momCareTextSecondary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.momCareCardBackground))
            }
            .disabled(Calendar.current.isDateInToday(selectedDate))
        }
    }
}

// MARK: - Nutrition Summary Card
struct NutritionSummaryCard: View {
    let nutrition: DailyNutrition
    let calorieGoal: Int

    private var progress: Double {
        guard calorieGoal > 0 else { return 0 }
        return min(Double(nutrition.totalCalories) / Double(calorieGoal), 1.0)
    }

    private var remaining: Int {
        calorieGoal - nutrition.totalCalories
    }

    var body: some View {
        MomCareCard(padding: 20) {
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Calories")
                            .font(.momCareCaptionBold)
                            .foregroundColor(.momCareTextSecondary)

                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("\(nutrition.totalCalories)")
                                .font(.momCareNumberMedium)
                                .foregroundColor(.momCareTextPrimary)

                            Text("/ \(calorieGoal)")
                                .font(.momCareBody)
                                .foregroundColor(.momCareTextTertiary)
                        }
                    }

                    Spacer()

                    // Progress ring
                    MomCareProgressRing(
                        progress: progress,
                        color: .momCareNutrition,
                        lineWidth: 8,
                        size: 80
                    )
                }

                // Remaining calories
                HStack {
                    if remaining > 0 {
                        Text("\(remaining) calories remaining")
                            .font(.momCareBody)
                            .foregroundColor(.momCareTextSecondary)
                    } else {
                        Text("Goal reached!")
                            .font(.momCareBody)
                            .foregroundColor(.momCareSuccess)
                    }

                    Spacer()
                }
            }
        }
    }
}

// MARK: - Macro Breakdown Card
struct MacroBreakdownCard: View {
    let nutrition: DailyNutrition

    // Recommended macros for postpartum (adjusted for breastfeeding)
    private let proteinGoal: Double = 75 // grams
    private let carbsGoal: Double = 250 // grams
    private let fatGoal: Double = 65 // grams

    var body: some View {
        MomCareCard {
            VStack(spacing: 16) {
                Text("Macronutrients")
                    .font(.momCareHeading3)
                    .foregroundColor(.momCareTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 16) {
                    MacroItem(
                        name: "Protein",
                        value: nutrition.totalProtein,
                        goal: proteinGoal,
                        color: .momCareExercise
                    )

                    MacroItem(
                        name: "Carbs",
                        value: nutrition.totalCarbs,
                        goal: carbsGoal,
                        color: .momCareAccent
                    )

                    MacroItem(
                        name: "Fat",
                        value: nutrition.totalFat,
                        goal: fatGoal,
                        color: .momCareWarning
                    )
                }

                // Iron and Calcium (important for postpartum)
                Divider()

                HStack(spacing: 24) {
                    MicroItem(
                        name: "Iron",
                        value: nutrition.totalIron,
                        goal: 18,
                        unit: "mg",
                        icon: "drop.fill",
                        color: .momCarePrimary
                    )

                    MicroItem(
                        name: "Calcium",
                        value: nutrition.totalCalcium,
                        goal: 1000,
                        unit: "mg",
                        icon: "figure.stand",
                        color: .momCareInfo
                    )
                }
            }
        }
    }
}

struct MacroItem: View {
    let name: String
    let value: Double
    let goal: Double
    let color: Color

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(value / goal, 1.0)
    }

    var body: some View {
        VStack(spacing: 8) {
            MomCareProgressRing(
                progress: progress,
                color: color,
                lineWidth: 6,
                size: 50,
                showPercentage: false
            )
            .overlay(
                Text("\(Int(value))g")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.momCareTextPrimary)
            )

            Text(name)
                .font(.momCareCaption)
                .foregroundColor(.momCareTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MicroItem: View {
    let name: String
    let value: Double
    let goal: Double
    let unit: String
    let icon: String
    let color: Color

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(value / goal, 1.0)
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.momCareCaptionBold)
                    .foregroundColor(.momCareTextSecondary)

                MomCareProgressBar(progress: progress, color: color, height: 4)
                    .frame(width: 80)

                Text("\(Int(value)) / \(Int(goal)) \(unit)")
                    .font(.system(size: 10))
                    .foregroundColor(.momCareTextTertiary)
            }
        }
    }
}

// MARK: - Add Food Section
struct AddFoodSection: View {
    let onCameraTap: () -> Void
    let onManualTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Food")
                .font(.momCareHeading3)
                .foregroundColor(.momCareTextPrimary)

            HStack(spacing: 12) {
                AddFoodButton(
                    title: "Camera",
                    subtitle: "AI recognition",
                    icon: "camera.fill",
                    color: .momCareNutrition,
                    isPremium: true,
                    action: onCameraTap
                )

                AddFoodButton(
                    title: "Manual",
                    subtitle: "Enter details",
                    icon: "pencil",
                    color: .momCareSecondary,
                    isPremium: false,
                    action: onManualTap
                )
            }
        }
    }
}

struct AddFoodButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isPremium: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.15))
                            .frame(width: 48, height: 48)

                        Image(systemName: icon)
                            .font(.system(size: 20))
                            .foregroundColor(color)
                    }

                    if isPremium {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.momCareAccent)
                            .offset(x: 4, y: -4)
                    }
                }

                VStack(spacing: 2) {
                    Text(title)
                        .font(.momCareCaptionBold)
                        .foregroundColor(.momCareTextPrimary)

                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(.momCareTextTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.momCareCardBackground)
                    .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Meal Section
struct MealSection: View {
    let mealType: MealType
    let entries: [FoodEntry]
    let onAddTap: () -> Void

    private var totalCalories: Int {
        entries.reduce(0) { $0 + $1.calories }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: mealType.icon)
                        .font(.system(size: 16))
                        .foregroundColor(.momCareTextSecondary)

                    Text(mealType.rawValue)
                        .font(.momCareHeading3)
                        .foregroundColor(.momCareTextPrimary)
                }

                Spacer()

                if !entries.isEmpty {
                    Text("\(totalCalories) kcal")
                        .font(.momCareCaptionBold)
                        .foregroundColor(.momCareTextSecondary)
                }

                Button(action: onAddTap) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.momCarePrimary)
                }
            }

            // Entries
            if entries.isEmpty {
                EmptyMealCard(mealType: mealType, onAddTap: onAddTap)
            } else {
                VStack(spacing: 8) {
                    ForEach(entries) { entry in
                        FoodEntryRow(entry: entry)
                    }
                }
            }
        }
    }
}

struct EmptyMealCard: View {
    let mealType: MealType
    let onAddTap: () -> Void

    var body: some View {
        Button(action: onAddTap) {
            HStack {
                Text("Add \(mealType.rawValue.lowercased())")
                    .font(.momCareBody)
                    .foregroundColor(.momCareTextTertiary)

                Spacer()

                Image(systemName: "plus")
                    .font(.system(size: 16))
                    .foregroundColor(.momCareTextTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [8]))
                    .foregroundColor(.momCareTextTertiary.opacity(0.3))
            )
        }
    }
}

struct FoodEntryRow: View {
    let entry: FoodEntry

    var body: some View {
        HStack(spacing: 12) {
            // Food image or icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.momCareNutrition.opacity(0.1))
                    .frame(width: 48, height: 48)

                if entry.isAIRecognized {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18))
                        .foregroundColor(.momCareNutrition)
                } else {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 18))
                        .foregroundColor(.momCareNutrition)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.momCareBody)
                    .foregroundColor(.momCareTextPrimary)

                Text("\(entry.servingSize)")
                    .font(.momCareCaption)
                    .foregroundColor(.momCareTextTertiary)
            }

            Spacer()

            Text("\(entry.calories) kcal")
                .font(.momCareCaptionBold)
                .foregroundColor(.momCareTextSecondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.momCareCardBackground)
        )
    }
}

// MARK: - Nutrition Tips Card
struct NutritionTipsCard: View {
    var body: some View {
        MomCareCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.momCareAccent)

                    Text("Nutrition Tip")
                        .font(.momCareBodyBold)
                        .foregroundColor(.momCareTextPrimary)
                }

                Text("Iron-rich foods like spinach, lentils, and lean red meat help prevent postpartum anemia. Pair them with vitamin C for better absorption!")
                    .font(.momCareBody)
                    .foregroundColor(.momCareTextSecondary)
                    .lineSpacing(4)
            }
        }
    }
}

// MARK: - Camera View
struct FoodCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var dailyNutrition: DailyNutrition
    var onEntrySaved: ((FoodEntry) -> Void)? = nil

    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var isAnalyzing = false
    @State private var recognitionResult: FoodRecognitionResult?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showManualEntry = false
    @State private var selectedMealType: MealType = .breakfast
    @State private var showUsageLimitAlert = false
    @State private var showUsageWarning = false

    @StateObject private var aiUsageManager = AIUsageManager.shared
    private let recognitionService = FoodRecognitionService()

    var body: some View {
        NavigationView {
            ZStack {
                Color.momCareBackground
                    .ignoresSafeArea()

                if let image = capturedImage {
                    // Show captured image and results
                    resultView(image: image)
                } else {
                    // Show camera instructions
                    cameraInstructionsView
                }

                // Loading overlay
                if isAnalyzing {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)

                            Text("Analyzing food...")
                                .font(.momCareBody)
                                .foregroundColor(.white)
                        }
                        .padding(32)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.momCareTextPrimary.opacity(0.9))
                        )
                    }
                }
            }
            .navigationTitle("Scan Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.momCareTextSecondary)
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker(isPresented: $showCamera) { image in
                    capturedImage = image
                    analyzeImage(image)
                }
            }
            .alert("Recognition Error", isPresented: $showError) {
                Button("Retry") {
                    if let image = capturedImage {
                        analyzeImage(image)
                    }
                }
                Button("Manual Entry") {
                    showManualEntry = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showManualEntry) {
                ManualFoodEntryView(
                    mealType: selectedMealType,
                    prefillData: recognitionResult
                ) { entry in
                    // Add the edited entry to daily nutrition
                    dailyNutrition.addEntry(entry)

                    #if DEBUG
                    print("✅ [Food Camera] Added edited entry: \(entry.name) to \(entry.mealType.rawValue)")
                    print("📊 [Food Camera] Total calories today: \(dailyNutrition.totalCalories)")
                    #endif

                    // Call sync callback
                    onEntrySaved?(entry)

                    // Dismiss camera view after saving
                    dismiss()
                }
            }
        }
    }

    private var cameraInstructionsView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.momCarePrimary.opacity(0.1))
                    .frame(height: 400)

                VStack(spacing: 16) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 60))
                        .foregroundColor(.momCarePrimary)

                    Text("Point camera at food")
                        .font(.momCareHeading3)
                        .foregroundColor(.momCareTextPrimary)

                    Text("AI will recognize the food and estimate calories")
                        .font(.momCareBody)
                        .foregroundColor(.momCareTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    // AI Usage status indicator
                    if !aiUsageManager.isPremiumUser {
                        HStack(spacing: 6) {
                            Image(systemName: aiUsageManager.shouldShowWarning ? "exclamationmark.triangle.fill" : "sparkles")
                                .font(.system(size: 12))
                                .foregroundColor(aiUsageManager.shouldShowWarning ? .momCareWarning : .momCareAccent)

                            Text(aiUsageManager.getUsageStatus().message)
                                .font(.momCareCaption)
                                .foregroundColor(aiUsageManager.shouldShowWarning ? .momCareWarning : .momCareTextTertiary)
                        }
                        .padding(.top, 8)
                    }
                }
            }

            Spacer()

            // Show upgrade button if limit reached, otherwise show take photo
            if aiUsageManager.hasReachedLimit {
                VStack(spacing: 12) {
                    Text("Free AI scans limit reached")
                        .font(.momCareBody)
                        .foregroundColor(.momCareWarning)

                    MomCarePrimaryButton("Upgrade to Premium", icon: "star.fill") {
                        showUsageLimitAlert = true
                    }

                    Button("Manual Entry Instead") {
                        showManualEntry = true
                    }
                    .font(.momCareButtonSecondary)
                    .foregroundColor(.momCarePrimary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            } else {
                MomCarePrimaryButton("Take Photo", icon: "camera.fill") {
                    // Check if warning threshold reached (8 uses)
                    if aiUsageManager.shouldShowWarning {
                        showUsageWarning = true
                    } else {
                        showCamera = true
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .padding()
        .alert("Usage Limit Reached", isPresented: $showUsageLimitAlert) {
            Button("Manual Entry") {
                showManualEntry = true
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("You've used all 10 free AI food scans. Upgrade to Premium for unlimited AI-powered food recognition, or use manual entry.")
        }
        .alert("Running Low on Free Scans", isPresented: $showUsageWarning) {
            Button("Continue Anyway") {
                showCamera = true
            }
            Button("Use Manual Entry") {
                showManualEntry = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have \(aiUsageManager.remainingUses) free AI scans remaining. Consider upgrading to Premium for unlimited scans.")
        }
    }

    private func resultView(image: UIImage) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Captured image
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)

                if let result = recognitionResult {
                    if result.isFoodItem {
                        // Food recognized
                        VStack(spacing: 20) {
                            // Success header
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.momCareSuccess)

                                Text("Food Recognized!")
                                    .font(.momCareHeading2)
                                    .foregroundColor(.momCareTextPrimary)
                            }

                            // Food details card
                            MomCareCard {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text(result.foodName)
                                        .font(.momCareHeading3)
                                        .foregroundColor(.momCareTextPrimary)

                                    Divider()

                                    // Nutrition info
                                    VStack(spacing: 12) {
                                        NutritionInfoRow(label: "Calories", value: "\(result.calories) kcal", icon: "flame.fill")
                                        NutritionInfoRow(label: "Protein", value: "\(Int(result.protein))g", icon: "fish.fill")
                                        NutritionInfoRow(label: "Carbs", value: "\(Int(result.carbohydrates))g", icon: "leaf.fill")
                                        NutritionInfoRow(label: "Fat", value: "\(Int(result.fat))g", icon: "drop.fill")
                                    }

                                    Divider()

                                    HStack {
                                        Text("Serving:")
                                            .font(.momCareCaptionBold)
                                            .foregroundColor(.momCareTextSecondary)

                                        Spacer()

                                        Text(result.servingSize)
                                            .font(.momCareBody)
                                            .foregroundColor(.momCareTextPrimary)
                                    }

                                    // Confidence indicator
                                    HStack(spacing: 6) {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 12))
                                            .foregroundColor(.momCareAccent)

                                        Text("AI Confidence: \(Int(result.confidence * 100))%")
                                            .font(.momCareCaption)
                                            .foregroundColor(.momCareTextTertiary)
                                    }
                                }
                            }

                            // Meal type selection
                            MomCareCard {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Add to Meal")
                                        .font(.momCareHeading3)
                                        .foregroundColor(.momCareTextPrimary)

                                    VStack(spacing: 12) {
                                        ForEach(MealType.allCases, id: \.self) { mealType in
                                            MealTypeOption(
                                                mealType: mealType,
                                                isSelected: selectedMealType == mealType,
                                                action: { selectedMealType = mealType }
                                            )
                                        }
                                    }
                                }
                            }

                            // Action buttons
                            VStack(spacing: 12) {
                                MomCarePrimaryButton("Add to \(selectedMealType.rawValue)", icon: "plus.circle.fill") {
                                    addFoodEntry(result: result)
                                }

                                Button("Edit Details") {
                                    showManualEntry = true
                                }
                                .font(.momCareButtonSecondary)
                                .foregroundColor(.momCarePrimary)
                                .padding()
                            }
                        }
                    } else {
                        // Not a food item
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.momCareWarning)

                            Text("Not a Food Item")
                                .font(.momCareHeading2)
                                .foregroundColor(.momCareTextPrimary)

                            Text(result.errorMessage ?? "The picture is not a known food item. Please manually log the calories.")
                                .font(.momCareBody)
                                .foregroundColor(.momCareTextSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)

                            VStack(spacing: 12) {
                                MomCarePrimaryButton("Manual Entry", icon: "pencil") {
                                    showManualEntry = true
                                }

                                Button("Try Again") {
                                    capturedImage = nil
                                    recognitionResult = nil
                                    showCamera = true
                                }
                                .font(.momCareButtonSecondary)
                                .foregroundColor(.momCarePrimary)
                                .padding()
                            }
                            .padding(.top, 8)
                        }
                        .padding()
                    }
                }

                Spacer()
                    .frame(height: 50)
            }
            .padding()
        }
    }

    private func addFoodEntry(result: FoodRecognitionResult) {
        // Create food entry from AI recognition result
        let entry = FoodEntry(
            name: result.foodName,
            mealType: selectedMealType,
            calories: result.calories,
            protein: result.protein,
            carbohydrates: result.carbohydrates,
            fat: result.fat,
            fiber: result.fiber,
            servingSize: result.servingSize,
            servingCount: result.servingCount,
            isAIRecognized: true,
            timestamp: Date()
        )

        // Add to daily nutrition
        dailyNutrition.addEntry(entry)

        #if DEBUG
        print("✅ [Food Camera] Added entry: \(entry.name) to \(selectedMealType.rawValue)")
        print("📊 [Food Camera] Total calories today: \(dailyNutrition.totalCalories)")
        #endif

        // Call sync callback
        onEntrySaved?(entry)

        // Dismiss and return to food tracking view
        dismiss()
    }

    private func analyzeImage(_ image: UIImage) {
        isAnalyzing = true

        Task {
            do {
                let result = try await recognitionService.recognizeFood(from: image)
                await MainActor.run {
                    recognitionResult = result
                    isAnalyzing = false

                    // Record AI usage after successful recognition
                    aiUsageManager.recordUsage()

                    #if DEBUG
                    print("✅ [Food Camera] Recognition completed: \(result.foodName)")
                    print("📊 [Food Camera] AI usage recorded - \(aiUsageManager.remainingUses) free scans remaining")
                    #endif
                }
            } catch {
                await MainActor.run {
                    isAnalyzing = false
                    errorMessage = error.localizedDescription
                    showError = true

                    #if DEBUG
                    print("❌ [Food Camera] Recognition failed: \(error)")
                    #endif
                }
            }
        }
    }
}

// MARK: - Nutrition Info Row
struct NutritionInfoRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.momCareNutrition)
                .frame(width: 20)

            Text(label)
                .font(.momCareBody)
                .foregroundColor(.momCareTextSecondary)

            Spacer()

            Text(value)
                .font(.momCareBodyBold)
                .foregroundColor(.momCareTextPrimary)
        }
    }
}

// MARK: - Meal Type Option
struct MealTypeOption: View {
    let mealType: MealType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Radio button
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.momCarePrimary : Color.momCareTextTertiary, lineWidth: 2)
                        .frame(width: 20, height: 20)

                    if isSelected {
                        Circle()
                            .fill(Color.momCarePrimary)
                            .frame(width: 12, height: 12)
                    }
                }

                // Meal icon
                Image(systemName: mealType.icon)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .momCarePrimary : .momCareTextSecondary)
                    .frame(width: 24)

                // Meal name
                VStack(alignment: .leading, spacing: 2) {
                    Text(mealType.rawValue)
                        .font(.momCareBodyBold)
                        .foregroundColor(isSelected ? .momCarePrimary : .momCareTextPrimary)

                    Text(mealType.suggestedTime)
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextTertiary)
                }

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.momCarePrimary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.momCarePrimary.opacity(0.1) : Color.momCareCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.momCarePrimary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Manual Entry View
struct ManualFoodEntryView: View {
    @Environment(\.dismiss) private var dismiss
    let mealType: MealType
    let onSave: (FoodEntry) -> Void

    // Optional pre-filled data from AI recognition
    let prefillData: FoodRecognitionResult?
    let isEditingAIResult: Bool

    @State private var foodName = ""
    @State private var calories = ""
    @State private var servingSize = "1 serving"
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var selectedMealType: MealType

    init(mealType: MealType, prefillData: FoodRecognitionResult? = nil, onSave: @escaping (FoodEntry) -> Void) {
        self.mealType = mealType
        self.prefillData = prefillData
        self.isEditingAIResult = prefillData != nil
        self.onSave = onSave
        _selectedMealType = State(initialValue: mealType)

        // Pre-fill form with AI recognition data if available
        if let data = prefillData {
            _foodName = State(initialValue: data.foodName)
            _calories = State(initialValue: String(data.calories))
            _servingSize = State(initialValue: data.servingSize)
            _protein = State(initialValue: String(format: "%.1f", data.protein))
            _carbs = State(initialValue: String(format: "%.1f", data.carbohydrates))
            _fat = State(initialValue: String(format: "%.1f", data.fat))
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Meal Type") {
                    Picker("Select Meal", selection: $selectedMealType) {
                        ForEach(MealType.allCases, id: \.self) { mealType in
                            HStack {
                                Image(systemName: mealType.icon)
                                Text(mealType.rawValue)
                            }
                            .tag(mealType)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Food Details") {
                    TextField("Food name", text: $foodName)
                    TextField("Calories", text: $calories)
                        .keyboardType(.numberPad)
                    TextField("Serving size", text: $servingSize)
                }

                Section("Macros (optional)") {
                    TextField("Protein (g)", text: $protein)
                        .keyboardType(.decimalPad)
                    TextField("Carbohydrates (g)", text: $carbs)
                        .keyboardType(.decimalPad)
                    TextField("Fat (g)", text: $fat)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle(isEditingAIResult ? "Edit Food" : "Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.momCareTextSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let entry = FoodEntry(
                            name: foodName,
                            mealType: selectedMealType,
                            calories: Int(calories) ?? 0,
                            protein: Double(protein) ?? 0,
                            carbohydrates: Double(carbs) ?? 0,
                            fat: Double(fat) ?? 0,
                            servingSize: servingSize,
                            isAIRecognized: isEditingAIResult
                        )
                        onSave(entry)
                        dismiss()
                    }
                    .foregroundColor(.momCarePrimary)
                    .disabled(foodName.isEmpty || calories.isEmpty)
                }
            }
        }
    }
}

// MARK: - Barcode Scanner View (Placeholder)
struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                Text("Barcode scanner coming soon!")
                    .font(.momCareHeading2)
                    .foregroundColor(.momCareTextPrimary)
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.momCareTextSecondary)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    FoodTrackingView()
}
