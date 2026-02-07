/**
 * MomCare API - Food Entry Model
 *
 * Handles food logging, nutritional tracking, and AI recognition data.
 */

const db = require('../config/database');
const logger = require('../utils/logger');

class FoodEntry {
  /**
   * Create a new food entry
   * @param {string} userId - User UUID
   * @param {Object} entryData - Food entry data
   * @returns {Promise<Object>}
   */
  static async create(userId, entryData) {
    const {
      name,
      mealType,
      calories,
      protein = 0,
      carbohydrates = 0,
      fat = 0,
      fiber = 0,
      sugar = 0,
      sodium = 0,
      iron = 0,
      calcium = 0,
      servingSize = '1 serving',
      servingCount = 1,
      imageUrl = null,
      isAiRecognized = false,
      aiConfidence = null,
      aiAlternatives = null,
      barcode = null,
      usdaFoodId = null,
      notes = null,
      timestamp = new Date(),
    } = entryData;

    const query = `
      INSERT INTO food_entries (
        user_id, name, meal_type, calories, protein_g, carbohydrates_g,
        fat_g, fiber_g, sugar_g, sodium_mg, iron_mg, calcium_mg,
        serving_size, serving_count, image_url, is_ai_recognized,
        ai_confidence, ai_alternatives, barcode, usda_food_id, notes, logged_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22)
      RETURNING *
    `;

    const values = [
      userId, name, mealType, calories, protein, carbohydrates,
      fat, fiber, sugar, sodium, iron, calcium,
      servingSize, servingCount, imageUrl, isAiRecognized,
      aiConfidence, aiAlternatives ? JSON.stringify(aiAlternatives) : null,
      barcode, usdaFoodId, notes, timestamp,
    ];

    const result = await db.query(query, values);
    return this.formatEntry(result.rows[0]);
  }

  /**
   * Get food entry by ID
   * @param {string} entryId - Entry UUID
   * @param {string} userId - User UUID (for authorization)
   * @returns {Promise<Object|null>}
   */
  static async findById(entryId, userId) {
    const query = `
      SELECT * FROM food_entries
      WHERE id = $1 AND user_id = $2
    `;

    const result = await db.readQuery(query, [entryId, userId]);
    return result.rows[0] ? this.formatEntry(result.rows[0]) : null;
  }

  /**
   * Get food entries for a specific date
   * @param {string} userId - User UUID
   * @param {Date} date - Date to get entries for
   * @returns {Promise<Object>}
   */
  static async getByDate(userId, date) {
    const query = `
      SELECT * FROM food_entries
      WHERE user_id = $1 AND DATE(logged_at) = $2
      ORDER BY logged_at ASC
    `;

    const result = await db.readQuery(query, [userId, date]);
    const entries = result.rows.map(this.formatEntry);

    // Calculate totals
    const totals = this.calculateTotals(entries);

    // Group by meal type
    const groupedByMeal = {
      breakfast: entries.filter(e => e.mealType === 'breakfast'),
      lunch: entries.filter(e => e.mealType === 'lunch'),
      dinner: entries.filter(e => e.mealType === 'dinner'),
      snack: entries.filter(e => e.mealType === 'snack'),
    };

    return {
      date,
      entries,
      groupedByMeal,
      totals,
    };
  }

  /**
   * Get food entries for a date range
   * @param {string} userId - User UUID
   * @param {Date} startDate - Start date
   * @param {Date} endDate - End date
   * @returns {Promise<Array>}
   */
  static async getByDateRange(userId, startDate, endDate) {
    const query = `
      SELECT * FROM food_entries
      WHERE user_id = $1 AND DATE(logged_at) BETWEEN $2 AND $3
      ORDER BY logged_at ASC
    `;

    const result = await db.readQuery(query, [userId, startDate, endDate]);
    return result.rows.map(this.formatEntry);
  }

