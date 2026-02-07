//
//  ProfileView.swift
//  PostFit (MomCare)
//
//  User profile display and settings
//  Shows health stats, achievements, and preferences
//

import SwiftUI

// MARK: - Profile View
struct ProfileView: View {
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var showHealthProfile = false
    @State private var showNotifications = false
    @State private var showPrivacy = false
    @State private var showHelpSupport = false
    @State private var showAllAchievements = false
    @State private var showSubscription = false

    // User session and profile managers
    @StateObject private var userSessionManager = UserSessionManager.shared
    @StateObject private var profileManager = UserProfileManager.shared

    /// Get the current user - from profile manager or fallback to sample
    private var user: User {
        profileManager.currentUser ?? User.sampleUser
    }

    /// Get the display name - from authenticated session or fallback to user model
    private var displayName: String {
        let sessionName = userSessionManager.userName
        return sessionName != "User" ? sessionName : user.name
    }

    /// Get the profile image URL from authenticated session
    private var profileImageURL: String? {
        userSessionManager.profileImageURL
    }

    /// Get the user email from authenticated session
    private var userEmail: String {
        let sessionEmail = userSessionManager.userEmail
        return !sessionEmail.isEmpty ? sessionEmail : user.email
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile header
                    ProfileHeaderCard(
                        displayName: displayName,
                        email: userEmail,
                        profileImageURL: profileImageURL,
                        postpartumWeek: user.healthProfile.postpartumWeek
                    ) {
                        showEditProfile = true
                    }

                    // Recovery stage indicator
                    RecoveryStageCard(healthProfile: user.healthProfile)

                    // Quick stats
                    ProfileStatsGrid(healthProfile: user.healthProfile)

                    // Achievements section
                    AchievementsSection(onSeeAll: {
                        showAllAchievements = true
                    })

                    // Menu items
                    ProfileMenuSection(
                        onHealthProfile: { showHealthProfile = true },
                        onNotifications: { showNotifications = true },
                        onPrivacy: { showPrivacy = true },
                        onHelpSupport: { showHelpSupport = true }
                    )

                    // Subscription status
                    SubscriptionCard(status: user.subscriptionStatus) {
                        showSubscription = true
                    }

                    // Sign out button
                    Button(action: {
                        // Handle sign out
                    }) {
                        Text("Sign Out")
                            .font(.momCareButtonSecondary)
                            .foregroundColor(.momCareError)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 20)
            }
            .background(Color.momCareBackground)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.momCareTextSecondary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileSheet()
            }
            .sheet(isPresented: $showHealthProfile) {
                HealthProfileSheetView()
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsView()
            }
            .sheet(isPresented: $showPrivacy) {
                PrivacyView()
            }
            .sheet(isPresented: $showHelpSupport) {
                HelpSupportView()
            }
            .sheet(isPresented: $showAllAchievements) {
                AllAchievementsView()
            }
            .sheet(isPresented: $showSubscription) {
                SubscriptionView()
            }
        }
    }
}

// MARK: - Profile Header Card
struct ProfileHeaderCard: View {
    let displayName: String
    let email: String
    let profileImageURL: String?
    let postpartumWeek: Int?
    let onEdit: () -> Void

    var body: some View {
        MomCareCard(padding: 20) {
            VStack(spacing: 16) {
                // Avatar - show profile image if available, otherwise show initial
                ZStack {
                    Circle()
                        .fill(Color.momCarePrimary.opacity(0.15))
                        .frame(width: 80, height: 80)

                    if let imageURL = profileImageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                            case .failure(_), .empty:
                                Text(displayName.prefix(1).uppercased())
                                    .font(.momCareDisplayMedium)
                                    .foregroundColor(.momCarePrimary)
                            @unknown default:
                                Text(displayName.prefix(1).uppercased())
                                    .font(.momCareDisplayMedium)
                                    .foregroundColor(.momCarePrimary)
                            }
                        }
                    } else {
                        Text(displayName.prefix(1).uppercased())
                            .font(.momCareDisplayMedium)
                            .foregroundColor(.momCarePrimary)
                    }
                }

                // Name and info
                VStack(spacing: 4) {
                    Text(displayName)
                        .font(.momCareHeading1)
                        .foregroundColor(.momCareTextPrimary)

                    Text(email)
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextTertiary)

