/// App-wide constants.
class AppConstants {
  AppConstants._();

  /// Backend server URL.
  /// For Android emulator: use 10.0.2.2 to reach host machine.
  /// For physical device: use your machine's local IP.
  static const String serverUrl = 'https://beam-server-vb9q.onrender.com';

  /// WebSocket server URL.
  static const String wsUrl = 'https://beam-server-vb9q.onrender.com';

  /// STUN servers for WebRTC ICE.
  static const Map<String, dynamic> iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  /// Heartbeat interval in seconds.
  static const int heartbeatIntervalSeconds = 15;

  /// Number length.
  static const int numberLength = 6;

  /// Storage keys.
  static const String storageKeyDeviceId = 'device_id';
  static const String storageKeyNumber = 'assigned_number';
}
