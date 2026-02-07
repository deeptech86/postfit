//
//  DashboardView.swift
//  PostFit (MomCare)
//
//  Main dashboard showing daily health overview
//  Encouraging, personalized view for postpartum mothers
//

import SwiftUI

// MARK: - Dashboard View
struct DashboardView: View {
    @State private var user = User.sampleUser
    @State private var selectedDate = Date()
    @State private var showMoodLog = false
    @State private var currentMood: Mood = .good

    // Navigation manager for tab switching
    @StateObject private var tabNavigationManager = TabNavigationManager.shared

    // Nutrition data from shared manager
    @StateObject private var nutritionDataManager = NutritionDataManager.shared

    // Exercise data from shared manager
    @StateObject private var exerciseDataManager = ExerciseDataManager.shared

    // User session for authenticated user name
    @StateObject private var userSessionManager = UserSessionManager.shared

    // Hydration data (will be replaced with HydrationDataManager later)
    @State private var waterGlasses = 6

    /// Total calories from nutrition tracking
    private var dailyCalories: Int {
        nutritionDataManager.totalCalories
    }

    private var exerciseMinutes: Int {
        exerciseDataManager.todayExerciseMinutes > 0 ? exerciseDataManager.todayExerciseMinutes : 25
    }

    private var exerciseCalories: Int {
        exerciseDataManager.todayExerciseCalories
    }

    /// Get the display name - from authenticated session or fallback to sample user
    private var displayName: String {
        let sessionName = userSessionManager.userName
        return sessionName != "User" ? sessionName : user.name
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome header
                    WelcomeHeader(displayName: displayName, date: selectedDate)

                    // Daily motivation
                    DailyMotivationCard()

                    // Quick actions
                    QuickActionsRow(
                        onFoodTap: { tabNavigationManager.navigateToAddFood() },
                        onWaterTap: { tabNavigationManager.navigateToHydration() },
                        onExerciseTap: { tabNavigationManager.navigateToExercise() },
                        onMoodTap: { showMoodLog = true }
                    )

                    // Daily progress summary
                    DailyProgressSection(
                        calories: dailyCalories,
                        calorieGoal: user.healthProfile.dailyCalorieTarget,
                        water: waterGlasses,
                        waterGoal: user.healthProfile.dailyHydrationGoal,
                        exercise: exerciseMinutes
                    )

                    // Feature cards
                    VStack(spacing: 16) {
                        // Nutrition card - navigates to Nutrition tab
                        MomCareFeatureCard(
                            title: "Nutrition",
                            subtitle: "Track your meals and nutrients",
                            icon: "fork.knife",
                            iconColor: .momCareNutrition,
                            value: "\(dailyCalories)",
                            unit: "/ \(user.healthProfile.dailyCalorieTarget) kcal"
                        ) {
                            tabNavigationManager.navigateTo(.nutrition)
                        }

                        // Hydration card - navigates to Hydration tab
                        MomCareFeatureCard(
                            title: "Hydration",
                            subtitle: user.healthProfile.isBreastfeeding ? "Adjusted for breastfeeding" : "Stay hydrated",
                            icon: "drop.fill",
                            iconColor: .momCareHydration,
                            value: "\(waterGlasses)",
                            unit: "/ \(user.healthProfile.dailyHydrationGoal) glasses"
                        ) {
                            tabNavigationManager.navigateToHydration()
                        }

                        // Exercise card - shows allocated exercise with progress
                        MomCareFeatureCard(
                            title: exerciseDataManager.todayExerciseName,
                            subtitle: exerciseDataManager.summaryString,
                            icon: "figure.run",
                            iconColor: .momCareExercise,
                            value: exerciseDataManager.progressString,
                            unit: "today"
                        ) {
                            tabNavigationManager.navigateToExercise()
                        }
                    }

                    // Weekly overview
                    WeeklyOverviewSection()

                    // Mood check-in
                    MoodCheckInCard(currentMood: currentMood) {
                        showMoodLog = true
                    }

                    // Tips and insights
                    TipsSection(healthProfile: user.healthProfile)

                    Spacer()
                        .frame(height: 100) // Bottom padding for tab bar
                }
                .padding(.horizontal, 20)
            }
            .background(Color.momCareBackground)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showMoodLog) {
            MoodLogSheet(currentMood: $currentMood)
        }
    }
}

// MARK: - Welcome Header
struct WelcomeHeader: View {
    let displayName: String
    let date: Date

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }

    /// Get first name from display name
    private var firstName: String {
        let components = displayName.split(separator: " ")
        return components.first.map(String.init) ?? displayName
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(greeting), \(firstName)!")
                    .font(.momCareHeading1)
                    .foregroundColor(.momCareTextPrimary)

                Text(dateString)
                    .font(.momCareBody)
                    .foregroundColor(.momCareTextSecondary)
            }

            Spacer()

            // Profile avatar
            ZStack {
                Circle()
                    .fill(Color.momCarePrimary.opacity(0.15))
                    .frame(width: 48, height: 48)

                Text(displayName.prefix(1).uppercased())
                    .font(.momCareHeading3)
                    .foregroundColor(.momCarePrimary)
            }
        }
        .padding(.top, 20)
    }
}

