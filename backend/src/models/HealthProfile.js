/**
 * MomCare API - Health Profile Model
 *
 * Manages postpartum-specific health data including delivery info,
 * breastfeeding status, weight goals, and medical conditions.
 */

const db = require('../config/database');
const { encrypt, decrypt } = require('../utils/encryption');
const logger = require('../utils/logger');

class HealthProfile {
  /**
   * Create or update health profile
   * @param {string} userId - User UUID
   * @param {Object} profileData - Health profile data
   * @returns {Promise<Object>}
   */
  static async upsert(userId, profileData) {
    const {
      dateOfBirth,
      heightCm,
      deliveryDate,
      deliveryType,
      numberOfChildren = 1,
      wasMultipleBirth = false,
      prePregnancyWeightKg,
      deliveryWeightKg,
      currentWeightKg,
      targetWeightKg,
      isBreastfeeding = false,
      breastfeedingIntensity,
      breastfeedingStartDate,
      activityLevel = 'light',
      medicalConditions = ['none'],
      dietaryRestrictions = ['none'],
      exerciseClearedByDoctor = false,
      exerciseClearanceDate,
      doctorNotes,
    } = profileData;

    // Encrypt sensitive medical notes
    const encryptedDoctorNotes = doctorNotes ? encrypt(doctorNotes) : null;

    const query = `
      INSERT INTO health_profiles (
        user_id, date_of_birth, height_cm, delivery_date, delivery_type,
        number_of_children, was_multiple_birth, pre_pregnancy_weight_kg,
        delivery_weight_kg, current_weight_kg, target_weight_kg,
        is_breastfeeding, breastfeeding_intensity, breastfeeding_start_date,
        activity_level, medical_conditions, dietary_restrictions,
        exercise_cleared_by_doctor, exercise_clearance_date, doctor_notes
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20)
      ON CONFLICT (user_id)
      DO UPDATE SET
        date_of_birth = COALESCE($2, health_profiles.date_of_birth),
        height_cm = COALESCE($3, health_profiles.height_cm),
        delivery_date = COALESCE($4, health_profiles.delivery_date),
        delivery_type = COALESCE($5, health_profiles.delivery_type),
        number_of_children = COALESCE($6, health_profiles.number_of_children),
        was_multiple_birth = COALESCE($7, health_profiles.was_multiple_birth),
        pre_pregnancy_weight_kg = COALESCE($8, health_profiles.pre_pregnancy_weight_kg),
        delivery_weight_kg = COALESCE($9, health_profiles.delivery_weight_kg),
        current_weight_kg = COALESCE($10, health_profiles.current_weight_kg),
        target_weight_kg = COALESCE($11, health_profiles.target_weight_kg),
        is_breastfeeding = COALESCE($12, health_profiles.is_breastfeeding),
        breastfeeding_intensity = COALESCE($13, health_profiles.breastfeeding_intensity),
        breastfeeding_start_date = COALESCE($14, health_profiles.breastfeeding_start_date),
        activity_level = COALESCE($15, health_profiles.activity_level),
        medical_conditions = COALESCE($16, health_profiles.medical_conditions),
        dietary_restrictions = COALESCE($17, health_profiles.dietary_restrictions),
        exercise_cleared_by_doctor = COALESCE($18, health_profiles.exercise_cleared_by_doctor),
        exercise_clearance_date = COALESCE($19, health_profiles.exercise_clearance_date),
        doctor_notes = COALESCE($20, health_profiles.doctor_notes),
        updated_at = NOW()
      RETURNING *
    `;

    const values = [
      userId,
      dateOfBirth,
      heightCm,
      deliveryDate,
      deliveryType,
      numberOfChildren,
      wasMultipleBirth,
      prePregnancyWeightKg,
      deliveryWeightKg,
      currentWeightKg,
      targetWeightKg,
      isBreastfeeding,
      breastfeedingIntensity,
      breastfeedingStartDate,
      activityLevel,
      medicalConditions,
      dietaryRestrictions,
      exerciseClearedByDoctor,
      exerciseClearanceDate,
      encryptedDoctorNotes,
    ];

    const result = await db.query(query, values);
    return this.formatProfile(result.rows[0]);
  }

  /**
   * Get health profile by user ID
   * @param {string} userId - User UUID
   * @returns {Promise<Object|null>}
   */
  static async findByUserId(userId) {
    const query = `
      SELECT * FROM health_profiles WHERE user_id = $1
    `;

    const result = await db.readQuery(query, [userId]);
    if (result.rows.length === 0) return null;

    return this.formatProfile(result.rows[0]);
  }

