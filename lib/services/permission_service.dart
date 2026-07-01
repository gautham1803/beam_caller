import 'package:permission_handler/permission_handler.dart';

/// Service for requesting and checking runtime permissions.
class PermissionService {
  /// Request microphone permission.
  Future<bool> requestMicrophone() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Request camera permission.
  Future<bool> requestCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request bluetooth permission (for bluetooth headsets).
  Future<bool> requestBluetooth() async {
    final status = await Permission.bluetoothConnect.request();
    return status.isGranted;
  }

  /// Request notification permission.
  Future<bool> requestNotification() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Request all call-related permissions.
  Future<Map<Permission, bool>> requestCallPermissions({
    bool includeCamera = false,
  }) async {
    final permissions = <Permission>[
      Permission.microphone,
      if (includeCamera) Permission.camera,
      Permission.bluetoothConnect,
    ];

    final statuses = await permissions.request();

    return statuses.map(
      (permission, status) => MapEntry(permission, status.isGranted),
    );
  }

  /// Check if microphone permission is granted.
  Future<bool> hasMicrophone() async {
    return await Permission.microphone.isGranted;
  }

  /// Check if camera permission is granted.
  Future<bool> hasCamera() async {
    return await Permission.camera.isGranted;
  }

  /// Check if all required call permissions are granted.
  Future<bool> hasCallPermissions({bool includeCamera = false}) async {
    final micGranted = await Permission.microphone.isGranted;
    if (!micGranted) return false;

    if (includeCamera) {
      final camGranted = await Permission.camera.isGranted;
      if (!camGranted) return false;
    }

    return true;
  }
}
