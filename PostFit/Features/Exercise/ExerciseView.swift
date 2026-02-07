//
//  ExerciseView.swift
//  PostFit (MomCare)
//
//  Postpartum-safe exercise library with recovery stage filtering
//  Medical safety is prioritized throughout
//

import SwiftUI

// MARK: - Exercise Data Manager (Shared State)
@MainActor
class ExerciseDataManager: ObservableObject {
    static let shared = ExerciseDataManager()

    // MARK: - Today's Progress
    @Published var todayExerciseCalories: Int = 0
    @Published var todayExerciseMinutes: Int = 0
    @Published var workoutHistory: [WorkoutRecord] = []

    // MARK: - Today's Allocated Exercise
    @Published var todayAllocatedExercise: Exercise?
    @Published var targetExerciseMinutes: Int = 25  // Default target: 25 minutes

    struct WorkoutRecord: Identifiable {
        let id = UUID()
        let exercise: Exercise
        let duration: TimeInterval
        let caloriesBurned: Int
        let timestamp: Date
    }

    // MARK: - Computed Properties

    /// Progress string for dashboard display (e.g., "05/25 min")
    var progressString: String {
        let completed = String(format: "%02d", todayExerciseMinutes)
        return "\(completed)/\(targetExerciseMinutes) min"
    }

    /// Summary string for dashboard (e.g., "completed and burned 15 cal")
    var summaryString: String {
        if todayExerciseMinutes > 0 {
            return "completed and burned \(todayExerciseCalories) cal"
        } else {
            return "Start your workout!"
        }
    }

    /// Today's exercise name for display
    var todayExerciseName: String {
        todayAllocatedExercise?.name ?? "Daily Workout"
    }

    /// Whether user has completed today's target
    var hasCompletedTarget: Bool {
        todayExerciseMinutes >= targetExerciseMinutes
    }

    // MARK: - Methods

    func addWorkout(exercise: Exercise, duration: TimeInterval, calories: Int) {
        let record = WorkoutRecord(
            exercise: exercise,
            duration: duration,
            caloriesBurned: calories,
            timestamp: Date()
        )
        workoutHistory.append(record)
        todayExerciseCalories += calories
        todayExerciseMinutes += Int(duration / 60)

        // Set as today's allocated exercise if not set
        if todayAllocatedExercise == nil {
            todayAllocatedExercise = exercise
        }
    }

    /// Set today's allocated exercise
    func setTodayExercise(_ exercise: Exercise, targetMinutes: Int = 25) {
        todayAllocatedExercise = exercise
        targetExerciseMinutes = targetMinutes
    }

    /// Reset daily stats (call at midnight or new day)
    func resetDailyStats() {
        todayExerciseCalories = 0
        todayExerciseMinutes = 0
        todayAllocatedExercise = nil
        // Keep workout history for records
    }

    private init() {
        // Set a default allocated exercise for today
        // This would typically come from a recommendation algorithm
        allocateDefaultExercise()
    }

    private func allocateDefaultExercise() {
        // Default to a gentle exercise suitable for postpartum
        // In a real app, this would be based on user's recovery stage and preferences
        if let defaultExercise = sampleExercises.first(where: { $0.category == .walking }) {
            todayAllocatedExercise = defaultExercise
        }
    }
}

// MARK: - Exercise View
struct ExerciseView: View {
    @State private var selectedCategory: ExerciseCategory?
    @State private var selectedExercise: Exercise?
    @State private var showExerciseDetail = false
    @State private var searchText = ""
    @State private var showFilters = false

    // Workout tracking state
    @State private var selectedExerciseForWorkout: Exercise?
    @State private var isWorkoutActive = false
    @State private var workoutStartTime: Date?
    @State private var elapsedTime: TimeInterval = 0
    @State private var workoutTimer: Timer?
    @State private var showWorkoutComplete = false
    @State private var calculatedCalories: Int = 0

    @StateObject private var exerciseDataManager = ExerciseDataManager.shared