                    if let week = postpartumWeek {
                        Text("Week \(week) Postpartum")
                            .font(.momCareBody)
                            .foregroundColor(.momCareTextSecondary)
                    }
                }

                // Edit button
                MomCareSecondaryButton("Edit Profile", icon: "pencil", size: .small) {
                    onEdit()
                }
                .frame(width: 140)
            }
        }
    }
}

// MARK: - Recovery Stage Card
struct RecoveryStageCard: View {
    let healthProfile: HealthProfile

    var body: some View {
        MomCareGradientCard(gradient: Color.momCareCalmGradient) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.momCareSecondary)

                    Text("Recovery Stage")
                        .font(.momCareCaptionBold)
                        .foregroundColor(.momCareTextSecondary)
                }

                Text(healthProfile.recoveryStage.rawValue)
                    .font(.momCareHeading2)
                    .foregroundColor(.momCareTextPrimary)

                Text(healthProfile.recoveryStage.description)
                    .font(.momCareBody)
                    .foregroundColor(.momCareTextSecondary)

                HStack {
                    Text("Recommended intensity:")
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextTertiary)

                    Text(healthProfile.recoveryStage.allowedExerciseIntensity)
                        .font(.momCareCaptionBold)
                        .foregroundColor(.momCareExercise)
                }
            }
        }
    }
}

// MARK: - Profile Stats Grid
struct ProfileStatsGrid: View {
    let healthProfile: HealthProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Stats")
                .font(.momCareHeading3)
                .foregroundColor(.momCareTextPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let weight = healthProfile.currentWeight {
                    MomCareStatsCard(
                        title: "Current Weight",
                        value: String(format: "%.1f", weight),
                        unit: "kg",
                        icon: "scalemass.fill",
                        color: .momCarePrimary
                    )
                }

                MomCareStatsCard(
                    title: "Daily Calories",
                    value: "\(healthProfile.dailyCalorieTarget)",
                    unit: "kcal",
                    icon: "flame.fill",
                    color: .momCareNutrition
                )

                MomCareStatsCard(
                    title: "Hydration Goal",
                    value: "\(healthProfile.dailyHydrationGoal)",
                    unit: "glasses",
                    icon: "drop.fill",
                    color: .momCareHydration
                )

                MomCareStatsCard(
                    title: "Activity Level",
                    value: healthProfile.activityLevel.rawValue,
                    unit: "",
                    icon: "figure.walk",
                    color: .momCareExercise
                )
            }
        }
    }
}

// MARK: - Achievements Section
struct AchievementsSection: View {
    let onSeeAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Achievements")
                    .font(.momCareHeading3)
                    .foregroundColor(.momCareTextPrimary)

                Spacer()

                Button("See All") {
                    onSeeAll()
                }
                .font(.momCareCaptionBold)
                .foregroundColor(.momCarePrimary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    MomCareAchievementBadge(
                        title: "First Week",
                        icon: "star.fill",
                        color: .momCareAccent,
                        isUnlocked: true
                    )

                    MomCareAchievementBadge(
                        title: "Hydration Hero",
                        icon: "drop.fill",
                        color: .momCareHydration,
                        isUnlocked: true
                    )

                    MomCareAchievementBadge(
                        title: "5 Workouts",
                        icon: "figure.run",
                        color: .momCareExercise,
                        isUnlocked: true
                    )

                    MomCareAchievementBadge(
                        title: "30 Day Streak",
                        icon: "flame.fill",
                        color: .momCareWarning,
                        isUnlocked: false
                    )

                    MomCareAchievementBadge(
                        title: "Goal Weight",
                        icon: "target",
                        color: .momCareSuccess,
                        isUnlocked: false
                    )
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Profile Menu Section
struct ProfileMenuSection: View {
    let onHealthProfile: () -> Void
    let onNotifications: () -> Void
    let onPrivacy: () -> Void
    let onHelpSupport: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ProfileMenuItem(
                icon: "heart.text.square.fill",
                iconColor: .momCarePrimary,
                title: "Health Profile",
                subtitle: "Update your health information",
                action: onHealthProfile
            )

            Divider().padding(.leading, 56)

            ProfileMenuItem(
                icon: "bell.fill",
                iconColor: .momCareWarning,
                title: "Notifications",
                subtitle: "Manage reminders and alerts",
                action: onNotifications
            )

            Divider().padding(.leading, 56)

            ProfileMenuItem(
                icon: "lock.fill",
                iconColor: .momCareInfo,
                title: "Privacy",
                subtitle: "Data and privacy settings",
                action: onPrivacy
            )

            Divider().padding(.leading, 56)

            ProfileMenuItem(
                icon: "questionmark.circle.fill",
                iconColor: .momCareSecondary,
                title: "Help & Support",
                subtitle: "FAQs and contact support",
                action: onHelpSupport
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.momCareCardBackground)
        )
    }
}

