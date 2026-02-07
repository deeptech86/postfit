/**
 * MomCare API - User Model
 *
 * Handles all database operations for user accounts,
 * including authentication, profile management, and preferences.
 */

const db = require('../config/database');
const { encrypt, decrypt, hashPassword, verifyPassword } = require('../utils/encryption');
const logger = require('../utils/logger');

class User {
  /**
   * Create a new user
   * @param {Object} userData - User data
   * @returns {Promise<Object>} Created user
   */
  static async create(userData) {
    const {
      email,
      password,
      name,
      phone = null,
      termsAccepted = true,
      marketingConsent = false,
    } = userData;

    const passwordHash = password ? await hashPassword(password) : null;

    const query = `
      INSERT INTO users (
        email, password_hash, name, phone,
        terms_accepted_at, marketing_consent,
        email_verified
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING id, email, name, phone, profile_image_url,
                email_verified, is_active, created_at
    `;

    const values = [
      email.toLowerCase(),
      passwordHash,
      name,
      phone,
      termsAccepted ? new Date() : null,
      marketingConsent,
      false, // email_verified
    ];

    const result = await db.query(query, values);
    return result.rows[0];
  }

  /**
   * Find user by ID
   * @param {string} id - User UUID
   * @returns {Promise<Object|null>}
   */
  static async findById(id) {
    const query = `
      SELECT
        u.id, u.email, u.name, u.phone, u.profile_image_url,
        u.email_verified, u.is_active, u.timezone, u.locale,
        u.created_at, u.last_login_at,
        s.status as subscription_status
      FROM users u
      LEFT JOIN subscriptions s ON u.id = s.user_id
      WHERE u.id = $1 AND u.deleted_at IS NULL
    `;

    const result = await db.readQuery(query, [id]);
    return result.rows[0] || null;
  }

  /**
   * Find user by email
   * @param {string} email - User email
   * @returns {Promise<Object|null>}
   */
  static async findByEmail(email) {
    const query = `
      SELECT
        u.id, u.email, u.password_hash, u.name, u.phone,
        u.profile_image_url, u.email_verified, u.is_active,
        u.is_locked, u.locked_until, u.timezone, u.locale,
        u.created_at, u.last_login_at,
        s.status as subscription_status
      FROM users u
      LEFT JOIN subscriptions s ON u.id = s.user_id
      WHERE u.email = $1 AND u.deleted_at IS NULL
    `;

    const result = await db.readQuery(query, [email.toLowerCase()]);
    return result.rows[0] || null;
  }

  /**
   * Verify user password
   * @param {string} password - Plain password
   * @param {string} hash - Stored hash
   * @returns {Promise<boolean>}
   */
  static async verifyPassword(password, hash) {
    return verifyPassword(password, hash);
  }

  /**
   * Update user's last login timestamp
   * @param {string} userId - User UUID
   */
  static async updateLastLogin(userId) {
    const query = `UPDATE users SET last_login_at = NOW() WHERE id = $1`;
    await db.query(query, [userId]);
  }

  /**
   * Update user profile
   * @param {string} userId - User UUID
   * @param {Object} updates - Fields to update
   * @returns {Promise<Object>} Updated user
   */
  static async update(userId, updates) {
    const allowedFields = [
      'name', 'phone', 'profile_image_url', 'timezone', 'locale',
    ];

    const fields = [];
    const values = [];
    let paramIndex = 1;

    for (const [key, value] of Object.entries(updates)) {
      if (allowedFields.includes(key)) {
        fields.push(`${key} = $${paramIndex}`);
        values.push(value);
        paramIndex++;
      }
    }

    if (fields.length === 0) {
      return this.findById(userId);
    }

    values.push(userId);

    const query = `
      UPDATE users
      SET ${fields.join(', ')}, updated_at = NOW()
      WHERE id = $${paramIndex}
      RETURNING id, email, name, phone, profile_image_url,
                email_verified, timezone, locale, updated_at
    `;

    const result = await db.query(query, values);
    return result.rows[0];
  }