    // User's recovery stage (would come from profile)
    private let userRecoveryStage: RecoveryStage = .progressiveStrengthening

    private var filteredExercises: [Exercise] {
        var exercises = sampleExercises

        // Filter by recovery stage
        exercises = exercises.filter { exercise in
            allowedRecoveryStages.contains(exercise.recoveryStage)
        }

        // Filter by category
        if let category = selectedCategory {
            exercises = exercises.filter { $0.category == category }
        }

        // Filter by search
        if !searchText.isEmpty {
            exercises = exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return exercises
    }

    private var allowedRecoveryStages: [RecoveryStage] {
        switch userRecoveryStage {
        case .earlyRecovery:
            return [.earlyRecovery]
        case .progressiveStrengthening:
            return [.earlyRecovery, .progressiveStrengthening]
        case .buildingStrength:
            return [.earlyRecovery, .progressiveStrengthening, .buildingStrength]
        case .fullRecovery:
            return RecoveryStage.allCases
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Recovery stage banner
                    RecoveryStageBanner(stage: userRecoveryStage)

                    // Video download banner (encourage offline downloads)
                    VideoDownloadBanner(exercises: sampleExercises)

                    // Search bar
                    SearchBar(text: $searchText)

                    // Category pills
                    CategoryFilterRow(selectedCategory: $selectedCategory)

                    // Today's workout suggestion with timer
                    TodayWorkoutCard(
                        selectedExercise: $selectedExerciseForWorkout,
                        isWorkoutActive: $isWorkoutActive,
                        elapsedTime: $elapsedTime,
                        showWorkoutComplete: $showWorkoutComplete,
                        calculatedCalories: $calculatedCalories,
                        onStartWorkout: startWorkout,
                        onStopWorkout: stopWorkout,
                        onAddCalories: addCaloriesToDashboard
                    )

                    // Exercise list with radio buttons
                    ExerciseListSection(
                        exercises: filteredExercises,
                        selectedExerciseForWorkout: $selectedExerciseForWorkout,
                        isWorkoutActive: isWorkoutActive,
                        onExerciseTap: { exercise in
                            selectedExercise = exercise
                            showExerciseDetail = true
                        }
                    )

                    // Safety reminder
                    SafetyReminderCard()

                    Spacer()
                        .frame(height: 100)
                }
                .padding(.horizontal, 20)
            }
            .background(Color.momCareBackground)
            .navigationTitle("Exercise")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showFilters = true }) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.momCareTextSecondary)
                    }
                }
            }
            .sheet(isPresented: $showExerciseDetail) {
                if let exercise = selectedExercise {
                    ExerciseDetailView(exercise: exercise)
                }
            }
            .sheet(isPresented: $showFilters) {
                ExerciseFiltersView()
            }
        }
        .onDisappear {
            // Clean up timer when view disappears
            workoutTimer?.invalidate()
        }
    }

    // MARK: - Workout Functions

    private func startWorkout() {
        guard selectedExerciseForWorkout != nil else { return }

        isWorkoutActive = true
        workoutStartTime = Date()
        elapsedTime = 0
        showWorkoutComplete = false
        calculatedCalories = 0

        // Start timer
        workoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let startTime = workoutStartTime {
                elapsedTime = Date().timeIntervalSince(startTime)
            }
        }
    }

    private func stopWorkout() {
        workoutTimer?.invalidate()
        workoutTimer = nil
        isWorkoutActive = false

        // Calculate calories
        if let exercise = selectedExerciseForWorkout {
            let caloriesPerMinute = Double(exercise.caloriesBurned) / Double(exercise.duration)
            let minutesWorked = elapsedTime / 60.0
            calculatedCalories = Int(caloriesPerMinute * minutesWorked)
        }

        showWorkoutComplete = true
    }

    private func addCaloriesToDashboard() {
        guard let exercise = selectedExerciseForWorkout else { return }

        exerciseDataManager.addWorkout(
            exercise: exercise,
            duration: elapsedTime,
            calories: calculatedCalories
        )

        // Reset state
        showWorkoutComplete = false
        elapsedTime = 0
        calculatedCalories = 0
        selectedExerciseForWorkout = nil
    }
}

