// Web client configuration
const API_BASE = window.location.origin;

// State management
let myNumber = null;
let deviceId = null;
let socket = null;
let localStream = null;
let remoteStream = null;
let peerConnection = null;
let callStartTime = null;
let callTimerInterval = null;
let activeCallPartner = null;
let currentCallType = 'voice';
let activeCallId = null;

// WebRTC STUN servers config
const rtcConfig = {
  iceServers: [
    { urls: 'stun:stun.l.google.com:19302' },
    { urls: 'stun:stun1.l.google.com:19302' }
  ]
};

// 1. Initialize Application
window.addEventListener('DOMContentLoaded', async () => {
  setupApp();
  await registerDevice();
  initSocket();
  setupEventListeners();
  loadFavorites();
  lucide.createIcons();
});

// Setup Unique Device ID per session to allow testing in multiple tabs
function setupApp() {
  // Use sessionStorage so different tabs act as different devices
  deviceId = sessionStorage.getItem('device_id');
  if (!deviceId) {
    deviceId = 'web-device-' + Math.random().toString(36).substring(2, 15);
    sessionStorage.setItem('device_id', deviceId);
  }
}

// 2. Register Device and get unique 6-digit number
async function registerDevice() {
  showScreen('screen-splash');
  try {
    const res = await fetch(`${API_BASE}/api/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ device_id: deviceId })
    });
    
    const data = await res.json();
    if (data.success) {
      myNumber = data.number;
      document.getElementById('share-number-display').innerText = formatNumber(myNumber);
      
      // Setup QR Image
      const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=caller://dial/${myNumber}`;
      document.getElementById('qr-image').src = qrUrl;

      // Register simulated push token
      await registerPushToken();

      setTimeout(() => {
        showScreen('screen-home');
      }, 1000);
    } else {
      showSplashError('Registration failed. Click to retry.');
    }
  } catch (err) {
    console.error(err);
    showSplashError('Server unavailable. Click to retry.');
  }
}

async function registerPushToken() {
  try {
    await fetch(`${API_BASE}/api/register-push`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        number: myNumber,
        push_token: `web-push-token-${deviceId}`
      })
    });
  } catch (e) {
    console.warn('Failed to register mock push token:', e);
  }
}

// 3. Initialize Socket.IO connection
function initSocket() {
  socket = io(API_BASE);

  socket.on('connect', () => {
    socket.emit('register', { number: myNumber });
    document.getElementById('status-text').innerText = 'Active';
    document.querySelector('.status-dot').className = 'status-dot green';
  });

  socket.on('disconnect', () => {
    document.getElementById('status-text').innerText = 'Connecting...';
    document.querySelector('.status-dot').className = 'status-dot gray';
  });

  // Periodical Heartbeat
  setInterval(() => {
    if (socket && socket.connected) {
      socket.emit('heartbeat', { number: myNumber });
    }
  }, 15000);

  // Incoming Call Handler
  socket.on('call:incoming', (data) => {
    if (peerConnection) {
      // Busy
      socket.emit('call:reject', { callerNumber: data.callerNumber });
      return;
    }
    activeCallPartner = data.callerNumber;
    currentCallType = data.callType;
    
    document.getElementById('incoming-number').innerText = formatNumber(activeCallPartner);
    document.getElementById('incoming-type').innerText = `Incoming ${currentCallType === 'video' ? 'Video' : 'Voice'} Call`;
    showScreen('screen-incoming');
  });

  socket.on('call:ringing', () => {
    updateCallStatus('Ringing...');
  });

  socket.on('call:accepted', async () => {
    updateCallStatus('Connecting...');
    await startWebRTC(true);
  });

  socket.on('call:rejected', () => {
    showToast('Call Declined');
    endCallCleanup();
  });

  socket.on('call:busy', () => {
    showToast('User Busy');
    endCallCleanup();
  });

  socket.on('call:cancelled', () => {
    showToast('Call Cancelled');
    endCallCleanup();
  });

  socket.on('call:ended', () => {
    showToast('Call Ended');
    endCallCleanup();
  });

  socket.on('call:error', (data) => {
    showToast(data.message || 'Call failed');
    endCallCleanup();
  });

  // Signaling Relays
  socket.on('call:sdp-offer', async (data) => {
    try {
      await peerConnection.setRemoteDescription(new RTCSessionDescription(data.sdp));
      const answer = await peerConnection.createAnswer();
      await peerConnection.setLocalDescription(answer);
      socket.emit('call:sdp-answer', { sdp: answer });
    } catch (e) {
      console.error(e);
    }
  });

  socket.on('call:sdp-answer', async (data) => {
    try {
      await peerConnection.setRemoteDescription(new RTCSessionDescription(data.sdp));
    } catch (e) {
      console.error(e);
    }
  });

  socket.on('call:ice-candidate', async (data) => {
    try {
      if (data.candidate) {
        await peerConnection.addIceCandidate(new RTCIceCandidate(data.candidate));
      }
    } catch (e) {
      console.error(e);
    }
  });
}

