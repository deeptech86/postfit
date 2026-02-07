/**
 * MomCare API - Exercise Model
 *
 * Manages exercise library and workout sessions with postpartum-safe filtering.
 */

const db = require('../config/database');
const logger = require('../utils/logger');

class Exercise {
  /**
   * Get all exercises with optional filters
   * @param {Object} filters - Filter options
   * @returns {Promise<Array>}
   */
  static async findAll(filters = {}) {
    const {
      category,
      recoveryStage,
      difficulty,
      maxDuration,
      isPremium,
      muscleGroups,
      page = 1,
      limit = 20,
    } = filters;

    let query = `
      SELECT * FROM exercises
      WHERE is_active = TRUE
    `;

    const values = [];
    let paramIndex = 1;

    if (category) {
      query += ` AND category = $${paramIndex++}`;
      values.push(category);
    }

    if (recoveryStage) {
      query += ` AND recovery_stage = $${paramIndex++}`;
      values.push(recoveryStage);
    }

    if (difficulty) {
      query += ` AND difficulty = $${paramIndex++}`;
      values.push(difficulty);
    }

    if (maxDuration) {
      query += ` AND duration_minutes <= $${paramIndex++}`;
      values.push(maxDuration);
    }

    if (isPremium !== undefined) {
      query += ` AND is_premium = $${paramIndex++}`;
      values.push(isPremium);
    }

    if (muscleGroups && muscleGroups.length > 0) {
      query += ` AND muscle_groups && $${paramIndex++}`;
      values.push(muscleGroups);
    }

    query += ` ORDER BY sort_order ASC, name ASC`;
    query += ` LIMIT $${paramIndex++} OFFSET $${paramIndex}`;
    values.push(limit, (page - 1) * limit);

    const result = await db.readQuery(query, values);
    return result.rows.map(this.formatExercise);
  }

  /**
   * Get exercises safe for a specific recovery stage
   * @param {string} recoveryStage - User's recovery stage
   * @param {boolean} includePremium - Include premium exercises
   * @returns {Promise<Array>}
   */
  static async getForRecoveryStage(recoveryStage, includePremium = true) {
    // Define which stages are safe at each recovery level
    const safeStages = {
      early_recovery: ['early_recovery'],
      progressive_strengthening: ['early_recovery', 'progressive_strengthening'],
      building_strength: ['early_recovery', 'progressive_strengthening', 'building_strength'],
      full_recovery: ['early_recovery', 'progressive_strengthening', 'building_strength', 'full_recovery'],
    };

    const allowedStages = safeStages[recoveryStage] || ['early_recovery'];

    let query = `
      SELECT * FROM exercises
      WHERE is_active = TRUE
        AND recovery_stage = ANY($1)
    `;

    const values = [allowedStages];

    if (!includePremium) {
      query += ` AND is_premium = FALSE`;
    }

    query += ` ORDER BY
      CASE recovery_stage
        WHEN 'early_recovery' THEN 1
        WHEN 'progressive_strengthening' THEN 2
        WHEN 'building_strength' THEN 3
        WHEN 'full_recovery' THEN 4
      END,
      sort_order ASC
    `;

    const result = await db.readQuery(query, values);
    return result.rows.map(this.formatExercise);
  }

  /**
   * Get exercise by ID
   * @param {string} exerciseId - Exercise UUID
   * @returns {Promise<Object|null>}
   */
  static async findById(exerciseId) {
    const query = `SELECT * FROM exercises WHERE id = $1 AND is_active = TRUE`;
    const result = await db.readQuery(query, [exerciseId]);
    return result.rows[0] ? this.formatExercise(result.rows[0]) : null;
  }

  /**
   * Get exercises by category
   * @param {string} category - Exercise category
   * @param {string} recoveryStage - User's recovery stage (optional)
   * @returns {Promise<Array>}
   */
  static async findByCategory(category, recoveryStage = null) {
    let query = `
      SELECT * FROM exercises
      WHERE is_active = TRUE AND category = $1
    `;

    const values = [category];

    if (recoveryStage) {
      // Filter to appropriate recovery stages
      const safeStages = {
        early_recovery: ['early_recovery'],
        progressive_strengthening: ['early_recovery', 'progressive_strengthening'],
        building_strength: ['early_recovery', 'progressive_strengthening', 'building_strength'],
        full_recovery: ['early_recovery', 'progressive_strengthening', 'building_strength', 'full_recovery'],
      };
      query += ` AND recovery_stage = ANY($2)`;
      values.push(safeStages[recoveryStage] || ['early_recovery']);
    }

    query += ` ORDER BY difficulty ASC, sort_order ASC`;

    const result = await db.readQuery(query, values);
    return result.rows.map(this.formatExercise);
  }

  /**
   * Get user's favorite exercises
   * @param {string} userId - User UUID
   * @returns {Promise<Array>}
   */
  static async getFavorites(userId) {
    const query = `
      SELECT e.* FROM exercises e
      INNER JOIN favorite_exercises fe ON e.id = fe.exercise_id
      WHERE fe.user_id = $1 AND e.is_active = TRUE
      ORDER BY fe.created_at DESC
    `;

    const result = await db.readQuery(query, [userId]);
    return result.rows.map(this.formatExercise);
  }

