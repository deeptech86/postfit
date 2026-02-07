/**
 * MomCare API - Hydration Controller
 *
 * Handles water intake tracking with breastfeeding-adjusted goals.
 */

const { HydrationEntry, HealthProfile } = require('../models');
const { success, created, noContent, notFound, healthResponse } = require('../utils/apiResponse');
const { cache } = require('../config/redis');
const logger = require('../utils/logger');

/**
 * Log a hydration entry
 * POST /api/v1/hydration
 */
async function createEntry(req, res, next) {
  try {
    const userId = req.user.id;
    const entryData = req.body;

    const entry = await HydrationEntry.create(userId, entryData);

    // Invalidate today's cache
    const today = new Date().toISOString().split('T')[0];
    await cache.del(`hydration:${userId}:${today}`);

    // Update streak
    await updateHydrationStreak(userId);

    logger.info('Hydration entry created', { userId, entryId: entry.id, amount: entry.amount });

    return created(res, { entry }, 'Hydration logged successfully');
  } catch (err) {
    next(err);
  }
}

/**
 * Get today's hydration progress
 * GET /api/v1/hydration/today
 */
async function getTodayProgress(req, res, next) {
  try {
    const userId = req.user.id;
    const today = new Date().toISOString().split('T')[0];

    // Check cache
    const cacheKey = `hydration:${userId}:${today}`;
    const cached = await cache.get(cacheKey);

    if (cached) {
      return success(res, cached);
    }

    // Get hydration goal
    const goalData = await HealthProfile.calculateHydrationGoal(userId);
    const goalMl = goalData?.goalMl || 2000; // Default 2L

    const progress = await HydrationEntry.getTodayProgress(userId, goalMl);

    const response = {
      ...progress,
      recommendation: goalData?.recommendation || 'Stay hydrated throughout the day.',
      nextReminder: calculateNextReminder(progress),
    };

    // Cache for 1 minute (frequently updated)
    await cache.set(cacheKey, response, 60);

    return success(res, response);
  } catch (err) {
    next(err);
  }
}

/**
 * Get hydration entries for a date
 * GET /api/v1/hydration/date/:date
 */
async function getByDate(req, res, next) {
  try {
    const userId = req.user.id;
    const { date } = req.params;

    const data = await HydrationEntry.getByDate(userId, date);

    // Get goal for context
    const goalData = await HealthProfile.calculateHydrationGoal(userId);

    return success(res, {
      ...data,
      goal: goalData,
    });
  } catch (err) {
    next(err);
  }
}

/**
 * Get hydration entry by ID
 * GET /api/v1/hydration/:id
 */
async function getById(req, res, next) {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    const entry = await HydrationEntry.findById(id, userId);

    if (!entry) {
      return notFound(res, 'Hydration entry');
    }

    return success(res, { entry });
  } catch (err) {
    next(err);
  }
}

/**
 * Update a hydration entry
 * PUT /api/v1/hydration/:id
 */
async function updateEntry(req, res, next) {
  try {
    const userId = req.user.id;
    const { id } = req.params;
    const updates = req.body;

    const entry = await HydrationEntry.update(id, userId, updates);

    if (!entry) {
      return notFound(res, 'Hydration entry');
    }

    // Invalidate cache
    const date = new Date(entry.loggedAt).toISOString().split('T')[0];
    await cache.del(`hydration:${userId}:${date}`);

    logger.info('Hydration entry updated', { userId, entryId: id });

    return success(res, { entry }, 'Hydration entry updated');
  } catch (err) {
    next(err);
  }
}

/**
 * Delete a hydration entry
 * DELETE /api/v1/hydration/:id
 */
async function deleteEntry(req, res, next) {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    // Get entry first for cache invalidation
    const entry = await HydrationEntry.findById(id, userId);

    if (!entry) {
      return notFound(res, 'Hydration entry');
    }

    await HydrationEntry.delete(id, userId);

    // Invalidate cache
    const date = new Date(entry.loggedAt).toISOString().split('T')[0];
    await cache.del(`hydration:${userId}:${date}`);

    logger.info('Hydration entry deleted', { userId, entryId: id });

    return noContent(res);
  } catch (err) {
    next(err);
  }
}

/**
 * Get hydration summary for date range
 * GET /api/v1/hydration/summary
 */