// 4. WebRTC Connection Setup
async function startWebRTC(isCaller) {
  try {
    updateCallStatus('Accessing media...');
    
    // Capture Local Audio/Video
    const constraints = {
      audio: true,
      video: currentCallType === 'video'
    };

    localStream = await navigator.mediaDevices.getUserMedia(constraints);
    
    // Render local preview
    const localVideo = document.getElementById('local-video');
    localVideo.srcObject = localStream;
    if (currentCallType === 'video') {
      localVideo.classList.remove('hidden');
      document.getElementById('btn-camera').classList.remove('hidden');
    } else {
      localVideo.classList.add('hidden');
      document.getElementById('btn-camera').classList.add('hidden');
    }

    // Initialize peer connection
    peerConnection = new RTCPeerConnection(rtcConfig);

    // Track stream addition
    localStream.getTracks().forEach(track => {
      peerConnection.addTrack(track, localStream);
    });

    peerConnection.ontrack = (event) => {
      document.getElementById('remote-video').srcObject = event.streams[0];
    };

    peerConnection.onicecandidate = (event) => {
      if (event.candidate) {
        socket.emit('call:ice-candidate', { candidate: event.candidate });
      }
    };

    peerConnection.onconnectionstatechange = () => {
      console.log('RTCPeerConnection state:', peerConnection.connectionState);
      if (peerConnection.connectionState === 'connected') {
        updateCallStatus('Connected');
        startCallTimer();
      } else if (peerConnection.connectionState === 'failed' || peerConnection.connectionState === 'disconnected') {
        socket.emit('call:end');
        endCallCleanup();
      }
    };

    if (isCaller) {
      updateCallStatus('Connecting...');
      const offer = await peerConnection.createOffer();
      await peerConnection.setLocalDescription(offer);
      socket.emit('call:sdp-offer', { sdp: offer });
    }

  } catch (err) {
    console.error(err);
    showToast('Permission denied');
    socket.emit('call:end');
    endCallCleanup();
  }
}

// 5. In-Call Actions
async function startCall(targetNumber, type) {
  if (targetNumber === myNumber) {
    showDialError('Cannot call yourself');
    return;
  }
  if (!/^\d{6}$/.test(targetNumber)) {
    showDialError('Enter a valid 6-digit number');
    return;
  }

  activeCallPartner = targetNumber;
  currentCallType = type;
  
  // Set in-call UI details
  document.getElementById('call-partner-number').innerText = formatNumber(targetNumber);
  document.getElementById('active-call-avatar').innerHTML = '<i data-lucide="user" class="avatar-icon-svg"></i>';
  lucide.createIcons();
  updateCallStatus('Calling...');
  showScreen('screen-active-call');

  // Register call start in history via REST
  try {
    const res = await fetch(`${API_BASE}/api/call/start`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        caller: myNumber,
        receiver: targetNumber,
        type: type
      })
    });
    const data = await res.json();
    if (data.success) {
      activeCallId = data.call_id;
    }
  } catch (e) {
    console.warn('Failed to record call start in db:', e);
  }

  // Socket emit
  socket.emit('call:start', {
    targetNumber,
    callerNumber: myNumber,
    callType: type
  });
}

function acceptCall() {
  socket.emit('call:accept', { callerNumber: activeCallPartner });
  
  document.getElementById('call-partner-number').innerText = formatNumber(activeCallPartner);
  updateCallStatus('Connecting...');
  showScreen('screen-active-call');
}

function declineCall() {
  socket.emit('call:reject', { callerNumber: activeCallPartner });
  endCallCleanup();
}

function hangupCall() {
  if (peerConnection && peerConnection.connectionState === 'new') {
    socket.emit('call:cancel');
  } else {
    socket.emit('call:end');
  }
  endCallCleanup();
}

