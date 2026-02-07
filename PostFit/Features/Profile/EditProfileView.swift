//
//  EditProfileView.swift
//  PostFit (MomCare)
//
//  Complete profile editing view with personal info and health profile sections
//

import SwiftUI

// MARK: - Edit Profile View
struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var user: User

    // User session and profile managers
    @StateObject private var userSessionManager = UserSessionManager.shared
    @StateObject private var profileManager = UserProfileManager.shared

    // Form state
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var showSaveConfirmation = false
    @State private var hasChanges = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Personal Information Section
                    PersonalInformationSection(
                        name: $name,
                        email: $email,
                        profileImageURL: userSessionManager.profileImageURL,
                        onChanged: { hasChanges = true }
                    )

                    // Health Profile Section
                    HealthProfileSection(user: $user, onChanged: { hasChanges = true })

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color.momCareBackground)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.momCareTextSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .foregroundColor(.momCarePrimary)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadCurrentData()
            }
            .alert("Profile Saved", isPresented: $showSaveConfirmation) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your profile has been updated successfully.")
            }
        }
    }

    private func loadCurrentData() {
        // Load from session manager (auth data) with fallback to user model
        name = userSessionManager.userName != "User" ? userSessionManager.userName : user.name
        email = !userSessionManager.userEmail.isEmpty ? userSessionManager.userEmail : user.email
    }

    private func saveProfile() {
        // Update user model
        user.name = name
        user.email = email

        // Persist to UserProfileManager
        profileManager.saveUser(user)

        // Also update session manager
        profileManager.updateName(name)
        profileManager.updateEmail(email)

        showSaveConfirmation = true
    }
}

// MARK: - Personal Information Section
struct PersonalInformationSection: View {
    @Binding var name: String
    @Binding var email: String
    let profileImageURL: String?
    let onChanged: () -> Void

    @State private var showImagePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            Text("Personal Information")
                .font(.momCareHeading3)
                .foregroundColor(.momCareTextPrimary)

            MomCareCard(padding: 20) {
                VStack(spacing: 20) {
                    // Profile Photo
                    VStack(spacing: 12) {
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
                                    case .failure, .empty:
                                        Text(name.prefix(1).uppercased())
                                            .font(.momCareDisplayMedium)
                                            .foregroundColor(.momCarePrimary)
                                    @unknown default:
                                        Text(name.prefix(1).uppercased())
                                            .font(.momCareDisplayMedium)
                                            .foregroundColor(.momCarePrimary)
                                    }
                                }
                            } else {
                                Text(name.prefix(1).uppercased())
                                    .font(.momCareDisplayMedium)
                                    .foregroundColor(.momCarePrimary)
                            }

                            // Camera overlay
                            Circle()
                                .fill(Color.momCarePrimary)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                )
                                .offset(x: 28, y: 28)
                        }

                        Button("Change Photo") {
                            showImagePicker = true
                        }
                        .font(.momCareCaptionBold)
                        .foregroundColor(.momCarePrimary)
                    }

                    Divider()

                    // Name Field
                    ProfileTextField(
                        title: "Full Name",
                        text: $name,
                        icon: "person.fill",
                        placeholder: "Enter your name"
                    )
                    .onChange(of: name) { _, _ in onChanged() }

                    // Email Field
                    ProfileTextField(
                        title: "Email",
                        text: $email,
                        icon: "envelope.fill",
                        placeholder: "Enter your email",
                        keyboardType: .emailAddress
                    )
                    .onChange(of: email) { _, _ in onChanged() }
                }
            }
        }
    }
}

// MARK: - Health Profile Section
struct HealthProfileSection: View {
    @Binding var user: User
    let onChanged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            Text("Health Profile")
                .font(.momCareHeading3)
                .foregroundColor(.momCareTextPrimary)

