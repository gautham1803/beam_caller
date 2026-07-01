const { pool } = require('../config/database');

/**
 * Generate a unique 6-digit number (100000-999999).
 * Retries until a non-colliding number is found.
 */
async function generateUniqueNumber() {
  const maxAttempts = 100;

  for (let i = 0; i < maxAttempts; i++) {
    const number = String(Math.floor(100000 + Math.random() * 900000));

    const result = await pool.query(
      'SELECT number FROM users WHERE number = $1',
      [number]
    );

    if (result.rows.length === 0) {
      return number;
    }
  }

  throw new Error('Unable to generate unique number after maximum attempts');
}

/**
 * Get user by device ID.
 */
async function getUserByDeviceId(deviceId) {
  const result = await pool.query(
    'SELECT number, device_id, created_at, last_seen FROM users WHERE device_id = $1',
    [deviceId]
  );
  return result.rows[0] || null;
}

/**
 * Get user by number.
 */
async function getUserByNumber(number) {
  const result = await pool.query(
    'SELECT number, device_id, created_at, last_seen FROM users WHERE number = $1',
    [number]
  );
  return result.rows[0] || null;
}

/**
 * Create a new user with a unique number.
 */
async function createUser(deviceId) {
  const number = await generateUniqueNumber();

  await pool.query(
    'INSERT INTO users (number, device_id) VALUES ($1, $2)',
    [number, deviceId]
  );

  return { number, device_id: deviceId };
}

/**
 * Update user's push token by number.
 */
async function updatePushToken(number, pushToken) {
  await pool.query(
    'UPDATE users SET push_token = $1 WHERE number = $2',
    [pushToken, number]
  );
}

module.exports = {
  generateUniqueNumber,
  getUserByDeviceId,
  getUserByNumber,
  createUser,
  updatePushToken,
};