struct ProfileMenuItem: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.momCareBody)
                        .foregroundColor(.momCareTextPrimary)

                    Text(subtitle)
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.momCareTextTertiary)
            }
            .padding(16)
        }
    }
}

// MARK: - Subscription Card
struct SubscriptionCard: View {
    let status: SubscriptionStatus
    let onUpgrade: () -> Void

    private var statusTitle: String {
        switch status {
        case .premium: return "Premium Member"
        case .trial: return "Trial Active"
        case .free: return "Free Plan"
        }
    }

    private var statusSubtitle: String {
        switch status {
        case .premium: return "All features unlocked"
        case .trial: return "Enjoying premium features"
        case .free: return "Upgrade for full access"
        }
    }

    var body: some View {
        MomCareCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(statusTitle)
                                .font(.momCareHeading3)
                                .foregroundColor(.momCareTextPrimary)

                            if status == .premium || status == .trial {
                                Image(systemName: status == .premium ? "checkmark.seal.fill" : "clock.fill")
                                    .foregroundColor(status == .premium ? .momCareAccent : .momCareWarning)
                            }
                        }

                        Text(statusSubtitle)
                            .font(.momCareCaption)
                            .foregroundColor(.momCareTextSecondary)
                    }

                    Spacer()
                }

                if status == .free {
                    MomCarePrimaryButton("Start 7-Day Free Trial", size: .small) {
                        onUpgrade()
                    }
                } else if status == .trial {
                    MomCareSecondaryButton("Manage Subscription", size: .small) {
                        onUpgrade()
                    }
                }
            }
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notificationsEnabled = true
    @State private var darkModeEnabled = false
    @State private var hapticFeedbackEnabled = true
    @State private var selectedUnit: MeasurementUnit = .metric

    var body: some View {
        NavigationView {
            List {
                // Appearance
                Section("Appearance") {
                    Toggle("Dark Mode", isOn: $darkModeEnabled)
                    Toggle("Haptic Feedback", isOn: $hapticFeedbackEnabled)
                }

                // Notifications
                Section("Notifications") {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                }

                // Units
                Section("Units") {
                    Picker("Measurement System", selection: $selectedUnit) {
                        ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.momCareTextTertiary)
                    }

                    Button("Terms of Service") {}
                    Button("Privacy Policy") {}
                    Button("Licenses") {}
                }

                // Danger zone
                Section {
                    Button("Delete Account", role: .destructive) {
                        // Show confirmation
                    }
                }
            }
            .navigationTitle("Settings")
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

// MARK: - Edit Profile Sheet Wrapper
struct EditProfileSheet: View {
    @StateObject private var profileManager = UserProfileManager.shared

    var body: some View {
        if let user = profileManager.currentUser {
            EditProfileView(user: Binding(
                get: { user },
                set: { profileManager.saveUser($0) }
            ))
        } else {
            // Create a new user if none exists
            EditProfileView(user: Binding(
                get: { User.sampleUser },
                set: { profileManager.saveUser($0) }
            ))
        }
    }
}

// MARK: - Health Profile Sheet Wrapper
struct HealthProfileSheetView: View {
    @StateObject private var profileManager = UserProfileManager.shared

    var body: some View {
        if let user = profileManager.currentUser {
            HealthProfileView(user: Binding(
                get: { user },
                set: { profileManager.saveUser($0) }
            ))
        } else {
            HealthProfileView(user: Binding(
                get: { User.sampleUser },
                set: { profileManager.saveUser($0) }
            ))
        }
    }
}

// MARK: - Health Profile View
struct HealthProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var user: User
    @StateObject private var profileManager = UserProfileManager.shared

    private var measurementUnit: MeasurementUnit {
        profileManager.measurementUnit
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Delivery Info Section
                    HealthProfileCard(title: "Delivery Info", icon: "heart.text.square.fill", iconColor: .momCarePrimary) {
                        VStack(alignment: .leading, spacing: 12) {
                            HealthProfileRow(
                                label: "Delivery Date",
                                value: user.healthProfile.deliveryDate?.formatted(date: .abbreviated, time: .omitted) ?? "Not set"
                            )

                            HealthProfileRow(
                                label: "Delivery Type",
                                value: user.healthProfile.deliveryType?.rawValue ?? "Not set"
                            )

                            HealthProfileRow(
                                label: "Recovery Stage",
                                value: user.healthProfile.recoveryStage.rawValue
                            )

                            if !user.healthProfile.deliveryComplications.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Complications")
                                        .font(.momCareCaptionBold)
                                        .foregroundColor(.momCareTextSecondary)

                                    ForEach(user.healthProfile.deliveryComplications, id: \.self) { complication in
                                        Text("• \(complication.rawValue)")
                                            .font(.momCareCaption)
                                            .foregroundColor(.momCareTextTertiary)
                                    }
                                }
                            }
                        }
                    }

                    // Measurements Section
                    HealthProfileCard(title: "Measurements", icon: "scalemass.fill", iconColor: .momCareAccent) {
                        VStack(alignment: .leading, spacing: 12) {
                            HealthProfileRow(
                                label: "Current Weight",
                                value: "\(measurementUnit.formatWeight(user.healthProfile.currentWeight)) \(measurementUnit.weightUnit)"
                            )

                            HealthProfileRow(
                                label: "Pre-Pregnancy Weight",
                                value: "\(measurementUnit.formatWeight(user.healthProfile.prePregnancyWeight)) \(measurementUnit.weightUnit)"
                            )

                            HealthProfileRow(
                                label: "Height",
                                value: "\(measurementUnit.formatHeight(user.healthProfile.height)) \(measurementUnit.heightUnit)"
                            )

                            if let dob = user.healthProfile.dateOfBirth {
                                HealthProfileRow(
                                    label: "Date of Birth",
                                    value: dob.formatted(date: .abbreviated, time: .omitted)
                                )
                            }
                        }
                    }

                    // Goals Section
                    HealthProfileCard(title: "Goals", icon: "star.fill", iconColor: .momCareWarning) {
                        VStack(alignment: .leading, spacing: 12) {
                            HealthProfileRow(
                                label: "Activity Level",
                                value: user.healthProfile.activityLevel.rawValue
                            )

                            if let target = user.healthProfile.targetWeight {
                                HealthProfileRow(
                                    label: "Target Weight",
                                    value: "\(measurementUnit.formatWeight(target)) \(measurementUnit.weightUnit)"
                                )
                            }

                            if !user.healthProfile.wellnessGoals.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Wellness Goals")
                                        .font(.momCareCaptionBold)
                                        .foregroundColor(.momCareTextSecondary)

                                    FlowLayout(spacing: 8) {
                                        ForEach(user.healthProfile.wellnessGoals, id: \.self) { goal in
                                            Text(goal.rawValue)
                                                .font(.momCareCaption)
                                                .foregroundColor(.momCarePrimary)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.momCarePrimary.opacity(0.1))
                                                )
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Feeding Section
                    HealthProfileCard(title: "Feeding", icon: "heart.fill", iconColor: .momCarePrimary) {
                        VStack(alignment: .leading, spacing: 12) {
                            HealthProfileRow(
                                label: "Breastfeeding",
                                value: user.healthProfile.isBreastfeeding ? "Yes" : "No"
                            )

                            if user.healthProfile.isBreastfeeding, let intensity = user.healthProfile.breastfeedingIntensity {
                                HealthProfileRow(
                                    label: "Intensity",
                                    value: intensity.rawValue
                                )

                                HealthProfileRow(
                                    label: "Extra Calories",
                                    value: "+\(intensity.additionalCalories) kcal/day"
                                )
                            }
                        }
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color.momCareBackground)
            .navigationTitle("Health Profile")
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

// MARK: - Health Profile Card
struct HealthProfileCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: Content

    var body: some View {
        MomCareCard(padding: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(0.15))
                            .frame(width: 36, height: 36)

                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .foregroundColor(iconColor)
                    }

                    Text(title)
                        .font(.momCareHeading3)
                        .foregroundColor(.momCareTextPrimary)
                }

                content
            }
        }
    }
}