            VStack(spacing: 0) {
                // Delivery Info
                NavigationLink {
                    DeliveryInfoEditView(healthProfile: $user.healthProfile, onSave: onChanged)
                } label: {
                    HealthProfileMenuItem(
                        icon: "heart.text.square.fill",
                        iconColor: .momCarePrimary,
                        title: "Delivery Info",
                        subtitle: deliveryInfoSubtitle
                    )
                }

                Divider().padding(.leading, 56)

                // Measurements
                NavigationLink {
                    MeasurementsEditView(
                        healthProfile: $user.healthProfile,
                        preferences: $user.preferences,
                        onSave: onChanged
                    )
                } label: {
                    HealthProfileMenuItem(
                        icon: "scalemass.fill",
                        iconColor: .momCareAccent,
                        title: "Measurements",
                        subtitle: measurementsSubtitle
                    )
                }

                Divider().padding(.leading, 56)

                // Goals
                NavigationLink {
                    GoalsEditView(healthProfile: $user.healthProfile, onSave: onChanged)
                } label: {
                    HealthProfileMenuItem(
                        icon: "star.fill",
                        iconColor: .momCareWarning,
                        title: "Goals",
                        subtitle: goalsSubtitle
                    )
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.momCareCardBackground)
            )
        }
    }

    private var deliveryInfoSubtitle: String {
        if let date = user.healthProfile.deliveryDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
        return "Not set"
    }

    private var measurementsSubtitle: String {
        if let weight = user.healthProfile.currentWeight {
            return String(format: "%.1f kg", weight)
        }
        return "Not set"
    }

    private var goalsSubtitle: String {
        let count = user.healthProfile.wellnessGoals.count
        if count > 0 {
            return "\(count) goal\(count > 1 ? "s" : "") selected"
        }
        return "Not set"
    }
}

// MARK: - Health Profile Menu Item
struct HealthProfileMenuItem: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
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

// MARK: - Profile Text Field
struct ProfileTextField: View {
    let title: String
    @Binding var text: String
    let icon: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.momCareCaptionBold)
                .foregroundColor(.momCareTextSecondary)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.momCareTextTertiary)
                    .frame(width: 24)

                TextField(placeholder, text: $text)
                    .font(.momCareBody)
                    .foregroundColor(.momCareTextPrimary)
                    .keyboardType(keyboardType)
                    .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                    .textContentType(keyboardType == .emailAddress ? .emailAddress : .name)
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.momCareSecondaryBackground)
            )
        }
    }
}

// MARK: - Delivery Info Edit View
struct DeliveryInfoEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var healthProfile: HealthProfile
    let onSave: () -> Void

    @State private var deliveryDate: Date
    @State private var selectedDeliveryType: DeliveryType?
    @State private var selectedComplications: Set<DeliveryComplication> = []

    init(healthProfile: Binding<HealthProfile>, onSave: @escaping () -> Void) {
        self._healthProfile = healthProfile
        self.onSave = onSave
        self._deliveryDate = State(initialValue: healthProfile.wrappedValue.deliveryDate ?? Date())
        self._selectedDeliveryType = State(initialValue: healthProfile.wrappedValue.deliveryType)
        self._selectedComplications = State(initialValue: Set(healthProfile.wrappedValue.deliveryComplications))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Delivery Date
                VStack(alignment: .leading, spacing: 10) {
                    Text("Delivery Date")
                        .font(.momCareBodyBold)
                        .foregroundColor(.momCareTextPrimary)

                    DatePicker(
                        "Select Date",
                        selection: $deliveryDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .tint(.momCarePrimary)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.momCareCardBackground)
                    )
                }

                // Delivery Type
                VStack(alignment: .leading, spacing: 10) {
                    Text("Delivery Type")
                        .font(.momCareBodyBold)
                        .foregroundColor(.momCareTextPrimary)

                    VStack(spacing: 8) {
                        ForEach(DeliveryType.allCases, id: \.self) { type in
                            SelectableOption(
                                title: type.rawValue,
                                isSelected: selectedDeliveryType == type
                            ) {
                                selectedDeliveryType = type
                            }
                        }
                    }
                }

                // Recovery info card
                if let type = selectedDeliveryType {
                    InfoCard(
                        icon: "info.circle.fill",
                        iconColor: .momCareInfo,
                        title: "Recovery Note",
                        message: type.recoveryConsiderations
                    )
                }

                // Complications
                VStack(alignment: .leading, spacing: 10) {
                    Text("Any Complications?")
                        .font(.momCareBodyBold)
                        .foregroundColor(.momCareTextPrimary)

                    Text("Select all that apply (optional)")
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextSecondary)

                    FlowLayout(spacing: 8) {
                        ForEach(DeliveryComplication.allCases.filter { $0 != .none }, id: \.self) { complication in
                            ComplicationChip(
                                title: complication.rawValue,
                                isSelected: selectedComplications.contains(complication)
                            ) {
                                if selectedComplications.contains(complication) {
                                    selectedComplications.remove(complication)
                                } else {
                                    selectedComplications.insert(complication)
                                }
                            }
                        }
                    }
                }

                // Complication info
                if !selectedComplications.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(selectedComplications), id: \.self) { complication in
                            InfoCard(
                                icon: "exclamationmark.triangle.fill",
                                iconColor: .momCareWarning,
                                title: complication.rawValue,
                                message: complication.recoveryConsiderations
                            )
                        }
                    }
                }

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(Color.momCareBackground)
        .navigationTitle("Delivery Info")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveChanges()
                }
                .foregroundColor(.momCarePrimary)
                .fontWeight(.semibold)
            }
        }
    }

    private func saveChanges() {
        healthProfile.deliveryDate = deliveryDate
        healthProfile.deliveryType = selectedDeliveryType
        healthProfile.deliveryComplications = Array(selectedComplications)

        // Explicitly save to UserProfileManager to ensure persistence
        UserProfileManager.shared.saveHealthProfile(healthProfile)

        onSave()
        dismiss()
    }
}