// End call cleanup & navigation
async function endCallCleanup() {
  // Stop call timer
  stopCallTimer();

  // Record call duration in history if we initiated it
  if (activeCallId && callStartTime) {
    const duration = Math.floor((Date.now() - callStartTime) / 1000);
    try {
      await fetch(`${API_BASE}/api/call/end`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          call_id: activeCallId,
          duration: duration
        })
      });
    } catch (_) {}
  }

  activeCallId = null;

  // Stop media tracks
  if (localStream) {
    localStream.getTracks().forEach(track => track.stop());
    localStream = null;
  }
  
  if (peerConnection) {
    peerConnection.close();
    peerConnection = null;
  }

  // Clear video tags
  document.getElementById('local-video').srcObject = null;
  document.getElementById('remote-video').srcObject = null;
  
  activeCallPartner = null;
  callStartTime = null;

  showScreen('screen-home');
  loadRecents();
}

// 6. UI Helpers & Timers
function startCallTimer() {
  callStartTime = Date.now();
  document.getElementById('call-timer').innerText = '00:00';
  
  callTimerInterval = setInterval(() => {
    const diff = Math.floor((Date.now() - callStartTime) / 1000);
    const mins = Math.floor(diff / 60).toString().padLeft(2, '0');
    const secs = (diff % 60).toString().padLeft(2, '0');
    document.getElementById('call-timer').innerText = `${mins}:${secs}`;
  }, 1000);
}

function stopCallTimer() {
  if (callTimerInterval) {
    clearInterval(callTimerInterval);
    callTimerInterval = null;
  }
  document.getElementById('call-timer').innerText = '00:00';
}

String.prototype.padLeft = function(size, char) {
  let s = this;
  while (s.length < size) s = char + s;
  return s;
};

function showScreen(screenId) {
  document.querySelectorAll('.screen').forEach(scr => {
    scr.classList.remove('active');
  });
  document.getElementById(screenId).classList.add('active');
}

function updateCallStatus(status) {
  document.getElementById('call-status').innerText = status;
}

function formatNumber(num) {
  if (num && num.length === 6) {
    return `${num.substring(0, 3)} ${num.substring(3)}`;
  }
  return num || '------';
}

function showToast(msg) {
  const toast = document.getElementById('toast');
  toast.innerText = msg;
  toast.classList.remove('hidden');
  setTimeout(() => {
    toast.classList.add('hidden');
  }, 2500);
}

function showSplashError(msg) {
  const err = document.getElementById('splash-error');
  err.innerText = msg;
  err.classList.remove('hidden');
  document.querySelector('.spinner').classList.add('hidden');
}

function showDialError(msg) {
  const err = document.getElementById('dial-error');
  err.innerText = msg;
  err.classList.remove('hidden');
}

// 7. Recents & Favorites List Rendering
async function loadRecents() {
  const recentsList = document.getElementById('recents-list');
  recentsList.innerHTML = '<div class="spinner-small"></div>';

  try {
    const res = await fetch(`${API_BASE}/api/calls/recent/${myNumber}`);
    const data = await res.json();
    
    if (data.success && data.calls.length > 0) {
      recentsList.innerHTML = '';
      data.calls.forEach(call => {
        const isIncoming = call.receiver === myNumber;
        const isMissed = isIncoming && call.duration === 0;
        const partner = isIncoming ? call.caller : call.receiver;
        const time = formatCallTime(call.started_at);

        let iconName = 'phone-outgoing';
        let avatarClass = 'outgoing';
        if (isIncoming) {
          iconName = isMissed ? 'phone-missed' : 'phone-incoming';
          avatarClass = isMissed ? 'missed' : 'received';
        }

        const item = document.createElement('div');
        item.className = 'list-item';
        item.innerHTML = `
          <div class="item-avatar ${avatarClass}">
            <i data-lucide="${iconName}"></i>
          </div>
          <div class="item-details">
            <h4 class="item-partner-title">
              ${formatNumber(partner)}
              <i data-lucide="${call.type === 'video' ? 'video' : 'phone'}" class="icon-inline"></i>
            </h4>
            <p>${time} • ${call.duration > 0 ? call.duration + 's' : (isMissed ? 'Missed' : 'No Answer')}</p>
          </div>
          <div class="item-actions">
            <button class="btn-icon call-back" data-num="${partner}" data-type="${call.type}">
              <i data-lucide="${call.type === 'video' ? 'video' : 'phone'}"></i>
            </button>
          </div>
        `;
        recentsList.appendChild(item);
      });

      lucide.createIcons();

      // Bind callbacks
      document.querySelectorAll('.call-back').forEach(btn => {
        btn.onclick = () => {
          const num = btn.getAttribute('data-num');
          const type = btn.getAttribute('data-type');
          startCall(num, type);
        };
      });
    } else {
      recentsList.innerHTML = `
        <div class="empty-state">
          <p>No Recent Calls</p>
        </div>
      `;
    }
  } catch (_) {
    recentsList.innerHTML = '<div class="error-text">Failed to load calls</div>';
  }
}

