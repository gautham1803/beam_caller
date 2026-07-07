import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/remote/socket_service.dart';
import '../../services/foreground_service.dart';
import 'user_provider.dart';

/// Provider for Socket.IO connection management.
class SocketNotifier extends StateNotifier<bool> {
  final SocketService _socketService;
  Timer? _heartbeatTimer;

  SocketNotifier(this._socketService) : super(false);

  SocketService get socket => _socketService;

  /// Connect to the signaling server.
  void connect(String userNumber) {
    _socketService.connect(userNumber);

    _socketService.connectionStream.listen((connected) {
      state = connected;
      if (connected) {
        _startHeartbeat(userNumber);
        // Start foreground service to keep socket alive in background
        ForegroundServiceHelper.start();
      } else {
        _stopHeartbeat();
      }
    });
  }

  void _startHeartbeat(String number) {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) {
        _socketService.sendHeartbeat();
      },
    );
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Disconnect.
  void disconnect() {
    _stopHeartbeat();
    _socketService.disconnect();
    ForegroundServiceHelper.stop();
    state = false;
  }

  @override
  void dispose() {
    _stopHeartbeat();
    _socketService.dispose();
    super.dispose();
  }
}

final socketServiceProvider = Provider((ref) => SocketService());

final socketProvider = StateNotifierProvider<SocketNotifier, bool>((ref) {
  return SocketNotifier(ref.read(socketServiceProvider));
});

