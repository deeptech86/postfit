/**
 * MomCare API - Authentication Middleware
 *
 * JWT validation, OAuth integration, and role-based access control.
 */

const jwt = require('jsonwebtoken');
const passport = require('passport');
const { Strategy: JwtStrategy, ExtractJwt } = require('passport-jwt');
const GoogleStrategy = require('passport-google-oauth20').Strategy;
const FacebookStrategy = require('passport-facebook').Strategy;
const AppleStrategy = require('passport-apple');

const config = require('../config');
const { User } = require('../models');
const { session: redisSession } = require('../config/redis');
const logger = require('../utils/logger');
const { unauthorized, forbidden } = require('../utils/apiResponse');

// =============================================================================
// JWT Strategy Configuration
// =============================================================================

const jwtOptions = {
  jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
  secretOrKey: config.jwt.secret,
  algorithms: ['HS256'],
};

passport.use(
  new JwtStrategy(jwtOptions, async (payload, done) => {
    try {
      const user = await User.findById(payload.sub);

      if (!user) {
        return done(null, false);
      }

      if (!user.is_active) {
        return done(null, false, { message: 'Account is deactivated' });
      }

      if (user.is_locked) {
        if (!user.locked_until || new Date(user.locked_until) > new Date()) {
          return done(null, false, { message: 'Account is locked' });
        }
      }

      return done(null, user);
    } catch (error) {
      logger.error('JWT Strategy error', { error: error.message });
      return done(error, false);
    }
  })
);

// =============================================================================
// Google OAuth Strategy
// =============================================================================

if (config.oauth.google.clientId) {
  passport.use(
    new GoogleStrategy(
      {
        clientID: config.oauth.google.clientId,
        clientSecret: config.oauth.google.clientSecret,
        callbackURL: config.oauth.google.callbackUrl,
        scope: ['profile', 'email'],
      },
      async (accessToken, refreshToken, profile, done) => {
        try {
          const oauthData = {
            provider: 'google',
            providerId: profile.id,
            email: profile.emails?.[0]?.value,
            name: profile.displayName,
            profileImageUrl: profile.photos?.[0]?.value,
            accessToken,
            refreshToken,
          };
          return done(null, oauthData);
        } catch (error) {
          return done(error, null);
        }
      }
    )
  );
}

// =============================================================================
// Facebook OAuth Strategy
// =============================================================================

if (config.oauth.facebook.appId) {
  passport.use(
    new FacebookStrategy(
      {
        clientID: config.oauth.facebook.appId,
        clientSecret: config.oauth.facebook.appSecret,
        callbackURL: config.oauth.facebook.callbackUrl,
        profileFields: ['id', 'emails', 'name', 'picture.type(large)'],
      },
      async (accessToken, refreshToken, profile, done) => {
        try {
          const oauthData = {
            provider: 'facebook',
            providerId: profile.id,
            email: profile.emails?.[0]?.value,
            name: `${profile.name?.givenName} ${profile.name?.familyName}`,
            profileImageUrl: profile.photos?.[0]?.value,
            accessToken,
            refreshToken,
          };
          return done(null, oauthData);
        } catch (error) {
          return done(error, null);
        }
      }
    )
  );
}

// =============================================================================
// Token Generation
// =============================================================================

/**
 * Generate access token
 * @param {Object} user - User object
 * @returns {string} JWT access token
 */
function generateAccessToken(user) {
  const payload = {
    sub: user.id,
    email: user.email,
    name: user.name,
    subscription: user.subscription_status || 'free',
  };

  return jwt.sign(payload, config.jwt.secret, {
    expiresIn: config.jwt.expiresIn,
    issuer: 'momcare-api',
    audience: 'momcare-app',
  });
}

/**
 * Generate refresh token
 * @param {Object} user - User object
 * @param {string} deviceId - Device identifier
 * @returns {string} JWT refresh token
 */
function generateRefreshToken(user, deviceId) {
  const payload = {
    sub: user.id,
    deviceId,
    type: 'refresh',
  };

  return jwt.sign(payload, config.jwt.refreshSecret, {
    expiresIn: config.jwt.refreshExpiresIn,
    issuer: 'momcare-api',
  });
}

/**
 * Verify refresh token
 * @param {string} token - Refresh token
 * @returns {Object|null} Decoded payload or null
 */
