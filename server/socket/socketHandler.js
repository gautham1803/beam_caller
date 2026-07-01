const {
  setActiveConnection,
  removeActiveConnectionBySocket,
  getActiveConnection,
  updateHeartbeat,
  isUserOnline,
  cleanStaleConnections,
} = require('../services/presenceService');
const { getUserByNumber } = require('../services/numberService');

// Track active calls in memory: socketId -> { callPartnerSocket, callPartnerNumber, callType }
const activeCalls = new Map();
// Track socket -> userNumber mapping
const socketUserMap = new Map();

function setupSocketHandler(io) {
  // Periodic cleanup of stale connections (every 30s)
  setInterval(async () => {
    try {
      await cleanStaleConnections();
    } catch (err) {
      console.error('Stale connection cleanup error:', err);
    }
  }, 30000);

  io.on('connection', (socket) => {
    console.log(`🔌 Socket connected: ${socket.id}`);

    /**
     * Register: Map socket to user number.
     */
    socket.on('register', async (data) => {
      try {
        const { number } = data;
        if (!number || !/^\d{6}$/.test(number)) {
          socket.emit('error', { message: 'Invalid number' });
          return;
        }

        const user = await getUserByNumber(number);
        if (!user) {
          socket.emit('error', { message: 'Number not found' });
          return;
        }

        await setActiveConnection(number, socket.id);
        socketUserMap.set(socket.id, number);

        socket.emit('registered', { success: true, number });
        console.log(`✅ User ${number} registered with socket ${socket.id}`);
      } catch (err) {
        console.error('Register error:', err);
        socket.emit('error', { message: 'Registration failed' });
      }
    });

    /**
     * Heartbeat: Update last ping.
     */
    socket.on('heartbeat', async (data) => {
      try {
        const { number } = data;
        if (number) {
          await updateHeartbeat(number);
        }
      } catch (err) {
        console.error('Heartbeat error:', err);
      }
    });

    /**
     * Call Start: Initiate a call to another user.
     */
    socket.on('call:start', async (data) => {
      try {
        const { targetNumber, callerNumber, callType = 'voice' } = data;

        if (!targetNumber || !callerNumber) {
          socket.emit('call:error', { message: 'Invalid call data' });
          return;
        }

        if (targetNumber === callerNumber) {
          socket.emit('call:error', { message: 'Cannot call yourself' });
          return;
        }

        // Check if target exists
        const targetUser = await getUserByNumber(targetNumber);
        if (!targetUser) {
          socket.emit('call:error', { message: 'Number not found' });
          return;
        }

        // Check if target is online
        const online = await isUserOnline(targetNumber);
        if (!online) {
          try {
            const { sendIncomingCallPush } = require('../services/pushNotificationService');
            await sendIncomingCallPush(targetNumber, callerNumber, callType);
          } catch (pushErr) {
            console.error('Failed to send push notification:', pushErr);
          }
          socket.emit('call:error', { message: 'User offline' });
          return;
        }

        // Get target's socket
        const targetConnection = await getActiveConnection(targetNumber);
        if (!targetConnection) {
          socket.emit('call:error', { message: 'User unavailable' });
          return;
        }

        // Check if target is already in a call
        if (activeCalls.has(targetConnection.socket_id)) {
          socket.emit('call:busy', { number: targetNumber });
          return;
        }

        // Check if caller is already in a call
        if (activeCalls.has(socket.id)) {
          socket.emit('call:error', { message: 'You are already in a call' });
          return;
        }

        // Send incoming call to target
        io.to(targetConnection.socket_id).emit('call:incoming', {
          callerNumber,
          callType,
        });

        // Track the pending call
        activeCalls.set(socket.id, {
          callPartnerSocket: targetConnection.socket_id,
          callPartnerNumber: targetNumber,
          callType,
          status: 'ringing',
        });

        socket.emit('call:ringing', { targetNumber });
        console.log(`📞 Call: ${callerNumber} → ${targetNumber} (${callType})`);
      } catch (err) {
        console.error('Call start error:', err);
        socket.emit('call:error', { message: 'Call failed' });
      }
    });

    /**
     * Call Accept: Callee accepts the incoming call.
     */
    socket.on('call:accept', async (data) => {
      try {
        const { callerNumber } = data;
        const calleeNumber = socketUserMap.get(socket.id);

        // Find the caller's socket
        const callerConnection = await getActiveConnection(callerNumber);
        if (!callerConnection) {
          socket.emit('call:error', { message: 'Caller no longer available' });
          return;
        }

        // Update call tracking
        const callerCall = activeCalls.get(callerConnection.socket_id);
        if (callerCall) {
          callerCall.status = 'connected';
        }

        activeCalls.set(socket.id, {
          callPartnerSocket: callerConnection.socket_id,
          callPartnerNumber: callerNumber,
          callType: callerCall?.callType || 'voice',
          status: 'connected',
        });

        io.to(callerConnection.socket_id).emit('call:accepted', {
          receiverNumber: calleeNumber,
        });

        console.log(`✅ Call accepted: ${callerNumber} ↔ ${calleeNumber}`);
      } catch (err) {
        console.error('Call accept error:', err);
        socket.emit('call:error', { message: 'Failed to accept call' });
      }
    });

    /**
     * Call Reject: Callee rejects the incoming call.
     */
    socket.on('call:reject', async (data) => {
      try {
        const { callerNumber } = data;

        const callerConnection = await getActiveConnection(callerNumber);
        if (callerConnection) {
          io.to(callerConnection.socket_id).emit('call:rejected', {
            receiverNumber: socketUserMap.get(socket.id),
          });
          activeCalls.delete(callerConnection.socket_id);
        }

        activeCalls.delete(socket.id);
        console.log(`❌ Call rejected by ${socketUserMap.get(socket.id)}`);
      } catch (err) {
        console.error('Call reject error:', err);
      }
    });

    /**
     * Call Cancel: Caller cancels before answer.
     */
    socket.on('call:cancel', async (data) => {
      try {
        const callData = activeCalls.get(socket.id);
        if (callData) {
          io.to(callData.callPartnerSocket).emit('call:cancelled', {
            callerNumber: socketUserMap.get(socket.id),
          });
          activeCalls.delete(callData.callPartnerSocket);
          activeCalls.delete(socket.id);
          console.log(`🚫 Call cancelled by ${socketUserMap.get(socket.id)}`);
        }
      } catch (err) {
        console.error('Call cancel error:', err);
      }
    });

    /**
     * Call End: Either party ends the call.
     */
    socket.on('call:end', async (data) => {
      try {
        const callData = activeCalls.get(socket.id);
        if (callData) {
          io.to(callData.callPartnerSocket).emit('call:ended', {
            number: socketUserMap.get(socket.id),
          });
          activeCalls.delete(callData.callPartnerSocket);
          activeCalls.delete(socket.id);
          console.log(`📴 Call ended by ${socketUserMap.get(socket.id)}`);
        }
      } catch (err) {
        console.error('Call end error:', err);
      }
    });

    /**
     * SDP Offer: Relay from caller to callee.
     */
    socket.on('call:sdp-offer', async (data) => {
      try {
        const callData = activeCalls.get(socket.id);
        if (callData) {
          io.to(callData.callPartnerSocket).emit('call:sdp-offer', {
            sdp: data.sdp,
            callerNumber: socketUserMap.get(socket.id),
          });
        }
      } catch (err) {
        console.error('SDP offer error:', err);
      }
    });

    /**
     * SDP Answer: Relay from callee to caller.
     */
    socket.on('call:sdp-answer', async (data) => {
      try {
        const callData = activeCalls.get(socket.id);
        if (callData) {
          io.to(callData.callPartnerSocket).emit('call:sdp-answer', {
            sdp: data.sdp,
            receiverNumber: socketUserMap.get(socket.id),
          });
        }
      } catch (err) {
        console.error('SDP answer error:', err);
      }
    });

    /**
     * ICE Candidate: Relay between peers.
     */
    socket.on('call:ice-candidate', async (data) => {
      try {
        const callData = activeCalls.get(socket.id);
        if (callData) {
          io.to(callData.callPartnerSocket).emit('call:ice-candidate', {
            candidate: data.candidate,
          });
        }
      } catch (err) {
        console.error('ICE candidate error:', err);
      }
    });

    /**
     * Disconnect: Clean up.
     */
    socket.on('disconnect', async (reason) => {
      try {
        const userNumber = socketUserMap.get(socket.id);

        // Notify call partner if in active call
        const callData = activeCalls.get(socket.id);
        if (callData) {
          io.to(callData.callPartnerSocket).emit('call:ended', {
            number: userNumber,
            reason: 'disconnect',
          });
          activeCalls.delete(callData.callPartnerSocket);
          activeCalls.delete(socket.id);
        }

        // Clean up connection tracking
        await removeActiveConnectionBySocket(socket.id);
        socketUserMap.delete(socket.id);

        console.log(`🔌 Socket disconnected: ${socket.id} (${userNumber || 'unknown'}) - ${reason}`);
      } catch (err) {
        console.error('Disconnect cleanup error:', err);
      }
    });
  });
}

module.exports = { setupSocketHandler };
