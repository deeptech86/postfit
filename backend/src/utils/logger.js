/**
 * MomCare API - Winston Logger Configuration
 *
 * Structured logging with HIPAA-compliant audit trails
 * Supports console, file, and external logging services
 */

const winston = require('winston');
const path = require('path');
const config = require('../config');

// Define log levels
const levels = {
  error: 0,
  warn: 1,
  info: 2,
  http: 3,
  debug: 4,
};

// Define log colors
const colors = {
  error: 'red',
  warn: 'yellow',
  info: 'green',
  http: 'magenta',
  debug: 'white',
};

winston.addColors(colors);

// Define log format
const format = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss:ms' }),
  winston.format.errors({ stack: true }),
  winston.format.printf(({ level, message, timestamp, ...metadata }) => {
    let msg = `${timestamp} [${level}]: ${message}`;
    if (Object.keys(metadata).length > 0) {
      msg += ` ${JSON.stringify(metadata)}`;
    }
    return msg;
  })
);

// Console format with colors
const consoleFormat = winston.format.combine(
  winston.format.colorize({ all: true }),
  format
);

// JSON format for production/file logs
const jsonFormat = winston.format.combine(
  winston.format.timestamp(),
  winston.format.errors({ stack: true }),
  winston.format.json()
);

// Define transports
const transports = [
  // Console transport
  new winston.transports.Console({
    format: config.env === 'development' ? consoleFormat : jsonFormat,
  }),
];

// File transports for production
if (config.env === 'production' || config.logging.filePath) {
  // Error log
  transports.push(
    new winston.transports.File({
      filename: path.join(config.logging.filePath, 'error.log'),
      level: 'error',
      format: jsonFormat,
      maxsize: parseInt(config.logging.maxSize) * 1024 * 1024, // Convert to bytes
      maxFiles: config.logging.maxFiles,
    })
  );

  // Combined log
  transports.push(
    new winston.transports.File({
      filename: path.join(config.logging.filePath, 'combined.log'),
      format: jsonFormat,
      maxsize: parseInt(config.logging.maxSize) * 1024 * 1024,
      maxFiles: config.logging.maxFiles,
    })
  );

  // HIPAA Audit log (separate for compliance)
  if (config.hipaa.auditEnabled) {
    transports.push(
      new winston.transports.File({
        filename: path.join(config.logging.filePath, 'hipaa-audit.log'),
        level: 'info',
        format: jsonFormat,
        maxsize: parseInt(config.logging.maxSize) * 1024 * 1024,
        maxFiles: config.hipaa.auditRetentionDays, // Keep for compliance period
      })
    );
  }
}

// Create logger instance
const logger = winston.createLogger({
  level: config.logging.level,
  levels,
  transports,
  exitOnError: false,
});

/**
 * HIPAA Audit Logger
 * Logs access to protected health information (PHI)
 */
const auditLogger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.File({
      filename: path.join(config.logging.filePath || './logs', 'hipaa-audit.log'),
      maxsize: parseInt(config.logging.maxSize || 10) * 1024 * 1024,
      maxFiles: config.hipaa.auditRetentionDays,
    }),
  ],
});

/**
 * Log HIPAA audit event
 * @param {Object} event - Audit event details
 */
function logAuditEvent(event) {
  if (!config.hipaa.auditEnabled) return;

  const auditEntry = {
    eventType: event.type,
    userId: event.userId,
    resourceType: event.resourceType,
    resourceId: event.resourceId,
    action: event.action,
    ipAddress: event.ipAddress,
    userAgent: event.userAgent,
    outcome: event.outcome || 'success',
    timestamp: new Date().toISOString(),
    details: event.details,
  };

  auditLogger.info('HIPAA_AUDIT', auditEntry);
}

/**
 * Create request logger middleware
 * @returns {Function} Express middleware
 */
function requestLogger() {
  return (req, res, next) => {
    const start = Date.now();

    res.on('finish', () => {
      const duration = Date.now() - start;
      const message = `${req.method} ${req.originalUrl}`;

      const logData = {
        method: req.method,
        url: req.originalUrl,
        status: res.statusCode,
        duration: `${duration}ms`,
        ip: req.ip,
        userAgent: req.get('user-agent'),
      };

      if (req.user) {
        logData.userId = req.user.id;
      }

      if (res.statusCode >= 500) {
        logger.error(message, logData);
      } else if (res.statusCode >= 400) {
        logger.warn(message, logData);
      } else {
        logger.http(message, logData);
      }
    });

    next();
  };
}

// Export logger with additional methods
logger.stream = {
  write: (message) => logger.http(message.trim()),
};
logger.logAuditEvent = logAuditEvent;
logger.requestLogger = requestLogger;
logger.auditLogger = auditLogger;

module.exports = logger;
