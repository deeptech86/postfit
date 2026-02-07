//
//  User.swift
//  PostFit (MomCare)
//
//  User model representing postpartum mothers using the app
//  Contains health profile, preferences, and tracking data
//

import Foundation

// MARK: - User Model
struct User: Identifiable, Codable {
    let id: UUID
    var email: String
    var name: String
    var profileImageURL: String?
    var createdAt: Date
    var lastActiveAt: Date

    // Health profile
    var healthProfile: HealthProfile
    var preferences: UserPreferences
    var subscriptionStatus: SubscriptionStatus

    init(
        id: UUID = UUID(),
        email: String,
        name: String,
        profileImageURL: String? = nil,
        healthProfile: HealthProfile = HealthProfile(),
        preferences: UserPreferences = UserPreferences()
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.profileImageURL = profileImageURL
        self.createdAt = Date()
        self.lastActiveAt = Date()
        self.healthProfile = healthProfile
        self.preferences = preferences
        self.subscriptionStatus = .free
    }
}

// MARK: - Health Profile
struct HealthProfile: Codable {
    var dateOfBirth: Date?
    var deliveryDate: Date?
    var deliveryType: DeliveryType?
    var deliveryComplications: [DeliveryComplication]
    var currentWeight: Double? // in kg
    var prePregnancyWeight: Double? // in kg
    var targetWeight: Double? // in kg
    var height: Double? // in cm
    var isBreastfeeding: Bool
    var breastfeedingIntensity: BreastfeedingIntensity?
    var activityLevel: ActivityLevel
    var medicalConditions: [MedicalCondition]
    var dietaryRestrictions: [DietaryRestriction]
    var wellnessGoals: [WellnessGoal]
    var postpartumWeek: Int? {
        guard let deliveryDate = deliveryDate else { return nil }
        let weeks = Calendar.current.dateComponents([.weekOfYear], from: deliveryDate, to: Date()).weekOfYear
        return weeks
    }

    var recoveryStage: RecoveryStage {
        guard let week = postpartumWeek else { return .earlyRecovery }
        switch week {
        case 0..<6: return .earlyRecovery
        case 6..<12: return .progressiveStrengthening
        case 12..<24: return .buildingStrength
        default: return .fullRecovery
        }
    }

    // Safe weight loss calculation (1-2 lbs/week max, adjusted for breastfeeding)
    var dailyCalorieTarget: Int {
        guard let currentWeight = currentWeight, let height = height else { return 1800 }

        // Basic BMR calculation (Mifflin-St Jeor)
        let bmr = 10 * currentWeight + 6.25 * height - 5 * 30 - 161 // Assuming average age 30

        var tdee = bmr * activityLevel.multiplier

        // Add calories for breastfeeding
        if isBreastfeeding {
            tdee += Double(breastfeedingIntensity?.additionalCalories ?? 400)
        }

        // Moderate deficit for safe weight loss (max 500 cal deficit)
        let targetCalories = max(tdee - 400, 1800) // Never go below 1800 for postpartum mothers

        return Int(targetCalories)
    }

    // Hydration goal adjusted for breastfeeding
    var dailyHydrationGoal: Int {
        let baseGoal = 8 // 8 glasses base
        if isBreastfeeding {
            return Int(Double(baseGoal) * 1.4) // 40% increase for breastfeeding
        }
        return baseGoal
    }

    init(
        dateOfBirth: Date? = nil,
        deliveryDate: Date? = nil,
        deliveryType: DeliveryType? = nil,
        deliveryComplications: [DeliveryComplication] = [],
        currentWeight: Double? = nil,
        prePregnancyWeight: Double? = nil,
        targetWeight: Double? = nil,
        height: Double? = nil,
        isBreastfeeding: Bool = false,
        breastfeedingIntensity: BreastfeedingIntensity? = nil,
        activityLevel: ActivityLevel = .light,
        medicalConditions: [MedicalCondition] = [],
        dietaryRestrictions: [DietaryRestriction] = [],
        wellnessGoals: [WellnessGoal] = []
    ) {
        self.dateOfBirth = dateOfBirth
        self.deliveryDate = deliveryDate
        self.deliveryType = deliveryType
        self.deliveryComplications = deliveryComplications
        self.currentWeight = currentWeight
        self.prePregnancyWeight = prePregnancyWeight
        self.targetWeight = targetWeight
        self.height = height
        self.isBreastfeeding = isBreastfeeding
        self.breastfeedingIntensity = breastfeedingIntensity
        self.activityLevel = activityLevel
        self.medicalConditions = medicalConditions
        self.dietaryRestrictions = dietaryRestrictions
        self.wellnessGoals = wellnessGoals
    }
}

