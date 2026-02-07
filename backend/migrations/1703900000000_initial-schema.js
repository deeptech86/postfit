/**
 * MomCare API - Initial Database Migration
 *
 * This migration creates the complete database schema for the
 * postpartum health & wellness application.
 *
 * Run: npm run migrate
 * Rollback: npm run migrate:down
 */

const fs = require('fs');
const path = require('path');

exports.shorthands = undefined;

exports.up = (pgm) => {
  // Read and execute the full SQL schema
  const schemaPath = path.join(__dirname, '001_initial_schema.sql');
  const schemaSql = fs.readFileSync(schemaPath, 'utf8');
  pgm.sql(schemaSql);
};

exports.down = (pgm) => {
  // Drop all tables in reverse order of dependencies
  const tables = [
    'app_feedback',
    'support_tickets',
    'audit_logs',
    'partner_access',
    'notifications',
    'telehealth_appointments',
    'medical_records',
    'streaks',
    'user_achievements',
    'achievements',
    'follows',
    'reports',
    'likes',
    'comments',
    'posts',
    'baby_sleep_entries',
    'diaper_changes',
    'pumping_sessions',
    'breastfeeding_sessions',
    'babies',
    'progress_photos',
    'body_measurements',
    'weight_entries',
    'journal_entries',
    'edinburgh_assessments',
    'mood_entries',
    'sleep_entries',
    'favorite_exercises',
    'workout_exercises',
    'workout_sessions',
    'exercises',
    'hydration_entries',
    'saved_recipes',
    'meal_plan_items',
    'meal_plans',
    'recipes',
    'custom_foods',
    'food_entries',
    'devices',
    'subscriptions',
    'user_preferences',
    'health_profiles',
    'oauth_accounts',
    'users',
  ];

  // Drop tables
  tables.forEach((table) => {
    pgm.dropTable(table, { ifExists: true, cascade: true });
  });

  // Drop types
  const types = [
    'measurement_unit',
    'oauth_provider',
    'report_reason',
    'post_category',
    'energy_level',
    'mood_state',
    'sleep_quality',
    'muscle_group',
    'exercise_difficulty',
    'exercise_category',
    'drink_type',
    'meal_type',
    'subscription_status',
    'dietary_restriction',
    'medical_condition',
    'activity_level',
    'breastfeeding_intensity',
    'recovery_stage',
    'delivery_type',
  ];

  types.forEach((type) => {
    pgm.sql(`DROP TYPE IF EXISTS ${type} CASCADE`);
  });

  // Drop functions
  pgm.sql('DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE');
  pgm.sql('DROP FUNCTION IF EXISTS update_post_comment_count() CASCADE');
  pgm.sql('DROP FUNCTION IF EXISTS update_like_count() CASCADE');
};
