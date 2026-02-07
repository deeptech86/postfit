/**
 * MomCare API - Food Controller
 *
 * Handles food logging, nutrition tracking, and AI recognition.
 */

const { FoodEntry, HealthProfile } = require('../models');
const { success, created, noContent, notFound, healthResponse, premiumRequired } = require('../utils/apiResponse');
const { cache } = require('../config/redis');
const logger = require('../utils/logger');
const config = require('../config');

/**
 * Log a food entry
 * POST /api/v1/food
 */
async function createEntry(req, res, next) {
  try {
    const userId = req.user.id;
    const entryData = req.body;

    const entry = await FoodEntry.create(userId, entryData);

    // Invalidate today's cache
    const today = new Date().toISOString().split('T')[0];
    await cache.del(`nutrition:${userId}:${today}`);

    // Update streak
    await updateLoggingStreak(userId);

    logger.info('Food entry created', { userId, entryId: entry.id });

    return created(res, { entry }, 'Food entry logged successfully');
  } catch (err) {
    next(err);
  }
}

/**
 * Get food entries for a date
 * GET /api/v1/food/date/:date
 */
async function getByDate(req, res, next) {
  try {
    const userId = req.user.id;
    const { date } = req.params;

    // Check cache
    const cacheKey = `nutrition:${userId}:${date}`;
    const cached = await cache.get(cacheKey);

    if (cached) {
      return healthResponse(res, cached, 'nutrition');
    }

    const data = await FoodEntry.getByDate(userId, date);

    // Get user's calorie target
    const calorieData = await HealthProfile.calculateCalorieTarget(userId);

    const response = {
      ...data,
      targets: calorieData ? {
        calories: calorieData.targetCalories,
        protein: calorieData.macros.protein,
        carbohydrates: calorieData.macros.carbohydrates,
        fat: calorieData.macros.fat,
      } : null,
      progress: calorieData ? {
        caloriesPercent: Math.round((data.totals.calories / calorieData.targetCalories) * 100),
        proteinPercent: Math.round((data.totals.protein / calorieData.macros.protein) * 100),
        carbsPercent: Math.round((data.totals.carbohydrates / calorieData.macros.carbohydrates) * 100),
        fatPercent: Math.round((data.totals.fat / calorieData.macros.fat) * 100),
      } : null,
    };

    // Cache for 5 minutes
    await cache.set(cacheKey, response, 300);

    return healthResponse(res, response, 'nutrition');
  } catch (err) {
    next(err);
  }
}

/**
 * Get food entry by ID
 * GET /api/v1/food/:id
 */
async function getById(req, res, next) {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    const entry = await FoodEntry.findById(id, userId);

    if (!entry) {
      return notFound(res, 'Food entry');
    }

    return success(res, { entry });
  } catch (err) {
    next(err);
  }
}

/**
 * Update a food entry
 * PUT /api/v1/food/:id
 */
async function updateEntry(req, res, next) {
  try {
    const userId = req.user.id;
    const { id } = req.params;
    const updates = req.body;

    const entry = await FoodEntry.update(id, userId, updates);

    if (!entry) {
      return notFound(res, 'Food entry');
    }

    // Invalidate cache
    const date = new Date(entry.loggedAt).toISOString().split('T')[0];
    await cache.del(`nutrition:${userId}:${date}`);

    logger.info('Food entry updated', { userId, entryId: id });

    return success(res, { entry }, 'Food entry updated successfully');
  } catch (err) {
    next(err);
  }
}

/**
 * Delete a food entry
 * DELETE /api/v1/food/:id
 */
async function deleteEntry(req, res, next) {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    // Get entry first to get the date for cache invalidation
    const entry = await FoodEntry.findById(id, userId);

    if (!entry) {
      return notFound(res, 'Food entry');
    }

    await FoodEntry.delete(id, userId);

    // Invalidate cache
    const date = new Date(entry.loggedAt).toISOString().split('T')[0];
    await cache.del(`nutrition:${userId}:${date}`);

    logger.info('Food entry deleted', { userId, entryId: id });

    return noContent(res);
  } catch (err) {
    next(err);
  }
}

/**
 * Get individual food entries for date range
 * GET /api/v1/food/range
 */
async function getByDateRange(req, res, next) {
  try {
    const userId = req.user.id;
    const { startDate, endDate } = req.query;

    const entries = await FoodEntry.getByDateRange(userId, startDate, endDate);

    return healthResponse(res, { entries }, 'nutrition');
  } catch (err) {
    next(err);
  }
}

/**
 * Get nutrition summary for date range
 * GET /api/v1/food/summary
 */
async function getSummary(req, res, next) {
  try {
    const userId = req.user.id;
    const { startDate, endDate } = req.query;

    const summary = await FoodEntry.getDailySummary(userId, startDate, endDate);

    // Get targets for comparison
    const calorieData = await HealthProfile.calculateCalorieTarget(userId);

    const response = {
      summary,
      period: {
        startDate,
        endDate,
        days: summary.length,
      },
      targets: calorieData ? {
        dailyCalories: calorieData.targetCalories,
        dailyProtein: calorieData.macros.protein,
        dailyCarbs: calorieData.macros.carbohydrates,
        dailyFat: calorieData.macros.fat,
      } : null,
      averages: summary.length > 0 ? {
        calories: Math.round(summary.reduce((s, d) => s + d.calories, 0) / summary.length),
        protein: Math.round(summary.reduce((s, d) => s + d.protein, 0) / summary.length),
        carbohydrates: Math.round(summary.reduce((s, d) => s + d.carbohydrates, 0) / summary.length),
        fat: Math.round(summary.reduce((s, d) => s + d.fat, 0) / summary.length),
      } : null,
    };

    return healthResponse(res, response, 'nutrition');
  } catch (err) {
    next(err);
  }
}

