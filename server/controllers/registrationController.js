const { getUserByDeviceId, createUser, updatePushToken } = require('../services/numberService');

/**
 * POST /api/register
 * Register a device and assign a unique 6-digit number.
 * If the device already has a number, return it.
 */
async function register(req, res) {
  try {
    const { device_id } = req.body;

    // Check if device already registered
    const existing = await getUserByDeviceId(device_id);
    if (existing) {
      return res.json({
        success: true,
        number: existing.number,
        is_new: false,
      });
    }

    // Create new user
    const user = await createUser(device_id);

    res.status(201).json({
      success: true,
      number: user.number,
      is_new: true,
    });
  } catch (err) {
    console.error('Registration error:', err);
    res.status(500).json({ error: 'Server unavailable' });
  }
}

/**
 * POST /api/register-push
 * Save user's push token.
 */
async function registerPush(req, res) {
  try {
    const { number, push_token } = req.body;
    if (!number || !push_token) {
      return res.status(400).json({ error: 'Number and push_token are required' });
    }
    await updatePushToken(number, push_token);
    res.json({ success: true });
  } catch (err) {
    console.error('Push registration error:', err);
    res.status(500).json({ error: 'Server unavailable' });
  }
}

module.exports = { register, registerPush };
