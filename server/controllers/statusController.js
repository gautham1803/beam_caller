const { getUserStatus } = require('../services/presenceService');
const { getUserByNumber } = require('../services/numberService');

/**
 * GET /api/status/:number
 * Get user's online/offline status and last seen.
 */
async function getStatus(req, res) {
  try {
    const { number } = req.params;

    const user = await getUserByNumber(number);
    if (!user) {
      return res.status(404).json({ error: 'Number not found' });
    }

    const status = await getUserStatus(number);

    res.json({
      success: true,
      ...status,
    });
  } catch (err) {
    console.error('Status error:', err);
    res.status(500).json({ error: 'Server unavailable' });
  }
}

module.exports = { getStatus };