function formatCallTime(dateStr) {
  const date = new Date(dateStr);
  const hrs = date.getHours().toString().padLeft(2, '0');
  const mins = date.getMinutes().toString().padLeft(2, '0');
  return `${date.toLocaleDateString()} ${hrs}:${mins}`;
}

// Local Favorites management
function loadFavorites() {
  const favList = document.getElementById('favorites-list');
  const favs = getFavoritesFromStorage();

  if (favs.length > 0) {
    favList.innerHTML = '';
    favs.forEach(async (num) => {
      // Check presence
      let onlineStatus = 'Offline';
      let dotColor = 'gray';
      try {
        const res = await fetch(`${API_BASE}/api/status/${num}`);
        const status = await res.json();
        if (status.success && status.online) {
          onlineStatus = 'Online';
          dotColor = 'green';
        }
      } catch (_) {}

      const item = document.createElement('div');
      item.className = 'list-item';
      item.innerHTML = `
        <div class="item-avatar">
          <i data-lucide="user"></i>
          <span class="status-dot ${dotColor}" style="position:absolute; bottom:0; right:0; width:12px; height:12px; border:2px solid white;"></span>
        </div>
        <div class="item-details">
          <h4>${formatNumber(num)}</h4>
          <p>${onlineStatus}</p>
        </div>
        <div class="item-actions">
          <button class="btn-icon call-fav-voice" data-num="${num}"><i data-lucide="phone"></i></button>
          <button class="btn-icon call-fav-video" data-num="${num}"><i data-lucide="video"></i></button>
          <button class="btn-icon remove-fav" data-num="${num}"><i data-lucide="star" style="fill: #EAB308; stroke: #EAB308;"></i></button>
        </div>
      `;
      favList.appendChild(item);

      // Event bindings
      item.querySelector('.call-fav-voice').onclick = () => startCall(num, 'voice');
      item.querySelector('.call-fav-video').onclick = () => startCall(num, 'video');
      item.querySelector('.remove-fav').onclick = () => {
        toggleFavorite(num);
        loadFavorites();
      };
    });

    setTimeout(() => {
      lucide.createIcons();
    }, 100);
  } else {
    favList.innerHTML = `
      <div class="empty-state">
        <p>No Favorites Yet</p>
      </div>
    `;
  }
}

function getFavoritesFromStorage() {
  const raw = localStorage.getItem('favorites');
  return raw ? JSON.parse(raw) : [];
}

function toggleFavorite(num) {
  let favs = getFavoritesFromStorage();
  if (favs.includes(num)) {
    favs = favs.filter(n => n !== num);
  } else {
    favs.push(num);
  }
  localStorage.setItem('favorites', JSON.stringify(favs));
}

