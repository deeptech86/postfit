//
//  HealthData.swift
//  PostFit (MomCare)
//
//  Models for health tracking: nutrition, hydration, exercise, sleep, mood
//

import Foundation

// MARK: - Food & Nutrition

struct FoodEntry: Identifiable, Codable {
    let id: UUID
    var name: String
    var mealType: MealType
    var calories: Int
    var protein: Double // grams
    var carbohydrates: Double // grams
    var fat: Double // grams
    var fiber: Double // grams
    var sugar: Double // grams
    var sodium: Double // mg
    var iron: Double // mg (important for postpartum)
    var calcium: Double // mg (important for breastfeeding)
    var servingSize: String
    var servingCount: Double
    var imageURL: String?
    var isAIRecognized: Bool
    var timestamp: Date
    var notes: String?

    init(
        id: UUID = UUID(),
        name: String,
        mealType: MealType,
        calories: Int,
        protein: Double = 0,
        carbohydrates: Double = 0,
        fat: Double = 0,
        fiber: Double = 0,
        sugar: Double = 0,
        sodium: Double = 0,
        iron: Double = 0,
        calcium: Double = 0,
        servingSize: String = "1 serving",
        servingCount: Double = 1,
        imageURL: String? = nil,
        isAIRecognized: Bool = false,
        timestamp: Date = Date(),
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.mealType = mealType
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.fiber = fiber
        self.sugar = sugar
        self.sodium = sodium
        self.iron = iron
        self.calcium = calcium
        self.servingSize = servingSize
        self.servingCount = servingCount
        self.imageURL = imageURL
        self.isAIRecognized = isAIRecognized
        self.timestamp = timestamp
        self.notes = notes
    }
}

enum MealType: String, Codable, CaseIterable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"

    var icon: String {
        switch self {
        case .breakfast: return "sun.rise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "leaf.fill"
        }
    }

    var suggestedTime: String {
        switch self {
        case .breakfast: return "7:00 AM - 9:00 AM"
        case .lunch: return "12:00 PM - 2:00 PM"
        case .dinner: return "6:00 PM - 8:00 PM"
        case .snack: return "Anytime"
        }
    }
}

struct DailyNutrition: Identifiable, Codable {
    let id: UUID
    let date: Date
    var entries: [FoodEntry]

    var totalCalories: Int {
        entries.reduce(0) { $0 + $1.calories }
    }

    var totalProtein: Double {
        entries.reduce(0) { $0 + $1.protein }
    }

    var totalCarbs: Double {
        entries.reduce(0) { $0 + $1.carbohydrates }
    }

    var totalFat: Double {
        entries.reduce(0) { $0 + $1.fat }
    }

    var totalIron: Double {
        entries.reduce(0) { $0 + $1.iron }
    }

    var totalCalcium: Double {
        entries.reduce(0) { $0 + $1.calcium }
    }

    // Meal-specific entries
    var breakfastEntries: [FoodEntry] {
        entries.filter { $0.mealType == .breakfast }
    }

    var lunchEntries: [FoodEntry] {
        entries.filter { $0.mealType == .lunch }
    }

    var dinnerEntries: [FoodEntry] {
        entries.filter { $0.mealType == .dinner }
    }

    var snackEntries: [FoodEntry] {
        entries.filter { $0.mealType == .snack }
    }

    // Meal-specific calories
    func calories(for mealType: MealType) -> Int {
        entries.filter { $0.mealType == mealType }.reduce(0) { $0 + $1.calories }
    }

    // Add food entry
    mutating func addEntry(_ entry: FoodEntry) {
        entries.append(entry)
    }

    init(id: UUID = UUID(), date: Date = Date(), entries: [FoodEntry] = []) {
        self.id = id
        self.date = date
        self.entries = entries
    }
}

// MARK: - Hydration

struct HydrationEntry: Identifiable, Codable {
    let id: UUID
    var amount: Int // in ml
    var drinkType: DrinkType
    var timestamp: Date

    init(id: UUID = UUID(), amount: Int, drinkType: DrinkType = .water, timestamp: Date = Date()) {
        self.id = id
        self.amount = amount
        self.drinkType = drinkType
        self.timestamp = timestamp
    }
}

