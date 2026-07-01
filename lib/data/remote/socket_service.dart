import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../utils/constants.dart';

/// Callback types for socket events.
typedef SocketEventCallback = void Function(Map<String, dynamic> data);

/// Socket.IO client wrapper for WebSocket signaling.
class SocketService {
  io.Socket? _socket;
  bool _isConnected = false;
  String? _userNumber;

  final Map<String, List<SocketEventCallback>> _eventListeners = {};
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  /// Stream of connection status changes.
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Whether the socket is currently connected.
  bool get isConnected => _isConnected;

  /// Connect to the signaling server.
  void connect(String userNumber) {
    _userNumber = userNumber;

    _socket = io.io(
      AppConstants.wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('🔌 Socket connected');
      _isConnected = true;
      _connectionController.add(true);

      // Register with server
      _socket!.emit('register', {'number': _userNumber});
    });

    _socket!.onConnectError((data) {
      debugPrint('🔌 Socket connection error: $data');
    });

    _socket!.onConnectTimeout((data) {
      debugPrint('🔌 Socket connection timeout: $data');
    });

    _socket!.onDisconnect((_) {
      debugPrint('🔌 Socket disconnected');
      _isConnected = false;
      _connectionController.add(false);
    });

    _socket!.onReconnect((_) {
      debugPrint('🔌 Socket reconnected');
      _isConnected = true;
      _connectionController.add(true);

      // Re-register after reconnection
      _socket!.emit('register', {'number': _userNumber});
    });

    _socket!.onError((error) {
      debugPrint('🔌 Socket error: $error');
    });

    // Set up event forwarding
    _setupEventListeners();

    _socket!.connect();
  }

  void _setupEventListeners() {
    final events = [
      'registered',
      'call:incoming',
      'call:ringing',
      'call:accepted',
      'call:rejected',
      'call:busy',
      'call:cancelled',
      'call:ended',
      'call:sdp-offer',
      'call:sdp-answer',
      'call:ice-candidate',
      'call:error',
      'error',
    ];

    for (final event in events) {
      _socket!.on(event, (data) {
        final mapped = data is Map<String, dynamic>
            ? data
            : (data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{});
        _notifyListeners(event, mapped);
      });
    }
  }

  /// Register a listener for a specific event.
  void on(String event, SocketEventCallback callback) {
    _eventListeners.putIfAbsent(event, () => []);
    _eventListeners[event]!.add(callback);
  }

  /// Remove a listener for a specific event.
  void off(String event, [SocketEventCallback? callback]) {
    if (callback != null) {
      _eventListeners[event]?.remove(callback);
    } else {
      _eventListeners.remove(event);
    }
  }

  void _notifyListeners(String event, Map<String, dynamic> data) {
    final listeners = _eventListeners[event];
    if (listeners != null) {
      for (final listener in listeners) {
        listener(data);
      }
    }
  }

  /// Emit an event to the server.
  void emit(String event, [dynamic data]) {
    if (_socket != null && _isConnected) {
      _socket!.emit(event, data);
    } else {
      debugPrint('⚠️ Socket not connected, cannot emit $event');
    }
  }

  /// Send heartbeat.
  void sendHeartbeat() {
    emit('heartbeat', {'number': _userNumber});
  }

  /// Initiate a call.
  void startCall(String targetNumber, String callerNumber, String callType) {
    emit('call:start', {
      'targetNumber': targetNumber,
      'callerNumber': callerNumber,
      'callType': callType,
    });
  }

  /// Accept incoming call.
  void acceptCall(String callerNumber) {
    emit('call:accept', {'callerNumber': callerNumber});
  }

  /// Reject incoming call.
  void rejectCall(String callerNumber) {
    emit('call:reject', {'callerNumber': callerNumber});
  }

  /// Cancel outgoing call.
  void cancelCall() {
    emit('call:cancel', {});
  }

  /// End active call.
  void endCall() {
    emit('call:end', {});
  }

  /// Send SDP offer.
  void sendSdpOffer(Map<String, dynamic> sdp) {
    emit('call:sdp-offer', {'sdp': sdp});
  }

  /// Send SDP answer.
  void sendSdpAnswer(Map<String, dynamic> sdp) {
    emit('call:sdp-answer', {'sdp': sdp});
  }

  /// Send ICE candidate.
  void sendIceCandidate(Map<String, dynamic> candidate) {
    emit('call:ice-candidate', {'candidate': candidate});
  }

  /// Disconnect and clean up.
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _eventListeners.clear();
    _connectionController.close();
  }

  void dispose() {
    disconnect();
  }
}