  /**
   * Update current weight
   * @param {string} userId - User UUID
   * @param {number} weightKg - Current weight in kg
   * @returns {Promise<Object>}
   */
  static async updateWeight(userId, weightKg) {
    const query = `
      UPDATE health_profiles
      SET current_weight_kg = $2, updated_at = NOW()
      WHERE user_id = $1
      RETURNING *
    `;

    const result = await db.query(query, [userId, weightKg]);
    return this.formatProfile(result.rows[0]);
  }

  /**
   * Update breastfeeding status
   * @param {string} userId - User UUID
   * @param {boolean} isBreastfeeding - Is currently breastfeeding
   * @param {string} intensity - Breastfeeding intensity
   * @returns {Promise<Object>}
   */
  static async updateBreastfeedingStatus(userId, isBreastfeeding, intensity = null) {
    const query = `
      UPDATE health_profiles
      SET is_breastfeeding = $2,
          breastfeeding_intensity = $3,
          updated_at = NOW()
      WHERE user_id = $1
      RETURNING *
    `;

    const result = await db.query(query, [userId, isBreastfeeding, intensity]);
    return this.formatProfile(result.rows[0]);
  }

  /**
   * Get recovery stage based on postpartum weeks
   * @param {string} userId - User UUID
   * @returns {Promise<Object>}
   */
  static async getRecoveryStage(userId) {
    const query = `
      SELECT
        postpartum_weeks,
        CASE
          WHEN postpartum_weeks < 6 THEN 'early_recovery'
          WHEN postpartum_weeks < 12 THEN 'progressive_strengthening'
          WHEN postpartum_weeks < 24 THEN 'building_strength'
          ELSE 'full_recovery'
        END as recovery_stage,
        delivery_type,
        exercise_cleared_by_doctor
      FROM health_profiles
      WHERE user_id = $1
    `;

    const result = await db.readQuery(query, [userId]);
    if (result.rows.length === 0) return null;

    const profile = result.rows[0];

    // Add stage-specific guidance
    const stageGuidance = {
      early_recovery: {
        title: 'Early Recovery (0-6 weeks)',
        description: 'Focus on rest, healing, and gentle movements',
        allowedIntensity: 'Very Light',
        exerciseTypes: ['pelvic_floor', 'breathing', 'walking'],
        warning: profile.delivery_type === 'cesarean'
          ? 'C-section recovery requires extra care. Avoid any ab work.'
          : null,
      },
      progressive_strengthening: {
        title: 'Progressive Strengthening (6-12 weeks)',
        description: 'Gradually rebuilding core strength and stamina',
        allowedIntensity: 'Light to Moderate',
        exerciseTypes: ['pelvic_floor', 'core_reconnection', 'yoga', 'walking', 'stretching'],
        warning: !profile.exercise_cleared_by_doctor
          ? 'Please get clearance from your healthcare provider before increasing intensity.'
          : null,
      },
      building_strength: {
        title: 'Building Strength (3-6 months)',
        description: 'Increasing intensity and variety of exercises',
        allowedIntensity: 'Moderate',
        exerciseTypes: ['strength', 'cardio', 'yoga', 'hiit'],
        warning: null,
      },
      full_recovery: {
        title: 'Full Recovery (6-12 months)',
        description: 'Return to full fitness activities',
        allowedIntensity: 'Moderate to High',
        exerciseTypes: ['strength', 'cardio', 'hiit', 'yoga'],
        warning: null,
      },
    };

    return {
      postpartumWeeks: profile.postpartum_weeks,
      stage: profile.recovery_stage,
      exerciseCleared: profile.exercise_cleared_by_doctor,
      ...stageGuidance[profile.recovery_stage],
    };
  }

