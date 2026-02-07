/**
 * MomCare API - Controllers Index
 *
 * Export all controllers for easy importing
 */

const authController = require('./authController');
const foodController = require('./foodController');
const hydrationController = require('./hydrationController');
const exerciseController = require('./exerciseController');

module.exports = {
  authController,
  foodController,
  hydrationController,
  exerciseController,
};
