import 'package:flutter/material.dart';
import '../../utils/theme.dart';

/// Status indicator showing online/offline state.
class StatusIndicator extends StatelessWidget {
  final bool isOnline;
  final String? lastSeenText;

  const StatusIndicator({
    super.key,
    required this.isOnline,
    this.lastSeenText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isOnline
            ? AppTheme.lightGreen
            : AppTheme.lightGray,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isOnline ? AppTheme.activeGreen : AppTheme.offlineGray,
              shape: BoxShape.circle,
              boxShadow: isOnline
                  ? [
                      BoxShadow(
                        color: AppTheme.activeGreen.withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isOnline
                ? 'Active'
                : (lastSeenText ?? 'Offline'),
            style: TextStyle(
              color: isOnline ? AppTheme.activeGreen : AppTheme.offlineGray,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