function verifyRefreshToken(token) {
  try {
    return jwt.verify(token, config.jwt.refreshSecret, {
      issuer: 'momcare-api',
    });
  } catch (error) {
    return null;
  }
}

/**
 * Generate token pair (access + refresh)
 * @param {Object} user - User object
 * @param {string} deviceId - Device identifier
 * @returns {Object} Token pair
 */
function generateTokenPair(user, deviceId) {
  const accessToken = generateAccessToken(user);
  const refreshToken = generateRefreshToken(user, deviceId);

  // Decode to get expiry times
  const accessDecoded = jwt.decode(accessToken);
  const refreshDecoded = jwt.decode(refreshToken);

  return {
    accessToken,
    refreshToken,
    accessTokenExpiresAt: new Date(accessDecoded.exp * 1000),
    refreshTokenExpiresAt: new Date(refreshDecoded.exp * 1000),
    tokenType: 'Bearer',
  };
}

// =============================================================================
// Middleware Functions
// =============================================================================

/**
 * Authenticate JWT token
 * Required authentication middleware
 */
const authenticate = (req, res, next) => {
  passport.authenticate('jwt', { session: false }, (err, user, info) => {
    if (err) {
      logger.error('Authentication error', { error: err.message });
      return unauthorized(res, 'Authentication error');
    }

    if (!user) {
      const message = info?.message || 'Invalid or expired token';
      return unauthorized(res, message);
    }

    req.user = user;
    next();
  })(req, res, next);
};

/**
 * Optional authentication
 * Attaches user if valid token, continues without error if not
 */
const optionalAuth = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return next();
  }

  passport.authenticate('jwt', { session: false }, (err, user) => {
    if (user) {
      req.user = user;
    }
    next();
  })(req, res, next);
};

/**
 * Require premium subscription
 */
const requirePremium = (req, res, next) => {
  if (!req.user) {
    return unauthorized(res, 'Authentication required');
  }

  const premiumStatuses = ['premium', 'trial'];

  if (!premiumStatuses.includes(req.user.subscription_status)) {
    return forbidden(res, 'Premium subscription required for this feature');
  }

  next();
};

/**
 * Require email verification
 */
const requireVerifiedEmail = (req, res, next) => {
  if (!req.user) {
    return unauthorized(res, 'Authentication required');
  }

  if (!req.user.email_verified) {
    return forbidden(res, 'Email verification required');
  }

  next();
};

/**
 * Rate limit by user
 * Uses Redis to track request counts
 */
const userRateLimit = (maxRequests, windowSeconds) => {
  return async (req, res, next) => {
    if (!req.user) {
      return next();
    }

    const key = `ratelimit:user:${req.user.id}`;

    try {
      const { cache } = require('../config/redis');
      const current = await cache.incr(key);

      if (current === 1) {
        await cache.expire(key, windowSeconds);
      }

      if (current > maxRequests) {
        res.set('Retry-After', windowSeconds);
        return res.status(429).json({
          success: false,
          message: 'Too many requests. Please try again later.',
          retryAfter: windowSeconds,
        });
      }

      next();
    } catch (error) {
      logger.error('Rate limit error', { error: error.message });
      next(); // Fail open
    }
  };
};

/**
 * Log HIPAA audit event
 */
const auditLog = (eventType, resourceType) => {
  return (req, res, next) => {
    const originalEnd = res.end;

    res.end = function (...args) {
      // Log after response
      if (config.hipaa.auditEnabled) {
        const { logAuditEvent } = require('../utils/logger');
        logAuditEvent({
          type: eventType,
          userId: req.user?.id,
          resourceType,
          resourceId: req.params.id,
          action: req.method,
          ipAddress: req.ip,
          userAgent: req.get('user-agent'),
          outcome: res.statusCode < 400 ? 'success' : 'failure',
        });
      }

      return originalEnd.apply(this, args);
    };

    next();
  };
};

// =============================================================================
// Initialize Passport
// =============================================================================

function initializePassport(app) {
  app.use(passport.initialize());
}

module.exports = {
  passport,
  authenticate,
  optionalAuth,
  requirePremium,
  requireVerifiedEmail,
  userRateLimit,
  auditLog,
  generateAccessToken,
  generateRefreshToken,
  generateTokenPair,
  verifyRefreshToken,
  initializePassport,
};