// MARK: - Enums

enum DeliveryType: String, Codable, CaseIterable {
    case vaginal = "Vaginal Delivery"
    case cesarean = "Cesarean Section (C-Section)"
    case vbac = "VBAC (Vaginal Birth After Cesarean)"

    var recoveryConsiderations: String {
        switch self {
        case .vaginal:
            return "Standard postpartum recovery. Light activity can begin when comfortable."
        case .cesarean:
            return "Major abdominal surgery requires 6-8 weeks before resuming exercise. Avoid core work initially."
        case .vbac:
            return "Monitor for any complications. Follow standard vaginal delivery recovery guidelines."
        }
    }
}

enum RecoveryStage: String, Codable, CaseIterable {
    case earlyRecovery = "Early Recovery (0-6 weeks)"
    case progressiveStrengthening = "Progressive Strengthening (6-12 weeks)"
    case buildingStrength = "Building Strength (3-6 months)"
    case fullRecovery = "Full Recovery (6-12 months)"

    var description: String {
        switch self {
        case .earlyRecovery:
            return "Focus on rest, healing, and gentle movements"
        case .progressiveStrengthening:
            return "Gradually rebuilding core strength and stamina"
        case .buildingStrength:
            return "Increasing intensity and variety of exercises"
        case .fullRecovery:
            return "Return to full fitness activities"
        }
    }

    var allowedExerciseIntensity: String {
        switch self {
        case .earlyRecovery: return "Very Light"
        case .progressiveStrengthening: return "Light to Moderate"
        case .buildingStrength: return "Moderate"
        case .fullRecovery: return "Moderate to High"
        }
    }
}

enum BreastfeedingIntensity: String, Codable, CaseIterable {
    case exclusive = "Exclusive Breastfeeding"
    case mostlyBreastfeeding = "Mostly Breastfeeding"
    case mixed = "Mixed (Breast + Formula)"
    case pumping = "Exclusively Pumping"

    var additionalCalories: Int {
        switch self {
        case .exclusive, .pumping: return 500
        case .mostlyBreastfeeding: return 400
        case .mixed: return 250
        }
    }
}

enum ActivityLevel: String, Codable, CaseIterable {
    case sedentary = "Sedentary"
    case light = "Lightly Active"
    case moderate = "Moderately Active"
    case active = "Very Active"

    var description: String {
        switch self {
        case .sedentary: return "Little to no exercise, mostly resting with baby"
        case .light: return "Light walks, gentle stretching 1-3 times/week"
        case .moderate: return "Moderate exercise 3-5 times/week"
        case .active: return "Active lifestyle, exercise most days"
        }
    }

    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        }
    }
}

enum MedicalCondition: String, Codable, CaseIterable {
    case diastasisRecti = "Diastasis Recti"
    case gestationalDiabetes = "Gestational Diabetes (History)"
    case preeclampsia = "Preeclampsia (History)"
    case postpartumDepression = "Postpartum Depression"
    case postpartumAnxiety = "Postpartum Anxiety"
    case thyroidIssues = "Thyroid Issues"
    case anemia = "Anemia"
    case pelvicFloorWeakness = "Pelvic Floor Weakness"
    case backPain = "Back Pain"
    case none = "None"

