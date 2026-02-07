/**
 * MomCare API - Standardized API Response Utilities
 *
 * Consistent response format across all endpoints
 * Includes medical disclaimers where appropriate
 */

/**
 * Medical disclaimers for health-related responses
 */
const DISCLAIMERS = {
  general:
    'This information is for educational purposes only and is not a substitute for professional medical advice. Always consult your healthcare provider.',
  weight:
    'Safe postpartum weight loss is typically 1-2 lbs per week. Consult your healthcare provider before starting any weight loss program.',
  breastfeeding:
    'If breastfeeding, maintain a minimum of 1800 calories daily. Your nutrition directly affects milk supply and quality.',
  exercise:
    'Wait until cleared by your healthcare provider (typically 6 weeks postpartum) before starting or intensifying exercise routines.',
  mentalHealth:
    'If you are experiencing persistent feelings of sadness, anxiety, or thoughts of self-harm, please contact a healthcare provider or crisis helpline immediately.',
  nutrition:
    'Postpartum nutritional needs vary. This guidance is general and may not account for your specific health conditions.',
  medication:
    'Always verify food and supplement safety with your healthcare provider, especially if breastfeeding or taking medications.',
};

/**
 * Emergency resources for mental health
 */
const EMERGENCY_RESOURCES = {
  national_suicide_prevention: '988',
  postpartum_support_international: '1-800-944-4773',
  crisis_text_line: 'Text HOME to 741741',
};

/**
 * Standard success response
 * @param {Object} res - Express response object
 * @param {Object} data - Response data
 * @param {string} message - Success message
 * @param {number} statusCode - HTTP status code
 * @param {Object} meta - Additional metadata
 */
function success(res, data, message = 'Success', statusCode = 200, meta = {}) {
  const responseBody = {
    success: true,
    message,
    data,
    meta: {
      timestamp: new Date().toISOString(),
      ...meta,
    },
  };

  // Debug logging
  const logger = require('./logger');

  // Check if headers were already sent
  if (res.headersSent) {
    logger.error('success() called but headers already sent!', {
      statusCode,
      message,
      url: res.req?.originalUrl,
      method: res.req?.method
    });
    return;
  }

  logger.debug('success() called', {
    statusCode,
    message,
    dataKeys: data ? Object.keys(data) : null,
    responseBodyKeys: Object.keys(responseBody),
    responseBodySize: JSON.stringify(responseBody).length,
    headersSent: res.headersSent
  });

  try {
    const result = res.status(statusCode).json(responseBody);
    logger.debug('res.json() completed', {
      headersSentAfter: res.headersSent,
      statusCode: res.statusCode
    });
    return result;
  } catch (err) {
    logger.error('Error in res.json()', { error: err.message, stack: err.stack });
    throw err;
  }
}

/**
 * Success response with pagination
 * @param {Object} res - Express response object
 * @param {Array} items - Array of items
 * @param {Object} pagination - Pagination info
 * @param {string} message - Success message
 */
function paginated(res, items, pagination, message = 'Success') {
  const { page, limit, total } = pagination;
  const totalPages = Math.ceil(total / limit);

  return res.status(200).json({
    success: true,
    message,
    data: items,
    pagination: {
      page,
      limit,
      total,
      totalPages,
      hasNext: page < totalPages,
      hasPrev: page > 1,
    },
    meta: {
      timestamp: new Date().toISOString(),
    },
  });
}

/**
 * Success response with medical disclaimer
 * @param {Object} res - Express response object
 * @param {Object} data - Response data
 * @param {string} disclaimerType - Type of disclaimer to include
 * @param {string} message - Success message
 */
function healthResponse(res, data, disclaimerType = 'general', message = 'Success') {
  return res.status(200).json({
    success: true,
    message,
    data,
    disclaimer: DISCLAIMERS[disclaimerType] || DISCLAIMERS.general,
    meta: {
      timestamp: new Date().toISOString(),
    },
  });
}

/**
 * Mental health response with emergency resources
 * @param {Object} res - Express response object
 * @param {Object} data - Response data
 * @param {boolean} showResources - Whether to include emergency resources
 * @param {string} message - Success message
 */
