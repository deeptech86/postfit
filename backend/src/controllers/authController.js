/**
 * MomCare API - Authentication Controller
 *
 * Handles user registration, login, OAuth, and token management.
 */

const { User, HealthProfile } = require('../models');
const {
  generateTokenPair,
  verifyRefreshToken,
} = require('../middleware/auth');
const { generateToken, hashToken } = require('../utils/encryption');
const { success, error, created, unauthorized } = require('../utils/apiResponse');
const { cache } = require('../config/redis');
const db = require('../config/database');
const logger = require('../utils/logger');
const config = require('../config');

/**
 * Register a new user
 * POST /api/v1/auth/register
 */
async function register(req, res, next) {
  try {
    const { email, password, name, acceptTerms, marketingConsent } = req.body;

    // Check if email already exists
    const existingUser = await User.emailExists(email);
    if (existingUser) {
      return error(res, 'An account with this email already exists', 409, null, 'EMAIL_EXISTS');
    }

    // Create user
    const user = await User.create({
      email,
      password,
      name,
      termsAccepted: acceptTerms,
      marketingConsent,
    });

    // Create default preferences
    await db.query(
      `INSERT INTO user_preferences (user_id) VALUES ($1)`,
      [user.id]
    );

    // Create default subscription (free tier)
    await db.query(
      `INSERT INTO subscriptions (user_id, status) VALUES ($1, 'free')`,
      [user.id]
    );

    // Generate tokens
    const deviceId = req.body.deviceId || 'default';
    const tokens = generateTokenPair(user, deviceId);

    // Generate email verification token
    const verificationToken = generateToken(32);
    await cache.set(
      `email_verify:${hashToken(verificationToken)}`,
      user.id,
      24 * 60 * 60 // 24 hours
    );

    // TODO: Send verification email
    logger.info('User registered', { userId: user.id, email: user.email });

    return created(res, {
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        emailVerified: false,
        subscriptionStatus: 'free',
      },
      tokens,
      needsHealthProfile: true,
    }, 'Account created successfully');
  } catch (err) {
    next(err);
  }
}

/**
 * Login with email and password
 * POST /api/v1/auth/login
 */
async function login(req, res, next) {
  try {
    const { email, password, deviceId = 'default', deviceType = 'unknown', pushToken } = req.body;

    // Find user
    const user = await User.findByEmail(email);

    if (!user) {
      return unauthorized(res, 'Invalid email or password');
    }

    // Check if account is locked
    if (user.is_locked) {
      if (!user.locked_until || new Date(user.locked_until) > new Date()) {
        return error(res, 'Account is temporarily locked. Please try again later.', 403, null, 'ACCOUNT_LOCKED');
      }
      // Unlock if lock period has passed
      await User.unlockAccount(user.id);
    }

    // Verify password
    if (!user.password_hash) {
      return error(res, 'Please login using your social account', 400, null, 'OAUTH_ONLY');
    }

    const isValidPassword = await User.verifyPassword(password, user.password_hash);

    if (!isValidPassword) {
      // Track failed attempts
      const failedKey = `login_failed:${user.id}`;
      const failedAttempts = await cache.incr(failedKey);

      if (failedAttempts === 1) {
        await cache.expire(failedKey, 15 * 60); // 15 minute window
      }

      // Lock account after 5 failed attempts
      if (failedAttempts >= 5) {
        const lockUntil = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes
        await User.lockAccount(user.id, 'Too many failed login attempts', lockUntil);
        await cache.del(failedKey);
        return error(res, 'Account locked due to too many failed attempts. Try again in 15 minutes.', 403, null, 'ACCOUNT_LOCKED');
      }

      return unauthorized(res, 'Invalid email or password');
    }

    // Clear failed attempts on successful login
    await cache.del(`login_failed:${user.id}`);

    // Update last login
    await User.updateLastLogin(user.id);

    // Update or create device record
    if (deviceId) {
      await db.query(
        `INSERT INTO devices (user_id, device_id, device_type, push_token, last_active_at)
         VALUES ($1, $2, $3, $4, NOW())
         ON CONFLICT (user_id, device_id)
         DO UPDATE SET device_type = $3, push_token = COALESCE($4, devices.push_token),
                       last_active_at = NOW(), updated_at = NOW()`,
        [user.id, deviceId, deviceType, pushToken]
      );
    }

    // Generate tokens
    const tokens = generateTokenPair(user, deviceId);

    // Check if health profile exists
    const healthProfile = await HealthProfile.findByUserId(user.id);

    logger.info('User logged in', { userId: user.id });

    return success(res, {
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        profileImageUrl: user.profile_image_url,
        emailVerified: user.email_verified,
        subscriptionStatus: user.subscription_status || 'free',
      },
      tokens,
      hasHealthProfile: !!healthProfile,
    }, 'Login successful');
  } catch (err) {
    next(err);
  }
}

