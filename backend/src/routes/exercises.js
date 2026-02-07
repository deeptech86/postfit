/**
 * MomCare API - Exercise Routes
 *
 * Handles exercise library, workout tracking, and recommendations.
 */

const express = require('express');
const router = express.Router();
const { exerciseController } = require('../controllers');
const { authenticate } = require('../middleware/auth');
const { validateBody, validateQuery, validateUUID, validatePagination } = require('../middleware/validation');
const { asyncHandler } = require('../middleware/errorHandler');
const { exerciseSchemas } = require('../utils/validators');

// All routes require authentication
router.use(authenticate);

/**
 * @route   GET /api/v1/exercises
 * @desc    Get exercises with filters
 * @access  Private
 */
router.get(
  '/',
  validateQuery(exerciseSchemas.listExercises),
  asyncHandler(exerciseController.getExercises)
);

/**
 * @route   GET /api/v1/exercises/recommendations
 * @desc    Get personalized exercise recommendations
 * @access  Private
 */
router.get(
  '/recommendations',
  asyncHandler(exerciseController.getRecommendations)
);

/**
 * @route   GET /api/v1/exercises/favorites
 * @desc    Get favorite exercises
 * @access  Private
 */
router.get(
  '/favorites',
  asyncHandler(exerciseController.getFavorites)
);

/**
 * @route   GET /api/v1/exercises/category/:category
 * @desc    Get exercises by category
 * @access  Private
 */
router.get(
  '/category/:category',
  asyncHandler(exerciseController.getByCategory)
);

/**
 * @route   GET /api/v1/exercises/:id
 * @desc    Get a specific exercise
 * @access  Private
 */
router.get(
  '/:id',
  validateUUID('id'),
  asyncHandler(exerciseController.getExercise)
);

/**
 * @route   POST /api/v1/exercises/:id/favorite
 * @desc    Toggle favorite status
 * @access  Private
 */
router.post(
  '/:id/favorite',
  validateUUID('id'),
  asyncHandler(exerciseController.toggleFavorite)
);

module.exports = router;
