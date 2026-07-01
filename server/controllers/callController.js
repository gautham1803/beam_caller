const { pool } = require('../config/database');
const { getUserByNumber } = require('../services/numberService');
const { isUserOnline } = require('../services/presenceService');

/**
 * POST /api/call/start
 * Record call start in history.
 */
async function startCall(req, res) {
  try {
    const { caller, receiver, type = 'voice' } = req.body;

    // Validate caller exists
    const callerUser = await getUserByNumber(caller);
    if (!callerUser) {
      return res.status(404).json({ error: 'Caller number not found' });
    }

    // Validate receiver exists
    const receiverUser = await getUserByNumber(receiver);
    if (!receiverUser) {
      return res.status(404).json({ error: 'Number not found' });
    }

    // Check if receiver is online
    const online = await isUserOnline(receiver);
    if (!online) {
      return res.status(200).json({ success: false, error: 'User offline' });
    }

    // Record call
    const result = await pool.query(
      'INSERT INTO call_history (caller, receiver, type) VALUES ($1, $2, $3) RETURNING id',
      [caller, receiver, type]
    );

    res.json({
      success: true,
      call_id: result.rows[0].id,
    });
  } catch (err) {
    console.error('Call start error:', err);
    res.status(500).json({ error: 'Call failed' });
  }
}

/**
 * POST /api/call/end
 * Update call record with end time and duration.
 */
async function endCall(req, res) {
  try {
    const { call_id, duration = 0 } = req.body;

    if (!call_id) {
      return res.status(400).json({ error: 'call_id is required' });
    }

    await pool.query(
      'UPDATE call_history SET ended_at = NOW(), duration = $1 WHERE id = $2',
      [duration, call_id]
    );

    res.json({ success: true });
  } catch (err) {
    console.error('Call end error:', err);
    res.status(500).json({ error: 'Server unavailable' });
  }
}

/**
 * GET /api/calls/recent/:number
 * Fetch recent call history for a specific user number.
 */
async function getRecentCalls(req, res) {
  try {
    const { number } = req.params;

    const result = await pool.query(
      `SELECT id, caller, receiver, type, started_at, ended_at, duration 
       FROM call_history 
       WHERE caller = $1 OR receiver = $2 
       ORDER BY started_at DESC 
       LIMIT 50`,
      [number, number]
    );

    res.json({
      success: true,
      calls: result.rows,
    });
  } catch (err) {
    console.error('Fetch recent calls error:', err);
    res.status(500).json({ error: 'Server unavailable' });
  }
}

module.exports = { startCall, endCall, getRecentCalls };
