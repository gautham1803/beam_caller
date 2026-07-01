import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/call_state.dart';
import '../../utils/theme.dart';
import '../providers/user_provider.dart';
import '../providers/socket_provider.dart';
import '../providers/call_provider.dart';
import '../providers/recents_provider.dart';
import '../../services/push_notification_service.dart';
import '../widgets/number_card.dart';
import '../widgets/status_indicator.dart';
import '../widgets/dial_pad.dart';
import '../widgets/recents_view.dart';
import '../widgets/favorites_view.dart';
import '../widgets/share_view.dart';
import 'incoming_call_screen.dart';
import 'voice_call_screen.dart';
import 'video_call_screen.dart';

/// Main home screen with bottom navigation (Dialer, Recents, Favorites, Share).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Connect socket and register push token after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectSocket();
    });
  }

  void _connectSocket() {
    final userState = ref.read(userProvider);
    if (userState.user != null) {
      ref.read(socketProvider.notifier).connect(userState.user!.number);
      // Initialize simulated push notification token registration
      PushNotificationService(ref.read(apiServiceProvider)).init(userState.user!.number);
    }
  }

  void _navigateToCallScreen(CallType type) {
    final callState = ref.read(callProvider);

    Widget screen;
    if (callState.status == CallStatus.ringing) {
      screen = const IncomingCallScreen();
    } else if (type == CallType.video) {
      screen = const VideoCallScreen();
    } else {
      screen = const VoiceCallScreen();
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Widget _buildDialerView(UserState userState, bool isSocketConnected) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          NumberCard(number: userState.user!.number),
          const SizedBox(height: 16),
          StatusIndicator(
            isOnline: isSocketConnected,
            lastSeenText: isSocketConnected ? null : 'Connecting...',
          ),
          const SizedBox(height: 40),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Make a Call',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(height: 16),
          DialPad(
            myNumber: userState.user!.number,
            onVoiceCall: (number) {
              ref.read(callProvider.notifier).makeVoiceCall(
                    number,
                    userState.user!.number,
                  );
            },
            onVideoCall: (number) {
              ref.read(callProvider.notifier).makeVideoCall(
                    number,
                    userState.user!.number,
                  );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBody(UserState userState, bool isSocketConnected) {
    if (userState.user == null) {
      if (userState.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Text(
          userState.error ?? 'Registration failed',
          style: const TextStyle(color: AppTheme.endCallRed),
        ),
      );
    }

    switch (_currentIndex) {
      case 0:
        return _buildDialerView(userState, isSocketConnected);
      case 1:
        return const RecentsView();
      case 2:
        return const FavoritesView();
      case 3:
        return ShareView(number: userState.user!.number);
      default:
        return const SizedBox.shrink();
    }
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Beam';
      case 1:
        return 'Recent Calls';
      case 2:
        return 'Favorites';
      case 3:
        return 'Share Number';
      default:
        return 'Beam';
    }
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final isSocketConnected = ref.watch(socketProvider);
    final callState = ref.watch(callProvider);

    // React to call state changes
    ref.listen(callProvider, (previous, next) {
      if (previous?.status != next.status) {
        if (next.status == CallStatus.ringing) {
          // Incoming call - navigate to incoming call screen
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const IncomingCallScreen(),
            ),
          );
        } else if (next.status == CallStatus.dialing) {
          // Outgoing call - navigate to appropriate screen
          _navigateToCallScreen(next.type);
        } else if (next.status == CallStatus.idle &&
            (previous?.status == CallStatus.ended ||
                previous?.status == CallStatus.declined ||
                previous?.status == CallStatus.cancelled)) {
          // Call finished, refresh recents
          ref.read(recentsProvider.notifier).fetchRecents();
        }
      }
    });

    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_currentIndex == 0) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.phone_in_talk_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Text(_getAppBarTitle()),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              themeMode == ThemeMode.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
            onPressed: () {
              ref.read(themeModeProvider.notifier).state =
                  themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _buildBody(userState, isSocketConnected),
      ),
      bottomNavigationBar: userState.user != null
          ? Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  setState(() => _currentIndex = index);
                  if (index == 1) {
                    ref.read(recentsProvider.notifier).fetchRecents();
                  }
                },
                indicatorColor: AppTheme.lightBlue,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.dialpad_rounded),
                    selectedIcon: Icon(Icons.dialpad_rounded, color: AppTheme.primaryBlue),
                    label: 'Dialer',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.history_rounded),
                    selectedIcon: Icon(Icons.history_rounded, color: AppTheme.primaryBlue),
                    label: 'Recents',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.star_border_rounded),
                    selectedIcon: Icon(Icons.star_rounded, color: AppTheme.primaryBlue),
                    label: 'Favorites',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.qr_code_rounded),
                    selectedIcon: Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primaryBlue),
                    label: 'Share',
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
