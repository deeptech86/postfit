/**
 * MomCare API - Routes Index
 *
 * Central router configuration for all API endpoints.
 */

const express = require('express');
const router = express.Router();

// Import route modules
const authRoutes = require('./auth');
const foodRoutes = require('./food');
const hydrationRoutes = require('./hydration');
const exerciseRoutes = require('./exercises');
const workoutRoutes = require('./workouts');

// API version prefix
const API_VERSION = '/api/v1';

/**
 * Health check endpoint
 */
router.get('/health', (req, res) => {
  res.status(200).json({
    success: true,
    message: 'MomCare API is healthy',
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version || '1.0.0',
  });
});

/**
 * Readiness check endpoint
 */
router.get('/ready', async (req, res) => {
  try {
    const db = require('../config/database');
    const redis = require('../config/redis');

    const dbHealthy = await db.healthCheck();
    const redisHealthy = await redis.healthCheck();

    if (dbHealthy && redisHealthy) {
      res.status(200).json({
        success: true,
        message: 'All services ready',
        services: {
          database: 'healthy',
          redis: 'healthy',
        },
      });
    } else {
      res.status(503).json({
        success: false,
        message: 'Some services unavailable',
        services: {
          database: dbHealthy ? 'healthy' : 'unhealthy',
          redis: redisHealthy ? 'healthy' : 'unhealthy',
        },
      });
    }
  } catch (error) {
    res.status(503).json({
      success: false,
      message: 'Health check failed',
      error: error.message,
    });
  }
});

/**
 * API documentation endpoint
 */
router.get(`${API_VERSION}`, (req, res) => {
  res.status(200).json({
    success: true,
    message: 'Welcome to MomCare API',
    version: 'v1',
    documentation: '/api/v1/docs',
    endpoints: {
      auth: `${API_VERSION}/auth`,
      food: `${API_VERSION}/food`,
      hydration: `${API_VERSION}/hydration`,
      exercises: `${API_VERSION}/exercises`,
      workouts: `${API_VERSION}/workouts`,
    },
    disclaimer: 'This API provides health and wellness features. Consult your healthcare provider before making health decisions.',
  });
});

// Mount routes
router.use(`${API_VERSION}/auth`, authRoutes);
router.use(`${API_VERSION}/food`, foodRoutes);
router.use(`${API_VERSION}/hydration`, hydrationRoutes);
router.use(`${API_VERSION}/exercises`, exerciseRoutes);
router.use(`${API_VERSION}/workouts`, workoutRoutes);

module.exports = router;
