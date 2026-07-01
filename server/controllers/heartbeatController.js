const { updateHeartbeat } = require('../services/presenceService');
const { getUserByNumber } = require('../services/numberService');

/**
 * POST /api/heartbeat
 * Update user's last seen and connection ping.
 */
async function heartbeat(req, res) {
  try {
    const { number } = req.body;

    const user = await getUserByNumber(number);
    if (!user) {
      return res.status(404).json({ error: 'Number not found' });
    }

    await updateHeartbeat(number);

    res.json({ success: true });
  } catch (err) {
    console.error('Heartbeat error:', err);
    res.status(500).json({ error: 'Server unavailable' });
  }
}

module.exports = { heartbeat };