// MARK: - Recovery Stage Banner
struct RecoveryStageBanner: View {
    let stage: RecoveryStage

    var body: some View {
        MomCareGradientCard(gradient: Color.momCareCalmGradient) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.momCareExercise.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: "leaf.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.momCareExercise)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Recovery Stage")
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextSecondary)

                    Text(stage.rawValue)
                        .font(.momCareBodyBold)
                        .foregroundColor(.momCareTextPrimary)

                    Text("Showing safe exercises for this stage")
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextTertiary)
                }

                Spacer()
            }
        }
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(.momCareTextTertiary)

            TextField("Search exercises", text: $text)
                .font(.momCareBody)
                .foregroundColor(.momCareTextPrimary)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.momCareTextTertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.momCareCardBackground)
        )
    }
}

// MARK: - Category Filter Row
struct CategoryFilterRow: View {
    @Binding var selectedCategory: ExerciseCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                CategoryPill(
                    title: "All",
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                ForEach(ExerciseCategory.allCases.prefix(6), id: \.self) { category in
                    CategoryPill(
                        title: category.rawValue,
                        icon: category.icon,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

struct CategoryPill: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                }
                Text(title)
                    .font(.momCareCaptionBold)
            }
            .foregroundColor(isSelected ? .white : .momCareTextSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.momCarePrimary : Color.momCareCardBackground)
            )
        }
    }
}

// MARK: - Today's Workout Card with Timer
struct TodayWorkoutCard: View {
    @Binding var selectedExercise: Exercise?
    @Binding var isWorkoutActive: Bool
    @Binding var elapsedTime: TimeInterval
    @Binding var showWorkoutComplete: Bool
    @Binding var calculatedCalories: Int

    let onStartWorkout: () -> Void
    let onStopWorkout: () -> Void
    let onAddCalories: () -> Void

    @StateObject private var exerciseDataManager = ExerciseDataManager.shared

    private var timerString: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var estimatedCaloriesPerMinute: Double {
        guard let exercise = selectedExercise else { return 3.5 }
        return Double(exercise.caloriesBurned) / Double(exercise.duration)
    }

    private var currentCalories: Int {
        let minutesWorked = elapsedTime / 60.0
        return Int(estimatedCaloriesPerMinute * minutesWorked)
    }

    var body: some View {
        MomCareCard(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's Suggested Workout")
                            .font(.momCareCaption)
                            .foregroundColor(.momCareTextSecondary)

                        if let exercise = selectedExercise {
                            Text(exercise.name)
                                .font(.momCareHeading2)
                                .foregroundColor(.momCareTextPrimary)
                                .lineLimit(2)
                        } else {
                            Text("Select an exercise below")
                                .font(.momCareHeading2)
                                .foregroundColor(.momCareTextTertiary)
                        }
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(Color.momCareExercise.opacity(0.15))
                            .frame(width: 56, height: 56)

                        Image(systemName: "figure.mind.and.body")
                            .font(.system(size: 24))
                            .foregroundColor(.momCareExercise)
                    }
                }

                if let exercise = selectedExercise {
                    HStack(spacing: 16) {
                        WorkoutInfoItem(icon: "clock.fill", text: "\(exercise.duration) min")
                        WorkoutInfoItem(icon: "flame.fill", text: "\(exercise.caloriesBurned) kcal")
                        WorkoutInfoItem(icon: "star.fill", text: exercise.difficulty.rawValue)
                    }
                }