  /**
   * Toggle favorite status
   * @param {string} userId - User UUID
   * @param {string} exerciseId - Exercise UUID
   * @returns {Promise<boolean>} True if favorited, false if unfavorited
   */
  static async toggleFavorite(userId, exerciseId) {
    const checkQuery = `
      SELECT id FROM favorite_exercises
      WHERE user_id = $1 AND exercise_id = $2
    `;
    const checkResult = await db.query(checkQuery, [userId, exerciseId]);

    if (checkResult.rows.length > 0) {
      // Remove from favorites
      await db.query(
        `DELETE FROM favorite_exercises WHERE user_id = $1 AND exercise_id = $2`,
        [userId, exerciseId]
      );
      return false;
    } else {
      // Add to favorites
      await db.query(
        `INSERT INTO favorite_exercises (user_id, exercise_id) VALUES ($1, $2)`,
        [userId, exerciseId]
      );
      return true;
    }
  }

  /**
   * Check if exercise is favorited
   * @param {string} userId - User UUID
   * @param {string} exerciseId - Exercise UUID
   * @returns {Promise<boolean>}
   */
  static async isFavorite(userId, exerciseId) {
    const query = `
      SELECT id FROM favorite_exercises
      WHERE user_id = $1 AND exercise_id = $2
    `;
    const result = await db.readQuery(query, [userId, exerciseId]);
    return result.rows.length > 0;
  }

  /**
   * Search exercises
   * @param {string} searchTerm - Search term
   * @param {Object} filters - Additional filters
   * @returns {Promise<Array>}
   */
  static async search(searchTerm, filters = {}) {
    const { recoveryStage, limit = 20 } = filters;

    let query = `
      SELECT * FROM exercises
      WHERE is_active = TRUE
        AND (name ILIKE $1 OR description ILIKE $1)
    `;

    const values = [`%${searchTerm}%`];

    if (recoveryStage) {
      const safeStages = {
        early_recovery: ['early_recovery'],
        progressive_strengthening: ['early_recovery', 'progressive_strengthening'],
        building_strength: ['early_recovery', 'progressive_strengthening', 'building_strength'],
        full_recovery: ['early_recovery', 'progressive_strengthening', 'building_strength', 'full_recovery'],
      };
      query += ` AND recovery_stage = ANY($2)`;
      values.push(safeStages[recoveryStage] || ['early_recovery']);
    }

    query += ` ORDER BY name ASC LIMIT $${values.length + 1}`;
    values.push(limit);

    const result = await db.readQuery(query, values);
    return result.rows.map(this.formatExercise);
  }

  /**
   * Get recommended exercises for user
   * @param {string} userId - User UUID
   * @param {Object} healthProfile - User's health profile
   * @returns {Promise<Array>}
   */
  static async getRecommendations(userId, healthProfile) {
    const { recoveryStage, medicalConditions = [], exerciseClearedByDoctor } = healthProfile;

    // Get appropriate exercises for recovery stage
    let exercises = await this.getForRecoveryStage(recoveryStage, false);

    // Filter based on medical conditions
    if (medicalConditions.includes('diastasis_recti')) {
      // Exclude exercises that may worsen diastasis
      exercises = exercises.filter(e =>
        e.category !== 'hiit' &&
        !e.warnings?.some(w => w.toLowerCase().includes('diastasis'))
      );
    }

    if (medicalConditions.includes('pelvic_floor_weakness')) {
      // Prioritize pelvic floor exercises
      exercises.sort((a, b) => {
        if (a.category === 'pelvic_floor') return -1;
        if (b.category === 'pelvic_floor') return 1;
        return 0;
      });
    }

    // If not cleared by doctor and in early stages, limit intensity
    if (!exerciseClearedByDoctor && ['early_recovery', 'progressive_strengthening'].includes(recoveryStage)) {
      exercises = exercises.filter(e => e.difficulty === 'beginner');
    }

    // Limit recommendations
    return exercises.slice(0, 10);
  }

  /**
   * Format exercise for API response
   * @param {Object} exercise - Raw database exercise
   * @returns {Object}
   */
  static formatExercise(exercise) {
    if (!exercise) return null;

    return {
      id: exercise.id,
      name: exercise.name,
      description: exercise.description,
      category: exercise.category,
      recoveryStage: exercise.recovery_stage,
      difficulty: exercise.difficulty,
      durationMinutes: exercise.duration_minutes,
      caloriesBurned: exercise.calories_burned,
      equipment: exercise.equipment || [],
      muscleGroups: exercise.muscle_groups || [],
      videoUrl: exercise.video_url,
      thumbnailUrl: exercise.thumbnail_url,
      instructions: exercise.instructions || [],
      benefits: exercise.benefits || [],
      warnings: exercise.warnings || [],
      isPremium: exercise.is_premium,
      createdAt: exercise.created_at,
    };
  }
}

module.exports = Exercise;
