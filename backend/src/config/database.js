/**
 * MomCare API - PostgreSQL Database Configuration
 *
 * Connection pool management with support for read replicas,
 * SSL, and HIPAA-compliant audit logging
 */

const { Pool } = require('pg');
const config = require('./index');
const logger = require('../utils/logger');

// Primary database pool
const poolConfig = {
  host: config.database.host,
  port: config.database.port,
  database: config.database.name,
  user: config.database.user,
  password: config.database.password,
  min: config.database.pool.min,
  max: config.database.pool.max,
  idleTimeoutMillis: config.database.pool.idleTimeout,
  connectionTimeoutMillis: config.database.pool.connectionTimeout,
};

// Add SSL configuration for production
if (config.database.ssl) {
  poolConfig.ssl = {
    rejectUnauthorized: true,
  };
  if (config.database.sslCa) {
    poolConfig.ssl.ca = config.database.sslCa;
  }
}

const pool = new Pool(poolConfig);

// Read replica pool (for scaling read operations)
let readPool = null;
if (config.database.readReplica.host) {
  readPool = new Pool({
    ...poolConfig,
    host: config.database.readReplica.host,
    port: config.database.readReplica.port,
  });
}

// Connection event handlers
pool.on('connect', (client) => {
  logger.debug('New database client connected');
});

pool.on('error', (err, client) => {
  logger.error('Unexpected database pool error', { error: err.message });
});

pool.on('remove', (client) => {
  logger.debug('Database client removed from pool');
});

/**
 * Execute a query on the primary database
 * @param {string} text - SQL query
 * @param {Array} params - Query parameters
 * @returns {Promise<Object>} Query result
 */
async function query(text, params) {
  const start = Date.now();
  try {
    const result = await pool.query(text, params);
    const duration = Date.now() - start;

    logger.debug('Query executed', {
      query: text.substring(0, 100),
      duration,
      rowCount: result.rowCount,
    });

    return result;
  } catch (error) {
    logger.error('Query failed', {
      query: text.substring(0, 100),
      error: error.message,
    });
    throw error;
  }
}

/**
 * Execute a read-only query (uses replica if available)
 * @param {string} text - SQL query
 * @param {Array} params - Query parameters
 * @returns {Promise<Object>} Query result
 */
async function readQuery(text, params) {
  const targetPool = readPool || pool;
  const start = Date.now();

  try {
    const result = await targetPool.query(text, params);
    const duration = Date.now() - start;

    logger.debug('Read query executed', {
      query: text.substring(0, 100),
      duration,
      rowCount: result.rowCount,
      useReplica: !!readPool,
    });

    return result;
  } catch (error) {
    logger.error('Read query failed', {
      query: text.substring(0, 100),
      error: error.message,
    });
    throw error;
  }
}

/**
 * Get a client from the pool for transaction management
 * @returns {Promise<PoolClient>}
 */
async function getClient() {
  const client = await pool.connect();
  const originalQuery = client.query.bind(client);
  const originalRelease = client.release.bind(client);

  // Track query count for debugging
  let queryCount = 0;

  client.query = (...args) => {
    queryCount++;
    return originalQuery(...args);
  };

  client.release = () => {
    logger.debug('Client released after queries', { queryCount });
    return originalRelease();
  };

  return client;
}

/**
 * Execute queries within a transaction
 * @param {Function} callback - Async function receiving client
 * @returns {Promise<any>} Result of callback
 */
async function transaction(callback) {
  const client = await getClient();

  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

/**
 * Health check for database connection
 * @returns {Promise<boolean>}
 */
async function healthCheck() {
  try {
    const result = await pool.query('SELECT NOW()');
    return !!result.rows[0];
  } catch (error) {
    logger.error('Database health check failed', { error: error.message });
    return false;
  }
}

/**
 * Gracefully close database connections
 */
async function close() {
  logger.info('Closing database connections...');
  await pool.end();
  if (readPool) {
    await readPool.end();
  }
  logger.info('Database connections closed');
}

module.exports = {
  pool,
  query,
  readQuery,
  getClient,
  transaction,
  healthCheck,
  close,
};
