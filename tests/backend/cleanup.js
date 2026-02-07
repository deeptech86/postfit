/**
 * Test Database Cleanup Script
 * Run this before tests to ensure clean state
 */

const { Client } = require('pg');

async function cleanup() {
  const client = new Client({
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME || 'momcare_db',
    user: process.env.DB_USER || 'dipmacmini',
    password: process.env.DB_PASSWORD || '',
  });

  try {
    await client.connect();
    console.log('🔧 Cleaning up test data...');

    // Delete test users and all related data
    await client.query(`
      DELETE FROM users
      WHERE email LIKE '%@momcare.com'
         OR email LIKE '%@test.com'
         OR email LIKE 'test%'
    `);

    console.log('✅ Test data cleaned up successfully');
  } catch (error) {
    console.error('❌ Cleanup failed:', error.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

cleanup();