    var exerciseModifications: String {
        switch self {
        case .diastasisRecti:
            return "Avoid crunches, planks, and exercises that cause abdominal doming"
        case .gestationalDiabetes:
            return "Monitor blood sugar, focus on steady-state cardio"
        case .preeclampsia:
            return "Check blood pressure regularly, avoid high-intensity initially"
        case .postpartumDepression, .postpartumAnxiety:
            return "Prioritize mood-boosting activities, outdoor walks"
        case .thyroidIssues:
            return "Adjust intensity based on energy levels"
        case .anemia:
            return "Lower intensity exercise, focus on iron-rich nutrition"
        case .pelvicFloorWeakness:
            return "Prioritize pelvic floor exercises, avoid high-impact"
        case .backPain:
            return "Focus on posture correction and core strengthening"
        case .none:
            return "Standard postpartum exercise progression"
        }
    }
}

enum DietaryRestriction: String, Codable, CaseIterable {
    case vegetarian = "Vegetarian"
    case vegan = "Vegan"
    case glutenFree = "Gluten-Free"
    case dairyFree = "Dairy-Free"
    case nutAllergy = "Nut Allergy"
    case lowSodium = "Low Sodium"
    case kosher = "Kosher"
    case halal = "Halal"
    case none = "None"
}

enum DeliveryComplication: String, Codable, CaseIterable {
    case none = "None"
    case hemorrhage = "Postpartum Hemorrhage"
    case infection = "Infection"
    case preterm = "Preterm Delivery"
    case prolongedLabor = "Prolonged Labor"
    case tearOrEpisiotomy = "Perineal Tear/Episiotomy"
    case placentaIssues = "Placenta Issues"
    case bloodPressure = "High Blood Pressure"
    case emergencyCSection = "Emergency C-Section"
    case other = "Other"

    var recoveryConsiderations: String {
        switch self {
        case .none:
            return "Standard postpartum recovery."
        case .hemorrhage:
            return "May need extra iron and rest. Monitor for fatigue and dizziness."
        case .infection:
            return "Complete prescribed antibiotics. Watch for fever or unusual discharge."
        case .preterm:
            return "Baby may need extra care. Breast milk pumping support available."
        case .prolongedLabor:
            return "May experience more fatigue. Take extra rest and recover gradually."
        case .tearOrEpisiotomy:
            return "Pelvic floor exercises recommended after healing. Avoid heavy lifting initially."
        case .placentaIssues:
            return "Monitor bleeding levels. Follow up with healthcare provider as scheduled."
        case .bloodPressure:
            return "Continue monitoring blood pressure. Reduce sodium intake."
        case .emergencyCSection:
            return "Major surgery recovery - 6-8 weeks before resuming exercise. Avoid core work initially."
        case .other:
            return "Follow your healthcare provider's specific recommendations."
        }
    }
}

enum WellnessGoal: String, Codable, CaseIterable {
    case loseWeight = "Healthy weight loss"
    case gainEnergy = "More energy"
    case eatHealthier = "Eat healthier"
    case exercise = "Start exercising"
    case sleep = "Better sleep"
    case mentalHealth = "Mental wellness"
    case hydration = "Stay hydrated"
    case strength = "Build strength"
    case flexibility = "Improve flexibility"
    case stressRelief = "Stress relief"

    var icon: String {
        switch self {
        case .loseWeight: return "scalemass.fill"
        case .gainEnergy: return "bolt.fill"
        case .eatHealthier: return "leaf.fill"
        case .exercise: return "figure.run"
        case .sleep: return "moon.fill"
        case .mentalHealth: return "brain.head.profile"
        case .hydration: return "drop.fill"
        case .strength: return "dumbbell.fill"
        case .flexibility: return "figure.flexibility"
        case .stressRelief: return "heart.circle.fill"
        }
    }
}

// MARK: - User Preferences
struct UserPreferences: Codable {
    var notificationsEnabled: Bool
    var reminderTimes: ReminderTimes
    var measurementUnit: MeasurementUnit
    var language: String
    var darkModeEnabled: Bool
    var hapticFeedbackEnabled: Bool