  /**
   * Get daily nutrition summary for a date range
   * @param {string} userId - User UUID
   * @param {Date} startDate - Start date
   * @param {Date} endDate - End date
   * @returns {Promise<Array>}
   */
  static async getDailySummary(userId, startDate, endDate) {
    const query = `
      SELECT
        DATE(logged_at) as date,
        COUNT(*) as entry_count,
        SUM(calories) as total_calories,
        SUM(protein_g) as total_protein,
        SUM(carbohydrates_g) as total_carbs,
        SUM(fat_g) as total_fat,
        SUM(fiber_g) as total_fiber,
        SUM(iron_mg) as total_iron,
        SUM(calcium_mg) as total_calcium
      FROM food_entries
      WHERE user_id = $1 AND DATE(logged_at) BETWEEN $2 AND $3
      GROUP BY DATE(logged_at)
      ORDER BY date ASC
    `;

    const result = await db.readQuery(query, [userId, startDate, endDate]);
    return result.rows.map(row => ({
      date: row.date,
      entryCount: parseInt(row.entry_count, 10),
      calories: parseInt(row.total_calories, 10),
      protein: parseFloat(row.total_protein),
      carbohydrates: parseFloat(row.total_carbs),
      fat: parseFloat(row.total_fat),
      fiber: parseFloat(row.total_fiber),
      iron: parseFloat(row.total_iron),
      calcium: parseFloat(row.total_calcium),
    }));
  }

  /**
   * Update a food entry
   * @param {string} entryId - Entry UUID
   * @param {string} userId - User UUID
   * @param {Object} updates - Fields to update
   * @returns {Promise<Object|null>}
   */
  static async update(entryId, userId, updates) {
    const allowedFields = [
      'name', 'meal_type', 'calories', 'protein_g', 'carbohydrates_g',
      'fat_g', 'fiber_g', 'sugar_g', 'sodium_mg', 'iron_mg', 'calcium_mg',
      'serving_size', 'serving_count', 'notes',
    ];

    // Map camelCase to snake_case
    const fieldMap = {
      mealType: 'meal_type',
      protein: 'protein_g',
      carbohydrates: 'carbohydrates_g',
      fat: 'fat_g',
      fiber: 'fiber_g',
      sugar: 'sugar_g',
      sodium: 'sodium_mg',
      iron: 'iron_mg',
      calcium: 'calcium_mg',
      servingSize: 'serving_size',
      servingCount: 'serving_count',
    };

    const fields = [];
    const values = [];
    let paramIndex = 1;

    for (const [key, value] of Object.entries(updates)) {
      const dbField = fieldMap[key] || key;
      if (allowedFields.includes(dbField)) {
        fields.push(`${dbField} = $${paramIndex}`);
        values.push(value);
        paramIndex++;
      }
    }

    if (fields.length === 0) {
      return this.findById(entryId, userId);
    }

    values.push(entryId, userId);

    const query = `
      UPDATE food_entries
      SET ${fields.join(', ')}, updated_at = NOW()
      WHERE id = $${paramIndex} AND user_id = $${paramIndex + 1}
      RETURNING *
    `;

    const result = await db.query(query, values);
    return result.rows[0] ? this.formatEntry(result.rows[0]) : null;
  }

  /**
   * Delete a food entry
   * @param {string} entryId - Entry UUID
   * @param {string} userId - User UUID
   * @returns {Promise<boolean>}
   */
  static async delete(entryId, userId) {
    const query = `
      DELETE FROM food_entries
      WHERE id = $1 AND user_id = $2
      RETURNING id
    `;

    const result = await db.query(query, [entryId, userId]);
    return result.rows.length > 0;
  }

