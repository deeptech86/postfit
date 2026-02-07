/**
 * MomCare API - Redis Configuration
 *
 * Redis client setup for caching, session management,
 * and real-time features (Socket.io adapter)
 */

const Redis = require('ioredis');
const config = require('./index');
const logger = require('../utils/logger');

// Redis connection options
const redisOptions = {
  host: config.redis.host,
  port: config.redis.port,
  db: config.redis.db,
  retryDelayOnFailover: 100,
  maxRetriesPerRequest: 3,
  lazyConnect: true,
  enableOfflineQueue: false,
  maxRetriesPerRequest: null,
  retryStrategy(times) {
    // Disable reconnection in development if Redis is not available
    if (config.env === 'development' && times > 3) {
      return null; // Stop retrying
    }
    const delay = Math.min(times * 100, 3000);
    return delay;
  },
};

if (config.redis.password) {
  redisOptions.password = config.redis.password;
}

if (config.redis.tls) {
  redisOptions.tls = {};
}

// Main Redis client
const redis = new Redis(redisOptions);

// Subscriber client for pub/sub
const subscriber = new Redis(redisOptions);

// Publisher client for pub/sub
const publisher = new Redis(redisOptions);

// Connection event handlers
redis.on('connect', () => {
  logger.info('Redis connected');
});

redis.on('ready', () => {
  logger.info('Redis ready');
});

redis.on('error', (error) => {
  logger.error('Redis error', { error: error.message });
});

redis.on('close', () => {
  logger.warn('Redis connection closed');
});

redis.on('reconnecting', () => {
  logger.info('Redis reconnecting...');
});

/**
 * Cache wrapper with automatic JSON serialization
 */
const cache = {
  /**
   * Get cached value
   * @param {string} key - Cache key
   * @returns {Promise<any>} Parsed value or null
   */
  async get(key) {
    try {
      const value = await redis.get(key);
      return value ? JSON.parse(value) : null;
    } catch (error) {
      logger.error('Cache get error', { key, error: error.message });
      return null;
    }
  },

  /**
   * Set cached value with optional TTL
   * @param {string} key - Cache key
   * @param {any} value - Value to cache
   * @param {number} ttl - Time to live in seconds (optional)
   * @returns {Promise<boolean>}
   */
  async set(key, value, ttl = config.redis.cacheTtl) {
    try {
      const serialized = JSON.stringify(value);
      if (ttl) {
        await redis.setex(key, ttl, serialized);
      } else {
        await redis.set(key, serialized);
      }
      return true;
    } catch (error) {
      logger.error('Cache set error', { key, error: error.message });
      return false;
    }
  },

  /**
   * Delete cached value
   * @param {string} key - Cache key
   * @returns {Promise<boolean>}
   */
  async del(key) {
    try {
      await redis.del(key);
      return true;
    } catch (error) {
      logger.error('Cache delete error', { key, error: error.message });
      return false;
    }
  },

  /**
   * Delete all keys matching pattern
   * @param {string} pattern - Key pattern (e.g., 'user:*')
   * @returns {Promise<number>} Number of deleted keys
   */
  async delPattern(pattern) {
    try {
      const keys = await redis.keys(pattern);
      if (keys.length > 0) {
        return await redis.del(...keys);
      }
      return 0;
    } catch (error) {
      logger.error('Cache delete pattern error', { pattern, error: error.message });
      return 0;
    }
  },

  /**
   * Check if key exists
   * @param {string} key - Cache key
   * @returns {Promise<boolean>}
   */
  async exists(key) {
    try {
      return (await redis.exists(key)) === 1;
    } catch (error) {
      logger.error('Cache exists error', { key, error: error.message });
      return false;
    }
  },

  /**
   * Increment value
   * @param {string} key - Cache key
   * @param {number} amount - Amount to increment
   * @returns {Promise<number>}
   */
  async incr(key, amount = 1) {
    try {
      if (amount === 1) {
        return await redis.incr(key);
      }
      return await redis.incrby(key, amount);
    } catch (error) {
      logger.error('Cache increment error', { key, error: error.message });
      return 0;
    }
  },

  /**
   * Set expiration on key
   * @param {string} key - Cache key
   * @param {number} ttl - Time to live in seconds
   * @returns {Promise<boolean>}
   */
  async expire(key, ttl) {
    try {
      return (await redis.expire(key, ttl)) === 1;
    } catch (error) {
      logger.error('Cache expire error', { key, error: error.message });
      return false;
    }
  },

  /**
   * Add to sorted set (for leaderboards, rankings)
   * @param {string} key - Sorted set key
   * @param {number} score - Score
   * @param {string} member - Member value
   * @returns {Promise<boolean>}
   */
  async zadd(key, score, member) {
    try {
      await redis.zadd(key, score, member);
      return true;
    } catch (error) {
      logger.error('Cache zadd error', { key, error: error.message });
      return false;
    }
  },

  /**
   * Get range from sorted set
   * @param {string} key - Sorted set key
   * @param {number} start - Start index
   * @param {number} stop - Stop index
   * @param {boolean} withScores - Include scores
   * @returns {Promise<Array>}
   */
  async zrange(key, start, stop, withScores = false) {
    try {
      if (withScores) {
        return await redis.zrange(key, start, stop, 'WITHSCORES');
      }
      return await redis.zrange(key, start, stop);
    } catch (error) {
      logger.error('Cache zrange error', { key, error: error.message });
      return [];
    }
  },
};

