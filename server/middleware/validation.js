/**
 * Validation middleware for request data.
 */

function validateNumber(req, res, next) {
  const number = req.params.number || req.body.number;

  if (!number) {
    return res.status(400).json({ error: 'Number is required' });
  }

  if (!/^\d{6}$/.test(number)) {
    return res.status(400).json({ error: 'Number must be exactly 6 digits' });
  }

  next();
}

function validateDeviceId(req, res, next) {
  const { device_id } = req.body;

  if (!device_id || typeof device_id !== 'string' || device_id.trim().length === 0) {
    return res.status(400).json({ error: 'Valid device_id is required' });
  }

  next();
}

function validateCallRequest(req, res, next) {
  const { caller, receiver, type } = req.body;

  if (!caller || !/^\d{6}$/.test(caller)) {
    return res.status(400).json({ error: 'Valid caller number is required' });
  }

  if (!receiver || !/^\d{6}$/.test(receiver)) {
    return res.status(400).json({ error: 'Valid receiver number is required' });
  }

  if (caller === receiver) {
    return res.status(400).json({ error: 'Cannot call yourself' });
  }

  if (type && !['voice', 'video'].includes(type)) {
    return res.status(400).json({ error: 'Call type must be voice or video' });
  }

  next();
}

module.exports = {
  validateNumber,
  validateDeviceId,
  validateCallRequest,
};
