import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/recent_call.dart';
import '../../utils/theme.dart';
import '../providers/call_provider.dart';
import '../providers/recents_provider.dart';
import '../providers/user_provider.dart';
import '../providers/favorites_provider.dart';

class RecentsView extends ConsumerStatefulWidget {
  const RecentsView({super.key});

  @override
  ConsumerState<RecentsView> createState() => _RecentsViewState();
}

class _RecentsViewState extends ConsumerState<RecentsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recentsProvider.notifier).fetchRecents();
    });
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(dt.year, dt.month, dt.day);

    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    if (dateToCheck == today) {
      return 'Today, $timeStr';
    } else if (dateToCheck == yesterday) {
      return 'Yesterday, $timeStr';
    } else {
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} $timeStr';
    }
  }

  String _formatNumber(String number) {
    if (number.length == 6) {
      return '${number.substring(0, 3)} ${number.substring(3)}';
    }
    return number;
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final recentsState = ref.watch(recentsProvider);
    final myNumber = ref.read(userProvider).user?.number ?? '';
    final favorites = ref.watch(favoritesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (recentsState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppTheme.endCallRed,
              size: 44,
            ),
            const SizedBox(height: 16),
            Text(
              recentsState.error!,
              style: const TextStyle(
                color: AppTheme.endCallRed,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(recentsProvider.notifier).fetchRecents(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (recentsState.isLoading && recentsState.calls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppTheme.primaryBlue.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading calls...',
              style: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (recentsState.calls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [AppTheme.surfaceBlue, AppTheme.lightBlue.withValues(alpha: 0.3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.call_missed_outgoing_rounded,
                size: 44,
                color: AppTheme.primaryBlue.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Recent Calls',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Calls you make or receive will appear here',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(recentsProvider.notifier).fetchRecents(),
      color: AppTheme.primaryBlue,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: recentsState.calls.length,
        itemBuilder: (context, index) {
          final call = recentsState.calls[index];
          final isIncoming = call.isIncoming(myNumber);
          final isMissed = call.isMissed(myNumber);
          final displayNum = isIncoming ? call.caller : call.receiver;
          final isFavorite = favorites.contains(displayNum);

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    // Could navigate to call detail
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Call type icon
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isMissed
                                  ? [const Color(0xFFFFCDD2), const Color(0xFFFFEBEE)]
                                  : (isIncoming
                                      ? [const Color(0xFFC8E6C9), const Color(0xFFE8F5E9)]
                                      : [const Color(0xFFBBDEFB), const Color(0xFFE3F2FD)]),
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isMissed
                                ? Icons.call_missed_rounded
                                : (isIncoming
                                    ? Icons.call_received_rounded
                                    : Icons.call_made_rounded),
                            color: isMissed
                                ? AppTheme.endCallRed
                                : (isIncoming ? AppTheme.activeGreen : AppTheme.primaryBlue),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Number and time info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _formatNumber(displayNum),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: isMissed
                                          ? AppTheme.endCallRed
                                          : (isDark ? Colors.white : AppTheme.textPrimary),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  if (call.type == 'video') ...[
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.videocam_rounded,
                                      size: 14,
                                      color: AppTheme.textSecondary.withValues(alpha: 0.5),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 12,
                                    color: AppTheme.textSecondary.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDateTime(call.startedAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  if (call.duration > 0) ...[
                                    Text(
                                      '  •  ${_formatDuration(call.duration)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ] else ...[
                                    Text(
                                      isMissed ? '  •  Missed' : '  •  No Answer',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isMissed
                                            ? AppTheme.endCallRed.withValues(alpha: 0.7)
                                            : AppTheme.textSecondary.withValues(alpha: 0.7),
                                        fontWeight: isMissed ? FontWeight.w500 : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Action buttons
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _MiniActionButton(
                              icon: isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                              color: isFavorite ? Colors.amber : AppTheme.offlineGray,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                ref.read(favoritesProvider.notifier).toggleFavorite(displayNum);
                              },
                            ),
                            const SizedBox(width: 4),
                            _MiniActionButton(
                              icon: call.type == 'video'
                                  ? Icons.videocam_rounded
                                  : Icons.call_rounded,
                              color: AppTheme.primaryBlue,
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                if (call.type == 'video') {
                                  ref.read(callProvider.notifier).makeVideoCall(displayNum, myNumber);
                                } else {
                                  ref.read(callProvider.notifier).makeVoiceCall(displayNum, myNumber);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MiniActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}