  /**
   * Calculate daily calorie target
   * @param {string} userId - User UUID
   * @returns {Promise<Object>}
   */
  static async calculateCalorieTarget(userId) {
    const query = `
      SELECT
        current_weight_kg,
        height_cm,
        date_of_birth,
        is_breastfeeding,
        breastfeeding_intensity,
        activity_level,
        target_weight_kg
      FROM health_profiles
      WHERE user_id = $1
    `;

    const result = await db.readQuery(query, [userId]);
    if (result.rows.length === 0) return null;

    const profile = result.rows[0];

    // Calculate age
    const age = profile.date_of_birth
      ? Math.floor((Date.now() - new Date(profile.date_of_birth)) / (365.25 * 24 * 60 * 60 * 1000))
      : 30; // Default to 30 if not provided

    // Mifflin-St Jeor equation for BMR (women)
    const bmr = profile.current_weight_kg && profile.height_cm
      ? 10 * profile.current_weight_kg + 6.25 * profile.height_cm - 5 * age - 161
      : 1500; // Default BMR

    // Activity multipliers
    const activityMultipliers = {
      sedentary: 1.2,
      light: 1.375,
      moderate: 1.55,
      active: 1.725,
    };

    const multiplier = activityMultipliers[profile.activity_level] || 1.375;
    let tdee = bmr * multiplier;

    // Add calories for breastfeeding
    const breastfeedingCalories = {
      exclusive: 500,
      mostly_breastfeeding: 400,
      mixed: 250,
      pumping: 500,
    };

    if (profile.is_breastfeeding && profile.breastfeeding_intensity) {
      tdee += breastfeedingCalories[profile.breastfeeding_intensity] || 300;
    }

    // Calculate safe deficit (max 500 cal, never below 1800 for postpartum)
    const targetCalories = Math.max(Math.round(tdee - 400), 1800);

    // Macro breakdown (40% carbs, 30% protein, 30% fat)
    const macros = {
      protein: Math.round((targetCalories * 0.30) / 4), // 4 cal per gram
      carbohydrates: Math.round((targetCalories * 0.40) / 4),
      fat: Math.round((targetCalories * 0.30) / 9), // 9 cal per gram
    };

    return {
      bmr: Math.round(bmr),
      tdee: Math.round(tdee),
      targetCalories,
      macros,
      breastfeedingAdjustment: profile.is_breastfeeding
        ? breastfeedingCalories[profile.breastfeeding_intensity] || 0
        : 0,
      disclaimer: 'These calculations are estimates. Consult with a healthcare provider or registered dietitian for personalized advice.',
    };
  }

  /**
   * Calculate daily hydration goal
   * @param {string} userId - User UUID
   * @returns {Promise<Object>}
   */
  static async calculateHydrationGoal(userId) {
    const query = `
      SELECT
        current_weight_kg,
        is_breastfeeding,
        breastfeeding_intensity,
        activity_level
      FROM health_profiles
      WHERE user_id = $1
    `;

    const result = await db.readQuery(query, [userId]);
    if (result.rows.length === 0) return null;

    const profile = result.rows[0];

    // Base: 30-35ml per kg of body weight
    let baseGoalMl = (profile.current_weight_kg || 65) * 33;

    // Increase for breastfeeding (30-50% more)
    if (profile.is_breastfeeding) {
      const breastfeedingMultiplier = {
        exclusive: 1.5,
        mostly_breastfeeding: 1.4,
        mixed: 1.3,
        pumping: 1.5,
      };
      baseGoalMl *= breastfeedingMultiplier[profile.breastfeeding_intensity] || 1.4;
    }

    // Increase for activity level
    const activityMultiplier = {
      sedentary: 1.0,
      light: 1.1,
      moderate: 1.2,
      active: 1.3,
    };
    baseGoalMl *= activityMultiplier[profile.activity_level] || 1.1;

    const goalMl = Math.round(baseGoalMl);
    const goalGlasses = Math.round(goalMl / 250); // 250ml per glass

    return {
      goalMl,
      goalGlasses,
      glassSize: 250,
      isBreastfeeding: profile.is_breastfeeding,
      recommendation: profile.is_breastfeeding
        ? 'Breastfeeding increases your hydration needs. Drink a glass of water each time you nurse or pump.'
        : 'Staying well-hydrated supports your energy levels and recovery.',
    };
  }

  /**
   * Format profile for API response
   * @param {Object} profile - Raw database profile
   * @returns {Object} Formatted profile
   */
  static formatProfile(profile) {
    if (!profile) return null;

    // Decrypt sensitive data if present
    const doctorNotes = profile.doctor_notes ? decrypt(profile.doctor_notes) : null;

    return {
      id: profile.id,
      userId: profile.user_id,
      dateOfBirth: profile.date_of_birth,
      heightCm: parseFloat(profile.height_cm),
      deliveryDate: profile.delivery_date,
      deliveryType: profile.delivery_type,
      numberOfChildren: profile.number_of_children,
      wasMultipleBirth: profile.was_multiple_birth,
      prePregnancyWeightKg: parseFloat(profile.pre_pregnancy_weight_kg),
      deliveryWeightKg: parseFloat(profile.delivery_weight_kg),
      currentWeightKg: parseFloat(profile.current_weight_kg),
      targetWeightKg: parseFloat(profile.target_weight_kg),
      isBreastfeeding: profile.is_breastfeeding,
      breastfeedingIntensity: profile.breastfeeding_intensity,
      breastfeedingStartDate: profile.breastfeeding_start_date,
      activityLevel: profile.activity_level,
      medicalConditions: profile.medical_conditions,
      dietaryRestrictions: profile.dietary_restrictions,
      exerciseClearedByDoctor: profile.exercise_cleared_by_doctor,
      exerciseClearanceDate: profile.exercise_clearance_date,
      doctorNotes,
      postpartumWeeks: profile.postpartum_weeks,
      createdAt: profile.created_at,
      updatedAt: profile.updated_at,
    };
  }
}

module.exports = HealthProfile;
