import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Top-level callback for starting the foreground task handler.
/// Must be a top-level or static function.
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(BeamTaskHandler());
}

/// Foreground task handler that keeps the app alive in the background.
/// The socket connection runs in the main isolate; this handler simply
/// keeps the Android process alive via a persistent notification.
class BeamTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Nothing to do here — the socket is managed in the main isolate.
    // The foreground service simply keeps the process alive.
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Heartbeat — keeps the service alive. No action needed.
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // Cleanup if needed
  }
}

/// Helper class to initialize and control the foreground service.
class ForegroundServiceHelper {
  static bool _isRunning = false;

  /// Initialize the foreground task configuration.
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'beam_foreground_service',
        channelName: 'Beam Call Service',
        channelDescription: 'Keeps Beam active to receive incoming calls',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: null, // Uses app icon by default
        isSticky: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Start the foreground service to keep the app alive.
  static Future<void> start() async {
    if (_isRunning) return;

    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) {
      _isRunning = true;
      return;
    }

    await FlutterForegroundTask.startService(
      notificationTitle: 'Beam is active',
      notificationText: 'Ready to receive calls',
      callback: startCallback,
    );
    _isRunning = true;
  }

  /// Stop the foreground service.
  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
    _isRunning = false;
  }

  /// Whether the foreground service is currently running.
  static bool get isRunning => _isRunning;
}
