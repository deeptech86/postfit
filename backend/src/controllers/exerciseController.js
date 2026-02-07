/**
 * MomCare API - Exercise Controller
 *
 * Handles exercise library, workout tracking, and postpartum-safe recommendations.
 */

const { Exercise, HealthProfile } = require('../models');
const db = require('../config/database');
const { success, created, notFound, healthResponse, premiumRequired, paginated } = require('../utils/apiResponse');
const { cache } = require('../config/redis');
const logger = require('../utils/logger');

/**
 * Get exercises with filters
 * GET /api/v1/exercises
 */
async function getExercises(req, res, next) {
  try {
    const userId = req.user.id;
    const { category, recoveryStage, difficulty, maxDuration, page = 1, limit = 20 } = req.query;

    // Get user's recovery stage if not specified
    let targetRecoveryStage = recoveryStage;
    if (!targetRecoveryStage) {
      const stageData = await HealthProfile.getRecoveryStage(userId);
      targetRecoveryStage = stageData?.stage;
    }

    // Check if user is premium for all exercises
    const isPremium = ['premium', 'trial'].includes(req.user.subscription_status);

    const filters = {
      category,
      recoveryStage: targetRecoveryStage,
      difficulty,
      maxDuration: maxDuration ? parseInt(maxDuration, 10) : null,
      isPremium: isPremium ? undefined : false, // Free users only see free exercises
      page: parseInt(page, 10),
      limit: parseInt(limit, 10),
    };

    const exercises = await Exercise.findAll(filters);

    // Get favorites for user
    const favorites = await Exercise.getFavorites(userId);
    const favoriteIds = new Set(favorites.map(f => f.id));

    // Mark favorites
    const exercisesWithFavorites = exercises.map(e => ({
      ...e,
      isFavorite: favoriteIds.has(e.id),
    }));

    return healthResponse(res, {
      exercises: exercisesWithFavorites,
      filters: {
        category,
        recoveryStage: targetRecoveryStage,
        difficulty,
        maxDuration,
      },
    }, 'exercise');
  } catch (err) {
    next(err);
  }
}

/**
 * Get exercise by ID
 * GET /api/v1/exercises/:id
 */
async function getExercise(req, res, next) {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    const exercise = await Exercise.findById(id);

    if (!exercise) {
      return notFound(res, 'Exercise');
    }

    // Check premium access
    if (exercise.isPremium) {
      const isPremium = ['premium', 'trial'].includes(req.user.subscription_status);
      if (!isPremium) {
        return premiumRequired(res, 'This exercise');
      }
    }

    // Check if favorited
    const isFavorite = await Exercise.isFavorite(userId, id);

    // Get user's recovery stage for safety check
    const stageData = await HealthProfile.getRecoveryStage(userId);

    // Add safety warning if exercise is above user's stage
    let safetyWarning = null;
    const stageOrder = ['early_recovery', 'progressive_strengthening', 'building_strength', 'full_recovery'];
    const userStageIndex = stageOrder.indexOf(stageData?.stage);
    const exerciseStageIndex = stageOrder.indexOf(exercise.recoveryStage);

    if (exerciseStageIndex > userStageIndex) {
      safetyWarning = {
        level: 'caution',
        message: `This exercise is recommended for ${exercise.recoveryStage.replace('_', ' ')}. You are currently in ${stageData?.stage.replace('_', ' ')}. Please consult your healthcare provider before attempting.`,
      };
    }

    return healthResponse(res, {
      exercise: {
        ...exercise,
        isFavorite,
      },
      safetyWarning,
      userRecoveryStage: stageData,
    }, 'exercise');
  } catch (err) {
    next(err);
  }
}

/**
 * Get recommended exercises for user
 * GET /api/v1/exercises/recommendations
 */
