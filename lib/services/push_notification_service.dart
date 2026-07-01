import 'package:flutter/foundation.dart';
import '../data/remote/api_service.dart';

/// Handles requesting notification permissions and registering push tokens.
/// To transition to production, configure Firebase in your Flutter app by:
/// 1. Running `flutterfire configure`
/// 2. Adding `firebase_core` and `firebase_messaging` packages
/// 3. Initializing Firebase: `await Firebase.initializeApp();`
class PushNotificationService {
  final ApiService _apiService;

  PushNotificationService(this._apiService);

  /// Initialize permissions and register token with backend.
  Future<void> init(String number) async {
    try {
      // 1. Request local permission (simulated/permission_handler used in settings)
      debugPrint('🔔 Requesting push notification permissions...');

      // 2. Retrieve FCM registration token (using a stable mock token for development)
      // When Firebase is configured:
      // final fcmToken = await FirebaseMessaging.instance.getToken();
      final fcmToken = 'mock-fcm-token-for-$number';

      debugPrint('🔔 Push token generated: $fcmToken');

      // 3. Register token with backend
      await _apiService.registerPushToken(number, fcmToken);
      debugPrint('🔔 Push token successfully registered on server');
    } catch (e) {
      debugPrint('⚠️ Push notification setup failed (expected if Firebase is not configured): $e');
    }
  }
}