// MARK: - Daily Motivation Card
struct DailyMotivationCard: View {
    private let motivations = [
        "Every small step is progress. You're doing amazing!",
        "Your body did something incredible. Be patient with it.",
        "Taking care of yourself helps you care for your baby.",
        "Progress, not perfection. You're on the right track!",
        "Remember: rest is productive too."
    ]

    @State private var currentMotivation: String = ""

    var body: some View {
        MomCareGradientCard {
            HStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 28))
                    .foregroundColor(.momCareAccent)

                Text(currentMotivation)
                    .font(.momCareBody)
                    .foregroundColor(.momCareTextPrimary)
                    .lineSpacing(4)
            }
        }
        .onAppear {
            currentMotivation = motivations.randomElement() ?? motivations[0]
        }
    }
}

// MARK: - Quick Actions Row
struct QuickActionsRow: View {
    let onFoodTap: () -> Void
    let onWaterTap: () -> Void
    let onExerciseTap: () -> Void
    let onMoodTap: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                MomCareQuickActionCard(
                    title: "Log Meal",
                    icon: "camera.fill",
                    color: .momCareNutrition,
                    action: onFoodTap
                )

                MomCareQuickActionCard(
                    title: "Add Water",
                    icon: "drop.fill",
                    color: .momCareHydration,
                    action: onWaterTap
                )

                MomCareQuickActionCard(
                    title: "Exercise",
                    icon: "figure.run",
                    color: .momCareExercise,
                    action: onExerciseTap
                )

                MomCareQuickActionCard(
                    title: "Mood",
                    icon: "face.smiling",
                    color: .momCareMentalHealth,
                    action: onMoodTap
                )
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Daily Progress Section
struct DailyProgressSection: View {
    let calories: Int
    let calorieGoal: Int
    let water: Int
    let waterGoal: Int
    let exercise: Int

    private var calorieProgress: Double {
        guard calorieGoal > 0 else { return 0 }
        return min(Double(calories) / Double(calorieGoal), 1.0)
    }

    private var waterProgress: Double {
        guard waterGoal > 0 else { return 0 }
        return min(Double(water) / Double(waterGoal), 1.0)
    }

    var body: some View {
        MomCareCard {
            VStack(spacing: 20) {
                Text("Today's Progress")
                    .font(.momCareHeading3)
                    .foregroundColor(.momCareTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 24) {
                    // Calories progress
                    VStack(spacing: 8) {
                        MomCareProgressRing(
                            progress: calorieProgress,
                            color: .momCareNutrition,
                            size: 70,
                            showPercentage: false
                        )
                        .overlay(
                            Image(systemName: "flame.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.momCareNutrition)
                        )

                        Text("Calories")
                            .font(.momCareCaption)
                            .foregroundColor(.momCareTextSecondary)
                    }

                    // Hydration progress
                    VStack(spacing: 8) {
                        MomCareProgressRing(
                            progress: waterProgress,
                            color: .momCareHydration,
                            size: 70,
                            showPercentage: false
                        )
                        .overlay(
                            Image(systemName: "drop.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.momCareHydration)
                        )

                        Text("Water")
                            .font(.momCareCaption)
                            .foregroundColor(.momCareTextSecondary)
                    }

                    // Exercise
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .stroke(Color.momCareExercise.opacity(0.2), lineWidth: 8)
                                .frame(width: 70, height: 70)

                            VStack(spacing: 0) {
                                Text("\(exercise)")
                                    .font(.momCareNumberSmall)
                                    .foregroundColor(.momCareTextPrimary)

                                Text("min")
                                    .font(.momCareCaption)
                                    .foregroundColor(.momCareTextTertiary)
                            }
                        }

                        Text("Exercise")
                            .font(.momCareCaption)
                            .foregroundColor(.momCareTextSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Weekly Overview Section
struct WeeklyOverviewSection: View {
    var body: some View {
        MomCareWeeklyProgress(
            data: [0.8, 0.6, 1.0, 0.4, 0.75, 0.5, 0.3],
            color: .momCarePrimary,
            title: "This Week's Activity"
        )
    }
}

// MARK: - Mood Check-In Card
struct MoodCheckInCard: View {
    let currentMood: Mood
    let onTap: () -> Void

    var body: some View {
        MomCareCard {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How are you feeling?")
                            .font(.momCareHeading3)
                            .foregroundColor(.momCareTextPrimary)

                        Text("Daily check-in helps track your wellbeing")
                            .font(.momCareCaption)
                            .foregroundColor(.momCareTextSecondary)
                    }

                    Spacer()

                    Button(action: onTap) {
                        HStack(spacing: 8) {
                            Image(systemName: currentMood.icon)
                                .font(.system(size: 24))
                                .foregroundColor(Color(hex: currentMood.color))

                            Text(currentMood.rawValue)
                                .font(.momCareBodyBold)
                                .foregroundColor(.momCareTextPrimary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: currentMood.color).opacity(0.15))
                        )
                    }
                }

                Text(currentMood.supportMessage)
                    .font(.momCareCaption)
                    .foregroundColor(.momCareTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Tips Section
struct TipsSection: View {
    let healthProfile: HealthProfile

    private var tips: [Tip] {
        var allTips: [Tip] = []

        if healthProfile.isBreastfeeding {
            allTips.append(Tip(
                icon: "drop.fill",
                title: "Hydration Reminder",
                text: "Breastfeeding increases fluid needs. Try to drink a glass of water each time you nurse.",
                color: .momCareHydration
            ))
        }

        allTips.append(Tip(
            icon: "bed.double.fill",
            title: "Sleep Tip",
            text: "Try to nap when your baby naps. Even short rests help with recovery.",
            color: .momCareSleep
        ))

        if healthProfile.recoveryStage == .earlyRecovery {
            allTips.append(Tip(
                icon: "figure.walk",
                title: "Gentle Movement",
                text: "Short walks and pelvic floor exercises are perfect for this stage of recovery.",
                color: .momCareExercise
            ))
        }

        return allTips
    }

    struct Tip {
        let icon: String
        let title: String
        let text: String
        let color: Color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tips for You")
                .font(.momCareHeading3)
                .foregroundColor(.momCareTextPrimary)

            ForEach(tips.indices, id: \.self) { index in
                TipCard(tip: tips[index])
            }
        }
    }
}

struct TipCard: View {
    let tip: TipsSection.Tip

    var body: some View {
        MomCareCard {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(tip.color.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: tip.icon)
                        .font(.system(size: 18))
                        .foregroundColor(tip.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(tip.title)
                        .font(.momCareBodyBold)
                        .foregroundColor(.momCareTextPrimary)

                    Text(tip.text)
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextSecondary)
                        .lineSpacing(4)
                }
            }
        }
    }
}

// MARK: - Sheet Views

struct FoodLogSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                Text("Food logging coming soon!")
                    .font(.momCareHeading2)
                    .foregroundColor(.momCareTextPrimary)
            }
            .navigationTitle("Log Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.momCarePrimary)
                }
            }
        }
    }
}

struct WaterLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var glasses: Int
    let goal: Int

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                MomCareHydrationProgress(
                    current: glasses,
                    goal: goal,
                    isBreastfeeding: true
                )
                .padding(.top, 40)

