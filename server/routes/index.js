const express = require('express');
const router = express.Router();

const { register, registerPush } = require('../controllers/registrationController');
const { heartbeat } = require('../controllers/heartbeatController');
const { getStatus } = require('../controllers/statusController');
const { startCall, endCall, getRecentCalls } = require('../controllers/callController');
const { validateNumber, validateDeviceId, validateCallRequest } = require('../middleware/validation');

// Registration
router.post('/register', validateDeviceId, register);
router.post('/register-push', validateNumber, registerPush);

// Heartbeat
router.post('/heartbeat', validateNumber, heartbeat);

// Status
router.get('/status/:number', validateNumber, getStatus);

// Calls
router.post('/call/start', validateCallRequest, startCall);
router.post('/call/end', endCall);
router.get('/calls/recent/:number', validateNumber, getRecentCalls);

module.exports = router;