async function getSummary(req, res, next) {
  try {
    const userId = req.user.id;
    const { startDate, endDate } = req.query;

    const summary = await HydrationEntry.getDailySummary(userId, startDate, endDate);
    const averages = await HydrationEntry.getAverageIntake(userId, 7);
    const goalData = await HealthProfile.calculateHydrationGoal(userId);

    // Calculate goal achievement
    const goalMl = goalData?.goalMl || 2000;
    const daysMetGoal = summary.filter(d => d.totalMl >= goalMl).length;

    return success(res, {
      summary,
      period: {
        startDate,
        endDate,
        totalDays: summary.length,
        daysMetGoal,
        goalAchievementRate: summary.length > 0 ? Math.round((daysMetGoal / summary.length) * 100) : 0,
      },
      averages,
      goal: goalData,
    });
  } catch (err) {
    next(err);
  }
}

/**
 * Get hydration goal
 * GET /api/v1/hydration/goal
 */
async function getGoal(req, res, next) {
  try {
    const userId = req.user.id;

    const goal = await HealthProfile.calculateHydrationGoal(userId);

    if (!goal) {
      return success(res, {
        hasProfile: false,
        message: 'Complete your health profile to get personalized hydration goals.',
        defaultGoal: {
          goalMl: 2000,
          goalGlasses: 8,
          glassSize: 250,
        },
      });
    }

    return healthResponse(res, {
      hasProfile: true,
      ...goal,
    }, 'breastfeeding');
  } catch (err) {
    next(err);
  }
}

/**
 * Quick add preset amounts
 * POST /api/v1/hydration/quick-add
 */
async function quickAdd(req, res, next) {
  try {
    const userId = req.user.id;
    const { preset } = req.body;

    // Preset amounts
    const presets = {
      glass: 250,
      bottle: 500,
      large_bottle: 750,
      small_cup: 150,
    };

    const amount = presets[preset];

    if (!amount) {
      return success(res, { presets }, 'Available presets');
    }

    const entry = await HydrationEntry.create(userId, {
      amount,
      drinkType: 'water',
    });

    // Invalidate cache
    const today = new Date().toISOString().split('T')[0];
    await cache.del(`hydration:${userId}:${today}`);

    // Get updated progress
    const goalData = await HealthProfile.calculateHydrationGoal(userId);
    const progress = await HydrationEntry.getTodayProgress(userId, goalData?.goalMl || 2000);

    logger.info('Quick hydration add', { userId, preset, amount });

    return created(res, {
      entry,
      progress,
    }, `Added ${amount}ml`);
  } catch (err) {
    next(err);
  }
}

/**
 * Get hourly distribution for today
 * GET /api/v1/hydration/distribution
 */
async function getDistribution(req, res, next) {
  try {
    const userId = req.user.id;
    const { date } = req.query;
    const targetDate = date || new Date().toISOString().split('T')[0];

    const distribution = await HydrationEntry.getHourlyDistribution(userId, targetDate);

    // Fill in missing hours with zeros
    const fullDistribution = [];
    for (let hour = 0; hour < 24; hour++) {
      const existing = distribution.find(d => d.hour === hour);
      fullDistribution.push(existing || { hour, totalMl: 0, count: 0 });
    }

    return success(res, {
      date: targetDate,
      distribution: fullDistribution,
      peakHour: distribution.length > 0
        ? distribution.reduce((max, d) => d.totalMl > max.totalMl ? d : max)
        : null,
    });
  } catch (err) {
    next(err);
  }
}

// =============================================================================
// Helper Functions
// =============================================================================

/**
 * Calculate next hydration reminder
 */
function calculateNextReminder(progress) {
  if (progress.isGoalMet) {
    return null;
  }

  const now = new Date();
  const hour = now.getHours();

  // Don't remind during sleep hours (10pm - 6am)
  if (hour >= 22 || hour < 6) {
    return new Date(now.setHours(6, 0, 0, 0)).toISOString();
  }

  // Calculate remaining needed per hour until 10pm
  const hoursUntilNight = 22 - hour;
  const mlPerHour = progress.remainingMl / hoursUntilNight;

  // Suggest in 1.5-2 hours
  const reminderTime = new Date(now.getTime() + 90 * 60 * 1000);

  return {
    time: reminderTime.toISOString(),
    suggestedAmount: Math.min(250, Math.round(mlPerHour * 1.5)),
  };
}

/**
 * Update hydration streak
 */
async function updateHydrationStreak(userId) {
  try {
    const db = require('../config/database');

    await db.query(`
      INSERT INTO streaks (user_id, streak_type, current_streak, longest_streak, last_activity_date)
      VALUES ($1, 'hydration', 1, 1, CURRENT_DATE)
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
    logger.error('Failed to update hydration streak', { userId, error: error.message });
  }
}

module.exports = {
  createEntry,
  getTodayProgress,
  getByDate,
  getById,
  updateEntry,
  deleteEntry,
  getSummary,
  getGoal,
  quickAdd,
  getDistribution,
};