// MARK: - Measurements Edit View
struct MeasurementsEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var healthProfile: HealthProfile
    @Binding var preferences: UserPreferences
    let onSave: () -> Void

    @State private var currentWeight: String = ""
    @State private var prePregnancyWeight: String = ""
    @State private var height: String = ""
    @State private var heightFeet: String = ""
    @State private var heightInches: String = ""
    @State private var dateOfBirth: Date
    @State private var showDateOfBirth = false

    init(healthProfile: Binding<HealthProfile>, preferences: Binding<UserPreferences>, onSave: @escaping () -> Void) {
        self._healthProfile = healthProfile
        self._preferences = preferences
        self.onSave = onSave
        self._dateOfBirth = State(initialValue: healthProfile.wrappedValue.dateOfBirth ?? Calendar.current.date(byAdding: .year, value: -30, to: Date())!)
        self._showDateOfBirth = State(initialValue: healthProfile.wrappedValue.dateOfBirth != nil)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Unit Selector
                VStack(alignment: .leading, spacing: 10) {
                    Text("Measurement Units")
                        .font(.momCareBodyBold)
                        .foregroundColor(.momCareTextPrimary)

                    Picker("Units", selection: $preferences.measurementUnit) {
                        ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Weight Measurements
                VStack(alignment: .leading, spacing: 16) {
                    Text("Weight")
                        .font(.momCareBodyBold)
                        .foregroundColor(.momCareTextPrimary)

                    MeasurementInputField(
                        title: "Current Weight",
                        value: $currentWeight,
                        unit: preferences.measurementUnit.weightUnit,
                        icon: "scalemass.fill"
                    )

                    MeasurementInputField(
                        title: "Pre-Pregnancy Weight",
                        value: $prePregnancyWeight,
                        unit: preferences.measurementUnit.weightUnit,
                        icon: "arrow.left.arrow.right"
                    )
                }

                // Height
                VStack(alignment: .leading, spacing: 10) {
                    Text("Height")
                        .font(.momCareBodyBold)
                        .foregroundColor(.momCareTextPrimary)

                    if preferences.measurementUnit == .imperial {
                        HStack(spacing: 12) {
                            MeasurementInputField(
                                title: "Feet",
                                value: $heightFeet,
                                unit: "ft",
                                icon: "ruler.fill"
                            )

                            MeasurementInputField(
                                title: "Inches",
                                value: $heightInches,
                                unit: "in",
                                icon: "ruler.fill"
                            )
                        }
                    } else {
                        MeasurementInputField(
                            title: "Height",
                            value: $height,
                            unit: "cm",
                            icon: "ruler.fill"
                        )
                    }
                }

                // Date of Birth
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Date of Birth")
                            .font(.momCareBodyBold)
                            .foregroundColor(.momCareTextPrimary)

                        Spacer()

                        Toggle("", isOn: $showDateOfBirth)
                            .tint(.momCarePrimary)
                    }

                    if showDateOfBirth {
                        DatePicker(
                            "Birth Date",
                            selection: $dateOfBirth,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .tint(.momCarePrimary)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.momCareCardBackground)
                        )
                    }
                }

                // Body positive message
                InfoCard(
                    icon: "heart.circle.fill",
                    iconColor: .momCarePrimary,
                    title: "Remember",
                    message: "Your body just did something amazing. We're here to support your health journey, not to pressure you."
                )

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(Color.momCareBackground)
        .navigationTitle("Measurements")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveChanges()
                }
                .foregroundColor(.momCarePrimary)
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            loadCurrentValues()
        }
        .onChange(of: preferences.measurementUnit) { _, newUnit in
            convertValues(to: newUnit)
        }
    }

    private func loadCurrentValues() {
        let unit = preferences.measurementUnit

        if let weight = healthProfile.currentWeight {
            currentWeight = unit == .metric ?
                String(format: "%.1f", weight) :
                String(format: "%.1f", MeasurementUnit.kgToLbs(weight))
        }

        if let preWeight = healthProfile.prePregnancyWeight {
            prePregnancyWeight = unit == .metric ?
                String(format: "%.1f", preWeight) :
                String(format: "%.1f", MeasurementUnit.kgToLbs(preWeight))
        }

        if let h = healthProfile.height {
            if unit == .metric {
                height = String(format: "%.0f", h)
            } else {
                let totalInches = h / 2.54
                heightFeet = String(Int(totalInches / 12))
                heightInches = String(Int(totalInches.truncatingRemainder(dividingBy: 12)))
            }
        }
    }

    private func convertValues(to newUnit: MeasurementUnit) {
        // Convert current weight
        if let value = Double(currentWeight) {
            if newUnit == .metric {
                currentWeight = String(format: "%.1f", MeasurementUnit.lbsToKg(value))
            } else {
                currentWeight = String(format: "%.1f", MeasurementUnit.kgToLbs(value))
            }
        }

        // Convert pre-pregnancy weight
        if let value = Double(prePregnancyWeight) {
            if newUnit == .metric {
                prePregnancyWeight = String(format: "%.1f", MeasurementUnit.lbsToKg(value))
            } else {
                prePregnancyWeight = String(format: "%.1f", MeasurementUnit.kgToLbs(value))
            }
        }

        // Convert height
        if newUnit == .metric {
            if let feet = Int(heightFeet), let inches = Int(heightInches) {
                let cm = MeasurementUnit.feetInchesToCm(feet: feet, inches: inches)
                height = String(format: "%.0f", cm)
            }
        } else {
            if let cm = Double(height) {
                let totalInches = cm / 2.54
                heightFeet = String(Int(totalInches / 12))
                heightInches = String(Int(totalInches.truncatingRemainder(dividingBy: 12)))
            }
        }
    }

    private func saveChanges() {
        let unit = preferences.measurementUnit

        // Save weights (convert to kg if imperial)
        if let value = Double(currentWeight) {
            healthProfile.currentWeight = unit == .metric ? value : MeasurementUnit.lbsToKg(value)
        }

        if let value = Double(prePregnancyWeight) {
            healthProfile.prePregnancyWeight = unit == .metric ? value : MeasurementUnit.lbsToKg(value)
        }

        // Save height (convert to cm if imperial)
        if unit == .metric {
            if let value = Double(height) {
                healthProfile.height = value
            }
        } else {
            if let feet = Int(heightFeet), let inches = Int(heightInches) {
                healthProfile.height = MeasurementUnit.feetInchesToCm(feet: feet, inches: inches)
            }
        }

        // Save date of birth
        healthProfile.dateOfBirth = showDateOfBirth ? dateOfBirth : nil

        // Save unit preference
        UserProfileManager.shared.updateMeasurementUnit(unit)

        // Explicitly save to UserProfileManager to ensure persistence
        UserProfileManager.shared.saveHealthProfile(healthProfile)

        onSave()
        dismiss()
    }
}

