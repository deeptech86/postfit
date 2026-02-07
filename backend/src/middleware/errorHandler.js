/**
 * MomCare API - Error Handling Middleware
 *
 * Centralized error handling with appropriate responses
 * and logging for debugging and monitoring.
 */

const logger = require('../utils/logger');
const config = require('../config');

/**
 * Custom API Error class
 */
class ApiError extends Error {
  constructor(message, statusCode = 500, code = null, errors = null) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.errors = errors;
    this.isOperational = true;

    Error.captureStackTrace(this, this.constructor);
  }

  static badRequest(message, errors = null) {
    return new ApiError(message, 400, 'BAD_REQUEST', errors);
  }

  static unauthorized(message = 'Authentication required') {
    return new ApiError(message, 401, 'UNAUTHORIZED');
  }

  static forbidden(message = 'Access denied') {
    return new ApiError(message, 403, 'FORBIDDEN');
  }

  static notFound(resource = 'Resource') {
    return new ApiError(`${resource} not found`, 404, 'NOT_FOUND');
  }

  static conflict(message) {
    return new ApiError(message, 409, 'CONFLICT');
  }

  static tooManyRequests(message = 'Too many requests') {
    return new ApiError(message, 429, 'RATE_LIMITED');
  }

  static internal(message = 'An unexpected error occurred') {
    return new ApiError(message, 500, 'INTERNAL_ERROR');
  }

  static serviceUnavailable(message = 'Service temporarily unavailable') {
    return new ApiError(message, 503, 'SERVICE_UNAVAILABLE');
  }
}

/**
 * Handle 404 Not Found
 */
const notFoundHandler = (req, res, next) => {
  const error = ApiError.notFound('Endpoint');
  next(error);
};

/**
 * Global error handler
 */
const errorHandler = (err, req, res, next) => {
  // Default values
  let statusCode = err.statusCode || 500;
  let message = err.message || 'An unexpected error occurred';
  let code = err.code || 'INTERNAL_ERROR';
  let errors = err.errors || null;

  // Log the error
  const logData = {
    message: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
    ip: req.ip,
    userId: req.user?.id,
    statusCode,
  };

  if (statusCode >= 500) {
    logger.error('Server error', logData);
  } else if (statusCode >= 400) {
    logger.warn('Client error', logData);
  }

  // Handle specific error types
  if (err.name === 'ValidationError') {
    statusCode = 400;
    code = 'VALIDATION_ERROR';
    message = 'Validation failed';
    errors = Object.values(err.errors || {}).map((e) => ({
      field: e.path,
      message: e.message,
    }));
  }

  if (err.name === 'JsonWebTokenError') {
    statusCode = 401;
    code = 'INVALID_TOKEN';
    message = 'Invalid authentication token';
  }

  if (err.name === 'TokenExpiredError') {
    statusCode = 401;
    code = 'TOKEN_EXPIRED';
    message = 'Authentication token has expired';
  }

  if (err.code === 'EBADCSRFTOKEN') {
    statusCode = 403;
    code = 'INVALID_CSRF';
    message = 'Invalid CSRF token';
  }

  // PostgreSQL errors
  if (err.code === '23505') {
    // Unique violation
    statusCode = 409;
    code = 'DUPLICATE_ENTRY';
    message = 'A record with this value already exists';
  }

  if (err.code === '23503') {
    // Foreign key violation
    statusCode = 400;
    code = 'INVALID_REFERENCE';
    message = 'Referenced resource does not exist';
  }

  if (err.code === '22P02') {
    // Invalid text representation
    statusCode = 400;
    code = 'INVALID_INPUT';
    message = 'Invalid input format';
  }

  // Multer errors (file upload)
  if (err.code === 'LIMIT_FILE_SIZE') {
    statusCode = 400;
    code = 'FILE_TOO_LARGE';
    message = 'File size exceeds the maximum allowed limit';
  }

  if (err.code === 'LIMIT_UNEXPECTED_FILE') {
    statusCode = 400;
    code = 'UNEXPECTED_FILE';
    message = 'Unexpected file field';
  }

  // Don't expose internal errors in production
  if (config.env === 'production' && statusCode === 500 && !err.isOperational) {
    message = 'An unexpected error occurred';
    errors = null;
  }

  // Send response
  const response = {
    success: false,
    message,
    code,
    meta: {
      timestamp: new Date().toISOString(),
      path: req.path,
      method: req.method,
    },
  };

  if (errors) {
    response.errors = errors;
  }

  // Include stack trace in development
  if (config.env === 'development' && err.stack) {
    response.stack = err.stack.split('\n');
  }

  res.status(statusCode).json(response);
};

/**
 * Async handler wrapper
 * Catches errors in async route handlers
 */
const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

/**
 * Handle uncaught exceptions
 */
const handleUncaughtException = () => {
  process.on('uncaughtException', (error) => {
    logger.error('Uncaught Exception', {
      message: error.message,
      stack: error.stack,
    });

    // Exit process after logging
    process.exit(1);
  });
};

/**
 * Handle unhandled promise rejections
 */
const handleUnhandledRejection = () => {
  process.on('unhandledRejection', (reason, promise) => {
    logger.error('Unhandled Rejection', {
      reason: reason instanceof Error ? reason.message : reason,
      stack: reason instanceof Error ? reason.stack : null,
    });
  });
};

module.exports = {
  ApiError,
  notFoundHandler,
  errorHandler,
  asyncHandler,
  handleUncaughtException,
  handleUnhandledRejection,
};
