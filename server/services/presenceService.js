const { pool } = require('../config/database');

const ONLINE_THRESHOLD_SECONDS = 30;

/**
 * Update user's last_seen timestamp.
 */
async function updateLastSeen(number) {
  await pool.query(
    'UPDATE users SET last_seen = NOW() WHERE number = $1',
    [number]
  );
}

/**
 * Upsert active connection for a user.
 */
async function setActiveConnection(userNumber, socketId) {
  await pool.query(
    `INSERT INTO active_connections (user_number, socket_id, last_ping)
     VALUES ($1, $2, NOW())
     ON CONFLICT (user_number) DO UPDATE
     SET socket_id = $2, last_ping = NOW()`,
    [userNumber, socketId]
  );
}

/**
 * Remove active connection.
 */
async function removeActiveConnection(userNumber) {
  await pool.query(
    'DELETE FROM active_connections WHERE user_number = $1',
    [userNumber]
  );
}

/**
 * Remove active connection by socket ID.
 */
async function removeActiveConnectionBySocket(socketId) {
  const result = await pool.query(
    'DELETE FROM active_connections WHERE socket_id = $1 RETURNING user_number',
    [socketId]
  );
  return result.rows[0]?.user_number || null;
}

/**
 * Get active connection for a user.
 */
async function getActiveConnection(userNumber) {
  const result = await pool.query(
    'SELECT socket_id, last_ping FROM active_connections WHERE user_number = $1',
    [userNumber]
  );
  return result.rows[0] || null;
}

/**
 * Update heartbeat ping.
 */
async function updateHeartbeat(userNumber) {
  await pool.query(
    'UPDATE active_connections SET last_ping = NOW() WHERE user_number = $1',
    [userNumber]
  );
  await updateLastSeen(userNumber);
}

/**
 * Check if user is online (has active connection with recent heartbeat).
 */
async function isUserOnline(userNumber) {
  const result = await pool.query(
    `SELECT socket_id FROM active_connections
     WHERE user_number = $1
     AND last_ping > NOW() - INTERVAL '${ONLINE_THRESHOLD_SECONDS} seconds'`,
    [userNumber]
  );
  return result.rows.length > 0;
}

/**
 * Get user status: online, offline, last_seen.
 */
async function getUserStatus(userNumber) {
  const online = await isUserOnline(userNumber);
  const userResult = await pool.query(
    'SELECT last_seen FROM users WHERE number = $1',
    [userNumber]
  );

  if (userResult.rows.length === 0) {
    return null;
  }

  const lastSeen = userResult.rows[0].last_seen;

  return {
    number: userNumber,
    online,
    last_seen: lastSeen,
    last_seen_text: online ? 'Active now' : formatLastSeen(lastSeen),
  };
}

/**
 * Format last seen into human-readable text.
 */
function formatLastSeen(lastSeen) {
  if (!lastSeen) return 'Unknown';

  const now = new Date();
  const seen = new Date(lastSeen);
  const diffMs = now - seen;
  const diffSeconds = Math.floor(diffMs / 1000);
  const diffMinutes = Math.floor(diffSeconds / 60);
  const diffHours = Math.floor(diffMinutes / 60);
  const diffDays = Math.floor(diffHours / 24);

  if (diffSeconds < 60) return 'Just now';
  if (diffMinutes < 60) return `${diffMinutes} minute${diffMinutes > 1 ? 's' : ''} ago`;
  if (diffHours < 24) return `${diffHours} hour${diffHours > 1 ? 's' : ''} ago`;
  if (diffDays === 1) return 'Yesterday';
  return `${diffDays} days ago`;
}

/**
 * Clean up stale connections (older than threshold).
 */
async function cleanStaleConnections() {
  const result = await pool.query(
    `DELETE FROM active_connections
     WHERE last_ping < NOW() - INTERVAL '${ONLINE_THRESHOLD_SECONDS} seconds'
     RETURNING user_number`
  );
  return result.rows.map((r) => r.user_number);
}

module.exports = {
  updateLastSeen,
  setActiveConnection,
  removeActiveConnection,
  removeActiveConnectionBySocket,
  getActiveConnection,
  updateHeartbeat,
  isUserOnline,
  getUserStatus,
  cleanStaleConnections,
};