// MARK: - Goals Edit View
struct GoalsEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var healthProfile: HealthProfile
    let onSave: () -> Void

    @State private var selectedGoals: Set<WellnessGoal> = []
    @State private var targetWeight: String = ""
    @State private var selectedActivityLevel: ActivityLevel

    init(healthProfile: Binding<HealthProfile>, onSave: @escaping () -> Void) {
        self._healthProfile = healthProfile
        self.onSave = onSave
        self._selectedGoals = State(initialValue: Set(healthProfile.wrappedValue.wellnessGoals))
        self._selectedActivityLevel = State(initialValue: healthProfile.wrappedValue.activityLevel)

        if let target = healthProfile.wrappedValue.targetWeight {
            self._targetWeight = State(initialValue: String(format: "%.1f", target))
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Wellness Goals
                VStack(alignment: .leading, spacing: 12) {
                    Text("Wellness Goals")
                        .font(.momCareBodyBold)
                        .foregroundColor(.momCareTextPrimary)

                    Text("Select all that apply")
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextSecondary)

                    FlowLayout(spacing: 10) {
                        ForEach(WellnessGoal.allCases, id: \.self) { goal in
                            GoalChip(
                                title: goal.rawValue,
                                isSelected: selectedGoals.contains(goal)
                            ) {
                                if selectedGoals.contains(goal) {
                                    selectedGoals.remove(goal)
                                } else {
                                    selectedGoals.insert(goal)
                                }
                            }
                        }
                    }
                }

                // Target Weight (if weight loss goal selected)
                if selectedGoals.contains(.loseWeight) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Target Weight (Optional)")
                            .font(.momCareBodyBold)
                            .foregroundColor(.momCareTextPrimary)

                        MeasurementInputField(
                            title: "",
                            value: $targetWeight,
                            unit: UserProfileManager.shared.measurementUnit.weightUnit,
                            icon: "target"
                        )

                        Text("We recommend losing 0.5-1 kg per week for sustainable, healthy weight loss.")
                            .font(.momCareCaption)
                            .foregroundColor(.momCareTextTertiary)
                    }
                }

                // Activity Level
                VStack(alignment: .leading, spacing: 12) {
                    Text("Current Activity Level")
                        .font(.momCareBodyBold)
                        .foregroundColor(.momCareTextPrimary)

                    VStack(spacing: 8) {
                        ForEach(ActivityLevel.allCases, id: \.self) { level in
                            ActivityLevelOption(
                                level: level,
                                isSelected: selectedActivityLevel == level
                            ) {
                                selectedActivityLevel = level
                            }
                        }
                    }
                }

                // Encouragement
                InfoCard(
                    icon: "sparkles",
                    iconColor: .momCareAccent,
                    title: "No pressure!",
                    message: "It's completely normal to have low activity levels with a newborn. We'll help you gradually increase as you feel ready."
                )

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(Color.momCareBackground)
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveChanges()
                }
                .foregroundColor(.momCarePrimary)
                .fontWeight(.semibold)
            }
        }
    }

    private func saveChanges() {
        healthProfile.wellnessGoals = Array(selectedGoals)
        healthProfile.activityLevel = selectedActivityLevel

        if let value = Double(targetWeight) {
            let unit = UserProfileManager.shared.measurementUnit
            healthProfile.targetWeight = unit == .metric ? value : MeasurementUnit.lbsToKg(value)
        }

        // Explicitly save to UserProfileManager to ensure persistence
        UserProfileManager.shared.saveHealthProfile(healthProfile)

        onSave()
        dismiss()
    }
}