/**
 * Session management
 */
const session = {
  /**
   * Create a new session
   * @param {string} userId - User ID
   * @param {Object} data - Session data
   * @param {string} deviceId - Device identifier
   * @returns {Promise<string>} Session ID
   */
  async create(userId, data, deviceId) {
    const sessionId = `session:${userId}:${deviceId}`;
    const sessionData = {
      ...data,
      createdAt: new Date().toISOString(),
      lastActivity: new Date().toISOString(),
    };

    await cache.set(sessionId, sessionData, config.redis.sessionTtl);

    // Track active sessions for user
    await redis.sadd(`user_sessions:${userId}`, sessionId);

    return sessionId;
  },

  /**
   * Get session data
   * @param {string} sessionId - Session ID
   * @returns {Promise<Object|null>}
   */
  async get(sessionId) {
    const data = await cache.get(sessionId);
    if (data) {
      // Update last activity
      data.lastActivity = new Date().toISOString();
      await cache.set(sessionId, data, config.redis.sessionTtl);
    }
    return data;
  },

  /**
   * Destroy session
   * @param {string} sessionId - Session ID
   * @param {string} userId - User ID
   * @returns {Promise<boolean>}
   */
  async destroy(sessionId, userId) {
    await cache.del(sessionId);
    await redis.srem(`user_sessions:${userId}`, sessionId);
    return true;
  },

  /**
   * Destroy all sessions for user (logout everywhere)
   * @param {string} userId - User ID
   * @returns {Promise<number>} Number of destroyed sessions
   */
  async destroyAll(userId) {
    const sessions = await redis.smembers(`user_sessions:${userId}`);
    for (const sessionId of sessions) {
      await cache.del(sessionId);
    }
    await redis.del(`user_sessions:${userId}`);
    return sessions.length;
  },

  /**
   * Get active session count for user
   * @param {string} userId - User ID
   * @returns {Promise<number>}
   */
  async count(userId) {
    return await redis.scard(`user_sessions:${userId}`);
  },
};

/**
 * Rate limiting helpers
 */
const rateLimit = {
  /**
   * Check and increment rate limit
   * @param {string} key - Rate limit key (e.g., 'api:userId')
   * @param {number} limit - Max requests
   * @param {number} window - Window in seconds
   * @returns {Promise<{allowed: boolean, remaining: number, resetAt: number}>}
   */
  async check(key, limit, window) {
    const now = Date.now();
    const windowKey = `ratelimit:${key}:${Math.floor(now / (window * 1000))}`;

    const count = await redis.incr(windowKey);
    if (count === 1) {
      await redis.expire(windowKey, window);
    }

    const resetAt = (Math.floor(now / (window * 1000)) + 1) * window * 1000;

    return {
      allowed: count <= limit,
      remaining: Math.max(0, limit - count),
      resetAt,
    };
  },
};

/**
 * Health check for Redis connection
 * @returns {Promise<boolean>}
 */
async function healthCheck() {
  try {
    const pong = await redis.ping();
    return pong === 'PONG';
  } catch (error) {
    logger.error('Redis health check failed', { error: error.message });
    return false;
  }
}

/**
 * Gracefully close Redis connections
 */
async function close() {
  logger.info('Closing Redis connections...');
  await redis.quit();
  await subscriber.quit();
  await publisher.quit();
  logger.info('Redis connections closed');
}

/**
 * Connect to Redis
 */
async function connect() {
  await redis.connect();
  await subscriber.connect();
  await publisher.connect();
}

module.exports = {
  redis,
  subscriber,
  publisher,
  cache,
  session,
  rateLimit,
  healthCheck,
  close,
  connect,
};
