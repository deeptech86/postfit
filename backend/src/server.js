/**
 * MomCare API - Main Server Entry Point
 *
 * Express.js server with Socket.io for real-time features,
 * HIPAA-compliant security, and comprehensive middleware.
 */

const express = require('express');
const http = require('http');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');

const config = require('./config');
const routes = require('./routes');
const { initializePassport } = require('./middleware/auth');
const { apiLimiter, speedLimiter } = require('./middleware/rateLimit');
const { notFoundHandler, errorHandler, handleUncaughtException, handleUnhandledRejection } = require('./middleware/errorHandler');
const { trimStrings, validateContentType } = require('./middleware/validation');
const { requestLogger } = require('./utils/logger');
const logger = require('./utils/logger');
const db = require('./config/database');
const redis = require('./config/redis');
const { initializeSocketIO } = require('./services/socketService');

// Handle uncaught exceptions
handleUncaughtException();
handleUnhandledRejection();

// Create Express app
const app = express();

// Create HTTP server for Socket.io
const server = http.createServer(app);

// =============================================================================
// Security Middleware
// =============================================================================

// Helmet for security headers
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", 'data:', 'https:'],
      scriptSrc: ["'self'"],
    },
  },
  crossOriginEmbedderPolicy: false,
}));

// CORS configuration
app.use(cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (mobile apps, curl, etc.)
    if (!origin) return callback(null, true);

    if (config.security.corsOrigins.includes(origin) || config.env === 'development') {
      return callback(null, true);
    }

    callback(new Error('Not allowed by CORS'));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'X-Device-ID'],
  exposedHeaders: ['X-Total-Count', 'X-Page', 'X-Per-Page', 'Retry-After'],
  maxAge: 86400, // 24 hours
}));

// Trust proxy if behind load balancer
if (config.security.trustProxy) {
  app.set('trust proxy', 1);
}

// =============================================================================
// Request Processing Middleware
// =============================================================================

// Compression
app.use(compression());

// Body parsing
app.use(express.json({
  limit: '10mb',
  verify: (req, res, buf) => {
    req.rawBody = buf; // For webhook signature verification
  },
}));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Trim whitespace from string inputs
app.use(trimStrings);

// Content-Type validation for POST/PUT requests
app.use(validateContentType('application/json', 'multipart/form-data'));

// =============================================================================
// Logging
// =============================================================================

// HTTP request logging
if (config.env === 'development') {
  app.use(morgan('dev'));
} else {
  app.use(morgan('combined', { stream: logger.stream }));
}

// Custom request logging
app.use(requestLogger());

// =============================================================================
// Rate Limiting
// =============================================================================

// Apply speed limiter (gradual slowdown)
app.use(speedLimiter);

// Apply general rate limiter
app.use('/api', apiLimiter);

// =============================================================================
// Authentication
// =============================================================================

// Initialize Passport.js
initializePassport(app);

// =============================================================================
// Routes
// =============================================================================

// Mount all routes
app.use(routes);

// =============================================================================
// Error Handling
// =============================================================================

// Handle 404
app.use(notFoundHandler);

// Global error handler
app.use(errorHandler);

// =============================================================================
// Socket.io Initialization
// =============================================================================

const io = initializeSocketIO(server);

// =============================================================================
// Graceful Shutdown
// =============================================================================

async function gracefulShutdown(signal) {
  logger.info(`${signal} received. Starting graceful shutdown...`);

  // Stop accepting new connections
  server.close(async () => {
    logger.info('HTTP server closed');

    try {
      // Close database connections
      await db.close();
      logger.info('Database connections closed');

      // Close Redis connections (if connected)
      try {
        await redis.close();
        logger.info('Redis connections closed');
      } catch (error) {
        logger.warn('Redis already disconnected or not available');
      }

      logger.info('Graceful shutdown completed');
      process.exit(0);
    } catch (error) {
      logger.error('Error during graceful shutdown', { error: error.message });
      process.exit(1);
    }
  });

  // Force shutdown after 30 seconds
  setTimeout(() => {
    logger.error('Forced shutdown after timeout');
    process.exit(1);
  }, 30000);
}

// Handle shutdown signals
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// =============================================================================
// Server Startup
// =============================================================================

async function startServer() {
  try {
    // Test database connection
    const dbHealthy = await db.healthCheck();
    if (!dbHealthy) {
      throw new Error('Database connection failed');
    }
    logger.info('Database connected successfully');

    // Connect to Redis (optional for development)
    try {
      await redis.connect();
      const redisHealthy = await redis.healthCheck();
      if (!redisHealthy) {
        logger.warn('Redis health check failed - continuing without caching');
      } else {
        logger.info('Redis connected successfully');
      }
    } catch (error) {
      logger.warn('Redis connection failed - continuing without caching', { error: error.message });
    }

    // Start server
    server.listen(config.port, () => {
      logger.info(`MomCare API server started`, {
        port: config.port,
        env: config.env,
        nodeVersion: process.version,
      });

      if (config.env === 'development') {
        logger.info(`API available at http://localhost:${config.port}/api/v1`);
        logger.info(`Health check at http://localhost:${config.port}/health`);
      }
    });
  } catch (error) {
    logger.error('Failed to start server', { error: error.message });
    process.exit(1);
  }
}

// Start the server
startServer();

module.exports = { app, server, io };
