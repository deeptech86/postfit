/**
 * MomCare API - Middleware Index
 *
 * Export all middleware for easy importing
 */

const auth = require('./auth');
const validation = require('./validation');
const rateLimit = require('./rateLimit');
const errorHandler = require('./errorHandler');

module.exports = {
  ...auth,
  ...validation,
  ...rateLimit,
  ...errorHandler,
};
