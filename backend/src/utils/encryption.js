/**
 * MomCare API - Encryption Utilities
 *
 * AES-256 encryption for sensitive health data (HIPAA compliant)
 * Includes hashing for passwords and tokens
 */

const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const config = require('../config');

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 16;
const AUTH_TAG_LENGTH = 16;
const SALT_LENGTH = 64;
const KEY_LENGTH = 32;

/**
 * Get encryption key from config
 * @returns {Buffer}
 */
function getEncryptionKey() {
  if (!config.security.encryptionKey) {
    throw new Error('Encryption key not configured');
  }
  return Buffer.from(config.security.encryptionKey, 'hex');
}

/**
 * Encrypt sensitive data using AES-256-GCM
 * @param {string} plaintext - Data to encrypt
 * @returns {string} Encrypted data (iv:authTag:ciphertext in base64)
 */
function encrypt(plaintext) {
  if (!plaintext) return null;

  const iv = crypto.randomBytes(IV_LENGTH);
  const key = getEncryptionKey();

  const cipher = crypto.createCipheriv(ALGORITHM, key, iv);

  let encrypted = cipher.update(plaintext, 'utf8', 'base64');
  encrypted += cipher.final('base64');

  const authTag = cipher.getAuthTag();

  // Combine iv:authTag:ciphertext
  return [
    iv.toString('base64'),
    authTag.toString('base64'),
    encrypted,
  ].join(':');
}

/**
 * Decrypt sensitive data
 * @param {string} encryptedData - Encrypted data string
 * @returns {string} Decrypted plaintext
 */
function decrypt(encryptedData) {
  if (!encryptedData) return null;

  try {
    const [ivBase64, authTagBase64, ciphertext] = encryptedData.split(':');

    if (!ivBase64 || !authTagBase64 || !ciphertext) {
      throw new Error('Invalid encrypted data format');
    }

    const iv = Buffer.from(ivBase64, 'base64');
    const authTag = Buffer.from(authTagBase64, 'base64');
    const key = getEncryptionKey();

    const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);
    decipher.setAuthTag(authTag);

    let decrypted = decipher.update(ciphertext, 'base64', 'utf8');
    decrypted += decipher.final('utf8');

    return decrypted;
  } catch (error) {
    throw new Error('Decryption failed: ' + error.message);
  }
}

/**
 * Hash a password using bcrypt
 * @param {string} password - Plain password
 * @returns {Promise<string>} Hashed password
 */
async function hashPassword(password) {
  const salt = await bcrypt.genSalt(12);
  return bcrypt.hash(password, salt);
}

/**
 * Verify a password against a hash
 * @param {string} password - Plain password
 * @param {string} hash - Stored hash
 * @returns {Promise<boolean>}
 */
async function verifyPassword(password, hash) {
  return bcrypt.compare(password, hash);
}

/**
 * Generate a secure random token
 * @param {number} length - Token length in bytes
 * @returns {string} Hex token
 */
function generateToken(length = 32) {
  return crypto.randomBytes(length).toString('hex');
}

/**
 * Generate a secure verification code (6 digits)
 * @returns {string}
 */
function generateVerificationCode() {
  return crypto.randomInt(100000, 999999).toString();
}

/**
 * Hash a token for storage (one-way)
 * @param {string} token - Plain token
 * @returns {string} Hashed token
 */
function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

/**
 * Create HMAC signature
 * @param {string} data - Data to sign
 * @param {string} secret - Secret key (optional, uses encryption key)
 * @returns {string} HMAC signature
 */
function createSignature(data, secret = null) {
  const key = secret || config.security.encryptionKey;
  return crypto.createHmac('sha256', key).update(data).digest('hex');
}

/**
 * Verify HMAC signature
 * @param {string} data - Original data
 * @param {string} signature - Signature to verify
 * @param {string} secret - Secret key (optional)
 * @returns {boolean}
 */
function verifySignature(data, signature, secret = null) {
  const expectedSignature = createSignature(data, secret);
  return crypto.timingSafeEqual(
    Buffer.from(signature, 'hex'),
    Buffer.from(expectedSignature, 'hex')
  );
}

/**
 * Mask sensitive data for logging
 * @param {string} data - Sensitive data
 * @param {number} visibleChars - Number of visible characters
 * @returns {string} Masked data
 */
function maskSensitiveData(data, visibleChars = 4) {
  if (!data || data.length <= visibleChars) {
    return '****';
  }
  return data.substring(0, visibleChars) + '****';
}

/**
 * Encrypt JSON object (for storing structured PHI)
 * @param {Object} data - Object to encrypt
 * @returns {string} Encrypted string
 */
function encryptObject(data) {
  return encrypt(JSON.stringify(data));
}

/**
 * Decrypt to JSON object
 * @param {string} encryptedData - Encrypted string
 * @returns {Object} Decrypted object
 */
function decryptObject(encryptedData) {
  const decrypted = decrypt(encryptedData);
  return decrypted ? JSON.parse(decrypted) : null;
}

/**
 * Derive a key from password (for user-specific encryption)
 * @param {string} password - User password
 * @param {string} salt - Salt (hex string)
 * @returns {Promise<{key: string, salt: string}>}
 */
async function deriveKey(password, salt = null) {
  const saltBuffer = salt
    ? Buffer.from(salt, 'hex')
    : crypto.randomBytes(SALT_LENGTH);

  return new Promise((resolve, reject) => {
    crypto.pbkdf2(password, saltBuffer, 100000, KEY_LENGTH, 'sha256', (err, derivedKey) => {
      if (err) reject(err);
      resolve({
        key: derivedKey.toString('hex'),
        salt: saltBuffer.toString('hex'),
      });
    });
  });
}

module.exports = {
  encrypt,
  decrypt,
  encryptObject,
  decryptObject,
  hashPassword,
  verifyPassword,
  generateToken,
  generateVerificationCode,
  hashToken,
  createSignature,
  verifySignature,
  maskSensitiveData,
  deriveKey,
};