  /**
   * Search user's food history
   * @param {string} userId - User UUID
   * @param {string} searchTerm - Search term
   * @param {number} limit - Max results
   * @returns {Promise<Array>}
   */
  static async searchHistory(userId, searchTerm, limit = 20) {
    const query = `
      SELECT DISTINCT ON (LOWER(name))
        name, calories, protein_g, carbohydrates_g, fat_g,
        serving_size, serving_count, MAX(logged_at) as last_logged
      FROM food_entries
      WHERE user_id = $1 AND name ILIKE $2
      GROUP BY name, calories, protein_g, carbohydrates_g, fat_g, serving_size, serving_count
      ORDER BY LOWER(name), last_logged DESC
      LIMIT $3
    `;

    const result = await db.readQuery(query, [userId, `%${searchTerm}%`, limit]);
    return result.rows.map(row => ({
      name: row.name,
      calories: parseInt(row.calories, 10),
      protein: parseFloat(row.protein_g),
      carbohydrates: parseFloat(row.carbohydrates_g),
      fat: parseFloat(row.fat_g),
      servingSize: row.serving_size,
      servingCount: parseFloat(row.serving_count),
      lastLogged: row.last_logged,
    }));
  }

  /**
   * Get frequently logged foods
   * @param {string} userId - User UUID
   * @param {number} limit - Max results
   * @returns {Promise<Array>}
   */
  static async getFrequentFoods(userId, limit = 10) {
    const query = `
      SELECT
        name, calories, protein_g, carbohydrates_g, fat_g,
        serving_size, COUNT(*) as frequency
      FROM food_entries
      WHERE user_id = $1 AND logged_at > NOW() - INTERVAL '30 days'
      GROUP BY name, calories, protein_g, carbohydrates_g, fat_g, serving_size
      ORDER BY frequency DESC
      LIMIT $2
    `;

    const result = await db.readQuery(query, [userId, limit]);
    return result.rows.map(row => ({
      name: row.name,
      calories: parseInt(row.calories, 10),
      protein: parseFloat(row.protein_g),
      carbohydrates: parseFloat(row.carbohydrates_g),
      fat: parseFloat(row.fat_g),
      servingSize: row.serving_size,
      frequency: parseInt(row.frequency, 10),
    }));
  }

  /**
   * Calculate nutrition totals from entries
   * @param {Array} entries - Food entries
   * @returns {Object}
   */
  static calculateTotals(entries) {
    return entries.reduce((totals, entry) => ({
      calories: totals.calories + entry.calories,
      protein: totals.protein + entry.protein,
      carbohydrates: totals.carbohydrates + entry.carbohydrates,
      fat: totals.fat + entry.fat,
      fiber: totals.fiber + entry.fiber,
      sugar: totals.sugar + entry.sugar,
      sodium: totals.sodium + entry.sodium,
      iron: totals.iron + entry.iron,
      calcium: totals.calcium + entry.calcium,
    }), {
      calories: 0,
      protein: 0,
      carbohydrates: 0,
      fat: 0,
      fiber: 0,
      sugar: 0,
      sodium: 0,
      iron: 0,
      calcium: 0,
    });
  }

  /**
   * Format entry for API response
   * @param {Object} entry - Raw database entry
   * @returns {Object}
   */
  static formatEntry(entry) {
    if (!entry) return null;

    return {
      id: entry.id,
      userId: entry.user_id,
      name: entry.name,
      mealType: entry.meal_type,
      calories: parseInt(entry.calories, 10),
      protein: parseFloat(entry.protein_g),
      carbohydrates: parseFloat(entry.carbohydrates_g),
      fat: parseFloat(entry.fat_g),
      fiber: parseFloat(entry.fiber_g),
      sugar: parseFloat(entry.sugar_g),
      sodium: parseFloat(entry.sodium_mg),
      iron: parseFloat(entry.iron_mg),
      calcium: parseFloat(entry.calcium_mg),
      servingSize: entry.serving_size,
      servingCount: parseFloat(entry.serving_count),
      imageUrl: entry.image_url,
      isAiRecognized: entry.is_ai_recognized,
      aiConfidence: entry.ai_confidence ? parseFloat(entry.ai_confidence) : null,
      aiAlternatives: entry.ai_alternatives,
      barcode: entry.barcode,
      usdaFoodId: entry.usda_food_id,
      notes: entry.notes,
      loggedAt: entry.logged_at,
      createdAt: entry.created_at,
      updatedAt: entry.updated_at,
    };
  }
}

module.exports = FoodEntry;
