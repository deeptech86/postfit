/**
 * MomCare API - Food Routes
 *
 * Handles food logging, nutrition tracking, and AI recognition.
 */

const express = require('express');
const router = express.Router();
const { foodController } = require('../controllers');
const { authenticate, requirePremium } = require('../middleware/auth');
const { validateBody, validateQuery, validateUUID } = require('../middleware/validation');
const { aiLimiter } = require('../middleware/rateLimit');
const { asyncHandler } = require('../middleware/errorHandler');
const { foodSchemas, dateRangeSchema } = require('../utils/validators');

// All routes require authentication
router.use(authenticate);

/**
 * @route   POST /api/v1/food
 * @desc    Create a food entry
 * @access  Private
 */
router.post(
  '/',
  validateBody(foodSchemas.createFoodEntry),
  asyncHandler(foodController.createEntry)
);

/**
 * @route   GET /api/v1/food/date/:date
 * @desc    Get food entries for a specific date
 * @access  Private
 */
router.get(
  '/date/:date',
  asyncHandler(foodController.getByDate)
);

/**
 * @route   GET /api/v1/food/range
 * @desc    Get individual food entries for date range
 * @access  Private
 */
router.get(
  '/range',
  validateQuery(dateRangeSchema),
  asyncHandler(foodController.getByDateRange)
);

/**
 * @route   GET /api/v1/food/summary
 * @desc    Get nutrition summary for date range
 * @access  Private
 */
router.get(
  '/summary',
  validateQuery(dateRangeSchema),
  asyncHandler(foodController.getSummary)
);

/**
 * @route   GET /api/v1/food/search
 * @desc    Search user's food history
 * @access  Private
 */
router.get(
  '/search',
  validateQuery(foodSchemas.searchFood),
  asyncHandler(foodController.searchHistory)
);

/**
 * @route   GET /api/v1/food/frequent
 * @desc    Get frequently logged foods
 * @access  Private
 */
router.get(
  '/frequent',
  asyncHandler(foodController.getFrequentFoods)
);

/**
 * @route   GET /api/v1/food/targets
 * @desc    Get calorie and nutrition targets
 * @access  Private
 */
router.get(
  '/targets',
  asyncHandler(foodController.getTargets)
);

/**
 * @route   POST /api/v1/food/recognize
 * @desc    AI-powered food recognition
 * @access  Private (Premium feature with limits for free users)
 */
router.post(
  '/recognize',
  aiLimiter,
  validateBody(foodSchemas.aiRecognition),
  asyncHandler(foodController.recognizeFood)
);

/**
 * @route   GET /api/v1/food/:id
 * @desc    Get a specific food entry
 * @access  Private
 */
router.get(
  '/:id',
  validateUUID('id'),
  asyncHandler(foodController.getById)
);

/**
 * @route   PUT /api/v1/food/:id
 * @desc    Update a food entry
 * @access  Private
 */
router.put(
  '/:id',
  validateUUID('id'),
  validateBody(foodSchemas.updateFoodEntry),
  asyncHandler(foodController.updateEntry)
);

/**
 * @route   DELETE /api/v1/food/:id
 * @desc    Delete a food entry
 * @access  Private
 */
router.delete(
  '/:id',
  validateUUID('id'),
  asyncHandler(foodController.deleteEntry)
);

module.exports = router;