/**
 * Refresh access token
 * POST /api/v1/auth/refresh
 */
async function refreshToken(req, res, next) {
  try {
    const { refreshToken } = req.body;

    // Verify refresh token
    const decoded = verifyRefreshToken(refreshToken);

    if (!decoded) {
      return unauthorized(res, 'Invalid or expired refresh token');
    }

    // Check if token is blacklisted
    const isBlacklisted = await cache.exists(`blacklist:${refreshToken}`);
    if (isBlacklisted) {
      return unauthorized(res, 'Token has been revoked');
    }

    // Get user
    const user = await User.findById(decoded.sub);

    if (!user || !user.is_active) {
      return unauthorized(res, 'User not found or inactive');
    }

    // Generate new tokens
    const tokens = generateTokenPair(user, decoded.deviceId);

    // Blacklist old refresh token
    await cache.set(
      `blacklist:${refreshToken}`,
      'revoked',
      7 * 24 * 60 * 60 // 7 days
    );

    return success(res, { tokens }, 'Token refreshed successfully');
  } catch (err) {
    next(err);
  }
}

/**
 * Logout (revoke tokens)
 * POST /api/v1/auth/logout
 */
async function logout(req, res, next) {
  try {
    const { refreshToken } = req.body;
    const userId = req.user.id;

    // Blacklist refresh token if provided
    if (refreshToken) {
      await cache.set(
        `blacklist:${refreshToken}`,
        'revoked',
        7 * 24 * 60 * 60
      );
    }

    // Optionally invalidate all sessions
    const { allDevices } = req.body;
    if (allDevices) {
      // Invalidate all refresh tokens for this user
      await cache.set(`invalidate_tokens:${userId}`, Date.now(), 30 * 24 * 60 * 60);
    }

    logger.info('User logged out', { userId });

    return success(res, null, 'Logged out successfully');
  } catch (err) {
    next(err);
  }
}

/**
 * Request password reset
 * POST /api/v1/auth/forgot-password
 */
async function forgotPassword(req, res, next) {
  try {
    const { email } = req.body;

    // Always return success to prevent email enumeration
    const successMessage = 'If an account exists with this email, you will receive a password reset link.';

    const user = await User.findByEmail(email);

    if (!user) {
      return success(res, null, successMessage);
    }

    // Generate reset token
    const resetToken = generateToken(32);
    const hashedToken = hashToken(resetToken);

    // Store token with 1 hour expiry
    await cache.set(
      `password_reset:${hashedToken}`,
      user.id,
      60 * 60 // 1 hour
    );

    // TODO: Send password reset email with resetToken
    logger.info('Password reset requested', { userId: user.id });

    return success(res, null, successMessage);
  } catch (err) {
    next(err);
  }
}

/**
 * Reset password with token
 * POST /api/v1/auth/reset-password
 */