// MARK: - Health Profile Row
struct HealthProfileRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.momCareBody)
                .foregroundColor(.momCareTextSecondary)

            Spacer()

            Text(value)
                .font(.momCareBody)
                .foregroundColor(.momCareTextPrimary)
        }
    }
}

// MARK: - Notifications View
struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var showPermissionAlert = false

    var body: some View {
        NavigationView {
            Form {
                // Permission Status
                if notificationManager.authorizationStatus == .notDetermined {
                    Section {
                        Button(action: requestPermission) {
                            HStack {
                                Image(systemName: "bell.badge")
                                    .foregroundColor(.momCarePrimary)
                                Text("Enable Notifications")
                                    .foregroundColor(.momCarePrimary)
                            }
                        }
                        Text("PostFit needs permission to send you helpful reminders")
                            .font(.momCareCaption)
                            .foregroundColor(.momCareTextSecondary)
                    }
                } else if notificationManager.authorizationStatus == .denied {
                    Section {
                        Text("Notifications are disabled. Please enable them in Settings.")
                            .foregroundColor(.orange)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }

                // Daily Check-in
                Section("Daily Check-in") {
                    Toggle("Enable Daily Check-in", isOn: $notificationManager.settings.dailyCheckInEnabled)
                        .onChange(of: notificationManager.settings.dailyCheckInEnabled) { _, newValue in
                            saveAndSchedule()
                        }

                    if notificationManager.settings.dailyCheckInEnabled {
                        DatePicker("Time", selection: $notificationManager.settings.dailyCheckInTime, displayedComponents: .hourAndMinute)
                            .onChange(of: notificationManager.settings.dailyCheckInTime) { _, _ in
                                saveAndSchedule()
                            }
                    }
                }

                // Activity Reminders
                Section("Activity Reminders") {
                    // Exercise Reminders
                    activityReminderSection(
                        title: "Exercise Reminders",
                        icon: "figure.walk",
                        enabled: $notificationManager.settings.exerciseEnabled,
                        time: $notificationManager.settings.exerciseTime,
                        frequency: $notificationManager.settings.exerciseFrequency,
                        duration: $notificationManager.settings.exerciseDuration
                    )

                    Divider()

                    // Hydration Reminders (with hourly frequency)
                    hydrationReminderSection()

                    Divider()

                    // Meal Tracking
                    activityReminderSection(
                        title: "Meal Tracking",
                        icon: "fork.knife",
                        enabled: $notificationManager.settings.mealEnabled,
                        time: $notificationManager.settings.mealTime,
                        frequency: $notificationManager.settings.mealFrequency,
                        duration: $notificationManager.settings.mealDuration
                    )

                    Divider()

                    // Sleep Tracking
                    activityReminderSection(
                        title: "Sleep Reminders",
                        icon: "moon.fill",
                        enabled: $notificationManager.settings.sleepEnabled,
                        time: $notificationManager.settings.sleepTime,
                        frequency: $notificationManager.settings.sleepFrequency,
                        duration: $notificationManager.settings.sleepDuration
                    )
                }

                Section {
                    Text("Notifications help you stay on track with your postpartum wellness goals. Customize the time, frequency, and duration for each reminder.")
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextSecondary)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.momCarePrimary)
                }
            }
            .onAppear {
                notificationManager.checkAuthorizationStatus()
            }
        }
    }

    @ViewBuilder
    private func activityReminderSection(
        title: String,
        icon: String,
        enabled: Binding<Bool>,
        time: Binding<Date>,
        frequency: Binding<NotificationFrequency>,
        duration: Binding<NotificationDuration>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.momCarePrimary)
                    .frame(width: 24)
                Toggle(title, isOn: enabled)
                    .onChange(of: enabled.wrappedValue) { _, _ in
                        saveAndSchedule()
                    }
            }

            if enabled.wrappedValue {
                VStack(alignment: .leading, spacing: 8) {
                    DatePicker("Preferred Time", selection: time, displayedComponents: .hourAndMinute)
                        .onChange(of: time.wrappedValue) { _, _ in
                            saveAndSchedule()
                        }

                    HStack {
                        Text("Frequency")
                            .font(.momCareBody)
                            .foregroundColor(.momCareTextSecondary)
                        Spacer()
                        Picker("", selection: frequency) {
                            ForEach(NotificationFrequency.allCases, id: \.self) { freq in
                                Text(freq.rawValue).tag(freq)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: frequency.wrappedValue) { _, _ in
                            saveAndSchedule()
                        }
                    }

                    HStack {
                        Text("Duration")
                            .font(.momCareBody)
                            .foregroundColor(.momCareTextSecondary)
                        Spacer()
                        Picker("", selection: duration) {
                            ForEach(NotificationDuration.allCases, id: \.self) { dur in
                                Text(dur.rawValue).tag(dur)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: duration.wrappedValue) { _, _ in
                            saveAndSchedule()
                        }
                    }
                }
                .padding(.leading, 32)
            }
        }
    }

    private func requestPermission() {
        Task {
            let granted = await notificationManager.requestAuthorization()
            if granted {
                await saveAndSchedule()
            } else {
                showPermissionAlert = true
            }
        }
    }

    private func saveAndSchedule() {
        Task {
            notificationManager.saveSettings()
            await notificationManager.scheduleAllNotifications()
        }
    }

    @ViewBuilder
    private func hydrationReminderSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundColor(.momCarePrimary)
                    .frame(width: 24)
                Toggle("Hydration Reminders", isOn: $notificationManager.settings.hydrationEnabled)
                    .onChange(of: notificationManager.settings.hydrationEnabled) { _, _ in
                        saveAndSchedule()
                    }
            }

            if notificationManager.settings.hydrationEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    DatePicker("Start Time", selection: $notificationManager.settings.hydrationTime, displayedComponents: .hourAndMinute)
                        .onChange(of: notificationManager.settings.hydrationTime) { _, _ in
                            saveAndSchedule()
                        }

                    HStack {
                        Text("Frequency")
                            .font(.momCareBody)
                            .foregroundColor(.momCareTextSecondary)
                        Spacer()
                        Picker("", selection: $notificationManager.settings.hydrationFrequency) {
                            ForEach(HydrationFrequency.allCases, id: \.self) { freq in
                                Text(freq.rawValue).tag(freq)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: notificationManager.settings.hydrationFrequency) { _, _ in
                            saveAndSchedule()
                        }
                    }

                    HStack {
                        Text("Duration")
                            .font(.momCareBody)
                            .foregroundColor(.momCareTextSecondary)
                        Spacer()
                        Picker("", selection: $notificationManager.settings.hydrationDuration) {
                            ForEach(NotificationDuration.allCases, id: \.self) { dur in
                                Text(dur.rawValue).tag(dur)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: notificationManager.settings.hydrationDuration) { _, _ in
                            saveAndSchedule()
                        }
                    }
                }
                .padding(.leading, 32)
            }
        }
    }
}

