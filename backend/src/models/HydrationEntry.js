/**
 * MomCare API - Hydration Entry Model
 *
 * Tracks water and fluid intake with breastfeeding-adjusted goals.
 */

const db = require('../config/database');
const logger = require('../utils/logger');

class HydrationEntry {
  /**
   * Create a new hydration entry
   * @param {string} userId - User UUID
   * @param {Object} entryData - Hydration entry data
   * @returns {Promise<Object>}
   */
  static async create(userId, entryData) {
    const {
      amount,
      drinkType = 'water',
      timestamp = new Date(),
    } = entryData;

    const query = `
      INSERT INTO hydration_entries (user_id, amount_ml, drink_type, logged_at)
      VALUES ($1, $2, $3, $4)
      RETURNING *
    `;

    const result = await db.query(query, [userId, amount, drinkType, timestamp]);
    return this.formatEntry(result.rows[0]);
  }

  /**
   * Get hydration entry by ID
   * @param {string} entryId - Entry UUID
   * @param {string} userId - User UUID
   * @returns {Promise<Object|null>}
   */
  static async findById(entryId, userId) {
    const query = `
      SELECT * FROM hydration_entries
      WHERE id = $1 AND user_id = $2
    `;

    const result = await db.readQuery(query, [entryId, userId]);
    return result.rows[0] ? this.formatEntry(result.rows[0]) : null;
  }

  /**
   * Get hydration entries for a specific date
   * @param {string} userId - User UUID
   * @param {Date} date - Date to get entries for
   * @returns {Promise<Object>}
   */
  static async getByDate(userId, date) {
    const query = `
      SELECT * FROM hydration_entries
      WHERE user_id = $1 AND DATE(logged_at) = $2
      ORDER BY logged_at ASC
    `;

    const result = await db.readQuery(query, [userId, date]);
    const entries = result.rows.map(this.formatEntry);

    // Calculate totals
    const totalMl = entries.reduce((sum, entry) => sum + entry.amount, 0);
    const totalGlasses = Math.floor(totalMl / 250);

    // Group by drink type
    const byDrinkType = entries.reduce((acc, entry) => {
      const type = entry.drinkType;
      if (!acc[type]) acc[type] = { amount: 0, count: 0 };
      acc[type].amount += entry.amount;
      acc[type].count += 1;
      return acc;
    }, {});

    return {
      date,
      entries,
      totalMl,
      totalGlasses,
      byDrinkType,
    };
  }

  /**
   * Get hydration summary for date range
   * @param {string} userId - User UUID
   * @param {Date} startDate - Start date
   * @param {Date} endDate - End date
   * @returns {Promise<Array>}
   */
  static async getDailySummary(userId, startDate, endDate) {
    const query = `
      SELECT
        DATE(logged_at) as date,
        SUM(amount_ml) as total_ml,
        COUNT(*) as entry_count
      FROM hydration_entries
      WHERE user_id = $1 AND DATE(logged_at) BETWEEN $2 AND $3
      GROUP BY DATE(logged_at)
      ORDER BY date ASC
    `;

    const result = await db.readQuery(query, [userId, startDate, endDate]);
    return result.rows.map(row => ({
      date: row.date,
      totalMl: parseInt(row.total_ml, 10),
      totalGlasses: Math.floor(parseInt(row.total_ml, 10) / 250),
      entryCount: parseInt(row.entry_count, 10),
    }));
  }

  /**
   * Get today's progress with goal
   * @param {string} userId - User UUID
   * @param {number} goalMl - Daily goal in ml
   * @returns {Promise<Object>}
   */
  static async getTodayProgress(userId, goalMl) {
    const today = new Date().toISOString().split('T')[0];
    const dailyData = await this.getByDate(userId, today);

    const progress = goalMl > 0 ? Math.min(dailyData.totalMl / goalMl, 1) : 0;
    const remaining = Math.max(goalMl - dailyData.totalMl, 0);
    const remainingGlasses = Math.ceil(remaining / 250);

    return {
      ...dailyData,
      goalMl,
      goalGlasses: Math.round(goalMl / 250),
      progress: Math.round(progress * 100) / 100,
      progressPercent: Math.round(progress * 100),
      remainingMl: remaining,
      remainingGlasses,
      isGoalMet: dailyData.totalMl >= goalMl,
    };
  }