async function resetPassword(req, res, next) {
  try {
    const { token, password } = req.body;

    const hashedToken = hashToken(token);
    const userId = await cache.get(`password_reset:${hashedToken}`);

    if (!userId) {
      return error(res, 'Invalid or expired reset token', 400, null, 'INVALID_TOKEN');
    }

    // Update password
    await User.updatePassword(userId, password);

    // Delete reset token
    await cache.del(`password_reset:${hashedToken}`);

    // Invalidate all existing sessions
    await cache.set(`invalidate_tokens:${userId}`, Date.now(), 30 * 24 * 60 * 60);

    logger.info('Password reset completed', { userId });

    return success(res, null, 'Password reset successfully. Please login with your new password.');
  } catch (err) {
    next(err);
  }
}

/**
 * Change password (authenticated)
 * POST /api/v1/auth/change-password
 */
async function changePassword(req, res, next) {
  try {
    const { currentPassword, newPassword } = req.body;
    const userId = req.user.id;

    // Get user with password
    const user = await User.findByEmail(req.user.email);

    if (!user.password_hash) {
      return error(res, 'Cannot change password for social login accounts', 400);
    }

    // Verify current password
    const isValid = await User.verifyPassword(currentPassword, user.password_hash);

    if (!isValid) {
      return error(res, 'Current password is incorrect', 400);
    }

    // Update password
    await User.updatePassword(userId, newPassword);

    // Invalidate other sessions
    await cache.set(`invalidate_tokens:${userId}`, Date.now(), 30 * 24 * 60 * 60);

    logger.info('Password changed', { userId });

    return success(res, null, 'Password changed successfully');
  } catch (err) {
    next(err);
  }
}

/**
 * Verify email
 * POST /api/v1/auth/verify-email
 */
async function verifyEmail(req, res, next) {
  try {
    const { token } = req.body;

    const hashedToken = hashToken(token);
    const userId = await cache.get(`email_verify:${hashedToken}`);

    if (!userId) {
      return error(res, 'Invalid or expired verification token', 400, null, 'INVALID_TOKEN');
    }

    // Verify email
    await User.verifyEmail(userId);

    // Delete verification token
    await cache.del(`email_verify:${hashedToken}`);

    logger.info('Email verified', { userId });

    return success(res, null, 'Email verified successfully');
  } catch (err) {
    next(err);
  }
}

/**
 * Resend verification email
 * POST /api/v1/auth/resend-verification
 */
async function resendVerification(req, res, next) {
  try {
    const userId = req.user.id;
    const user = await User.findById(userId);

    if (user.email_verified) {
      return error(res, 'Email is already verified', 400);
    }

    // Generate new verification token
    const verificationToken = generateToken(32);
    await cache.set(
      `email_verify:${hashToken(verificationToken)}`,
      userId,
      24 * 60 * 60
    );

    // TODO: Send verification email
    logger.info('Verification email resent', { userId });

    return success(res, null, 'Verification email sent');
  } catch (err) {
    next(err);
  }
}

/**
 * Get current user
 * GET /api/v1/auth/me
 */
async function getCurrentUser(req, res, next) {
  try {
    const userData = await User.getFullProfile(req.user.id);

    if (!userData) {
      return error(res, 'User not found', 404);
    }

    // Separate user fields from health profile fields
    const healthProfileFields = [
      'delivery_date', 'delivery_type', 'is_breastfeeding', 'breastfeeding_intensity',
      'current_weight_kg', 'target_weight_kg', 'pre_pregnancy_weight_kg', 'height_cm',
      'activity_level', 'medical_conditions', 'dietary_restrictions', 'postpartum_weeks',
      'exercise_cleared_by_doctor'
    ];

    const healthProfile = {};
    const user = {};

    Object.keys(userData).forEach(key => {
      if (healthProfileFields.includes(key)) {
        healthProfile[key] = userData[key];
      } else {
        user[key] = userData[key];
      }
    });

    return success(res, { user, healthProfile });
  } catch (err) {
    next(err);
  }
}