enum DrinkType: String, Codable, CaseIterable {
    case water = "Water"
    case tea = "Tea (caffeine-free)"
    case milk = "Milk"
    case juice = "Juice"
    case smoothie = "Smoothie"
    case broth = "Broth/Soup"

    var icon: String {
        switch self {
        case .water: return "drop.fill"
        case .tea: return "cup.and.saucer.fill"
        case .milk: return "mug.fill"
        case .juice: return "carrot.fill"
        case .smoothie: return "takeoutbag.and.cup.and.straw.fill"
        case .broth: return "flame.fill"
        }
    }

    var hydrationFactor: Double {
        switch self {
        case .water: return 1.0
        case .tea, .broth: return 0.9
        case .milk, .juice: return 0.85
        case .smoothie: return 0.8
        }
    }
}

struct DailyHydration: Identifiable, Codable {
    let id: UUID
    let date: Date
    var entries: [HydrationEntry]
    var goal: Int // in glasses (250ml each)

    var totalAmount: Int {
        entries.reduce(0) { $0 + $1.amount }
    }

    var glassesConsumed: Int {
        totalAmount / 250
    }

    var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(glassesConsumed) / Double(goal), 1.0)
    }

    init(id: UUID = UUID(), date: Date = Date(), entries: [HydrationEntry] = [], goal: Int = 8) {
        self.id = id
        self.date = date
        self.entries = entries
        self.goal = goal
    }
}

// MARK: - Exercise

struct Exercise: Identifiable, Codable {
    let id: UUID
    var name: String
    var category: ExerciseCategory
    var recoveryStage: RecoveryStage
    var duration: Int // in minutes
    var caloriesBurned: Int
    var difficulty: ExerciseDifficulty
    var equipment: [String]
    var muscleGroups: [MuscleGroup]
    var videoURL: String?           // Legacy: generic video URL
    var youtubeID: String?          // YouTube video ID (e.g., "dQw4w9WgXcQ")
    var firebaseURL: String?        // Firebase Storage direct URL
    var thumbnailURL: String?
    var instructions: [String]
    var benefits: [String]
    var warnings: [String] // Safety warnings for postpartum
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        name: String,
        category: ExerciseCategory,
        recoveryStage: RecoveryStage,
        duration: Int,
        caloriesBurned: Int,
        difficulty: ExerciseDifficulty,
        equipment: [String] = [],
        muscleGroups: [MuscleGroup] = [],
        videoURL: String? = nil,
        youtubeID: String? = nil,
        firebaseURL: String? = nil,
        thumbnailURL: String? = nil,
        instructions: [String] = [],
        benefits: [String] = [],
        warnings: [String] = [],
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.recoveryStage = recoveryStage
        self.duration = duration
        self.caloriesBurned = caloriesBurned
        self.difficulty = difficulty
        self.equipment = equipment
        self.muscleGroups = muscleGroups
        self.videoURL = videoURL
        self.youtubeID = youtubeID
        self.firebaseURL = firebaseURL
        self.thumbnailURL = thumbnailURL
        self.instructions = instructions
        self.benefits = benefits
        self.warnings = warnings
        self.isFavorite = isFavorite
    }
}

enum ExerciseCategory: String, Codable, CaseIterable {
    case pelvicFloor = "Pelvic Floor"
    case coreReconnection = "Core Reconnection"
    case breathing = "Breathing"
    case yoga = "Yoga"
    case walking = "Walking"
    case strength = "Strength"
    case cardio = "Cardio"
    case stretching = "Stretching"
    case hiit = "HIIT"

    var icon: String {
        switch self {
        case .pelvicFloor: return "figure.stand"
        case .coreReconnection: return "circle.dotted"
        case .breathing: return "wind"
        case .yoga: return "figure.mind.and.body"
        case .walking: return "figure.walk"
        case .strength: return "dumbbell.fill"
        case .cardio: return "heart.fill"
        case .stretching: return "figure.flexibility"
        case .hiit: return "flame.fill"
        }
    }

    var color: String {
        switch self {
        case .pelvicFloor: return "F4A5A5"
        case .coreReconnection: return "F5C9A6"
        case .breathing: return "87CEEB"
        case .yoga: return "B4A7D6"
        case .walking: return "98D8AA"
        case .strength: return "E8A5B8"
        case .cardio: return "FFB6C1"
        case .stretching: return "8ECAE6"
        case .hiit: return "FF6B6B"
        }
    }
}