                // Today's exercise summary
                if exerciseDataManager.todayExerciseCalories > 0 {
                    HStack {
                        Image(systemName: "flame.circle.fill")
                            .foregroundColor(.momCareSuccess)
                        Text("Today: \(exerciseDataManager.todayExerciseCalories) kcal burned")
                            .font(.momCareCaptionBold)
                            .foregroundColor(.momCareSuccess)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.momCareSuccess.opacity(0.1))
                    )
                }

                // Timer display (shown when workout is active or complete)
                if isWorkoutActive || showWorkoutComplete {
                    VStack(spacing: 12) {
                        // Timer
                        HStack {
                            Image(systemName: "timer")
                                .font(.system(size: 20))
                                .foregroundColor(isWorkoutActive ? .momCarePrimary : .momCareTextSecondary)

                            Text(timerString)
                                .font(.system(size: 36, weight: .bold, design: .monospaced))
                                .foregroundColor(isWorkoutActive ? .momCarePrimary : .momCareTextPrimary)

                            Spacer()

                            // Live calorie counter
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(isWorkoutActive ? "\(currentCalories)" : "\(calculatedCalories)")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.momCareNutrition)
                                Text("kcal")
                                    .font(.momCareCaption)
                                    .foregroundColor(.momCareTextSecondary)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isWorkoutActive ? Color.momCarePrimary.opacity(0.1) : Color.momCareSecondaryBackground)
                        )

                        // Workout complete message with Add button
                        if showWorkoutComplete && calculatedCalories > 0 {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.momCareSuccess)
                                    Text("Workout Complete!")
                                        .font(.momCareBodyBold)
                                        .foregroundColor(.momCareSuccess)
                                }

                                Text("You burned \(calculatedCalories) kcal in \(Int(elapsedTime / 60)) min \(Int(elapsedTime) % 60) sec")
                                    .font(.momCareCaption)
                                    .foregroundColor(.momCareTextSecondary)

                                Button(action: onAddCalories) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add to Today's Dashboard")
                                    }
                                    .font(.momCareBodyBold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.momCareSuccess)
                                    )
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.momCareSuccess.opacity(0.1))
                            )
                        }
                    }
                }

                // Start/Stop Workout Button
                if selectedExercise != nil {
                    if isWorkoutActive {
                        Button(action: onStopWorkout) {
                            HStack {
                                Image(systemName: "stop.fill")
                                Text("Stop Workout")
                            }
                            .font(.momCareButtonPrimary)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.red)
                            )
                        }
                    } else if !showWorkoutComplete {
                        MomCarePrimaryButton("Start Workout", icon: "play.fill") {
                            onStartWorkout()
                        }
                    }
                } else {
                    // Disabled state when no exercise selected
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Workout")
                    }
                    .font(.momCareButtonPrimary)
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.momCarePrimary.opacity(0.5))
                    )
                }
            }
        }
    }
}

struct WorkoutInfoItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.momCareTextTertiary)

            Text(text)
                .font(.momCareCaption)
                .foregroundColor(.momCareTextSecondary)
        }
    }
}

// MARK: - Exercise List Section with Radio Buttons
struct ExerciseListSection: View {
    let exercises: [Exercise]
    @Binding var selectedExerciseForWorkout: Exercise?
    let isWorkoutActive: Bool
    let onExerciseTap: (Exercise) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Available Exercises")
                    .font(.momCareHeading3)
                    .foregroundColor(.momCareTextPrimary)

                Spacer()

                if selectedExerciseForWorkout != nil {
                    Text("Selected")
                        .font(.momCareCaption)
                        .foregroundColor(.momCarePrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.momCarePrimary.opacity(0.1))
                        )
                }
            }

            if exercises.isEmpty {
                EmptyExerciseState()
            } else {
                // Using LazyVStack for better performance with large exercise lists
                LazyVStack(spacing: 12) {
                    ForEach(exercises, id: \.id) { exercise in
                        ExerciseCardWithRadio(
                            exercise: exercise,
                            isSelected: selectedExerciseForWorkout?.id == exercise.id,
                            isWorkoutActive: isWorkoutActive,
                            onRadioTap: {
                                if !isWorkoutActive {
                                    if selectedExerciseForWorkout?.id == exercise.id {
                                        selectedExerciseForWorkout = nil
                                    } else {
                                        selectedExerciseForWorkout = exercise
                                    }
                                }
                            },
                            onDetailTap: {
                                onExerciseTap(exercise)
                            }
                        )
                    }
                }
            }
        }
    }
}

