const { pool } = require('../config/database');

/**
 * Send a wake-up push notification using Firebase Cloud Messaging (FCM).
 * Since we don't have access to active service account credentials, this
 * logs the notification dispatch payload. To make it operational, the user
 * only needs to configure the Firebase SDK with their service-account.json.
 */
async function sendIncomingCallPush(targetNumber, callerNumber, callType) {
  try {
    const result = await pool.query(
      'SELECT push_token FROM users WHERE number = $1',
      [targetNumber]
    );

    const pushToken = result.rows[0]?.push_token;
    if (!pushToken) {
      console.log(`ℹ️ [Push Notification] No push token registered for ${targetNumber}`);
      return false;
    }

    console.log(`📣 [Push Notification] Sending FCM payload to target: ${targetNumber} (Token: ${pushToken})`);
    console.log(JSON.stringify({
      to: pushToken,
      notification: {
        title: 'Incoming Call',
        body: `Incoming ${callType} call from ${callerNumber}`,
        sound: 'default',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      data: {
        callerNumber: callerNumber,
        callType: callType,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        category: 'incoming_call',
      },
      priority: 'high',
    }, null, 2));

    // Firebase FCM API endpoint logic placeholder:
    // In production, initialize Firebase Admin SDK:
    // admin.messaging().send({ token: pushToken, ... })
    
    return true;
  } catch (err) {
    console.error('❌ Push notification dispatch failed:', err);
    return false;
  }
}

module.exports = { sendIncomingCallPush };