// 8. Event Listeners Setup
function setupEventListeners() {
  // Splash retry click
  document.getElementById('screen-splash').onclick = () => {
    if (!document.getElementById('splash-error').classList.contains('hidden')) {
      document.getElementById('splash-error').classList.add('hidden');
      document.querySelector('.spinner').classList.remove('hidden');
      registerDevice();
    }
  };

  // Copy Buttons
  document.getElementById('btn-share-copy').onclick = () => {
    navigator.clipboard.writeText(myNumber);
    showToast('Number copied!');
  };

  document.getElementById('btn-share-link').onclick = () => {
    navigator.clipboard.writeText(`Hey! Call me on Beam: ${window.location.origin}/?dial=${myNumber}`);
    showToast('Call Link copied!');
  };

  // Dial Pad State & Input management
  let dialedNumber = '';
  const dialNumberEl = document.getElementById('dial-number');
  const dialErrorEl = document.getElementById('dial-error');

  function updateDialDisplay() {
    dialErrorEl.classList.add('hidden');
    if (dialedNumber.length === 0) {
      dialNumberEl.innerText = 'Enter number';
      dialNumberEl.className = 'dial-number-placeholder';
    } else {
      dialNumberEl.innerText = formatNumber(dialedNumber);
      dialNumberEl.className = '';
    }
  }

  // Bind Keypad Buttons
  document.querySelectorAll('.keypad-btn').forEach(btn => {
    btn.onclick = () => {
      if (btn.classList.contains('btn-backspace')) return;
      const val = btn.getAttribute('data-val');
      if (dialedNumber.length < 6) {
        dialedNumber += val;
        updateDialDisplay();
      }
    };
  });

  // Bind Backspace Button
  document.getElementById('btn-backspace').onclick = () => {
    if (dialedNumber.length > 0) {
      dialedNumber = dialedNumber.slice(0, -1);
      updateDialDisplay();
    }
  };

  // Call Initiations
  document.getElementById('btn-voice-call').onclick = () => {
    startCall(dialedNumber, 'voice');
  };

  document.getElementById('btn-video-call').onclick = () => {
    startCall(dialedNumber, 'video');
  };

  // Answer & Decline
  document.getElementById('btn-accept').onclick = acceptCall;
  document.getElementById('btn-decline').onclick = declineCall;
  document.getElementById('btn-hangup').onclick = hangupCall;

  // Tab switcher
  document.querySelectorAll('.nav-item').forEach(item => {
    item.onclick = () => {
      document.querySelectorAll('.nav-item').forEach(i => i.classList.remove('active'));
      document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
      
      item.classList.add('active');
      const tabId = item.getAttribute('data-tab');
      document.getElementById(`tab-${tabId}`).classList.add('active');

      // Set headers
      const titles = {
        dialer: 'Beam',
        recents: 'Recent Calls',
        favorites: 'Favorites',
        share: 'Share Number'
      };
      document.getElementById('header-title').innerText = titles[tabId];
      setTimeout(() => {
        lucide.createIcons();
      }, 50);

      if (tabId === 'recents') loadRecents();
      if (tabId === 'favorites') loadFavorites();
    };
  });

  // In-call toggles
  document.getElementById('btn-mute').onclick = () => {
    const btn = document.getElementById('btn-mute');
    const audioTrack = localStream.getAudioTracks()[0];
    if (audioTrack) {
      audioTrack.enabled = !audioTrack.enabled;
      btn.classList.toggle('active');
      btn.innerText = audioTrack.enabled ? 'Mute' : 'Unmute';
    }
  };

  document.getElementById('btn-camera').onclick = () => {
    const btn = document.getElementById('btn-camera');
    const videoTrack = localStream.getVideoTracks()[0];
    if (videoTrack) {
      videoTrack.enabled = !videoTrack.enabled;
      btn.classList.toggle('active');
      btn.innerText = videoTrack.enabled ? 'Cam Off' : 'Cam On';
      document.getElementById('local-video').style.opacity = videoTrack.enabled ? '1' : '0';
    }
  };

  // Favorites add dialog trigger
  const modal = document.getElementById('favorite-modal');
  document.getElementById('btn-add-favorite').onclick = () => {
    document.getElementById('favorite-input').value = '';
    document.getElementById('favorite-error').classList.add('hidden');
    modal.classList.remove('hidden');
  };

  document.getElementById('btn-flat');
  document.getElementById('btn-modal-cancel').onclick = () => {
    modal.classList.add('hidden');
  };

  document.getElementById('btn-modal-add').onclick = async () => {
    const val = document.getElementById('favorite-input').value.trim();
    const errorEl = document.getElementById('favorite-error');

    if (val.length !== 6 || !/^\d{6}$/.test(val)) {
      errorEl.innerText = 'Enter a valid 6-digit number';
      errorEl.classList.remove('hidden');
      return;
    }
    if (val === myNumber) {
      errorEl.innerText = 'Cannot add yourself';
      errorEl.classList.remove('hidden');
      return;
    }

    // Verify if user exists on backend
    try {
      const res = await fetch(`${API_BASE}/api/status/${val}`);
      if (res.status === 404) {
        errorEl.innerText = 'Number not found';
        errorEl.classList.remove('hidden');
        return;
      }
      
      toggleFavorite(val);
      modal.classList.add('hidden');
      loadFavorites();
    } catch (_) {
      errorEl.innerText = 'Server unavailable';
      errorEl.classList.remove('hidden');
    }
  };

  // Support direct dial links in url params (?dial=381942)
  const urlParams = new URLSearchParams(window.location.search);
  const directDial = urlParams.get('dial');
  if (directDial && /^\d{6}$/.test(directDial)) {
    dialedNumber = directDial;
    updateDialDisplay();
  }
}