  /**
   * Update a hydration entry
   * @param {string} entryId - Entry UUID
   * @param {string} userId - User UUID
   * @param {Object} updates - Fields to update
   * @returns {Promise<Object|null>}
   */
  static async update(entryId, userId, updates) {
    const { amount, drinkType } = updates;

    const fields = [];
    const values = [];
    let paramIndex = 1;

    if (amount !== undefined) {
      fields.push(`amount_ml = $${paramIndex++}`);
      values.push(amount);
    }

    if (drinkType !== undefined) {
      fields.push(`drink_type = $${paramIndex++}`);
      values.push(drinkType);
    }

    if (fields.length === 0) {
      return this.findById(entryId, userId);
    }

    values.push(entryId, userId);

    const query = `
      UPDATE hydration_entries
      SET ${fields.join(', ')}
      WHERE id = $${paramIndex++} AND user_id = $${paramIndex}
      RETURNING *
    `;

    const result = await db.query(query, values);
    return result.rows[0] ? this.formatEntry(result.rows[0]) : null;
  }

  /**
   * Delete a hydration entry
   * @param {string} entryId - Entry UUID
   * @param {string} userId - User UUID
   * @returns {Promise<boolean>}
   */
  static async delete(entryId, userId) {
    const query = `
      DELETE FROM hydration_entries
      WHERE id = $1 AND user_id = $2
      RETURNING id
    `;

    const result = await db.query(query, [entryId, userId]);
    return result.rows.length > 0;
  }

  /**
   * Get average daily intake
   * @param {string} userId - User UUID
   * @param {number} days - Number of days to average
   * @returns {Promise<Object>}
   */
  static async getAverageIntake(userId, days = 7) {
    const query = `
      SELECT
        AVG(daily_total) as avg_ml,
        MAX(daily_total) as max_ml,
        MIN(daily_total) as min_ml,
        COUNT(*) as days_tracked
      FROM (
        SELECT DATE(logged_at) as date, SUM(amount_ml) as daily_total
        FROM hydration_entries
        WHERE user_id = $1 AND logged_at > NOW() - INTERVAL '${days} days'
        GROUP BY DATE(logged_at)
      ) daily_totals
    `;

    const result = await db.readQuery(query, [userId]);
    const row = result.rows[0];

    return {
      averageMl: Math.round(parseFloat(row.avg_ml) || 0),
      averageGlasses: Math.round((parseFloat(row.avg_ml) || 0) / 250),
      maxMl: parseInt(row.max_ml, 10) || 0,
      minMl: parseInt(row.min_ml, 10) || 0,
      daysTracked: parseInt(row.days_tracked, 10) || 0,
      period: days,
    };
  }

  /**
   * Get hourly distribution for a date
   * @param {string} userId - User UUID
   * @param {Date} date - Date
   * @returns {Promise<Array>}
   */
  static async getHourlyDistribution(userId, date) {
    const query = `
      SELECT
        EXTRACT(HOUR FROM logged_at) as hour,
        SUM(amount_ml) as total_ml,
        COUNT(*) as count
      FROM hydration_entries
      WHERE user_id = $1 AND DATE(logged_at) = $2
      GROUP BY EXTRACT(HOUR FROM logged_at)
      ORDER BY hour
    `;

    const result = await db.readQuery(query, [userId, date]);
    return result.rows.map(row => ({
      hour: parseInt(row.hour, 10),
      totalMl: parseInt(row.total_ml, 10),
      count: parseInt(row.count, 10),
    }));
  }

  /**
   * Format entry for API response
   * @param {Object} entry - Raw database entry
   * @returns {Object}
   */
  static formatEntry(entry) {
    if (!entry) return null;

    // Hydration factors for different drinks
    const hydrationFactors = {
      water: 1.0,
      tea: 0.9,
      milk: 0.85,
      juice: 0.85,
      smoothie: 0.8,
      broth: 0.9,
    };

    const amount = parseInt(entry.amount_ml, 10);
    const factor = hydrationFactors[entry.drink_type] || 1.0;

    return {
      id: entry.id,
      userId: entry.user_id,
      amount: amount,
      drinkType: entry.drink_type,
      effectiveHydration: Math.round(amount * factor),
      loggedAt: entry.logged_at,
      createdAt: entry.created_at,
    };
  }
}

module.exports = HydrationEntry;
