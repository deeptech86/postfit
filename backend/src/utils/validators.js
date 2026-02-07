/**
 * MomCare API - Validation Utilities
 *
 * Input validation schemas and helpers for all API endpoints
 * Uses Joi for declarative validation
 */

const Joi = require('joi');

// Common validation patterns
const patterns = {
  uuid: /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,
  password: /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/,
  phone: /^\+?[1-9]\d{1,14}$/,
};

// Custom Joi extensions
const customJoi = Joi.extend((joi) => ({
  type: 'string',
  base: joi.string(),
  messages: {
    'string.strongPassword':
      'Password must contain at least one uppercase, lowercase, number, and special character',
  },
  rules: {
    strongPassword: {
      validate(value, helpers) {
        if (!patterns.password.test(value)) {
          return helpers.error('string.strongPassword');
        }
        return value;
      },
    },
  },
}));

// ============================================================================
// Authentication Schemas
// ============================================================================

const authSchemas = {
  register: Joi.object({
    email: Joi.string().email().required().max(255),
    password: customJoi.string().strongPassword().min(8).max(128).required(),
    name: Joi.string().min(2).max(100).required(),
    acceptTerms: Joi.boolean().valid(true).required(),
    marketingConsent: Joi.boolean().default(false),
    // Health profile fields for postpartum tracking
    deliveryDate: Joi.date().max('now').required(),
    deliveryType: Joi.string().valid('vaginal', 'cesarean', 'assisted').required(),
    isBreastfeeding: Joi.boolean().required(),
  }),

  login: Joi.object({
    email: Joi.string().email().required(),
    password: Joi.string().required(),
    deviceId: Joi.string().max(255),
    deviceType: Joi.string().valid('ios', 'android', 'web'),
    pushToken: Joi.string().max(500),
  }),

  refreshToken: Joi.object({
    refreshToken: Joi.string().required(),
  }),

  forgotPassword: Joi.object({
    email: Joi.string().email().required(),
  }),

  resetPassword: Joi.object({
    token: Joi.string().required(),
    password: customJoi.string().strongPassword().min(8).max(128).required(),
  }),

  changePassword: Joi.object({
    currentPassword: Joi.string().required(),
    newPassword: customJoi.string().strongPassword().min(8).max(128).required(),
  }),

  oauthLogin: Joi.object({
    provider: Joi.string().valid('apple', 'google', 'facebook').required(),
    token: Joi.string().required(),
    deviceId: Joi.string().max(255),
    deviceType: Joi.string().valid('ios', 'android', 'web'),
  }),
};

// ============================================================================
// User & Profile Schemas
// ============================================================================

const userSchemas = {
  updateProfile: Joi.object({
    name: Joi.string().min(2).max(100),
    profileImageURL: Joi.string().uri().max(500),
    phone: Joi.string().pattern(patterns.phone).allow(null),
    timezone: Joi.string().max(50),
    locale: Joi.string().max(10),
  }),

  healthProfile: Joi.object({
    dateOfBirth: Joi.date().max('now').allow(null),
    deliveryDate: Joi.date().max('now').allow(null),
    deliveryType: Joi.string().valid('vaginal', 'cesarean', 'vbac').allow(null),
    currentWeight: Joi.number().min(30).max(300).allow(null),
    prePregnancyWeight: Joi.number().min(30).max(300).allow(null),
    targetWeight: Joi.number().min(30).max(300).allow(null),
    height: Joi.number().min(100).max(250).allow(null),
    isBreastfeeding: Joi.boolean(),
    breastfeedingIntensity: Joi.string()
      .valid('exclusive', 'mostly_breastfeeding', 'mixed', 'pumping')
      .allow(null),
    activityLevel: Joi.string()
      .valid('sedentary', 'light', 'moderate', 'active'),
    medicalConditions: Joi.array().items(
      Joi.string().valid(
        'diastasis_recti',
        'gestational_diabetes',
        'preeclampsia',
        'postpartum_depression',
        'postpartum_anxiety',
        'thyroid_issues',
        'anemia',
        'pelvic_floor_weakness',
        'back_pain',
        'none'
      )
    ),
    dietaryRestrictions: Joi.array().items(
      Joi.string().valid(
        'vegetarian',
        'vegan',
        'gluten_free',
        'dairy_free',
        'nut_allergy',
        'low_sodium',
        'kosher',
        'halal',
        'none'
      )
    ),
  }),

  preferences: Joi.object({
    notificationsEnabled: Joi.boolean(),
    mealReminders: Joi.boolean(),
    hydrationInterval: Joi.number().min(15).max(480),
    morningCheckIn: Joi.string().pattern(/^\d{2}:\d{2}$/),
    eveningReflection: Joi.string().pattern(/^\d{2}:\d{2}$/),
    exerciseReminder: Joi.string().pattern(/^\d{2}:\d{2}$/),
    measurementUnit: Joi.string().valid('metric', 'imperial'),
    language: Joi.string().valid('en', 'es', 'hi'),
    darkModeEnabled: Joi.boolean(),
    hapticFeedbackEnabled: Joi.boolean(),
  }),
};

