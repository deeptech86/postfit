//
//  ProfileSetupView.swift
//  PostFit (MomCare)
//
//  Profile setup flow for collecting health information
//  Designed with sensitivity and care for new mothers
//

import SwiftUI

// MARK: - Profile Setup Container
struct ProfileSetupView: View {
    @State private var currentStep = 0
    @State private var healthProfile = HealthProfile()
    @Binding var isProfileComplete: Bool

    private let totalSteps = 5

    var body: some View {
        ZStack {
            Color.momCareBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                ProfileSetupProgressBar(currentStep: currentStep, totalSteps: totalSteps)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                // Step content
                TabView(selection: $currentStep) {
                    DeliveryInfoStep(healthProfile: $healthProfile) {
                        nextStep()
                    }
                    .tag(0)

                    BreastfeedingStep(healthProfile: $healthProfile) {
                        nextStep()
                    }
                    .tag(1)

                    BodyMeasurementsStep(healthProfile: $healthProfile) {
                        nextStep()
                    }
                    .tag(2)

                    ActivityLevelStep(healthProfile: $healthProfile) {
                        nextStep()
                    }
                    .tag(3)

                    GoalsStep(healthProfile: $healthProfile) {
                        completeSetup()
                    }
                    .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
                // Disable TabView's horizontal swipe gestures to allow vertical scrolling
                .gesture(DragGesture().onEnded({ _ in }))
            }
        }
        .navigationBarBackButtonHidden(currentStep > 0)
        .toolbar {
            // Back button
            if currentStep > 0 {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: previousStep) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.momCareButtonSecondary)
                        .foregroundColor(.momCareTextSecondary)
                    }
                }
            }

            // Skip button - always shown
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Skip") {
                    skipProfileSetup()
                }
                .font(.momCareButtonSecondary)
                .foregroundColor(.momCarePrimary)
            }
        }
    }

    private func nextStep() {
        withAnimation {
            if currentStep < totalSteps - 1 {
                currentStep += 1
            }
        }
    }

    private func previousStep() {
        withAnimation {
            if currentStep > 0 {
                currentStep -= 1
            }
        }
    }

    private func completeSetup() {
        // Save health profile data to UserProfileManager
        UserProfileManager.shared.saveHealthProfile(healthProfile)

        #if DEBUG
        print("✅ [Profile Setup] Health profile saved successfully")
        #endif

        isProfileComplete = true
    }

    private func skipProfileSetup() {
        // Skip all remaining steps and mark profile as complete
        // User can fill this information later from Profile section
        isProfileComplete = true

        #if DEBUG
        print("🔄 [Profile Setup] User skipped profile setup")
        #endif
    }
}

// MARK: - Progress Bar
struct ProfileSetupProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(step <= currentStep ? Color.momCarePrimary : Color.momCarePrimary.opacity(0.2))
                        .frame(height: 4)
                        .animation(.easeInOut, value: currentStep)
                }
            }

            HStack {
                Text("Step \(currentStep + 1) of \(totalSteps)")
                    .font(.momCareCaption)
                    .foregroundColor(.momCareTextTertiary)
                Spacer()
            }
        }
    }
}

// MARK: - Step 1: Delivery Information
struct DeliveryInfoStep: View {
    @Binding var healthProfile: HealthProfile
    let onContinue: () -> Void

    @State private var selectedDeliveryType: DeliveryType?
    @State private var deliveryDate = Date()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                ProfileStepHeader(
                    icon: "heart.text.square.fill",
                    iconColor: .momCarePrimary,
                    title: "About Your Delivery",
                    subtitle: "This helps us personalize your recovery journey"
                )

                // Delivery date - More compact style
                VStack(alignment: .leading, spacing: 10) {
                    Text("When did you deliver?")
                        .font(.momCareBodyBold)
                        .foregroundColor(.momCareTextPrimary)

                    DatePicker(
                        "Delivery Date",
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

                // Delivery type
                VStack(alignment: .leading, spacing: 10) {
                    Text("How did you deliver?")
                        .font(.momCareBodyBold)
                        .foregroundColor(.momCareTextPrimary)

                    VStack(spacing: 8) {
                        ForEach(DeliveryType.allCases.filter { $0 != .vbac }, id: \.self) { type in
                            DeliveryTypeOption(
                                type: type,
                                isSelected: selectedDeliveryType == type
                            ) {
                                selectedDeliveryType = type
                            }
                        }
                    }
                }

                // Recovery info card - More compact
                if let type = selectedDeliveryType {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.momCareInfo)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Recovery Note")
                                .font(.momCareCaptionBold)
                                .foregroundColor(.momCareTextPrimary)

                            Text(type.recoveryConsiderations)
                                .font(.momCareCaption)
                                .foregroundColor(.momCareTextSecondary)
                                .lineSpacing(3)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.momCareInfo.opacity(0.1))
                    )
                }

                // Continue button - Always visible at bottom
                MomCarePrimaryButton("Continue") {
                    healthProfile.deliveryDate = deliveryDate
                    healthProfile.deliveryType = selectedDeliveryType
                    onContinue()
                }
                .disabled(selectedDeliveryType == nil)
                .opacity(selectedDeliveryType == nil ? 0.6 : 1.0)
                .padding(.top, 8)
                .padding(.bottom, 50)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
        }
    }
}