function mentalHealthResponse(res, data, showResources = false, message = 'Success') {
  const response = {
    success: true,
    message,
    data,
    disclaimer: DISCLAIMERS.mentalHealth,
    meta: {
      timestamp: new Date().toISOString(),
    },
  };

  if (showResources) {
    response.emergencyResources = EMERGENCY_RESOURCES;
  }

  return res.status(200).json(response);
}

/**
 * Error response
 * @param {Object} res - Express response object
 * @param {string} message - Error message
 * @param {number} statusCode - HTTP status code
 * @param {Object} errors - Detailed errors
 * @param {string} code - Error code
 */
function error(res, message, statusCode = 400, errors = null, code = null) {
  const response = {
    success: false,
    message,
    meta: {
      timestamp: new Date().toISOString(),
    },
  };

  if (code) {
    response.code = code;
  }

  if (errors) {
    response.errors = errors;
  }

  return res.status(statusCode).json(response);
}

/**
 * Validation error response
 * @param {Object} res - Express response object
 * @param {Array} errors - Validation errors
 */
function validationError(res, errors) {
  return error(res, 'Validation failed', 400, errors, 'VALIDATION_ERROR');
}

/**
 * Not found response
 * @param {Object} res - Express response object
 * @param {string} resource - Resource name
 */
function notFound(res, resource = 'Resource') {
  return error(res, `${resource} not found`, 404, null, 'NOT_FOUND');
}

/**
 * Unauthorized response
 * @param {Object} res - Express response object
 * @param {string} message - Error message
 */
function unauthorized(res, message = 'Authentication required') {
  return error(res, message, 401, null, 'UNAUTHORIZED');
}

/**
 * Forbidden response
 * @param {Object} res - Express response object
 * @param {string} message - Error message
 */
function forbidden(res, message = 'Access denied') {
  return error(res, message, 403, null, 'FORBIDDEN');
}

/**
 * Rate limit exceeded response
 * @param {Object} res - Express response object
 * @param {number} retryAfter - Seconds until retry
 */
function rateLimited(res, retryAfter = 60) {
  res.set('Retry-After', retryAfter);
  return error(
    res,
    'Too many requests. Please try again later.',
    429,
    null,
    'RATE_LIMITED'
  );
}

/**
 * Server error response
 * @param {Object} res - Express response object
 * @param {string} message - Error message (generic in production)
 */
function serverError(res, message = 'An unexpected error occurred') {
  return error(res, message, 500, null, 'SERVER_ERROR');
}

/**
 * Created response
 * @param {Object} res - Express response object
 * @param {Object} data - Created resource
 * @param {string} message - Success message
 */
function created(res, data, message = 'Resource created successfully') {
  return success(res, data, message, 201);
}

/**
 * No content response (for deletes)
 * @param {Object} res - Express response object
 */
function noContent(res) {
  return res.status(204).send();
}

/**
 * Accepted response (for async operations)
 * @param {Object} res - Express response object
 * @param {Object} data - Response data (e.g., job ID)
 * @param {string} message - Success message
 */
function accepted(res, data, message = 'Request accepted for processing') {
  return success(res, data, message, 202);
}

/**
 * Premium feature response (for subscription prompts)
 * @param {Object} res - Express response object
 * @param {string} feature - Feature name
 */
function premiumRequired(res, feature) {
  return error(
    res,
    `${feature} is a premium feature. Upgrade to access.`,
    403,
    {
      feature,
      upgradeUrl: '/subscription/upgrade',
    },
    'PREMIUM_REQUIRED'
  );
}

/**
 * Feature disabled response
 * @param {Object} res - Express response object
 * @param {string} feature - Feature name
 */
function featureDisabled(res, feature) {
  return error(
    res,
    `${feature} is currently unavailable`,
    503,
    null,
    'FEATURE_DISABLED'
  );
}

module.exports = {
  success,
  paginated,
  healthResponse,
  mentalHealthResponse,
  error,
  validationError,
  notFound,
  unauthorized,
  forbidden,
  rateLimited,
  serverError,
  created,
  noContent,
  accepted,
  premiumRequired,
  featureDisabled,
  DISCLAIMERS,
  EMERGENCY_RESOURCES,
};