enum ExerciseDifficulty: String, Codable, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var color: String {
        switch self {
        case .beginner: return "98D8AA"
        case .intermediate: return "F5C9A6"
        case .advanced: return "F4A5A5"
        }
    }
}

enum MuscleGroup: String, Codable, CaseIterable {
    case pelvicFloor = "Pelvic Floor"
    case core = "Core"
    case transverseAbdominis = "Transverse Abdominis"
    case glutes = "Glutes"
    case legs = "Legs"
    case back = "Back"
    case arms = "Arms"
    case shoulders = "Shoulders"
    case chest = "Chest"
    case fullBody = "Full Body"
}

struct WorkoutSession: Identifiable, Codable {
    let id: UUID
    var exercises: [Exercise]
    var startTime: Date
    var endTime: Date?
    var totalDuration: Int // minutes
    var caloriesBurned: Int
    var notes: String?
    var moodBefore: Mood?
    var moodAfter: Mood?

    init(
        id: UUID = UUID(),
        exercises: [Exercise] = [],
        startTime: Date = Date(),
        endTime: Date? = nil,
        totalDuration: Int = 0,
        caloriesBurned: Int = 0,
        notes: String? = nil,
        moodBefore: Mood? = nil,
        moodAfter: Mood? = nil
    ) {
        self.id = id
        self.exercises = exercises
        self.startTime = startTime
        self.endTime = endTime
        self.totalDuration = totalDuration
        self.caloriesBurned = caloriesBurned
        self.notes = notes
        self.moodBefore = moodBefore
        self.moodAfter = moodAfter
    }
}

// MARK: - Sleep

struct SleepEntry: Identifiable, Codable {
    let id: UUID
    var startTime: Date
    var endTime: Date
    var quality: SleepQuality
    var interruptions: Int // Number of times woken up (common with newborn)
    var notes: String?

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    var durationHours: Double {
        duration / 3600
    }

    init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date,
        quality: SleepQuality = .fair,
        interruptions: Int = 0,
        notes: String? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.quality = quality
        self.interruptions = interruptions
        self.notes = notes
    }
}

enum SleepQuality: String, Codable, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"

    var icon: String {
        switch self {
        case .excellent: return "star.fill"
        case .good: return "moon.stars.fill"
        case .fair: return "moon.fill"
        case .poor: return "cloud.moon.fill"
        }
    }

    var color: String {
        switch self {
        case .excellent: return "98D8AA"
        case .good: return "A8C5A8"
        case .fair: return "E5B85C"
        case .poor: return "D98E8E"
        }
    }
}

// MARK: - Mood & Mental Health

struct MoodEntry: Identifiable, Codable {
    let id: UUID
    var mood: Mood
    var energy: EnergyLevel
    var notes: String?
    var triggers: [String]?
    var timestamp: Date

    init(
        id: UUID = UUID(),
        mood: Mood,
        energy: EnergyLevel = .moderate,
        notes: String? = nil,
        triggers: [String]? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.mood = mood
        self.energy = energy
        self.notes = notes
        self.triggers = triggers
        self.timestamp = timestamp
    }
}

enum Mood: String, Codable, CaseIterable {
    case great = "Great"
    case good = "Good"
    case okay = "Okay"
    case low = "Low"
    case struggling = "Struggling"

    var icon: String {
        switch self {
        case .great: return "face.smiling.fill"
        case .good: return "face.smiling"
        case .okay: return "minus.circle.fill"
        case .low: return "cloud.fill"
        case .struggling: return "cloud.rain.fill"
        }
    }

    var color: String {
        switch self {
        case .great: return "98D8AA"
        case .good: return "A8C5A8"
        case .okay: return "F5C9A6"
        case .low: return "E5B85C"
        case .struggling: return "D98E8E"
        }
    }

    var supportMessage: String {
        switch self {
        case .great:
            return "Wonderful! Celebrate these positive moments."
        case .good:
            return "Keep it up! You're doing great."
        case .okay:
            return "It's okay to have neutral days. Be gentle with yourself."
        case .low:
            return "Sending you warmth. Consider reaching out to someone you trust."
        case .struggling:
            return "You're not alone. Please consider talking to a healthcare provider or calling a support line."
        }
    }
}