struct DeliveryTypeOption: View {
    let type: DeliveryType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.rawValue)
                        .font(.momCareBody)
                        .foregroundColor(.momCareTextPrimary)
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

// MARK: - Step 2: Breastfeeding
struct BreastfeedingStep: View {
    @Binding var healthProfile: HealthProfile
    let onContinue: () -> Void

    @State private var isBreastfeeding = false
    @State private var selectedIntensity: BreastfeedingIntensity?

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                ProfileStepHeader(
                    icon: "heart.fill",
                    iconColor: .momCarePrimary,
                    title: "Feeding Your Baby",
                    subtitle: "This helps us adjust your nutrition recommendations"
                )

                // Breastfeeding toggle
                MomCareCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Are you breastfeeding?")
                                .font(.momCareBodyBold)
                                .foregroundColor(.momCareTextPrimary)

                            Spacer()

                            Toggle("", isOn: $isBreastfeeding)
                                .tint(.momCarePrimary)
                        }

                        if isBreastfeeding {
                            Divider()

                            Text("How often are you breastfeeding?")
                                .font(.momCareBody)
                                .foregroundColor(.momCareTextSecondary)

                            VStack(spacing: 12) {
                                ForEach(BreastfeedingIntensity.allCases, id: \.self) { intensity in
                                    BreastfeedingOption(
                                        intensity: intensity,
                                        isSelected: selectedIntensity == intensity
                                    ) {
                                        selectedIntensity = intensity
                                    }
                                }
                            }
                        }
                    }
                }

                // Nutrition info card
                if isBreastfeeding, let intensity = selectedIntensity {
                    MomCareCard {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "fork.knife")
                                .foregroundColor(.momCareNutrition)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Extra Calories Needed")
                                    .font(.momCareCaptionBold)
                                    .foregroundColor(.momCareTextPrimary)

                                Text("We'll add approximately \(intensity.additionalCalories) calories to your daily target to support milk production.")
                                    .font(.momCareCaption)
                                    .foregroundColor(.momCareTextSecondary)
                                    .lineSpacing(4)
                            }
                        }
                    }
                }

                Spacer()
                    .frame(height: 60)

                // Continue button
                MomCarePrimaryButton("Continue") {
                    healthProfile.isBreastfeeding = isBreastfeeding
                    healthProfile.breastfeedingIntensity = selectedIntensity
                    onContinue()
                }
                .disabled(isBreastfeeding && selectedIntensity == nil)
                .opacity(isBreastfeeding && selectedIntensity == nil ? 0.6 : 1.0)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct BreastfeedingOption: View {
    let intensity: BreastfeedingIntensity
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(intensity.rawValue)
                    .font(.momCareBody)
                    .foregroundColor(.momCareTextPrimary)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .momCarePrimary : .momCareTextTertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.momCarePrimary.opacity(0.1) : Color.momCareSecondaryBackground)
            )
        }
    }
}

// MARK: - Step 3: Body Measurements
struct BodyMeasurementsStep: View {
    @Binding var healthProfile: HealthProfile
    let onContinue: () -> Void

    @State private var currentWeight = ""
    @State private var prePregnancyWeight = ""
    @State private var height = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                ProfileStepHeader(
                    icon: "scalemass.fill",
                    iconColor: .momCareAccent,
                    title: "Your Measurements",
                    subtitle: "Optional but helps personalize your plan"
                )

                // Measurement inputs
                VStack(spacing: 20) {
                    MeasurementInput(
                        title: "Current Weight",
                        value: $currentWeight,
                        unit: "kg",
                        icon: "scalemass.fill"
                    )

                    MeasurementInput(
                        title: "Pre-Pregnancy Weight",
                        value: $prePregnancyWeight,
                        unit: "kg",
                        icon: "arrow.left.arrow.right"
                    )

                    MeasurementInput(
                        title: "Height",
                        value: $height,
                        unit: "cm",
                        icon: "ruler.fill"
                    )
                }

                // Body positive message
                MomCareCard {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "heart.circle.fill")
                            .foregroundColor(.momCarePrimary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Remember")
                                .font(.momCareCaptionBold)
                                .foregroundColor(.momCareTextPrimary)

                            Text("Your body just did something amazing. We're here to support your health journey, not to pressure you. Every body is different, and recovery takes time.")
                                .font(.momCareCaption)
                                .foregroundColor(.momCareTextSecondary)
                                .lineSpacing(4)
                        }
                    }
                }

                Spacer()
                    .frame(height: 60)

                // Continue buttons
                VStack(spacing: 12) {
                    MomCarePrimaryButton("Continue") {
                        saveWeights()
                        onContinue()
                    }

                    Button("Skip for now") {
                        onContinue()
                    }
                    .font(.momCareButtonSecondary)
                    .foregroundColor(.momCareTextSecondary)
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
    }

    private func saveWeights() {
        healthProfile.currentWeight = Double(currentWeight)
        healthProfile.prePregnancyWeight = Double(prePregnancyWeight)
        healthProfile.height = Double(height)
    }
}

