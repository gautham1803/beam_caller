import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../utils/constants.dart';

/// HTTP client for backend REST API.
class ApiService {
  final String baseUrl;
  final http.Client _client;

  ApiService({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? AppConstants.serverUrl,
        _client = client ?? http.Client();

  /// Register device and get assigned number.
  Future<Map<String, dynamic>> register(String deviceId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'device_id': deviceId}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw ApiException('Registration failed: ${response.body}');
  }

  /// Send heartbeat.
  Future<void> sendHeartbeat(String number) async {
    try {
      await _client.post(
        Uri.parse('$baseUrl/api/heartbeat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'number': number}),
      );
    } catch (_) {
      // Heartbeat failures are non-critical
    }
  }

  /// Get user status.
  Future<Map<String, dynamic>> getStatus(String number) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/status/$number'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    if (response.statusCode == 404) {
      throw ApiException('Number not found');
    }

    throw ApiException('Failed to get status: ${response.body}');
  }

  /// Record call start.
  Future<Map<String, dynamic>> startCall(
    String caller,
    String receiver,
    String type,
  ) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/call/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'caller': caller,
        'receiver': receiver,
        'type': type,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw ApiException('Call failed: ${response.body}');
  }

  /// Record call end.
  Future<void> endCall(int callId, int duration) async {
    try {
      await _client.post(
        Uri.parse('$baseUrl/api/call/end'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'call_id': callId,
          'duration': duration,
        }),
      );
    } catch (_) {
      // Non-critical
    }
  }

  /// Register FCM push token for push notifications.
  Future<void> registerPushToken(String number, String pushToken) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/register-push'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'number': number,
        'push_token': pushToken,
      }),
    );

    if (response.statusCode != 200) {
      throw ApiException('Push token registration failed: ${response.body}');
    }
  }

  /// Fetch recent calls from server.
  Future<List<dynamic>> getRecentCalls(String number) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/calls/recent/$number'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['calls'] as List<dynamic>;
    }

    throw ApiException('Failed to fetch recent calls: ${response.body}');
  }

  void dispose() {
    _client.close();
  }
}

/// API exception.
class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
