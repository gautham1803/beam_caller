import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../utils/theme.dart';
import '../providers/settings_provider.dart';
import '../providers/user_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _micPermission = false;
  bool _camPermission = false;
  bool _notifPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final mic = await Permission.microphone.status.isGranted;
    final cam = await Permission.camera.status.isGranted;
    final notif = await Permission.notification.status.isGranted;

    if (mounted) {
      setState(() {
        _micPermission = mic;
        _camPermission = cam;
        _notifPermission = notif;
      });
    }
  }

  Future<void> _requestPermission(Permission permission) async {
    final status = await permission.request();
    HapticFeedback.mediumImpact();
    if (status.isPermanentlyDenied) {
      openAppSettings();
    }
    _checkPermissions();
  }

  String _formatNumber(String number) {
    if (number.length == 6) {
      return '${number.substring(0, 3)} ${number.substring(3)}';
    }
    return number;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final userState = ref.watch(userProvider);
    final myNumber = userState.user?.number ?? '------';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User profile/number section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [AppTheme.surfaceBlue, AppTheme.lightBlue.withValues(alpha: 0.3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _formatNumber(myNumber),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your Assigned Beam Number',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Section Header
            _buildSectionHeader('Preferences'),
            const SizedBox(height: 12),

            // Theme switch
            _buildSettingCard([
              SwitchListTile(
                title: const Text('Dark Theme', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Switch between dark and light modes'),
                secondary: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: isDark ? Colors.amber : Colors.blueGrey,
                ),
                value: settings.themeMode == ThemeMode.dark,
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  ref.read(settingsProvider.notifier).setThemeMode(
                        val ? ThemeMode.dark : ThemeMode.light,
                      );
                },
              ),
              const Divider(height: 1, indent: 56),
              // Call alerts switch
              SwitchListTile(
                title: const Text('Enable Call Alerts', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Receive sound ringtones for calls'),
                secondary: const Icon(Icons.notifications_active_rounded, color: AppTheme.primaryBlue),
                value: settings.notificationsEnabled,
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  ref.read(settingsProvider.notifier).setNotificationsEnabled(val);
                },
              ),
            ]),
            const SizedBox(height: 32),

            // Section Header
            _buildSectionHeader('Permissions'),
            const SizedBox(height: 12),

            // Permissions list card
            _buildSettingCard([
              _buildPermissionTile(
                title: 'Microphone Access',
                subtitle: 'Required to speak during calls',
                icon: Icons.mic_rounded,
                isGranted: _micPermission,
                onRequest: () => _requestPermission(Permission.microphone),
              ),
              const Divider(height: 1, indent: 56),
              _buildPermissionTile(
                title: 'Camera Access',
                subtitle: 'Required for video calling capability',
                icon: Icons.videocam_rounded,
                isGranted: _camPermission,
                onRequest: () => _requestPermission(Permission.camera),
              ),
              const Divider(height: 1, indent: 56),
              _buildPermissionTile(
                title: 'Notifications Access',
                subtitle: 'Required to receive incoming call alerts',
                icon: Icons.notifications_rounded,
                isGranted: _notifPermission,
                onRequest: () => _requestPermission(Permission.notification),
              ),
            ]),
            const SizedBox(height: 32),

            // Section Header
            _buildSectionHeader('Application'),
            const SizedBox(height: 12),

            // Reset/deregister section
            _buildSettingCard([
              ListTile(
                leading: const Icon(Icons.refresh_rounded, color: AppTheme.endCallRed),
                title: const Text(
                  'Deregister & Reset',
                  style: TextStyle(color: AppTheme.endCallRed, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Deletes your current number and requests a new one'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  HapticFeedback.heavyImpact();
                  _showResetConfirmation();
                },
              ),
            ]),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryBlue,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildSettingCard(List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.02),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildPermissionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isGranted,
    required VoidCallback onRequest,
  }) {
    return ListTile(
      leading: Icon(icon, color: isGranted ? AppTheme.activeGreen : AppTheme.offlineGray),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: isGranted
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.activeGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Granted',
                style: TextStyle(
                  color: AppTheme.activeGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onRequest,
              child: const Text('Allow', style: TextStyle(fontSize: 12)),
            ),
    );
  }

  void _showResetConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Reset Application?', style: TextStyle(fontWeight: FontWeight.w700)),
          content: const Text(
            'This will delete your 6-digit number and clear your settings. '
            'You will need to request a new number when you open the app again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.endCallRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                // Clear state and restart
                await ref.read(userProvider.notifier).resetApp();
                SystemNavigator.pop(); // Close app
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }
}