  /**
   * Update user password
   * @param {string} userId - User UUID
   * @param {string} newPassword - New password
   */
  static async updatePassword(userId, newPassword) {
    const passwordHash = await hashPassword(newPassword);
    const query = `UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2`;
    await db.query(query, [passwordHash, userId]);
  }

  /**
   * Verify user email
   * @param {string} userId - User UUID
   */
  static async verifyEmail(userId) {
    const query = `
      UPDATE users
      SET email_verified = TRUE, updated_at = NOW()
      WHERE id = $1
    `;
    await db.query(query, [userId]);
  }

  /**
   * Soft delete user account
   * @param {string} userId - User UUID
   */
  static async delete(userId) {
    const query = `
      UPDATE users
      SET deleted_at = NOW(), is_active = FALSE, updated_at = NOW()
      WHERE id = $1
    `;
    await db.query(query, [userId]);
  }

  /**
   * Lock user account
   * @param {string} userId - User UUID
   * @param {string} reason - Lock reason
   * @param {Date} until - Lock expiry (optional)
   */
  static async lockAccount(userId, reason, until = null) {
    const query = `
      UPDATE users
      SET is_locked = TRUE, lock_reason = $2, locked_until = $3, updated_at = NOW()
      WHERE id = $1
    `;
    await db.query(query, [userId, reason, until]);
  }

  /**
   * Unlock user account
   * @param {string} userId - User UUID
   */
  static async unlockAccount(userId) {
    const query = `
      UPDATE users
      SET is_locked = FALSE, lock_reason = NULL, locked_until = NULL, updated_at = NOW()
      WHERE id = $1
    `;
    await db.query(query, [userId]);
  }

  /**
   * Get full user profile with health data
   * @param {string} userId - User UUID
   * @returns {Promise<Object>}
   */
  static async getFullProfile(userId) {
    const query = `
      SELECT
        u.id, u.email, u.name, u.phone, u.profile_image_url,
        u.email_verified, u.is_active, u.timezone, u.locale,
        u.created_at, u.last_login_at,
        hp.delivery_date, hp.delivery_type, hp.is_breastfeeding,
        hp.breastfeeding_intensity, hp.current_weight_kg, hp.target_weight_kg,
        hp.pre_pregnancy_weight_kg, hp.height_cm, hp.activity_level,
        hp.medical_conditions, hp.dietary_restrictions, hp.postpartum_weeks,
        hp.exercise_cleared_by_doctor,
        up.notifications_enabled, up.measurement_unit, up.language,
        up.dark_mode_enabled, up.hydration_interval_minutes,
        s.status as subscription_status, s.plan_name,
        s.current_period_end as subscription_expires_at
      FROM users u
      LEFT JOIN health_profiles hp ON u.id = hp.user_id
      LEFT JOIN user_preferences up ON u.id = up.user_id
      LEFT JOIN subscriptions s ON u.id = s.user_id
      WHERE u.id = $1 AND u.deleted_at IS NULL
    `;

    const result = await db.readQuery(query, [userId]);
    return result.rows[0] || null;
  }

  /**
   * Check if email exists
   * @param {string} email - Email to check
   * @returns {Promise<boolean>}
   */
  static async emailExists(email) {
    const query = `SELECT id FROM users WHERE email = $1 AND deleted_at IS NULL`;
    const result = await db.readQuery(query, [email.toLowerCase()]);
    return result.rows.length > 0;
  }

  /**
   * Get user count (for analytics)
   * @returns {Promise<number>}
   */
  static async count() {
    const query = `SELECT COUNT(*) as count FROM users WHERE deleted_at IS NULL`;
    const result = await db.readQuery(query);
    return parseInt(result.rows[0].count, 10);
  }
}

module.exports = User;
