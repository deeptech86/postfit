/**
 * MomCare API Tests - Setup & Configuration
 *
 * This file runs before all tests to set up the test environment
 */

require('dotenv').config({ path: '../../backend/.env' });

// Set test timeout to 10 seconds
jest.setTimeout(10000);

// Global test configuration
global.API_BASE_URL = process.env.API_BASE_URL || 'http://localhost:3000';
global.API_VERSION = '/api/v1';

// Test user credentials
global.TEST_USER = {
  email: 'test@momcare.com',
  password: 'TestPassword123!',
  name: 'Test Mother',
  deliveryDate: '2024-06-15',
  deliveryType: 'vaginal',
  isBreastfeeding: true,
  acceptTerms: true,
};

global.TEST_USER_2 = {
  email: 'test2@momcare.com',
  password: 'TestPassword456!',
  name: 'Test Mother 2',
  deliveryDate: '2024-07-20',
  deliveryType: 'cesarean',
  isBreastfeeding: false,
  acceptTerms: true,
};

// Store tokens for authenticated requests
// Don't reset if already exists (preserve tokens from auth tests)
global.authTokens = global.authTokens || {
  user1: null,
  user2: null,
};

// Clean up function to run after all tests
afterAll(async () => {
  // Close any open connections
  console.log('\n✓ Tests completed');
});
