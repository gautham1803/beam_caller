import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final recentsState = ref.watch(recentsProvider);
    final myNumber = ref.read(userProvider).user?.number ?? '';
    final favorites = ref.watch(favoritesProvider);

    if (recentsState.isLoading && recentsState.calls.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (recentsState.calls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.lightGray,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.call_missed_outgoing_rounded,
                size: 40,
                color: AppTheme.offlineGray,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Recent Calls',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Calls you make or receive will appear here',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(recentsProvider.notifier).fetchRecents(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: recentsState.calls.length,
        separatorBuilder: (context, index) => const Divider(
          height: 1,
          color: AppTheme.lightGray,
          indent: 72,
        ),
        itemBuilder: (context, index) {
          final call = recentsState.calls[index];
          final isIncoming = call.isIncoming(myNumber);
          final isMissed = call.isMissed(myNumber);
          final displayNum = isIncoming ? call.caller : call.receiver;
          final isFavorite = favorites.contains(displayNum);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isMissed
                      ? AppTheme.lightRed
                      : (isIncoming ? AppTheme.lightGreen : AppTheme.lightBlue),
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
              title: Row(
                children: [
                  Text(
                    _formatNumber(displayNum),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isMissed ? AppTheme.endCallRed : AppTheme.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (call.type == 'video')
                    const Icon(
                      Icons.videocam_rounded,
                      size: 16,
                      color: AppTheme.offlineGray,
                    ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${_formatDateTime(call.startedAt)} • ${call.duration > 0 ? "${call.duration}s" : (isMissed ? "Missed" : "No Answer")}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                      color: isFavorite ? Colors.amber : AppTheme.offlineGray,
                    ),
                    onPressed: () {
                      ref.read(favoritesProvider.notifier).toggleFavorite(displayNum);
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      call.type == 'video'
                          ? Icons.videocam_rounded
                          : Icons.call_rounded,
                      color: AppTheme.primaryBlue,
                    ),
                    onPressed: () {
                      if (call.type == 'video') {
                        ref.read(callProvider.notifier).makeVideoCall(displayNum, myNumber);
                      } else {
                        ref.read(callProvider.notifier).makeVoiceCall(displayNum, myNumber);
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
