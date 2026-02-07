/**
 * Test Helper - Authentication Management
 *
 * Provides authentication tokens for all test suites
 */

const request = require('supertest');

const BASE_URL = process.env.API_BASE_URL || 'http://localhost:3000';
const API_VERSION = '/api/v1';

// In-memory token storage
let cachedTokens = {
  user1: null,
  user2: null,
};

/**
 * Ensure user1 is authenticated
 * Creates user if needed, logs in, and returns access token
 */
async function ensureAuth() {
  // Return cached token if available
  if (cachedTokens.user1) {
    return cachedTokens.user1;
  }

  // Try to login first (user might already exist from auth tests)
  try {
    const loginResponse = await request(BASE_URL)
      .post(`${API_VERSION}/auth/login`)
      .send({
        email: 'test@momcare.com',
        password: 'TestPassword123!',
      });

    if (loginResponse.status === 200 && loginResponse.body.data?.tokens?.accessToken) {
      cachedTokens.user1 = loginResponse.body.data.tokens.accessToken;
      global.authTokens.user1 = cachedTokens.user1;
      return cachedTokens.user1;
    }
  } catch (err) {
    // Login failed, user doesn't exist - will try to register
  }

  // User doesn't exist, register new user
  try {
    const registerResponse = await request(BASE_URL)
      .post(`${API_VERSION}/auth/register`)
      .send({
        email: 'test@momcare.com',
        password: 'TestPassword123!',
        name: 'Test Mother',
        deliveryDate: '2024-06-15',
        deliveryType: 'vaginal',
        isBreastfeeding: true,
        acceptTerms: true,
      });

    if (registerResponse.status === 201 && registerResponse.body.data?.tokens?.accessToken) {
      cachedTokens.user1 = registerResponse.body.data.tokens.accessToken;
      global.authTokens.user1 = cachedTokens.user1;
      return cachedTokens.user1;
    }
  } catch (err) {
    console.error('Failed to register test user:', err.message);
  }

  throw new Error('Failed to authenticate test user');
}

/**
 * Ensure user2 is authenticated
 */
async function ensureAuth2() {
  if (cachedTokens.user2) {
    return cachedTokens.user2;
  }

  try {
    const loginResponse = await request(BASE_URL)
      .post(`${API_VERSION}/auth/login`)
      .send({
        email: 'test2@momcare.com',
        password: 'TestPassword456!',
      });

    if (loginResponse.status === 200 && loginResponse.body.data?.tokens?.accessToken) {
      cachedTokens.user2 = loginResponse.body.data.tokens.accessToken;
      global.authTokens.user2 = cachedTokens.user2;
      return cachedTokens.user2;
    }
  } catch (err) {
    // Login failed
  }

  try {
    const registerResponse = await request(BASE_URL)
      .post(`${API_VERSION}/auth/register`)
      .send({
        email: 'test2@momcare.com',
        password: 'TestPassword456!',
        name: 'Test Mother 2',
        deliveryDate: '2024-07-20',
        deliveryType: 'cesarean',
        isBreastfeeding: false,
        acceptTerms: true,
      });

    if (registerResponse.status === 201 && registerResponse.body.data?.tokens?.accessToken) {
      cachedTokens.user2 = registerResponse.body.data.tokens.accessToken;
      global.authTokens.user2 = cachedTokens.user2;
      return cachedTokens.user2;
    }
  } catch (err) {
    console.error('Failed to register test user 2:', err.message);
  }

  throw new Error('Failed to authenticate test user 2');
}

module.exports = {
  ensureAuth,
  ensureAuth2,
};