/**
 * Apple Sign-In
 * POST /api/v1/auth/apple
 */
async function appleSignIn(req, res, next) {
  try {
    const {
      userIdentifier,
      email,
      fullName,
      identityToken,
      authorizationCode,
      nonce,
      deviceId = 'default',
      deviceType = 'ios',
      pushToken
    } = req.body;

    // TODO: Verify identityToken with Apple servers
    // For now, we trust the client verification

    // Check if user exists
    let user = await db.query(
      `SELECT * FROM users WHERE apple_id = $1`,
      [userIdentifier]
    );

    let isNewUser = false;

    if (!user.rows.length) {
      // Create new user
      isNewUser = true;
      const result = await db.query(
        `INSERT INTO users (email, name, apple_id, email_verified, auth_provider)
         VALUES ($1, $2, $3, true, 'apple')
         RETURNING *`,
        [email || `apple_${userIdentifier}@momcare.app`, fullName || 'Apple User', userIdentifier]
      );
      user = result.rows[0];

      // Create default preferences
      await db.query(
        `INSERT INTO user_preferences (user_id) VALUES ($1)`,
        [user.id]
      );

      // Create default subscription (free tier)
      await db.query(
        `INSERT INTO subscriptions (user_id, status) VALUES ($1, 'free')`,
        [user.id]
      );

      logger.info('New Apple user created', { userId: user.id, appleId: userIdentifier });
    } else {
      user = user.rows[0];

      // Update last login
      await User.updateLastLogin(user.id);

      logger.info('Existing Apple user logged in', { userId: user.id });
    }

    // Update or create device record
    if (deviceId) {
      await db.query(
        `INSERT INTO devices (user_id, device_id, device_type, push_token, last_active_at)
         VALUES ($1, $2, $3, $4, NOW())
         ON CONFLICT (user_id, device_id)
         DO UPDATE SET device_type = $3, push_token = COALESCE($4, devices.push_token),
                       last_active_at = NOW(), updated_at = NOW()`,
        [user.id, deviceId, deviceType, pushToken]
      );
    }

    // Generate tokens
    const tokens = generateTokenPair(user, deviceId);

    // Check if health profile exists
    const healthProfile = await HealthProfile.findByUserId(user.id);

    return success(res, {
      sessionToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        profileImageURL: user.profile_image_url,
        hasCompletedProfile: !!healthProfile,
      },
      isNewUser,
      expiresAt: new Date(Date.now() + 2 * 60 * 60 * 1000), // 2 hours
    }, 'Apple Sign-In successful');
  } catch (err) {
    next(err);
  }
}

/**
 * Google Sign-In
 * POST /api/v1/auth/google
 */