// MARK: - Reusable Components

struct SelectableOption: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.momCareBody)
                    .foregroundColor(.momCareTextPrimary)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .momCarePrimary : .momCareTextTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.momCareCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.momCarePrimary : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct ComplicationChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.momCareCaption)
                .foregroundColor(isSelected ? .white : .momCareTextPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.momCareWarning : Color.momCareCardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.clear : Color.momCareTextTertiary.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

struct InfoCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.momCareCaptionBold)
                    .foregroundColor(.momCareTextPrimary)

                Text(message)
                    .font(.momCareCaption)
                    .foregroundColor(.momCareTextSecondary)
                    .lineSpacing(4)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(iconColor.opacity(0.1))
        )
    }
}

struct MeasurementInputField: View {
    let title: String
    @Binding var value: String
    let unit: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.momCareCaptionBold)
                    .foregroundColor(.momCareTextSecondary)
            }

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.momCareTextTertiary)
                    .frame(width: 24)

                TextField("Enter value", text: $value)
                    .font(.momCareBody)
                    .foregroundColor(.momCareTextPrimary)
                    .keyboardType(.decimalPad)

                Text(unit)
                    .font(.momCareBody)
                    .foregroundColor(.momCareTextTertiary)
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.momCareCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.momCareTextTertiary.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct EditActivityLevelOption: View {
    let level: ActivityLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(level.rawValue)
                        .font(.momCareBodyBold)
                        .foregroundColor(.momCareTextPrimary)

                    Text(level.description)
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .momCarePrimary : .momCareTextTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.momCareCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.momCarePrimary : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Preview
#Preview {
    EditProfileView(user: .constant(User.sampleUser))
}
