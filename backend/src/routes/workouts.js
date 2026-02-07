/**
 * MomCare API - Workout Routes
 *
 * Handles workout session management and history.
 */

const express = require('express');
const router = express.Router();
const { exerciseController } = require('../controllers');
const { authenticate } = require('../middleware/auth');
const { validateBody, validateQuery, validateUUID, validatePagination } = require('../middleware/validation');
const { asyncHandler } = require('../middleware/errorHandler');
const { exerciseSchemas, dateRangeSchema, paginationSchema } = require('../utils/validators');
const Joi = require('joi');

// All routes require authentication
router.use(authenticate);

/**
 * @route   GET /api/v1/workouts
 * @desc    Get workout history
 * @access  Private
 */
router.get(
  '/',
  validateQuery(paginationSchema.concat(Joi.object({
    startDate: Joi.date(),
    endDate: Joi.date(),
  }))),
  asyncHandler(exerciseController.getWorkoutHistory)
);

/**
 * @route   GET /api/v1/workouts/stats
 * @desc    Get workout statistics
 * @access  Private
 */
router.get(
  '/stats',
  asyncHandler(exerciseController.getWorkoutStats)
);

/**
 * @route   POST /api/v1/workouts
 * @desc    Start a workout session
 * @access  Private
 */
router.post(
  '/',
  validateBody(exerciseSchemas.startWorkout),
  asyncHandler(exerciseController.startWorkout)
);

/**
 * @route   PUT /api/v1/workouts/:id/complete
 * @desc    Complete a workout session
 * @access  Private
 */
router.put(
  '/:id/complete',
  validateUUID('id'),
  validateBody(exerciseSchemas.completeWorkout),
  asyncHandler(exerciseController.completeWorkout)
);

module.exports = router;