enum EnergyLevel: String, Codable, CaseIterable {
    case high = "High"
    case moderate = "Moderate"
    case low = "Low"
    case exhausted = "Exhausted"

    var icon: String {
        switch self {
        case .high: return "bolt.fill"
        case .moderate: return "bolt"
        case .low: return "battery.25"
        case .exhausted: return "battery.0"
        }
    }
}

// MARK: - Weight Tracking

struct WeightEntry: Identifiable, Codable {
    let id: UUID
    var weight: Double // in kg
    var date: Date
    var notes: String?

    init(id: UUID = UUID(), weight: Double, date: Date = Date(), notes: String? = nil) {
        self.id = id
        self.weight = weight
        self.date = date
        self.notes = notes
    }
}

// MARK: - Sample Data
extension FoodEntry {
    static let sampleBreakfast = FoodEntry(
        name: "Oatmeal with Berries",
        mealType: .breakfast,
        calories: 350,
        protein: 12,
        carbohydrates: 55,
        fat: 8,
        fiber: 6,
        iron: 3.5,
        calcium: 200
    )

    static let sampleLunch = FoodEntry(
        name: "Grilled Chicken Salad",
        mealType: .lunch,
        calories: 420,
        protein: 35,
        carbohydrates: 20,
        fat: 22,
        iron: 2.0,
        calcium: 100
    )
}

extension Exercise {
    static let sampleKegel = Exercise(
        id: UUID(uuidString: "E1000000-0000-0000-0000-000000000001")!,
        name: "Kegel Exercises (Pelvic Floor Strengthening)",
        category: .pelvicFloor,
        recoveryStage: .earlyRecovery,
        duration: 10,
        caloriesBurned: 15,
        difficulty: .beginner,
        equipment: ["None required - can be done anywhere"],
        muscleGroups: [.pelvicFloor, .core],
        videoURL: "https://www.youtube.com/watch?v=Ip7wrGxqQhM",  // Legacy
        youtubeID: "Ip7wrGxqQhM",  // YouTube streaming
        firebaseURL: "https://firebasestorage.googleapis.com/v0/b/postfit-5efe5.firebasestorage.app/o/exercise-videos%2Fkegel.mp4?alt=media&token=e7d8c8cb-3141-49e2-aa8d-775a999cd9a8",  // TODO: Add after Firebase setup
        thumbnailURL: "https://img.youtube.com/vi/Ip7wrGxqQhM/maxresdefault.jpg",
        instructions: [
            "Find a comfortable position - lying down, sitting, or standing",
            "Identify your pelvic floor muscles by imagining stopping urine mid-flow (but don't actually do this during urination)",
            "Contract and lift these muscles, pulling them upward and inward",
            "Hold the contraction for 5-10 seconds while breathing normally",
            "Release slowly and rest for 5-10 seconds",
            "Repeat 10-15 times per set",
            "Perform 3 sets daily (morning, afternoon, evening)",
            "Focus on isolating pelvic floor muscles - avoid tightening buttocks, thighs, or abdomen",
            "Start with 5-second holds and gradually increase to 10 seconds",
            "Be patient - improvement takes 4-6 weeks of consistent practice"
        ],
        benefits: [
            "Strengthens and tones weakened pelvic floor muscles after childbirth",
            "Improves or prevents urinary incontinence (stress incontinence from coughing, sneezing, laughing)",
            "Enhances bladder and bowel control",
            "Supports uterus, bladder, and bowel in their proper positions",
            "Aids in postpartum recovery and healing",
            "May improve sexual function and sensation",
            "Helps prevent pelvic organ prolapse",
            "Reduces risk of future pelvic floor dysfunction",
            "Can be done discreetly anytime, anywhere",
            "Complements other postpartum exercises for core recovery"
        ],
        warnings: [
            "NEVER do Kegels while urinating - this can weaken muscles and cause urinary tract infections",
            "Stop if you experience pain, discomfort, or burning sensations",
            "Don't hold your breath - breathe normally throughout the exercise",
            "Avoid over-tightening - gentle, controlled contractions are more effective",
            "If you had a C-section, wait for your doctor's clearance (usually 2-4 weeks)",
            "If you had vaginal tearing or episiotomy, start gently after initial healing (consult your provider)",
            "Consult a pelvic floor physical therapist if you're unsure you're doing them correctly",
            "Some women may have overly tight pelvic floors (hypertonic) - Kegels may not be appropriate",
            "If symptoms worsen or don't improve after 6 weeks, seek professional evaluation"
        ]
    )

