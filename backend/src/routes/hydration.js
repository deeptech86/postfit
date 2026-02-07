/**
 * MomCare API - Hydration Routes
 *
 * Handles water intake tracking with breastfeeding-adjusted goals.
 */

const express = require('express');
const router = express.Router();
const { hydrationController } = require('../controllers');
const { authenticate } = require('../middleware/auth');
const { validateBody, validateQuery, validateUUID } = require('../middleware/validation');
const { asyncHandler } = require('../middleware/errorHandler');
const { hydrationSchemas, dateRangeSchema } = require('../utils/validators');

// All routes require authentication
router.use(authenticate);

/**
 * @route   POST /api/v1/hydration
 * @desc    Log a hydration entry
 * @access  Private
 */
router.post(
  '/',
  validateBody(hydrationSchemas.createEntry),
  asyncHandler(hydrationController.createEntry)
);

/**
 * @route   GET /api/v1/hydration/today
 * @desc    Get today's hydration progress
 * @access  Private
 */
router.get(
  '/today',
  asyncHandler(hydrationController.getTodayProgress)
);

/**
 * @route   GET /api/v1/hydration/goal
 * @desc    Get hydration goal
 * @access  Private
 */
router.get(
  '/goal',
  asyncHandler(hydrationController.getGoal)
);

/**
 * @route   GET /api/v1/hydration/summary
 * @desc    Get hydration summary for date range
 * @access  Private
 */
router.get(
  '/summary',
  validateQuery(dateRangeSchema),
  asyncHandler(hydrationController.getSummary)
);

/**
 * @route   GET /api/v1/hydration/distribution
 * @desc    Get hourly distribution
 * @access  Private
 */
router.get(
  '/distribution',
  asyncHandler(hydrationController.getDistribution)
);

/**
 * @route   POST /api/v1/hydration/quick-add
 * @desc    Quick add preset amounts
 * @access  Private
 */
router.post(
  '/quick-add',
  asyncHandler(hydrationController.quickAdd)
);

/**
 * @route   GET /api/v1/hydration/date/:date
 * @desc    Get hydration entries for a specific date
 * @access  Private
 */
router.get(
  '/date/:date',
  asyncHandler(hydrationController.getByDate)
);

/**
 * @route   GET /api/v1/hydration/:id
 * @desc    Get a specific hydration entry
 * @access  Private
 */
router.get(
  '/:id',
  validateUUID('id'),
  asyncHandler(hydrationController.getById)
);

/**
 * @route   PUT /api/v1/hydration/:id
 * @desc    Update a hydration entry
 * @access  Private
 */
router.put(
  '/:id',
  validateUUID('id'),
  validateBody(hydrationSchemas.updateEntry),
  asyncHandler(hydrationController.updateEntry)
);

/**
 * @route   DELETE /api/v1/hydration/:id
 * @desc    Delete a hydration entry
 * @access  Private
 */
router.delete(
  '/:id',
  validateUUID('id'),
  asyncHandler(hydrationController.deleteEntry)
);

module.exports = router;