async function googleSignIn(req, res, next) {
  try {
    // Debug: Log the incoming request body
    logger.debug('Google Sign-In request received', { body: req.body });

    // Extract credentials from nested structure (iOS sends AuthRequest)
    const credentialsData = req.body.credentials || req.body;
    const deviceInfoData = req.body.deviceInfo || {};

    const {
      userID,
      email,
      fullName,
      profileImageURL,
      idToken
    } = credentialsData;

    const {
      deviceID: deviceId = 'default',
      deviceModel: deviceType = 'ios',
      pushToken
    } = deviceInfoData;

    // Log extracted values
    logger.debug('Extracted Google Sign-In fields', {
      userID,
      email,
      emailType: typeof email,
      emailLength: email ? email.length : 0,
      fullName,
      profileImageURL,
      deviceId,
      deviceType
    });

    // Validate required fields
    if (!userID) {
      return res.status(400).json({
        success: false,
        message: 'Missing required field: userID'
      });
    }

    // Validate and sanitize email
    let validEmail = email;
    if (!validEmail || validEmail.trim() === '') {
      // Generate fallback email if not provided
      validEmail = `${userID}@google.user`;
      logger.warn('Google Sign-In: No email provided, using fallback', { userID, fallbackEmail: validEmail });
    }

    // TODO: Verify idToken with Google servers
    // For now, we trust the client verification

    // Check if user exists
    let user = await db.query(
      `SELECT * FROM users WHERE google_id = $1`,
      [userID]
    );

    let isNewUser = false;

    if (!user.rows.length) {
      // Create new user
      isNewUser = true;
      const result = await db.query(
        `INSERT INTO users (email, name, google_id, profile_image_url, email_verified, auth_provider)
         VALUES ($1, $2, $3, $4, true, 'google')
         RETURNING *`,
        [validEmail, fullName || 'Google User', userID, profileImageURL]
      );
      user = result.rows[0];

      // Create default preferences
      await db.query(
        `INSERT INTO user_preferences (user_id) VALUES ($1)`,
        [user.id]
      );

      // Create default subscription (free tier)
      await db.query(
        `INSERT INTO subscriptions (user_id, status) VALUES ($1, 'free')`,
        [user.id]
      );

      logger.info('New Google user created', { userId: user.id, googleId: userID });
    } else {
      user = user.rows[0];

      // Update last login and profile image if changed
      await User.updateLastLogin(user.id);
      if (profileImageURL && profileImageURL !== user.profile_image_url) {
        await db.query(
          `UPDATE users SET profile_image_url = $1, updated_at = NOW() WHERE id = $2`,
          [profileImageURL, user.id]
        );
      }

      logger.info('Existing Google user logged in', { userId: user.id });
    }

    // Update or create device record
    if (deviceId) {
      await db.query(
        `INSERT INTO devices (user_id, device_id, device_type, push_token, last_active_at)
         VALUES ($1, $2, $3, $4, NOW())
         ON CONFLICT (user_id, device_id)
         DO UPDATE SET device_type = $3, push_token = COALESCE($4, devices.push_token),
                       last_active_at = NOW(), updated_at = NOW()`,
        [user.id, deviceId, deviceType, pushToken]
      );
    }

    // Generate tokens
    const tokens = generateTokenPair(user, deviceId);

    // Check if health profile exists
    const healthProfile = await HealthProfile.findByUserId(user.id);

    const responseData = {
      sessionToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        profileImageURL: user.profile_image_url,
        hasCompletedProfile: !!healthProfile,
      },
      isNewUser,
      expiresAt: new Date(Date.now() + 2 * 60 * 60 * 1000), // 2 hours
    };

    logger.debug('Sending Google Sign-In response', {
      userId: user.id,
      isNewUser,
      hasProfile: !!healthProfile,
      responseKeys: Object.keys(responseData)
    });

    return success(res, responseData, 'Google Sign-In successful');
  } catch (err) {
    next(err);
  }
}

/**
 * Verify session
 * POST /api/v1/auth/verify-session
 */
async function verifySession(req, res, next) {
  try {
    const userId = req.user.id;

    // Get user with profile
    const userData = await User.getFullProfile(userId);

    if (!userData) {
      return unauthorized(res, 'Session invalid');
    }

    // Check if health profile exists
    const healthProfile = await HealthProfile.findByUserId(userId);

    return success(res, {
      isValid: true,
      user: {
        id: userData.id,
        email: userData.email,
        name: userData.name,
        profileImageURL: userData.profile_image_url,
        hasCompletedProfile: !!healthProfile,
      },
      expiresAt: new Date(req.user.exp * 1000), // Convert JWT exp to Date
    }, 'Session is valid');
  } catch (err) {
    next(err);
  }
}

module.exports = {
  register,
  login,
  refreshToken,
  logout,
  forgotPassword,
  resetPassword,
  changePassword,
  verifyEmail,
  resendVerification,
  getCurrentUser,
  appleSignIn,
  googleSignIn,
  verifySession,
};