    static let sampleWalk = Exercise(
        id: UUID(uuidString: "E1000000-0000-0000-0000-000000000002")!,
        name: "Gentle Walking",
        category: .walking,
        recoveryStage: .earlyRecovery,
        duration: 20,
        caloriesBurned: 80,
        difficulty: .beginner,
        equipment: ["Comfortable walking shoes", "Water bottle"],
        muscleGroups: [.legs, .fullBody],
        videoURL: "https://www.youtube.com/watch?v=bO6NNfX_1ns",  // Legacy
        youtubeID: "bO6NNfX_1ns",  // YouTube streaming
        firebaseURL: "https://firebasestorage.googleapis.com/v0/b/postfit-5efe5.firebasestorage.app/o/exercise-videos%2FWalking_indoor.mp4?alt=media&token=cf05c878-0586-4952-aeb2-250a819c36b8",  // TODO: Add after Firebase setup
        thumbnailURL: "https://img.youtube.com/vi/bO6NNfX_1ns/maxresdefault.jpg",
        instructions: [
            "Wear comfortable, supportive shoes",
            "Start with a gentle warm-up - walk slowly for 2-3 minutes",
            "Maintain good posture - shoulders back, head up",
            "Walk at a comfortable, conversational pace",
            "Swing arms naturally at your sides",
            "Start with 10-15 minutes and gradually increase",
            "Stay on flat, even surfaces initially",
            "Take breaks if needed - listen to your body",
            "Cool down with slower walking for 2-3 minutes",
            "Hydrate before, during, and after walking"
        ],
        benefits: [
            "Improves circulation and cardiovascular health",
            "Boosts mood and reduces postpartum depression symptoms",
            "Gentle on recovering body and pelvic floor",
            "Helps with weight management",
            "Increases energy levels",
            "Safe for early postpartum (can start days after delivery with doctor approval)",
            "Can be done with baby in stroller",
            "Promotes better sleep quality"
        ],
        warnings: [
            "Avoid hills or uneven terrain initially",
            "Stop if you experience heavy bleeding, pain, or dizziness",
            "Don't push yourself - fatigue is normal in early postpartum",
            "Wear supportive bra if breastfeeding",
            "Check with your doctor before starting any exercise program"
        ]
    )

    static let sampleBreathing = Exercise(
        id: UUID(uuidString: "E1000000-0000-0000-0000-000000000003")!,
        name: "Diaphragmatic Breathing",
        category: .breathing,
        recoveryStage: .earlyRecovery,
        duration: 5,
        caloriesBurned: 5,
        difficulty: .beginner,
        equipment: ["None required"],
        muscleGroups: [.core],
        videoURL: "https://www.youtube.com/watch?v=O4OAQ4MoYqA",  // Legacy
        youtubeID: "O4OAQ4MoYqA",  // YouTube streaming
        firebaseURL: "https://firebasestorage.googleapis.com/v0/b/postfit-5efe5.firebasestorage.app/o/exercise-videos%2FDiaphragmatic_breathing.mp4?alt=media&token=31b1123c-a942-4c58-a13d-0fd487cd2b11",  // TODO: Add after Firebase setup
        thumbnailURL: "https://img.youtube.com/vi/O4OAQ4MoYqA/maxresdefault.jpg",
        instructions: [
            "Lie on your back or sit comfortably",
            "Place one hand on your chest, one on your belly",
            "Breathe in slowly through your nose for 4 counts",
            "Feel your belly rise (chest stays relatively still)",
            "Exhale slowly through pursed lips for 6 counts",
            "Feel your belly fall",
            "Repeat for 5-10 minutes",
            "Practice 2-3 times daily"
        ],
        benefits: [
            "Reconnects you with core muscles",
            "Reduces stress and anxiety",
            "Promotes healing and relaxation",
            "Improves oxygen flow",
            "Safe from day one postpartum"
        ],
        warnings: [
            "Stop if you feel dizzy",
            "Don't force deep breaths if uncomfortable"
        ]
    )

