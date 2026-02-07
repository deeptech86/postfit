/**
 * MomCare API - Configuration Module
 *
 * Centralizes all configuration from environment variables with validation
 * and sensible defaults. All sensitive configuration is loaded from .env
 */

require('dotenv').config();

const config = {
  // Server
  env: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT, 10) || 3000,
  apiVersion: process.env.API_VERSION || 'v1',
  baseUrl: process.env.API_BASE_URL || 'http://localhost:3000',

  // Database
  database: {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT, 10) || 5432,
    name: process.env.DB_NAME || 'momcare_db',
    user: process.env.DB_USER || 'momcare_admin',
    password: process.env.DB_PASSWORD,
    pool: {
      min: parseInt(process.env.DB_POOL_MIN, 10) || 2,
      max: parseInt(process.env.DB_POOL_MAX, 10) || 10,
      idleTimeout: parseInt(process.env.DB_IDLE_TIMEOUT, 10) || 30000,
      connectionTimeout: parseInt(process.env.DB_CONNECTION_TIMEOUT, 10) || 10000,
    },
    ssl: process.env.DB_SSL === 'true',
    sslCa: process.env.DB_SSL_CA,
    readReplica: {
      host: process.env.DB_READ_REPLICA_HOST,
      port: parseInt(process.env.DB_READ_REPLICA_PORT, 10) || 5432,
    },
  },

  // Redis
  redis: {
    host: process.env.REDIS_HOST || 'localhost',
    port: parseInt(process.env.REDIS_PORT, 10) || 6379,
    password: process.env.REDIS_PASSWORD,
    db: parseInt(process.env.REDIS_DB, 10) || 0,
    tls: process.env.REDIS_TLS === 'true',
    sessionTtl: parseInt(process.env.SESSION_TTL, 10) || 86400,
    cacheTtl: parseInt(process.env.CACHE_TTL, 10) || 3600,
  },

  // JWT
  jwt: {
    secret: process.env.JWT_SECRET,
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
    refreshSecret: process.env.JWT_REFRESH_SECRET,
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '30d',
  },

  // OAuth Providers
  oauth: {
    apple: {
      clientId: process.env.APPLE_CLIENT_ID,
      teamId: process.env.APPLE_TEAM_ID,
      keyId: process.env.APPLE_KEY_ID,
      privateKeyPath: process.env.APPLE_PRIVATE_KEY_PATH,
    },
    google: {
      clientId: process.env.GOOGLE_CLIENT_ID,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET,
      callbackUrl: process.env.GOOGLE_CALLBACK_URL,
    },
    facebook: {
      appId: process.env.FACEBOOK_APP_ID,
      appSecret: process.env.FACEBOOK_APP_SECRET,
      callbackUrl: process.env.FACEBOOK_CALLBACK_URL,
    },
  },

  // AWS
  aws: {
    region: process.env.AWS_REGION || 'us-east-1',
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
    s3: {
      uploadsBucket: process.env.S3_BUCKET_UPLOADS || 'momcare-uploads',
      mediaBucket: process.env.S3_BUCKET_MEDIA || 'momcare-media',
      presignedUrlExpires: parseInt(process.env.S3_PRESIGNED_URL_EXPIRES, 10) || 3600,
    },
    cloudfront: {
      domain: process.env.CLOUDFRONT_DOMAIN,
    },
  },

  // Stripe
  stripe: {
    secretKey: process.env.STRIPE_SECRET_KEY,
    publishableKey: process.env.STRIPE_PUBLISHABLE_KEY,
    webhookSecret: process.env.STRIPE_WEBHOOK_SECRET,
    prices: {
      premiumMonthly: process.env.STRIPE_PREMIUM_MONTHLY_PRICE_ID,
      premiumYearly: process.env.STRIPE_PREMIUM_YEARLY_PRICE_ID,
    },
  },

  // OpenAI
  openai: {
    apiKey: process.env.OPENAI_API_KEY,
    model: process.env.OPENAI_MODEL || 'gpt-4-turbo-preview',
    visionModel: process.env.OPENAI_VISION_MODEL || 'gpt-4-vision-preview',
  },

  // USDA API
  usda: {
    apiKey: process.env.USDA_API_KEY,
  },

  // Security
  security: {
    encryptionKey: process.env.ENCRYPTION_KEY,
    rateLimit: {
      windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS, 10) || 900000,
      maxRequests: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS, 10) || 100,
      skipFailed: process.env.RATE_LIMIT_SKIP_FAILED === 'true',
    },
    corsOrigins: process.env.CORS_ORIGINS ? process.env.CORS_ORIGINS.split(',') : ['http://localhost:3000'],
    trustProxy: process.env.TRUST_PROXY === 'true',
  },

  // Logging
  logging: {
    level: process.env.LOG_LEVEL || 'debug',
    format: process.env.LOG_FORMAT || 'combined',
    filePath: process.env.LOG_FILE_PATH || './logs',
    maxSize: process.env.LOG_FILE_MAX_SIZE || '10m',
    maxFiles: parseInt(process.env.LOG_FILE_MAX_FILES, 10) || 14,
  },

  // Email
  email: {
    host: process.env.SMTP_HOST,
    port: parseInt(process.env.SMTP_PORT, 10) || 587,
    secure: process.env.SMTP_SECURE === 'true',
    user: process.env.SMTP_USER,
    password: process.env.SMTP_PASSWORD,
    from: process.env.EMAIL_FROM || 'MomCare <noreply@momcare.com>',
  },

  // Push Notifications
  apns: {
    keyId: process.env.APNS_KEY_ID,
    teamId: process.env.APNS_TEAM_ID,
    keyPath: process.env.APNS_KEY_PATH,
    bundleId: process.env.APNS_BUNDLE_ID,
    production: process.env.APNS_PRODUCTION === 'true',
  },

  // Feature Flags
  features: {
    aiFoodRecognition: process.env.FEATURE_AI_FOOD_RECOGNITION !== 'false',
    telehealth: process.env.FEATURE_TELEHEALTH !== 'false',
    communityChat: process.env.FEATURE_COMMUNITY_CHAT !== 'false',
    partnerDashboard: process.env.FEATURE_PARTNER_DASHBOARD !== 'false',
  },

  // HIPAA Compliance
  hipaa: {
    auditEnabled: process.env.HIPAA_AUDIT_ENABLED !== 'false',
    auditRetentionDays: parseInt(process.env.HIPAA_AUDIT_RETENTION_DAYS, 10) || 2555,
  },

  // Data Retention
  dataRetention: {
    activeUserDays: parseInt(process.env.DATA_RETENTION_ACTIVE_USER, 10) || 365,
    deletedUserDays: parseInt(process.env.DATA_RETENTION_DELETED_USER, 10) || 90,
  },
};

/**
 * Validate required configuration
 */
function validateConfig() {
  const required = [
    { key: 'jwt.secret', value: config.jwt.secret },
    { key: 'jwt.refreshSecret', value: config.jwt.refreshSecret },
    { key: 'database.password', value: config.database.password },
    { key: 'security.encryptionKey', value: config.security.encryptionKey },
  ];

  const missing = required.filter(item => !item.value);

  if (missing.length > 0 && config.env === 'production') {
    throw new Error(
      `Missing required configuration: ${missing.map(m => m.key).join(', ')}`
    );
  }

  if (missing.length > 0) {
    console.warn(
      `[Config Warning] Missing configuration (required in production): ${missing.map(m => m.key).join(', ')}`
    );
  }
}

// Validate on load
validateConfig();

module.exports = config;
