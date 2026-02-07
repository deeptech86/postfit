/**
 * MomCare API - Authentication Routes
 *
 * Handles user registration, login, OAuth, and token management.
 */

const express = require('express');
const router = express.Router();
const { authController } = require('../controllers');
const { authenticate } = require('../middleware/auth');
const { validateBody } = require('../middleware/validation');
const { authLimiter, passwordResetLimiter } = require('../middleware/rateLimit');
const { asyncHandler } = require('../middleware/errorHandler');
const { authSchemas } = require('../utils/validators');

/**
 * @route   POST /api/v1/auth/register
 * @desc    Register a new user
 * @access  Public
 */
router.post(
  '/register',
  authLimiter,
  validateBody(authSchemas.register),
  asyncHandler(authController.register)
);

/**
 * @route   POST /api/v1/auth/login
 * @desc    Login with email and password
 * @access  Public
 */
router.post(
  '/login',
  authLimiter,
  validateBody(authSchemas.login),
  asyncHandler(authController.login)
);

/**
 * @route   POST /api/v1/auth/refresh
 * @desc    Refresh access token
 * @access  Public (with valid refresh token)
 */
router.post(
  '/refresh',
  validateBody(authSchemas.refreshToken),
  asyncHandler(authController.refreshToken)
);

/**
 * @route   POST /api/v1/auth/logout
 * @desc    Logout and revoke tokens
 * @access  Private
 */
router.post(
  '/logout',
  authenticate,
  asyncHandler(authController.logout)
);

/**
 * @route   POST /api/v1/auth/forgot-password
 * @desc    Request password reset
 * @access  Public
 */
router.post(
  '/forgot-password',
  passwordResetLimiter,
  validateBody(authSchemas.forgotPassword),
  asyncHandler(authController.forgotPassword)
);

/**
 * @route   POST /api/v1/auth/reset-password
 * @desc    Reset password with token
 * @access  Public
 */
router.post(
  '/reset-password',
  passwordResetLimiter,
  validateBody(authSchemas.resetPassword),
  asyncHandler(authController.resetPassword)
);

/**
 * @route   POST /api/v1/auth/change-password
 * @desc    Change password (authenticated)
 * @access  Private
 */
router.post(
  '/change-password',
  authenticate,
  validateBody(authSchemas.changePassword),
  asyncHandler(authController.changePassword)
);

/**
 * @route   POST /api/v1/auth/verify-email
 * @desc    Verify email with token
 * @access  Public
 */
router.post(
  '/verify-email',
  asyncHandler(authController.verifyEmail)
);

/**
 * @route   POST /api/v1/auth/resend-verification
 * @desc    Resend verification email
 * @access  Private
 */
router.post(
  '/resend-verification',
  authenticate,
  asyncHandler(authController.resendVerification)
);

/**
 * @route   GET /api/v1/auth/me
 * @desc    Get current user profile
 * @access  Private
 */
router.get(
  '/me',
  authenticate,
  asyncHandler(authController.getCurrentUser)
);

/**
 * @route   POST /api/v1/auth/apple
 * @desc    Sign in with Apple
 * @access  Public
 */
router.post(
  '/apple',
  authLimiter,
  asyncHandler(authController.appleSignIn)
);

/**
 * @route   POST /api/v1/auth/google
 * @desc    Sign in with Google
 * @access  Public
 */
router.post(
  '/google',
  authLimiter,
  asyncHandler(authController.googleSignIn)
);

/**
 * @route   POST /api/v1/auth/verify-session
 * @desc    Verify if session token is still valid
 * @access  Private
 */
router.post(
  '/verify-session',
  authenticate,
  asyncHandler(authController.verifySession)
);

module.exports = router;