async function getRecommendations(req, res, next) {
  try {
    const userId = req.user.id;

    // Get user's health profile
    const healthProfile = await HealthProfile.findByUserId(userId);

    if (!healthProfile) {
      return success(res, {
        hasProfile: false,
        message: 'Complete your health profile to get personalized exercise recommendations.',
        defaultExercises: await Exercise.findByCategory('breathing'),
      });
    }

    const recoveryStage = await HealthProfile.getRecoveryStage(userId);

    const recommendations = await Exercise.getRecommendations(userId, {
      recoveryStage: recoveryStage.stage,
      medicalConditions: healthProfile.medicalConditions,
      exerciseClearedByDoctor: healthProfile.exerciseClearedByDoctor,
    });

    return healthResponse(res, {
      recommendations,
      recoveryStage,
      guidance: {
        clearanceRequired: !healthProfile.exerciseClearedByDoctor &&
          ['early_recovery', 'progressive_strengthening'].includes(recoveryStage.stage),
        message: healthProfile.exerciseClearedByDoctor
          ? `You're in ${recoveryStage.title}. These exercises are safe for your stage.`
          : `Please get clearance from your healthcare provider before starting exercise.`,
      },
    }, 'exercise');
  } catch (err) {
    next(err);
  }
}

/**
 * Get exercises by category
 * GET /api/v1/exercises/category/:category
 */
async function getByCategory(req, res, next) {
  try {
    const userId = req.user.id;
    const { category } = req.params;

    // Get user's recovery stage
    const stageData = await HealthProfile.getRecoveryStage(userId);

    const exercises = await Exercise.findByCategory(category, stageData?.stage);

    // Filter premium if user is not premium
    const isPremium = ['premium', 'trial'].includes(req.user.subscription_status);
    const filteredExercises = isPremium
      ? exercises
      : exercises.filter(e => !e.isPremium);

    // Category info
    const categoryInfo = {
      pelvic_floor: {
        name: 'Pelvic Floor',
        description: 'Strengthen your pelvic floor muscles for better bladder control and recovery.',
        icon: 'figure.stand',
      },
      core_reconnection: {
        name: 'Core Reconnection',
        description: 'Safely rebuild core strength, especially important if you have diastasis recti.',
        icon: 'circle.dotted',
      },
      breathing: {
        name: 'Breathing',
        description: 'Deep breathing exercises to reduce stress and improve oxygen flow.',
        icon: 'wind',
      },
      yoga: {
        name: 'Yoga',
        description: 'Postpartum-safe yoga poses for flexibility and mental wellness.',
        icon: 'figure.mind.and.body',
      },
      walking: {
        name: 'Walking',
        description: 'Gentle cardio to boost mood and energy without overexertion.',
        icon: 'figure.walk',
      },
      strength: {
        name: 'Strength Training',
        description: 'Build muscle and increase metabolism with resistance exercises.',
        icon: 'dumbbell.fill',
      },
      cardio: {
        name: 'Cardio',
        description: 'Heart-pumping exercises to improve endurance and burn calories.',
        icon: 'heart.fill',
      },
      stretching: {
        name: 'Stretching',
        description: 'Improve flexibility and relieve muscle tension from baby care.',
        icon: 'figure.flexibility',
      },
      hiit: {
        name: 'HIIT',
        description: 'High-intensity intervals for maximum efficiency. Recommended for full recovery stage.',
        icon: 'flame.fill',
      },
    };

    return healthResponse(res, {
      category: categoryInfo[category] || { name: category },
      exercises: filteredExercises,
      totalCount: exercises.length,
      premiumCount: exercises.filter(e => e.isPremium).length,
    }, 'exercise');
  } catch (err) {
    next(err);
  }
}

/**
 * Toggle favorite exercise
 * POST /api/v1/exercises/:id/favorite
 */
async function toggleFavorite(req, res, next) {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    // Check if exercise exists
    const exercise = await Exercise.findById(id);
    if (!exercise) {
      return notFound(res, 'Exercise');
    }

    const isFavorite = await Exercise.toggleFavorite(userId, id);

    logger.info('Exercise favorite toggled', { userId, exerciseId: id, isFavorite });

    return success(res, {
      exerciseId: id,
      isFavorite,
    }, isFavorite ? 'Added to favorites' : 'Removed from favorites');
  } catch (err) {
    next(err);
  }
}

/**
 * Get favorite exercises
 * GET /api/v1/exercises/favorites
 */
async function getFavorites(req, res, next) {
  try {
    const userId = req.user.id;

    const favorites = await Exercise.getFavorites(userId);

    return success(res, { exercises: favorites });
  } catch (err) {
    next(err);
  }
}

/**
 * Start a workout session
 * POST /api/v1/workouts
 */