struct MeasurementInput: View {
    let title: String
    @Binding var value: String
    let unit: String
    let icon: String

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

// MARK: - Step 4: Activity Level
struct ActivityLevelStep: View {
    @Binding var healthProfile: HealthProfile
    let onContinue: () -> Void

    @State private var selectedLevel: ActivityLevel?

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                ProfileStepHeader(
                    icon: "figure.walk",
                    iconColor: .momCareExercise,
                    title: "Your Current Activity",
                    subtitle: "How active are you right now?"
                )

                // Activity level options
                VStack(spacing: 12) {
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        ActivityLevelOption(
                            level: level,
                            isSelected: selectedLevel == level
                        ) {
                            selectedLevel = level
                        }
                    }
                }

                // Encouragement card
                MomCareCard {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.momCareAccent)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("No pressure!")
                                .font(.momCareCaptionBold)
                                .foregroundColor(.momCareTextPrimary)

                            Text("It's completely normal to have low activity levels with a newborn. We'll help you gradually increase as you feel ready.")
                                .font(.momCareCaption)
                                .foregroundColor(.momCareTextSecondary)
                                .lineSpacing(4)
                        }
                    }
                }

                Spacer()
                    .frame(height: 60)

                MomCarePrimaryButton("Continue") {
                    healthProfile.activityLevel = selectedLevel ?? .light
                    onContinue()
                }
                .disabled(selectedLevel == nil)
                .opacity(selectedLevel == nil ? 0.6 : 1.0)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct ActivityLevelOption: View {
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

// MARK: - Step 5: Goals
struct GoalsStep: View {
    @Binding var healthProfile: HealthProfile
    let onContinue: () -> Void

    @State private var targetWeight = ""
    @State private var selectedGoals: Set<WellnessGoal> = []

    enum WellnessGoal: String, CaseIterable {
        case loseWeight = "Healthy weight loss"
        case gainEnergy = "More energy"
        case eatHealthier = "Eat healthier"
        case exercise = "Start exercising"
        case sleep = "Better sleep"
        case mentalHealth = "Mental wellness"
        case hydration = "Stay hydrated"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                ProfileStepHeader(
                    icon: "star.fill",
                    iconColor: .momCareAccent,
                    title: "Your Wellness Goals",
                    subtitle: "What would you like to focus on?"
                )

                // Goals selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select your goals (choose all that apply)")
                        .font(.momCareCaptionBold)
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

                // Target weight (optional)
                if selectedGoals.contains(.loseWeight) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Target weight (optional)")
                            .font(.momCareCaptionBold)
                            .foregroundColor(.momCareTextSecondary)

                        MeasurementInput(
                            title: "",
                            value: $targetWeight,
                            unit: "kg",
                            icon: "target"
                        )

                        Text("We recommend losing 0.5-1 kg per week for sustainable, healthy weight loss.")
                            .font(.momCareCaption)
                            .foregroundColor(.momCareTextTertiary)
                    }
                }

                // Celebration card
                MomCareGradientCard {
                    VStack(spacing: 12) {
                        Image(systemName: "hands.clap.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.momCareTextPrimary)

                        Text("You're all set!")
                            .font(.momCareHeading2)
                            .foregroundColor(.momCareTextPrimary)

                        Text("We'll create a personalized plan just for you based on your goals and recovery stage.")
                            .font(.momCareBody)
                            .foregroundColor(.momCareTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                }

                Spacer()
                    .frame(height: 60)

                MomCarePrimaryButton("Start My Journey", icon: "arrow.right") {
                    healthProfile.targetWeight = Double(targetWeight)
                    onContinue()
                }
                .disabled(selectedGoals.isEmpty)
                .opacity(selectedGoals.isEmpty ? 0.6 : 1.0)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct GoalChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.momCareCaptionBold)
                .foregroundColor(isSelected ? .white : .momCareTextPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.momCarePrimary : Color.momCareCardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : Color.momCareTextTertiary.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

// MARK: - Flow Layout for Goals
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                     y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var maxY: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y = maxY + spacing
                }
                positions.append(CGPoint(x: x, y: y))
                x += size.width + spacing
                maxY = max(maxY, y + size.height)
            }

            self.size = CGSize(width: maxWidth, height: maxY)
        }
    }
}

// MARK: - Profile Step Header
struct ProfileStepHeader: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundColor(iconColor)
            }
            .padding(.top, 24)

            VStack(spacing: 8) {
                Text(title)
                    .font(.momCareHeading1)
                    .foregroundColor(.momCareTextPrimary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.momCareBody)
                    .foregroundColor(.momCareTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        ProfileSetupView(isProfileComplete: .constant(false))
    }
}