// ============================================================================
// Food & Nutrition Schemas
// ============================================================================

const foodSchemas = {
  createFoodEntry: Joi.object({
    name: Joi.string().min(1).max(200).required(),
    mealType: Joi.string().valid('breakfast', 'lunch', 'dinner', 'snack').required(),
    calories: Joi.number().min(0).max(10000).required(),
    protein: Joi.number().min(0).max(500).default(0),
    carbohydrates: Joi.number().min(0).max(1000).default(0),
    fat: Joi.number().min(0).max(500).default(0),
    fiber: Joi.number().min(0).max(200).default(0),
    sugar: Joi.number().min(0).max(500).default(0),
    sodium: Joi.number().min(0).max(10000).default(0),
    iron: Joi.number().min(0).max(100).default(0),
    calcium: Joi.number().min(0).max(5000).default(0),
    servingSize: Joi.string().max(100).default('1 serving'),
    servingCount: Joi.number().min(0.1).max(100).default(1),
    imageURL: Joi.string().uri().max(500).allow(null),
    barcode: Joi.string().max(50).allow(null),
    usdaFoodId: Joi.string().max(50).allow(null),
    notes: Joi.string().max(500).allow(null),
    timestamp: Joi.date().default(() => new Date()),
  }),

  updateFoodEntry: Joi.object({
    name: Joi.string().min(1).max(200),
    mealType: Joi.string().valid('breakfast', 'lunch', 'dinner', 'snack'),
    calories: Joi.number().min(0).max(10000),
    protein: Joi.number().min(0).max(500),
    carbohydrates: Joi.number().min(0).max(1000),
    fat: Joi.number().min(0).max(500),
    fiber: Joi.number().min(0).max(200),
    sugar: Joi.number().min(0).max(500),
    sodium: Joi.number().min(0).max(10000),
    iron: Joi.number().min(0).max(100),
    calcium: Joi.number().min(0).max(5000),
    servingSize: Joi.string().max(100),
    servingCount: Joi.number().min(0.1).max(100),
    notes: Joi.string().max(500).allow(null),
  }),

  aiRecognition: Joi.object({
    imageUrl: Joi.string().uri().required(),
    mealType: Joi.string().valid('breakfast', 'lunch', 'dinner', 'snack'),
  }),

  searchFood: Joi.object({
    query: Joi.string().min(2).max(100).required(),
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(50).default(20),
  }),
};

// ============================================================================
// Hydration Schemas
// ============================================================================

const hydrationSchemas = {
  createEntry: Joi.object({
    amount: Joi.number().min(1).max(5000).required(),
    drinkType: Joi.string()
      .valid('water', 'tea', 'milk', 'juice', 'smoothie', 'broth')
      .default('water'),
    timestamp: Joi.date().default(() => new Date()),
  }),

  updateEntry: Joi.object({
    amount: Joi.number().min(1).max(5000),
    drinkType: Joi.string().valid('water', 'tea', 'milk', 'juice', 'smoothie', 'broth'),
  }),

  getDailyGoal: Joi.object({
    date: Joi.date().default(() => new Date()),
  }),
};