// MARK: - Privacy View
struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var dataSharing = false
    @State private var analytics = true
    @State private var crashReports = true

    var body: some View {
        NavigationView {
            Form {
                Section("Data Collection") {
                    Toggle("Anonymous Analytics", isOn: $analytics)
                    Toggle("Crash Reports", isOn: $crashReports)
                }

                Section("Data Sharing") {
                    Toggle("Share with Healthcare Provider", isOn: $dataSharing)
                }

                Section("Your Data") {
                    Button("Export My Data") {
                        // Export data
                    }

                    Button("Delete All Data", role: .destructive) {
                        // Delete data with confirmation
                    }
                }

                Section("Privacy Policy") {
                    Button("View Privacy Policy") {
                        // Open privacy policy
                    }

                    Button("View Terms of Service") {
                        // Open terms
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your privacy matters")
                            .font(.momCareBodyBold)

                        Text("All your health data is stored securely on your device and in your private iCloud. We never share your personal information without your explicit consent.")
                            .font(.momCareCaption)
                            .foregroundColor(.momCareTextSecondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Privacy")
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

// MARK: - Help & Support View
struct HelpSupportView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Getting Started") {
                    NavigationLink("How to track nutrition") {
                        FAQDetailView(
                            title: "How to track nutrition",
                            content: "Take a photo of your food, and our AI will automatically recognize and log the nutritional information. You can select the meal type (breakfast, lunch, dinner, or snack) and review the details before saving."
                        )
                    }

                    NavigationLink("Understanding recovery stages") {
                        FAQDetailView(
                            title: "Understanding recovery stages",
                            content: "Your recovery stage determines which exercises and activities are safe for you. We automatically recommend appropriate exercises based on your postpartum week and recovery progress."
                        )
                    }

                    NavigationLink("Setting up exercise routine") {
                        FAQDetailView(
                            title: "Setting up exercise routine",
                            content: "Browse exercises filtered by your recovery stage. Start with gentle activities like walking and pelvic floor exercises. Gradually progress as you feel stronger and with your doctor's approval."
                        )
                    }
                }

                Section("Features") {
                    NavigationLink("AI Food Recognition") {
                        FAQDetailView(
                            title: "AI Food Recognition",
                            content: "Our AI analyzes your food photos to identify ingredients, portion sizes, and nutritional content. It provides detailed macro and micronutrient breakdowns to help you meet your postpartum nutrition goals."
                        )
                    }

                    NavigationLink("iCloud Sync") {
                        FAQDetailView(
                            title: "iCloud Sync",
                            content: "Your data syncs automatically to your private iCloud. Local data from the last 90 days is stored on your device for quick access, while up to 1 year of history is available in iCloud."
                        )
                    }

                    NavigationLink("Achievements & Progress") {
                        FAQDetailView(
                            title: "Achievements & Progress",
                            content: "Earn badges and track milestones as you progress through your postpartum journey. Achievements help motivate and celebrate your wellness goals."
                        )
                    }
                }

                Section("Contact Support") {
                    Button("Email Support") {
                        if let url = URL(string: "mailto:support@momcare.app") {
                            UIApplication.shared.open(url)
                        }
                    }

                    Button("Visit Help Center") {
                        if let url = URL(string: "https://momcare.app/help") {
                            UIApplication.shared.open(url)
                        }
                    }
                }

                Section {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.momCareTextTertiary)
                    }
                }
            }
            .navigationTitle("Help & Support")
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

// MARK: - FAQ Detail View
struct FAQDetailView: View {
    let title: String
    let content: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.momCareHeading2)
                    .foregroundColor(.momCareTextPrimary)

                Text(content)
                    .font(.momCareBody)
                    .foregroundColor(.momCareTextSecondary)
                    .lineSpacing(6)
            }
            .padding(20)
        }
        .background(Color.momCareBackground)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - All Achievements View