struct EmptyExerciseState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.stand")
                .font(.system(size: 48))
                .foregroundColor(.momCareTextTertiary)

            Text("No exercises match your filters")
                .font(.momCareBody)
                .foregroundColor(.momCareTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

// MARK: - Exercise Card with Radio Button
struct ExerciseCardWithRadio: View {
    let exercise: Exercise
    let isSelected: Bool
    let isWorkoutActive: Bool
    let onRadioTap: () -> Void
    let onDetailTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 12) {
            // Radio button
            Button(action: onRadioTap) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.momCarePrimary : Color.momCareTextTertiary, lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(Color.momCarePrimary)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .disabled(isWorkoutActive)
            .opacity(isWorkoutActive ? 0.5 : 1.0)

            // Exercise card content
            Button(action: onDetailTap) {
                HStack(spacing: 16) {
                    // Thumbnail
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: exercise.category.color).opacity(0.15))
                            .frame(width: 64, height: 64)

                        Image(systemName: exercise.category.icon)
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: exercise.category.color))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(exercise.name)
                            .font(.momCareBodyBold)
                            .foregroundColor(.momCareTextPrimary)
                            .lineLimit(1)

                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 11))
                                Text("\(exercise.duration) min")
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "flame")
                                    .font(.system(size: 11))
                                Text("\(exercise.caloriesBurned) kcal")
                            }
                        }
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextTertiary)

                        // Difficulty badge
                        Text(exercise.difficulty.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(hex: exercise.difficulty.color))
                            )
                    }

                    Spacer()

                    // Play button
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.momCarePrimary)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? Color.momCarePrimary.opacity(0.08) : Color.momCareCardBackground)
                .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.momCarePrimary : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Safety Reminder Card
struct SafetyReminderCard: View {
    var body: some View {
        MomCareCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.momCareWarning)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Safety First")
                        .font(.momCareCaptionBold)
                        .foregroundColor(.momCareTextPrimary)

                    Text("Stop exercising if you experience pain, heavy bleeding, or dizziness. Always consult your healthcare provider before starting any exercise program.")
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextSecondary)
                        .lineSpacing(4)
                }
            }
        }
    }
}