// ============================================================================
// Exercise Schemas
// ============================================================================

const exerciseSchemas = {
  startWorkout: Joi.object({
    exerciseIds: Joi.array().items(Joi.string().pattern(patterns.uuid)).required(),
    moodBefore: Joi.string().valid('great', 'good', 'okay', 'low', 'struggling'),
  }),

  completeWorkout: Joi.object({
    duration: Joi.number().min(1).max(600).required(),
    caloriesBurned: Joi.number().min(0).max(5000).default(0),
    moodAfter: Joi.string().valid('great', 'good', 'okay', 'low', 'struggling'),
    notes: Joi.string().max(500).allow(null),
    exerciseCompletions: Joi.array().items(
      Joi.object({
        exerciseId: Joi.string().pattern(patterns.uuid).required(),
        completed: Joi.boolean().required(),
        reps: Joi.number().min(0),
        sets: Joi.number().min(0),
        duration: Joi.number().min(0),
      })
    ),
  }),

  listExercises: Joi.object({
    category: Joi.string().valid(
      'pelvic_floor',
      'core_reconnection',
      'breathing',
      'yoga',
      'walking',
      'strength',
      'cardio',
      'stretching',
      'hiit'
    ),
    recoveryStage: Joi.string().valid(
      'early_recovery',
      'progressive_strengthening',
      'building_strength',
      'full_recovery'
    ),
    difficulty: Joi.string().valid('beginner', 'intermediate', 'advanced'),
    duration: Joi.number().min(5).max(120),
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(50).default(20),
  }),
};

// ============================================================================
// Sleep Schemas
// ============================================================================

const sleepSchemas = {
  createEntry: Joi.object({
    startTime: Joi.date().required(),
    endTime: Joi.date().greater(Joi.ref('startTime')).required(),
    quality: Joi.string().valid('excellent', 'good', 'fair', 'poor').default('fair'),
    interruptions: Joi.number().integer().min(0).max(50).default(0),
    notes: Joi.string().max(500).allow(null),
  }),

  updateEntry: Joi.object({
    startTime: Joi.date(),
    endTime: Joi.date(),
    quality: Joi.string().valid('excellent', 'good', 'fair', 'poor'),
    interruptions: Joi.number().integer().min(0).max(50),
    notes: Joi.string().max(500).allow(null),
  }),
};

// ============================================================================
// Mental Health Schemas
// ============================================================================

const mentalHealthSchemas = {
  createMoodEntry: Joi.object({
    mood: Joi.string().valid('great', 'good', 'okay', 'low', 'struggling').required(),
    energy: Joi.string().valid('high', 'moderate', 'low', 'exhausted').default('moderate'),
    notes: Joi.string().max(1000).allow(null),
    triggers: Joi.array().items(Joi.string().max(100)),
    timestamp: Joi.date().default(() => new Date()),
  }),

  edinburghScale: Joi.object({
    answers: Joi.array()
      .items(Joi.number().integer().min(0).max(3))
      .length(10)
      .required(),
    timestamp: Joi.date().default(() => new Date()),
  }),

  journalEntry: Joi.object({
    content: Joi.string().min(1).max(10000).required(),
    mood: Joi.string().valid('great', 'good', 'okay', 'low', 'struggling'),
    isPrivate: Joi.boolean().default(true),
    timestamp: Joi.date().default(() => new Date()),
  }),
};

// ============================================================================
// Weight & Measurements Schemas
// ============================================================================

const weightSchemas = {
  createEntry: Joi.object({
    weight: Joi.number().min(20).max(500).required(),
    date: Joi.date().max('now').default(() => new Date()),
    notes: Joi.string().max(500).allow(null),
  }),

  bodyMeasurements: Joi.object({
    bust: Joi.number().min(30).max(200).allow(null),
    waist: Joi.number().min(30).max(200).allow(null),
    hips: Joi.number().min(30).max(200).allow(null),
    thigh: Joi.number().min(20).max(100).allow(null),
    arm: Joi.number().min(10).max(60).allow(null),
    date: Joi.date().max('now').default(() => new Date()),
    notes: Joi.string().max(500).allow(null),
  }),
};

