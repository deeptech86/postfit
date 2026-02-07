/**
 * MomCare API - Models Index
 *
 * Export all models for easy importing
 */

const User = require('./User');
const HealthProfile = require('./HealthProfile');
const FoodEntry = require('./FoodEntry');
const HydrationEntry = require('./HydrationEntry');
const Exercise = require('./Exercise');

module.exports = {
  User,
  HealthProfile,
  FoodEntry,
  HydrationEntry,
  Exercise,
};