/**
 * Search food history
 * GET /api/v1/food/search
 */
async function searchHistory(req, res, next) {
  try {
    const userId = req.user.id;
    const { query, limit = 20 } = req.query;

    const results = await FoodEntry.searchHistory(userId, query, parseInt(limit, 10));

    return success(res, { results, query });
  } catch (err) {
    next(err);
  }
}

/**
 * Get frequently logged foods
 * GET /api/v1/food/frequent
 */
async function getFrequentFoods(req, res, next) {
  try {
    const userId = req.user.id;
    const { limit = 10 } = req.query;

    const foods = await FoodEntry.getFrequentFoods(userId, parseInt(limit, 10));

    return success(res, { foods });
  } catch (err) {
    next(err);
  }
}

/**
 * AI-powered food recognition
 * POST /api/v1/food/recognize
 */
async function recognizeFood(req, res, next) {
  try {
    const userId = req.user.id;
    const { imageUrl, mealType } = req.body;

    // Check if premium feature
    if (!config.features.aiFoodRecognition) {
      return premiumRequired(res, 'AI Food Recognition');
    }

    // Check user subscription
    const isPremium = ['premium', 'trial'].includes(req.user.subscription_status);
    if (!isPremium) {
      // Check daily limit for free users
      const today = new Date().toISOString().split('T')[0];
      const usageKey = `ai_usage:${userId}:${today}`;
      const usage = await cache.incr(usageKey);

      if (usage === 1) {
        await cache.expire(usageKey, 24 * 60 * 60);
      }

      if (usage > 3) {
        return premiumRequired(res, 'AI Food Recognition (daily limit reached)');
      }
    }

    // Call AI service (placeholder - implement with OpenAI Vision)
    const recognitionResult = await recognizeFoodWithAI(imageUrl);

    if (!recognitionResult) {
      return success(res, {
        recognized: false,
        message: 'Could not identify food in image. Please try again or log manually.',
        suggestions: [],
      });
    }

    // Get nutrition data from USDA or database
    const nutritionData = await getNutritionData(recognitionResult.foodName);

    const response = {
      recognized: true,
      food: {
        name: recognitionResult.foodName,
        confidence: recognitionResult.confidence,
        alternatives: recognitionResult.alternatives,
        ...nutritionData,
      },
      suggestedEntry: {
        name: recognitionResult.foodName,
        mealType: mealType || 'snack',
        ...nutritionData,
        isAiRecognized: true,
        aiConfidence: recognitionResult.confidence,
        imageUrl,
      },
    };

    logger.info('Food recognized with AI', { userId, food: recognitionResult.foodName });

    return healthResponse(res, response, 'nutrition');
  } catch (err) {
    next(err);
  }
}

/**
 * Get calorie and nutrition targets
 * GET /api/v1/food/targets
 */
async function getTargets(req, res, next) {
  try {
    const userId = req.user.id;

    const targets = await HealthProfile.calculateCalorieTarget(userId);

    if (!targets) {
      return success(res, {
        hasProfile: false,
        message: 'Complete your health profile to get personalized nutrition targets.',
        defaultTargets: {
          calories: 2000,
          protein: 75,
          carbohydrates: 250,
          fat: 65,
        },
      });
    }

    return healthResponse(res, {
      hasProfile: true,
      ...targets,
    }, 'nutrition');
  } catch (err) {
    next(err);
  }
}

// =============================================================================
// Helper Functions
// =============================================================================

/**
 * Update food logging streak
 */
async function updateLoggingStreak(userId) {
  try {
    const db = require('../config/database');

    await db.query(`
      INSERT INTO streaks (user_id, streak_type, current_streak, longest_streak, last_activity_date)
      VALUES ($1, 'food_logging', 1, 1, CURRENT_DATE)
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
    logger.error('Failed to update streak', { userId, error: error.message });
  }
}

/**
 * AI food recognition (placeholder)
 * TODO: Implement with OpenAI Vision API
 */
async function recognizeFoodWithAI(imageUrl) {
  // Placeholder - implement with actual AI service
  // This would call OpenAI's GPT-4 Vision API

  /*
  const openai = require('openai');
  const response = await openai.chat.completions.create({
    model: "gpt-4-vision-preview",
    messages: [
      {
        role: "user",
        content: [
          { type: "text", text: "Identify the food in this image and estimate its nutritional content." },
          { type: "image_url", image_url: { url: imageUrl } }
        ]
      }
    ]
  });
  */

  return null;
}

/**
 * Get nutrition data from USDA or database
 * TODO: Implement USDA FoodData Central API integration
 */
async function getNutritionData(foodName) {
  // Placeholder - implement with actual USDA API
  return {
    calories: 0,
    protein: 0,
    carbohydrates: 0,
    fat: 0,
    servingSize: '1 serving',
  };
}

module.exports = {
  createEntry,
  getByDate,
  getByDateRange,
  getById,
  updateEntry,
  deleteEntry,
  getSummary,
  searchHistory,
  getFrequentFoods,
  recognizeFood,
  getTargets,
};