struct AllAchievementsView: View {
    @Environment(\.dismiss) private var dismiss

    let achievements = [
        ("First Week", "star.fill", Color.momCareAccent, true, "Complete your first week postpartum"),
        ("Hydration Hero", "drop.fill", Color.momCareHydration, true, "Reach hydration goal 7 days in a row"),
        ("5 Workouts", "figure.run", Color.momCareExercise, true, "Complete 5 workout sessions"),
        ("Nutrition Tracker", "leaf.fill", Color.momCareNutrition, true, "Log meals for 7 consecutive days"),
        ("Early Riser", "sunrise.fill", Color.momCareWarning, false, "Complete morning routine 10 times"),
        ("30 Day Streak", "flame.fill", Color.momCareWarning, false, "Use the app for 30 consecutive days"),
        ("Goal Weight", "target", Color.momCareSuccess, false, "Reach your goal weight"),
        ("Pelvic Floor Pro", "figure.stand", Color.momCarePrimary, false, "Complete 30 Kegel exercise sessions"),
        ("Sleep Champion", "moon.stars.fill", Color.momCareInfo, false, "Log quality sleep for 7 nights"),
        ("Wellness Warrior", "heart.fill", Color.momCareError, false, "Complete all postpartum milestones")
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(achievements, id: \.0) { achievement in
                        AchievementRow(
                            title: achievement.0,
                            icon: achievement.1,
                            color: achievement.2,
                            isUnlocked: achievement.3,
                            description: achievement.4
                        )
                    }
                }
                .padding(20)
            }
            .background(Color.momCareBackground)
            .navigationTitle("Achievements")
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

struct AchievementRow: View {
    let title: String
    let icon: String
    let color: Color
    let isUnlocked: Bool
    let description: String

    var body: some View {
        MomCareCard {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isUnlocked ? color.opacity(0.2) : Color.momCareTextTertiary.opacity(0.1))
                        .frame(width: 60, height: 60)

                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundColor(isUnlocked ? color : .momCareTextTertiary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.momCareBodyBold)
                        .foregroundColor(isUnlocked ? .momCareTextPrimary : .momCareTextTertiary)

                    Text(description)
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextSecondary)
                        .lineLimit(2)
                }

                Spacer()

                if isUnlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.momCareSuccess)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.momCareTextTertiary)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ProfileView()
}
