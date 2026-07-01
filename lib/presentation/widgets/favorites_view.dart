import 'package:flutter/material.dart';
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
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Add Favorite',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter the 6-digit number to add to your favorites list.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 6,
                    ),
                    decoration: InputDecoration(
                      hintText: '000000',
                      counterText: '',
                      errorText: error,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
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

                    // Verify if number exists on server
                    setDialogState(() {
                      error = null;
                    });

                    try {
                      final api = ref.read(apiServiceProvider);
                      await api.getStatus(val); // will throw 404 if not found
                      
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

    ref.listen(favoritesProvider, (_, __) => _checkPresence());

    if (list.isEmpty) {
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
                Icons.star_outline_rounded,
                size: 40,
                color: AppTheme.offlineGray,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Favorites Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add people you call frequently for quick dialing',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddFavoriteDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Favorite'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${list.length} Favorites',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryBlue),
                onPressed: _showAddFavoriteDialog,
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _checkPresence,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                color: AppTheme.lightGray,
                indent: 72,
              ),
              itemBuilder: (context, index) {
                final num = list[index];
                final isOnline = _presenceMap[num] ?? false;

                return ListTile(
                  leading: Stack(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: AppTheme.lightBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: AppTheme.primaryBlue,
                          size: 24,
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
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    _formatNumber(num),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  subtitle: Text(
                    isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 13,
                      color: isOnline ? AppTheme.activeGreen : AppTheme.textSecondary,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.videocam_rounded, color: AppTheme.primaryBlue),
                        onPressed: () {
                          ref.read(callProvider.notifier).makeVideoCall(num, myNumber);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.call_rounded, color: AppTheme.primaryBlue),
                        onPressed: () {
                          ref.read(callProvider.notifier).makeVoiceCall(num, myNumber);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.star_rounded, color: Colors.amber),
                        onPressed: () {
                          ref.read(favoritesProvider.notifier).toggleFavorite(num);
                        },
                      ),
                    ],
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