    init(
        notificationsEnabled: Bool = true,
        reminderTimes: ReminderTimes = ReminderTimes(),
        measurementUnit: MeasurementUnit = .metric,
        language: String = "en",
        darkModeEnabled: Bool = false,
        hapticFeedbackEnabled: Bool = true
    ) {
        self.notificationsEnabled = notificationsEnabled
        self.reminderTimes = reminderTimes
        self.measurementUnit = measurementUnit
        self.language = language
        self.darkModeEnabled = darkModeEnabled
        self.hapticFeedbackEnabled = hapticFeedbackEnabled
    }
}

struct ReminderTimes: Codable {
    var morningCheckIn: Date?
    var mealReminders: Bool
    var hydrationInterval: Int // minutes
    var exerciseReminder: Date?
    var eveningReflection: Date?

    init(
        morningCheckIn: Date? = nil,
        mealReminders: Bool = true,
        hydrationInterval: Int = 90,
        exerciseReminder: Date? = nil,
        eveningReflection: Date? = nil
    ) {
        self.morningCheckIn = morningCheckIn
        self.mealReminders = mealReminders
        self.hydrationInterval = hydrationInterval
        self.exerciseReminder = exerciseReminder
        self.eveningReflection = eveningReflection
    }
}

enum MeasurementUnit: String, Codable, CaseIterable {
    case metric = "Metric (kg, cm)"
    case imperial = "Imperial (lbs, ft/in)"

    var weightUnit: String {
        switch self {
        case .metric: return "kg"
        case .imperial: return "lbs"
        }
    }

    var heightUnit: String {
        switch self {
        case .metric: return "cm"
        case .imperial: return "ft/in"
        }
    }

    // MARK: - Conversion Methods

    /// Convert kg to lbs
    static func kgToLbs(_ kg: Double) -> Double {
        return kg * 2.20462
    }

    /// Convert lbs to kg
    static func lbsToKg(_ lbs: Double) -> Double {
        return lbs / 2.20462
    }

    /// Convert cm to feet and inches string
    static func cmToFeetInches(_ cm: Double) -> String {
        let totalInches = cm / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
        return "\(feet)'\(inches)\""
    }

    /// Convert feet and inches to cm
    static func feetInchesToCm(feet: Int, inches: Int) -> Double {
        let totalInches = Double(feet * 12 + inches)
        return totalInches * 2.54
    }

    /// Format weight value based on unit
    func formatWeight(_ kgValue: Double?) -> String {
        guard let kg = kgValue else { return "--" }
        switch self {
        case .metric:
            return String(format: "%.1f", kg)
        case .imperial:
            return String(format: "%.1f", MeasurementUnit.kgToLbs(kg))
        }
    }

    /// Format height value based on unit
    func formatHeight(_ cmValue: Double?) -> String {
        guard let cm = cmValue else { return "--" }
        switch self {
        case .metric:
            return String(format: "%.0f", cm)
        case .imperial:
            return MeasurementUnit.cmToFeetInches(cm)
        }
    }
}

enum SubscriptionStatus: String, Codable {
    case free = "Free"
    case premium = "Premium"
    case trial = "Trial"

    var features: [String] {
        switch self {
        case .free:
            return ["Basic food logging", "Limited exercises", "Water reminders", "Weight tracking"]
        case .trial, .premium:
            return ["AI food recognition", "Personalized meal plans", "Full exercise library", "Advanced analytics", "Expert consultations"]
        }
    }
}

// MARK: - Sample Data
extension User {
    static let sampleUser = User(
        email: "sarah@example.com",
        name: "Sarah",
        healthProfile: HealthProfile(
            dateOfBirth: Calendar.current.date(byAdding: .year, value: -32, to: Date()),
            deliveryDate: Calendar.current.date(byAdding: .weekOfYear, value: -8, to: Date()),
            deliveryType: .vaginal,
            deliveryComplications: [],
            currentWeight: 68,
            prePregnancyWeight: 62,
            targetWeight: 64,
            height: 165,
            isBreastfeeding: true,
            breastfeedingIntensity: .exclusive,
            activityLevel: .light,
            wellnessGoals: [.loseWeight, .gainEnergy, .exercise]
        )
    )
}