// ============================================================================
// Baby Care Schemas
// ============================================================================

const babyCareSchemas = {
  breastfeedingSession: Joi.object({
    startTime: Joi.date().required(),
    endTime: Joi.date().greater(Joi.ref('startTime')),
    side: Joi.string().valid('left', 'right', 'both').required(),
    duration: Joi.number().min(1).max(120),
    notes: Joi.string().max(500).allow(null),
  }),

  diaperChange: Joi.object({
    type: Joi.string().valid('wet', 'dirty', 'both').required(),
    timestamp: Joi.date().default(() => new Date()),
    notes: Joi.string().max(500).allow(null),
  }),

  babySleep: Joi.object({
    startTime: Joi.date().required(),
    endTime: Joi.date().greater(Joi.ref('startTime')),
    notes: Joi.string().max(500).allow(null),
  }),
};

// ============================================================================
// Community Schemas
// ============================================================================

const communitySchemas = {
  createPost: Joi.object({
    title: Joi.string().min(5).max(200).required(),
    content: Joi.string().min(10).max(10000).required(),
    category: Joi.string()
      .valid(
        'general',
        'nutrition',
        'exercise',
        'mental_health',
        'breastfeeding',
        'sleep',
        'success_stories'
      )
      .required(),
    tags: Joi.array().items(Joi.string().max(50)).max(5),
    isAnonymous: Joi.boolean().default(false),
  }),

  createComment: Joi.object({
    content: Joi.string().min(1).max(2000).required(),
    parentCommentId: Joi.string().pattern(patterns.uuid).allow(null),
    isAnonymous: Joi.boolean().default(false),
  }),

  reportContent: Joi.object({
    contentType: Joi.string().valid('post', 'comment').required(),
    contentId: Joi.string().pattern(patterns.uuid).required(),
    reason: Joi.string()
      .valid('spam', 'harassment', 'misinformation', 'inappropriate', 'other')
      .required(),
    details: Joi.string().max(1000).allow(null),
  }),
};

// ============================================================================
// Subscription Schemas
// ============================================================================

const subscriptionSchemas = {
  createCheckout: Joi.object({
    priceId: Joi.string().required(),
    successUrl: Joi.string().uri().required(),
    cancelUrl: Joi.string().uri().required(),
  }),

  validateReceipt: Joi.object({
    platform: Joi.string().valid('ios', 'android').required(),
    receipt: Joi.string().required(),
    productId: Joi.string().required(),
  }),
};

// ============================================================================
// Pagination & Query Schemas
// ============================================================================

const paginationSchema = Joi.object({
  page: Joi.number().integer().min(1).default(1),
  limit: Joi.number().integer().min(1).max(100).default(20),
  sortBy: Joi.string().max(50),
  sortOrder: Joi.string().valid('asc', 'desc').default('desc'),
});

const dateRangeSchema = Joi.object({
  startDate: Joi.date().required(),
  endDate: Joi.date().min(Joi.ref('startDate')).required(),
});

// ============================================================================
// Validation Helper
// ============================================================================

/**
 * Validate request data against schema
 * @param {Object} schema - Joi schema
 * @param {Object} data - Data to validate
 * @returns {{value: Object, error: Object|null}}
 */
function validate(schema, data) {
  const { value, error } = schema.validate(data, {
    abortEarly: false,
    stripUnknown: true,
    convert: true,
  });

  if (error) {
    const errors = error.details.map((detail) => ({
      field: detail.path.join('.'),
      message: detail.message,
    }));
    return { value: null, error: errors };
  }

  return { value, error: null };
}

module.exports = {
  validate,
  patterns,
  authSchemas,
  userSchemas,
  foodSchemas,
  hydrationSchemas,
  exerciseSchemas,
  sleepSchemas,
  mentalHealthSchemas,
  weightSchemas,
  babyCareSchemas,
  communitySchemas,
  subscriptionSchemas,
  paginationSchema,
  dateRangeSchema,
};