                HStack(spacing: 24) {
                    MomCareIconButton(icon: "minus", size: 56, color: .momCareHydration) {
                        if glasses > 0 { glasses -= 1 }
                    }

                    MomCareIconButton(icon: "plus", size: 56, color: .momCareHydration) {
                        glasses += 1
                    }
                }

                Text("Tap + to add a glass of water (250ml)")
                    .font(.momCareCaption)
                    .foregroundColor(.momCareTextSecondary)

                Spacer()
            }
            .padding()
            .background(Color.momCareBackground)
            .navigationTitle("Hydration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.momCarePrimary)
                }
            }
        }
    }
}

struct ExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                Text("Exercise library coming soon!")
                    .font(.momCareHeading2)
                    .foregroundColor(.momCareTextPrimary)
            }
            .navigationTitle("Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.momCarePrimary)
                }
            }
        }
    }
}

struct MoodLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var currentMood: Mood

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Text("How are you feeling right now?")
                    .font(.momCareHeading2)
                    .foregroundColor(.momCareTextPrimary)
                    .padding(.top, 40)

                VStack(spacing: 12) {
                    ForEach(Mood.allCases, id: \.self) { mood in
                        Button(action: {
                            currentMood = mood
                        }) {
                            HStack {
                                Image(systemName: mood.icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(Color(hex: mood.color))
                                    .frame(width: 40)

                                Text(mood.rawValue)
                                    .font(.momCareBody)
                                    .foregroundColor(.momCareTextPrimary)

                                Spacer()

                                if currentMood == mood {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.momCarePrimary)
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(currentMood == mood ? Color(hex: mood.color).opacity(0.1) : Color.momCareCardBackground)
                            )
                        }
                    }
                }
                .padding(.horizontal)

                if currentMood == .struggling || currentMood == .low {
                    MomCareCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.momCarePrimary)
                                Text("Support Available")
                                    .font(.momCareBodyBold)
                                    .foregroundColor(.momCareTextPrimary)
                            }

                            Text("If you're struggling, please reach out to your healthcare provider or call a support hotline.")
                                .font(.momCareCaption)
                                .foregroundColor(.momCareTextSecondary)

                            Button("Find Help Resources") {
                                // Open resources
                            }
                            .font(.momCareCaptionBold)
                            .foregroundColor(.momCarePrimary)
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .background(Color.momCareBackground)
            .navigationTitle("Mood Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.momCarePrimary)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    DashboardView()
}