    static let sampleCatCow = Exercise(
        id: UUID(uuidString: "E1000000-0000-0000-0000-000000000004")!,
        name: "Cat-Cow Stretch",
        category: .yoga,
        recoveryStage: .progressiveStrengthening,
        duration: 5,
        caloriesBurned: 20,
        difficulty: .beginner,
        equipment: ["Yoga mat or comfortable surface"],
        muscleGroups: [.core, .back],
        videoURL: "https://www.youtube.com/watch?v=Nfi3RBLdX6s",  // Legacy
        youtubeID: "Nfi3RBLdX6s",  // YouTube streaming
        firebaseURL: "https://firebasestorage.googleapis.com/v0/b/postfit-5efe5.firebasestorage.app/o/exercise-videos%2FCat_Cows.mp4?alt=media&token=effc1d6c-ea91-4186-a495-9b6c9ac79ef3",  // TODO: Add after Firebase setup
        thumbnailURL: "https://img.youtube.com/vi/Nfi3RBLdX6s/maxresdefault.jpg",
        instructions: [
            "Start on hands and knees (tabletop position)",
            "Hands under shoulders, knees under hips",
            "Inhale: arch back, lift chest and tailbone (Cow)",
            "Exhale: round spine, tuck chin to chest (Cat)",
            "Move slowly between positions",
            "Repeat 10-15 times",
            "Focus on smooth, controlled movement"
        ],
        benefits: [
            "Gently strengthens core muscles",
            "Improves spinal flexibility",
            "Relieves back pain",
            "Promotes mind-body connection",
            "Safe for diastasis recti recovery"
        ],
        warnings: [
            "Avoid if you have wrist pain",
            "Move gently - no extreme arching",
            "Stop if you feel abdominal coning or doming"
        ]
    )

    static let samplePelvicTilts = Exercise(
        id: UUID(uuidString: "E1000000-0000-0000-0000-000000000005")!,
        name: "Pelvic Tilts",
        category: .coreReconnection,
        recoveryStage: .progressiveStrengthening,
        duration: 5,
        caloriesBurned: 15,
        difficulty: .beginner,
        equipment: ["Yoga mat"],
        muscleGroups: [.core, .pelvicFloor],
        videoURL: "https://www.youtube.com/watch?v=APLtYdVQEjQ",  // Legacy
        youtubeID: "APLtYdVQEjQ",  // YouTube streaming
        firebaseURL: "https://firebasestorage.googleapis.com/v0/b/postfit-5efe5.firebasestorage.app/o/exercise-videos%2FPelvic_Tilt_exercise.mp4?alt=media&token=3bbc4876-d8d7-4cb3-a302-d7a8a9462d16",  // TODO: Add after Firebase setup
        thumbnailURL: "https://img.youtube.com/vi/APLtYdVQEjQ/maxresdefault.jpg",
        instructions: [
            "Lie on your back, knees bent, feet flat",
            "Relax your spine in neutral position",
            "Inhale to prepare",
            "Exhale: gently tilt pelvis, pressing lower back to floor",
            "Engage core and pelvic floor simultaneously",
            "Hold for 3-5 seconds",
            "Inhale to release",
            "Repeat 10-15 times"
        ],
        benefits: [
            "Reconnects core and pelvic floor muscles",
            "Reduces lower back pain",
            "Improves posture",
            "Foundational exercise for core recovery",
            "Helps heal diastasis recti"
        ],
        warnings: [
            "Keep movements small and controlled",
            "Don't flatten back completely",
            "Stop if you see abdominal doming"
        ]
    )
}

// MARK: - Exercise Video Integration

extension Exercise {
    /// VideoInfo for caching system integration
    var videoInfo: VideoInfo {
        VideoInfo(
            id: id.uuidString,
            youtubeID: youtubeID,
            downloadURL: firebaseURL ?? videoURL,  // Prefer Firebase, fallback to legacy videoURL
            title: name,
            duration: duration * 60,  // Convert minutes to seconds
            fileSize: estimatedFileSize
        )
    }

    /// Estimated file size in bytes (approximately 10 MB per video)
    var estimatedFileSize: Int64? {
        guard firebaseURL != nil || videoURL != nil else { return nil }
        return 10_485_760  // 10 MB in bytes (reasonable estimate for short exercise videos)
    }

    /// Check if exercise has any video source
    var hasVideo: Bool {
        return youtubeID != nil || firebaseURL != nil || videoURL != nil
    }
}
