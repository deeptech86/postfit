/**
 * MomCare API - Validation Middleware
 *
 * Request validation using Joi schemas
 */

const { validate } = require('../utils/validators');
const { validationError } = require('../utils/apiResponse');

/**
 * Create validation middleware for a schema
 * @param {Object} schema - Joi schema
 * @param {string} source - Request property to validate ('body', 'query', 'params')
 * @returns {Function} Express middleware
 */
function validateRequest(schema, source = 'body') {
  return (req, res, next) => {
    const data = req[source];
    const { value, error } = validate(schema, data);

    if (error) {
      return validationError(res, error);
    }

    // Replace with validated/sanitized data
    req[source] = value;
    next();
  };
}

/**
 * Validate request body
 * @param {Object} schema - Joi schema
 * @returns {Function} Express middleware
 */
function validateBody(schema) {
  return validateRequest(schema, 'body');
}

/**
 * Validate query parameters
 * @param {Object} schema - Joi schema
 * @returns {Function} Express middleware
 */
function validateQuery(schema) {
  return validateRequest(schema, 'query');
}

/**
 * Validate route parameters
 * @param {Object} schema - Joi schema
 * @returns {Function} Express middleware
 */
function validateParams(schema) {
  return validateRequest(schema, 'params');
}

/**
 * Validate UUID parameter
 * Common validation for resource IDs
 */
function validateUUID(paramName = 'id') {
  const Joi = require('joi');
  const schema = Joi.object({
    [paramName]: Joi.string()
      .guid({ version: 'uuidv4' })
      .required()
      .messages({
        'string.guid': `${paramName} must be a valid UUID`,
      }),
  });

  return validateParams(schema);
}

/**
 * Validate date parameter
 * @param {string} paramName - Parameter name
 */
function validateDate(paramName = 'date') {
  const Joi = require('joi');
  const schema = Joi.object({
    [paramName]: Joi.date().iso().required(),
  });

  return validateParams(schema);
}

/**
 * Validate pagination query parameters
 */
function validatePagination() {
  const { paginationSchema } = require('../utils/validators');
  return validateQuery(paginationSchema);
}

/**
 * Sanitize HTML from string inputs
 * Prevents XSS attacks
 */
function sanitizeInput(fields) {
  return (req, res, next) => {
    const sanitize = (str) => {
      if (typeof str !== 'string') return str;
      return str
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#x27;')
        .replace(/\//g, '&#x2F;');
    };

    fields.forEach((field) => {
      if (req.body && req.body[field]) {
        req.body[field] = sanitize(req.body[field]);
      }
    });

    next();
  };
}

/**
 * Validate content type
 * Ensures request has correct Content-Type header
 */
function validateContentType(...allowedTypes) {
  return (req, res, next) => {
    if (req.method === 'GET' || req.method === 'DELETE') {
      return next();
    }

    const contentType = req.get('Content-Type');

    if (!contentType) {
      return res.status(415).json({
        success: false,
        message: 'Content-Type header is required',
      });
    }

    const isAllowed = allowedTypes.some((type) =>
      contentType.toLowerCase().includes(type.toLowerCase())
    );

    if (!isAllowed) {
      return res.status(415).json({
        success: false,
        message: `Unsupported Content-Type. Allowed: ${allowedTypes.join(', ')}`,
      });
    }

    next();
  };
}

/**
 * Trim whitespace from string fields
 */
function trimStrings(req, res, next) {
  const trimObject = (obj) => {
    if (typeof obj !== 'object' || obj === null) return obj;

    for (const key of Object.keys(obj)) {
      if (typeof obj[key] === 'string') {
        obj[key] = obj[key].trim();
      } else if (typeof obj[key] === 'object') {
        trimObject(obj[key]);
      }
    }

    return obj;
  };

  if (req.body) {
    req.body = trimObject(req.body);
  }

  next();
}

module.exports = {
  validateRequest,
  validateBody,
  validateQuery,
  validateParams,
  validateUUID,
  validateDate,
  validatePagination,
  sanitizeInput,
  validateContentType,
  trimStrings,
};