async function startWorkout(req, res, next) {
  try {
    const userId = req.user.id;
    const { exerciseIds, moodBefore } = req.body;

    // Validate exercises exist
    const exercises = [];
    for (const exerciseId of exerciseIds) {
      const exercise = await Exercise.findById(exerciseId);
      if (!exercise) {
        return notFound(res, `Exercise ${exerciseId}`);
      }
      exercises.push(exercise);
    }

    // Create workout session
    const result = await db.query(`
      INSERT INTO workout_sessions (user_id, start_time, mood_before)
      VALUES ($1, NOW(), $2)
      RETURNING *
    `, [userId, moodBefore]);

    const session = result.rows[0];

    // Add exercises to session
    for (let i = 0; i < exerciseIds.length; i++) {
      await db.query(`
        INSERT INTO workout_exercises (workout_session_id, exercise_id, sort_order)
        VALUES ($1, $2, $3)
      `, [session.id, exerciseIds[i], i]);
    }

    logger.info('Workout started', { userId, sessionId: session.id, exerciseCount: exerciseIds.length });

    return created(res, {
      session: {
        id: session.id,
        startTime: session.start_time,
        moodBefore,
        exercises,
      },
    }, 'Workout started');
  } catch (err) {
    next(err);
  }
}

/**
 * Complete a workout session
 * PUT /api/v1/workouts/:id/complete
 */
async function completeWorkout(req, res, next) {
  try {
    const userId = req.user.id;
    const { id } = req.params;
    const { duration, caloriesBurned, moodAfter, notes, exerciseCompletions } = req.body;

    // Get session
    const sessionResult = await db.query(
      `SELECT * FROM workout_sessions WHERE id = $1 AND user_id = $2`,
      [id, userId]
    );

    if (sessionResult.rows.length === 0) {
      return notFound(res, 'Workout session');
    }

    // Update session
    const updateResult = await db.query(`
      UPDATE workout_sessions
      SET end_time = NOW(),
          duration_minutes = $2,
          calories_burned = $3,
          mood_after = $4,
          notes = $5,
          is_completed = TRUE,
          updated_at = NOW()
      WHERE id = $1 AND user_id = $6
      RETURNING *
    `, [id, duration, caloriesBurned, moodAfter, notes, userId]);

    const session = updateResult.rows[0];

    // Update exercise completions
    if (exerciseCompletions) {
      for (const completion of exerciseCompletions) {
        await db.query(`
          UPDATE workout_exercises
          SET is_completed = $2, reps_completed = $3, sets_completed = $4, duration_seconds = $5
          WHERE workout_session_id = $1 AND exercise_id = $6
        `, [id, completion.completed, completion.reps, completion.sets, completion.duration, completion.exerciseId]);
      }
    }

    // Update exercise streak
    await updateExerciseStreak(userId);

    // Check for achievements
    await checkExerciseAchievements(userId);

    logger.info('Workout completed', { userId, sessionId: id, duration, caloriesBurned });

    return success(res, {
      session: {
        id: session.id,
        startTime: session.start_time,
        endTime: session.end_time,
        duration: session.duration_minutes,
        caloriesBurned: session.calories_burned,
        moodBefore: session.mood_before,
        moodAfter: session.mood_after,
        isCompleted: true,
      },
      message: 'Great job completing your workout!',
    });
  } catch (err) {
    next(err);
  }
}

/**
 * Get workout history
 * GET /api/v1/workouts
 */
async function getWorkoutHistory(req, res, next) {
  try {
    const userId = req.user.id;
    const { startDate, endDate, page = 1, limit = 20 } = req.query;

    let query = `
      SELECT ws.*,
             json_agg(json_build_object(
               'id', e.id,
               'name', e.name,
               'category', e.category,
               'completed', we.is_completed
             )) as exercises
      FROM workout_sessions ws
      LEFT JOIN workout_exercises we ON ws.id = we.workout_session_id
      LEFT JOIN exercises e ON we.exercise_id = e.id
      WHERE ws.user_id = $1 AND ws.is_completed = TRUE
    `;

    const values = [userId];
    let paramIndex = 2;

    if (startDate) {
      query += ` AND ws.start_time >= $${paramIndex++}`;
      values.push(startDate);
    }

    if (endDate) {
      query += ` AND ws.start_time <= $${paramIndex++}`;
      values.push(endDate);
    }

    query += ` GROUP BY ws.id ORDER BY ws.start_time DESC`;
    query += ` LIMIT $${paramIndex++} OFFSET $${paramIndex}`;
    values.push(parseInt(limit, 10), (parseInt(page, 10) - 1) * parseInt(limit, 10));

    const result = await db.readQuery(query, values);

    // Get total count
    const countResult = await db.readQuery(
      `SELECT COUNT(*) FROM workout_sessions WHERE user_id = $1 AND is_completed = TRUE`,
      [userId]
    );

    return paginated(res, result.rows, {
      page: parseInt(page, 10),
      limit: parseInt(limit, 10),
      total: parseInt(countResult.rows[0].count, 10),
    });
  } catch (err) {
    next(err);
  }
}

