import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/theme.dart';
import '../providers/call_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/user_provider.dart';
import '../providers/user_provider.dart' show apiServiceProvider;

class FavoritesView extends ConsumerStatefulWidget {
  const FavoritesView({super.key});

  @override
  ConsumerState<FavoritesView> createState() => _FavoritesViewState();
}

class _FavoritesViewState extends ConsumerState<FavoritesView> {
  final Map<String, bool> _presenceMap = {};
  bool _loadingPresence = false;

  @override
  void initState() {
    super.initState();
    _checkPresence();
  }

  Future<void> _checkPresence() async {
    final list = ref.read(favoritesProvider);
    if (list.isEmpty) return;

    if (mounted) {
      setState(() => _loadingPresence = true);
    }

    final api = ref.read(apiServiceProvider);
    for (final num in list) {
      try {
        final status = await api.getStatus(num);
        if (mounted) {
          setState(() {
            _presenceMap[num] = status['online'] as bool? ?? false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _presenceMap[num] = false;
          });
        }
      }
    }

    if (mounted) {
      setState(() => _loadingPresence = false);
    }
  }

  String _formatNumber(String number) {
    if (number.length == 6) {
      return '${number.substring(0, 3)} ${number.substring(3)}';
    }
    return number;
  }

  void _showAddFavoriteDialog() {
    final controller = TextEditingController();
    String? error;

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: AppTheme.primaryBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Add Favorite',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Enter the 6-digit number to add to your favorites.',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 8,
                    ),
                    decoration: InputDecoration(
                      hintText: '000000',
                      counterText: '',
                      errorText: error,
                      hintStyle: TextStyle(
                        letterSpacing: 8,
                        color: isDark ? Colors.white24 : AppTheme.offlineGray.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : AppTheme.textSecondary,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final val = controller.text.trim();
                    final myNum = ref.read(userProvider).user?.number ?? '';

                    if (val.length != 6 || !RegExp(r'^\d{6}$').hasMatch(val)) {
                      setDialogState(() => error = 'Enter a valid 6-digit number');
                      return;
                    }

                    if (val == myNum) {
                      setDialogState(() => error = 'Cannot add yourself');
                      return;
                    }

                    setDialogState(() {
                      error = null;
                    });

                    try {
                      final api = ref.read(apiServiceProvider);
                      await api.getStatus(val);
                      
                      ref.read(favoritesProvider.notifier).toggleFavorite(val);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                      _checkPresence();
                    } catch (e) {
                      setDialogState(() {
                        error = 'Number not found';
                      });
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(favoritesProvider);
    final myNumber = ref.read(userProvider).user?.number ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen(favoritesProvider, (_, __) => _checkPresence());

    if (list.isEmpty) {
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
                      : [const Color(0xFFFFF8E1), const Color(0xFFFFF3E0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.star_rounded,
                size: 44,
                color: Colors.amber.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Favorites Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add people you call often for quick dialing',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : AppTheme.textSecondary.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _showAddFavoriteDialog,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Add Favorite'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 12, top: 4, bottom: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.amber.withValues(alpha: 0.1)
                      : Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${list.length} Favorite${list.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark ? Colors.amber.shade200 : Colors.amber.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_rounded, color: AppTheme.primaryBlue, size: 20),
                ),
                onPressed: _showAddFavoriteDialog,
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _checkPresence,
            color: AppTheme.primaryBlue,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final num = list[index];
                final isOnline = _presenceMap[num] ?? false;

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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          // Avatar with online indicator
                          Stack(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.primaryBlue.withValues(alpha: 0.15),
                                      AppTheme.primaryBlue.withValues(alpha: 0.05),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    num.substring(0, 2),
                                    style: const TextStyle(
                                      color: AppTheme.primaryBlue,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: isOnline ? AppTheme.activeGreen : AppTheme.offlineGray,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      width: 2.5,
                                    ),
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
                              ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          // Number and status
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatNumber(num),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : AppTheme.textPrimary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isOnline ? AppTheme.activeGreen : AppTheme.offlineGray,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isOnline ? 'Online' : 'Offline',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isOnline ? FontWeight.w500 : FontWeight.normal,
                                        color: isOnline
                                            ? AppTheme.activeGreen
                                            : (isDark ? Colors.white38 : AppTheme.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Action buttons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _FavActionButton(
                                icon: Icons.videocam_rounded,
                                color: AppTheme.primaryBlue,
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  ref.read(callProvider.notifier).makeVideoCall(num, myNumber);
                                },
                              ),
                              const SizedBox(width: 4),
                              _FavActionButton(
                                icon: Icons.call_rounded,
                                color: AppTheme.activeGreen,
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  ref.read(callProvider.notifier).makeVoiceCall(num, myNumber);
                                },
                              ),
                              const SizedBox(width: 4),
                              _FavActionButton(
                                icon: Icons.star_rounded,
                                color: Colors.amber,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  ref.read(favoritesProvider.notifier).toggleFavorite(num);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _FavActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FavActionButton({
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
