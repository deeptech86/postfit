/**
 * MomCare API - Rate Limiting Middleware
 *
 * Configurable rate limiting to prevent abuse
 * Uses Redis for distributed rate limiting
 */

const rateLimit = require('express-rate-limit');
const slowDown = require('express-slow-down');
const config = require('../config');
const logger = require('../utils/logger');

/**
 * Custom Redis store for rate limiting
 */
class RedisStore {
  constructor(options = {}) {
    this.client = options.client;
    this.prefix = options.prefix || 'rl:';
    this.windowMs = options.windowMs || 60000;
  }

  async increment(key) {
    const redisKey = `${this.prefix}${key}`;

    try {
      const multi = this.client.multi();
      multi.incr(redisKey);
      multi.pttl(redisKey);

      const results = await multi.exec();
      let [count, ttl] = results.map((r) => r[1]);

      // Set expiry if this is a new key
      if (ttl === -1) {
        await this.client.pexpire(redisKey, this.windowMs);
        ttl = this.windowMs;
      }

      return {
        totalHits: count,
        resetTime: new Date(Date.now() + ttl),
      };
    } catch (error) {
      logger.error('Rate limit Redis error', { error: error.message });
      // Fail open - allow request if Redis fails
      return { totalHits: 0, resetTime: new Date(Date.now() + this.windowMs) };
    }
  }

  async decrement(key) {
    const redisKey = `${this.prefix}${key}`;
    try {
      await this.client.decr(redisKey);
    } catch (error) {
      logger.error('Rate limit decrement error', { error: error.message });
    }
  }

  async resetKey(key) {
    const redisKey = `${this.prefix}${key}`;
    try {
      await this.client.del(redisKey);
    } catch (error) {
      logger.error('Rate limit reset error', { error: error.message });
    }
  }
}

/**
 * Key generator based on user ID or IP
 */
const keyGenerator = (req) => {
  if (req.user?.id) {
    return `user:${req.user.id}`;
  }
  return `ip:${req.ip}`;
};

/**
 * Skip rate limiting for certain conditions
 */
const skip = (req) => {
  // Skip rate limiting entirely in development mode for testing
  if (config.env === 'development') {
    return true;
  }

  // Skip for health checks
  if (req.path === '/health' || req.path === '/ready') {
    return true;
  }

  // Skip for internal requests (if applicable)
  if (req.headers['x-internal-request'] === config.security.encryptionKey) {
    return true;
  }

  return false;
};

/**
 * Handler for when rate limit is exceeded
 */
const handler = (req, res, next, options) => {
  logger.warn('Rate limit exceeded', {
    ip: req.ip,
    userId: req.user?.id,
    path: req.path,
  });

  res.status(429).json({
    success: false,
    message: 'Too many requests. Please try again later.',
    retryAfter: Math.ceil(options.windowMs / 1000),
    code: 'RATE_LIMITED',
  });
};

/**
 * Standard API rate limiter
 * 100 requests per 15 minutes
 */
const apiLimiter = rateLimit({
  windowMs: config.security.rateLimit.windowMs,
  max: config.security.rateLimit.maxRequests,
  message: {
    success: false,
    message: 'Too many requests. Please try again later.',
  },
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator,
  skip,
  handler,
});

/**
 * Strict limiter for authentication endpoints
 * 5 requests per 15 minutes (disabled in development)
 */
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5,
  message: {
    success: false,
    message: 'Too many authentication attempts. Please try again later.',
  },
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => `auth:${req.ip}`,
  skipSuccessfulRequests: false,
  skip: (req) => config.env === 'development', // Skip in development
  handler: (req, res) => {
    logger.warn('Auth rate limit exceeded', { ip: req.ip });
    res.status(429).json({
      success: false,
      message: 'Too many login attempts. Please try again in 15 minutes.',
      code: 'AUTH_RATE_LIMITED',
    });
  },
});

/**
 * Password reset limiter
 * 3 requests per hour
 */
const passwordResetLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 3,
  message: {
    success: false,
    message: 'Too many password reset requests. Please try again in an hour.',
  },
  keyGenerator: (req) => `pwreset:${req.body?.email || req.ip}`,
});

/**
 * File upload limiter
 * 30 uploads per hour
 */
const uploadLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 30,
  message: {
    success: false,
    message: 'Too many file uploads. Please try again later.',
  },
  keyGenerator,
});

/**
 * AI feature limiter (expensive operations)
 * 20 requests per hour for free users, 100 for premium
 */
const aiLimiter = (req, res, next) => {
  const isPremium = ['premium', 'trial'].includes(req.user?.subscription_status);
  const limit = isPremium ? 100 : 20;
  const windowMs = 60 * 60 * 1000; // 1 hour

  const limiter = rateLimit({
    windowMs,
    max: limit,
    message: {
      success: false,
      message: isPremium
        ? 'AI feature limit reached. Please try again in an hour.'
        : 'Free tier AI limit reached. Upgrade to premium for more.',
    },
    keyGenerator: (req) => `ai:${req.user?.id || req.ip}`,
  });

  return limiter(req, res, next);
};

/**
 * Slow down middleware
 * Gradually increases response time after threshold
 */
const speedLimiter = slowDown({
  windowMs: 15 * 60 * 1000, // 15 minutes
  delayAfter: 50, // Start slowing after 50 requests
  delayMs: (hits) => hits * 100, // Add 100ms per request after threshold
  maxDelayMs: 5000, // Max 5 second delay
  keyGenerator,
  skip,
});

/**
 * Create custom rate limiter with Redis store
 * @param {Object} options - Rate limit options
 * @returns {Function} Express middleware
 */
function createRateLimiter(options) {
  const {
    windowMs = 60000,
    max = 100,
    message = 'Too many requests',
    keyPrefix = 'custom',
    skipSuccessfulRequests = false,
  } = options;

  return rateLimit({
    windowMs,
    max,
    message: {
      success: false,
      message,
    },
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req) => `${keyPrefix}:${keyGenerator(req)}`,
    skipSuccessfulRequests,
    skip,
    handler,
  });
}

/**
 * Dynamic rate limiter based on user tier
 * @param {Object} tiers - Rate limits per tier
 * @returns {Function} Express middleware
 */
function tieredRateLimiter(tiers) {
  return async (req, res, next) => {
    const tier = req.user?.subscription_status || 'free';
    const limit = tiers[tier] || tiers.default || 100;

    const limiter = rateLimit({
      windowMs: 60 * 60 * 1000, // 1 hour
      max: limit,
      keyGenerator,
      handler,
    });

    return limiter(req, res, next);
  };
}

module.exports = {
  apiLimiter,
  authLimiter,
  passwordResetLimiter,
  uploadLimiter,
  aiLimiter,
  speedLimiter,
  createRateLimiter,
  tieredRateLimiter,
  RedisStore,
};