/**
 * Get workout statistics
 * GET /api/v1/workouts/stats
 */
async function getWorkoutStats(req, res, next) {
  try {
    const userId = req.user.id;
    const { period = 'week' } = req.query;

    const intervals = {
      week: '7 days',
      month: '30 days',
      year: '365 days',
    };

    const interval = intervals[period] || '7 days';

    const stats = await db.readQuery(`
      SELECT
        COUNT(*) as total_workouts,
        COALESCE(SUM(duration_minutes), 0) as total_minutes,
        COALESCE(SUM(calories_burned), 0) as total_calories,
        COALESCE(AVG(duration_minutes), 0) as avg_duration,
        COALESCE(AVG(calories_burned), 0) as avg_calories
      FROM workout_sessions
      WHERE user_id = $1
        AND is_completed = TRUE
        AND start_time > NOW() - INTERVAL '${interval}'
    `, [userId]);

    // Get streak
    const streakResult = await db.readQuery(`
      SELECT current_streak, longest_streak
      FROM streaks
      WHERE user_id = $1 AND streak_type = 'exercise'
    `, [userId]);

    // Get category breakdown
    const categoryStats = await db.readQuery(`
      SELECT e.category, COUNT(*) as count
      FROM workout_exercises we
      JOIN workout_sessions ws ON we.workout_session_id = ws.id
      JOIN exercises e ON we.exercise_id = e.id
      WHERE ws.user_id = $1
        AND ws.is_completed = TRUE
        AND ws.start_time > NOW() - INTERVAL '${interval}'
      GROUP BY e.category
      ORDER BY count DESC
    `, [userId]);

    return success(res, {
      period,
      summary: {
        totalWorkouts: parseInt(stats.rows[0].total_workouts, 10),
        totalMinutes: parseInt(stats.rows[0].total_minutes, 10),
        totalCalories: parseInt(stats.rows[0].total_calories, 10),
        avgDuration: Math.round(parseFloat(stats.rows[0].avg_duration)),
        avgCalories: Math.round(parseFloat(stats.rows[0].avg_calories)),
      },
      streak: streakResult.rows[0] || { current_streak: 0, longest_streak: 0 },
      categoryBreakdown: categoryStats.rows,
    });
  } catch (err) {
    next(err);
  }
}

// =============================================================================
// Helper Functions
// =============================================================================

async function updateExerciseStreak(userId) {
  try {
    await db.query(`
      INSERT INTO streaks (user_id, streak_type, current_streak, longest_streak, last_activity_date)
      VALUES ($1, 'exercise', 1, 1, CURRENT_DATE)
      ON CONFLICT (user_id, streak_type)
      DO UPDATE SET
        current_streak = CASE
          WHEN streaks.last_activity_date = CURRENT_DATE - INTERVAL '1 day' THEN streaks.current_streak + 1
          WHEN streaks.last_activity_date = CURRENT_DATE THEN streaks.current_streak
          ELSE 1
        END,
        longest_streak = GREATEST(streaks.longest_streak,
          CASE
            WHEN streaks.last_activity_date = CURRENT_DATE - INTERVAL '1 day' THEN streaks.current_streak + 1
            ELSE 1
          END
        ),
        last_activity_date = CURRENT_DATE,
        updated_at = NOW()
    `, [userId]);
  } catch (error) {
    logger.error('Failed to update exercise streak', { userId, error: error.message });
  }
}

async function checkExerciseAchievements(userId) {
  // TODO: Implement achievement checking
}

module.exports = {
  getExercises,
  getExercise,
  getRecommendations,
  getByCategory,
  toggleFavorite,
  getFavorites,
  startWorkout,
  completeWorkout,
  getWorkoutHistory,
  getWorkoutStats,
};