// MARK: - Exercise Detail View
struct ExerciseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise

    @StateObject private var videoManager = VideoManager.shared
    @State private var isPlaying = false
    @State private var isDownloading = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Video demo player with caching support
                    ExerciseVideoPlayer(exercise: exercise)
                        .padding(.horizontal, 20)

                    // Exercise info
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(exercise.name)
                                .font(.momCareDisplayMedium)
                                .foregroundColor(.momCareTextPrimary)

                            HStack(spacing: 16) {
                                InfoBadge(icon: "clock.fill", text: "\(exercise.duration) min")
                                InfoBadge(icon: "flame.fill", text: "\(exercise.caloriesBurned) kcal")
                                InfoBadge(icon: "star.fill", text: exercise.difficulty.rawValue)
                            }
                        }

                        // Benefits
                        if !exercise.benefits.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Benefits")
                                    .font(.momCareHeading3)
                                    .foregroundColor(.momCareTextPrimary)

                                ForEach(exercise.benefits, id: \.self) { benefit in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.momCareSuccess)
                                            .font(.system(size: 16))

                                        Text(benefit)
                                            .font(.momCareBody)
                                            .foregroundColor(.momCareTextSecondary)
                                    }
                                }
                            }
                        }

                        // Instructions
                        if !exercise.instructions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Instructions")
                                    .font(.momCareHeading3)
                                    .foregroundColor(.momCareTextPrimary)

                                ForEach(exercise.instructions.indices, id: \.self) { index in
                                    HStack(alignment: .top, spacing: 12) {
                                        Text("\(index + 1)")
                                            .font(.momCareCaptionBold)
                                            .foregroundColor(.white)
                                            .frame(width: 24, height: 24)
                                            .background(Circle().fill(Color.momCarePrimary))

                                        Text(exercise.instructions[index])
                                            .font(.momCareBody)
                                            .foregroundColor(.momCareTextSecondary)
                                            .lineSpacing(4)
                                    }
                                }
                            }
                        }

                        // Warnings
                        if !exercise.warnings.isEmpty {
                            MomCareCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.momCareWarning)

                                        Text("Precautions")
                                            .font(.momCareBodyBold)
                                            .foregroundColor(.momCareTextPrimary)
                                    }

                                    ForEach(exercise.warnings, id: \.self) { warning in
                                        Text("- \(warning)")
                                            .font(.momCareBody)
                                            .foregroundColor(.momCareTextSecondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // Start button
                    MomCarePrimaryButton("Start Exercise", icon: "play.fill") {
                        isPlaying = true
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .background(Color.momCareBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.momCareTextSecondary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Download button
                        Button(action: {
                            if videoManager.isCached(videoID: exercise.id.uuidString) {
                                // Already cached, do nothing or show options
                            } else {
                                downloadVideo()
                            }
                        }) {
                            if videoManager.isCached(videoID: exercise.id.uuidString) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.momCareSuccess)
                            } else if isDownloading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.down.circle")
                                    .foregroundColor(.momCarePrimary)
                            }
                        }
                        .disabled(isDownloading)

                        // Favorite button
                        Button(action: {
                            // Toggle favorite
                        }) {
                            Image(systemName: exercise.isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(.momCarePrimary)
                        }
                    }
                }
            }
        }
    }

    private func downloadVideo() {
        isDownloading = true

        Task { @MainActor in
            do {
                try await videoManager.downloadVideo(videoInfo: exercise.videoInfo)
                isDownloading = false
                print("Downloaded video: \(exercise.name)")
            } catch {
                isDownloading = false
                print("Failed to download video: \(error)")
            }
        }
    }
}

struct InfoBadge: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))

            Text(text)
                .font(.momCareCaption)
        }
        .foregroundColor(.momCareTextSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.momCareSecondaryBackground)
        )
    }
}

// MARK: - Exercise Filters View
struct ExerciseFiltersView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDifficulties: Set<ExerciseDifficulty> = []
    @State private var selectedDuration: Int = 30
    @State private var showEquipmentFree = false

    var body: some View {
        NavigationView {
            List {
                Section("Difficulty") {
                    ForEach(ExerciseDifficulty.allCases, id: \.self) { difficulty in
                        Toggle(difficulty.rawValue, isOn: Binding(
                            get: { selectedDifficulties.contains(difficulty) },
                            set: { isOn in
                                if isOn {
                                    selectedDifficulties.insert(difficulty)
                                } else {
                                    selectedDifficulties.remove(difficulty)
                                }
                            }
                        ))
                    }
                }

                Section("Maximum Duration") {
                    Picker("Duration", selection: $selectedDuration) {
                        Text("5 min").tag(5)
                        Text("10 min").tag(10)
                        Text("15 min").tag(15)
                        Text("20 min").tag(20)
                        Text("30 min").tag(30)
                        Text("Any").tag(60)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Equipment") {
                    Toggle("Equipment-free only", isOn: $showEquipmentFree)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        selectedDifficulties = []
                        selectedDuration = 30
                        showEquipmentFree = false
                    }
                    .foregroundColor(.momCareTextSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") { dismiss() }
                        .foregroundColor(.momCarePrimary)
                }
            }
        }
    }
}

// MARK: - Sample Data
// Using enhanced exercises from HealthData extensions with video demos
private let sampleExercises: [Exercise] = [
    .sampleKegel,          // Enhanced with detailed instructions and video
    .sampleBreathing,      // Diaphragmatic breathing with video
    .sampleWalk,           // Enhanced walking guide with video
    .sampleCatCow,         // Cat-Cow yoga stretch with video
    .samplePelvicTilts,    // Core reconnection with video
]

// MARK: - Preview
#Preview {
    ExerciseView()
}
