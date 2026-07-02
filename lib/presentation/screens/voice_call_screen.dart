import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/call_model.dart';
import '../../domain/models/call_state.dart';
import '../../utils/theme.dart';
import '../providers/call_provider.dart';
import '../widgets/call_controls.dart';
import '../widgets/call_timer.dart';

/// Active voice call screen with controls.
class VoiceCallScreen extends ConsumerStatefulWidget {
  const VoiceCallScreen({super.key});

  @override
  ConsumerState<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends ConsumerState<VoiceCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  String _getStatusText(CallStatus status) {
    switch (status) {
      case CallStatus.dialing:
        return 'Dialing...';
      case CallStatus.ringing:
        return 'Ringing...';
      case CallStatus.connecting:
        return 'Connecting...';
      case CallStatus.connected:
        return 'Connected';
      case CallStatus.ended:
        return 'Call Ended';
      case CallStatus.busy:
        return 'Busy';
      case CallStatus.declined:
        return 'Declined';
      case CallStatus.cancelled:
        return 'Cancelled';
      case CallStatus.offline:
        return 'User Offline';
      case CallStatus.unavailable:
        return 'Unavailable';
      default:
        return '';
    }
  }

  Color _getStatusColor(CallStatus status) {
    switch (status) {
      case CallStatus.connected:
        return AppTheme.activeGreen;
      case CallStatus.ended:
      case CallStatus.declined:
      case CallStatus.cancelled:
      case CallStatus.busy:
        return AppTheme.endCallRed;
      default:
        return Colors.white.withValues(alpha: 0.6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callProvider);

    // Navigate back when call ends
    ref.listen(callProvider, (previous, next) {
      if (next.status == CallStatus.idle) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    });

    final remoteNumber = callState.remoteNumber ?? '------';
    final formattedNumber = remoteNumber.length == 6
        ? '${remoteNumber.substring(0, 3)} ${remoteNumber.substring(3)}'
        : remoteNumber;

    final isConnecting = callState.status == CallStatus.connecting ||
        callState.status == CallStatus.dialing ||
        callState.status == CallStatus.ringing;

    return PopScope(
      canPop: !callState.isActive,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0A1628),
                Color(0xFF0D2137),
                Color(0xFF0F3460),
                Color(0xFF162447),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.3, 0.7, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Subtle animated background orbs
              if (isConnecting || callState.status == CallStatus.connected)
                ...List.generate(3, (i) {
                  return Positioned(
                    left: i == 0 ? -50 : (i == 1 ? 200 : 100),
                    top: i == 0 ? 100 : (i == 1 ? 300 : 600),
                    child: AnimatedBuilder(
                      animation: _waveController,
                      builder: (context, _) {
                        final scale = 0.8 + 0.4 * sin(_waveController.value * pi * 2 + i * 2);
                        return Opacity(
                          opacity: 0.04 + 0.02 * sin(_waveController.value * pi * 2 + i),
                          child: Container(
                            width: 200 * scale,
                            height: 200 * scale,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppTheme.primaryBlue.withValues(alpha: 0.5),
                                  AppTheme.primaryBlue.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),

              SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 1),

                    // Status text with dot indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (callState.status == CallStatus.connected)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.activeGreen,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.activeGreen.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        Text(
                          _getStatusText(callState.status),
                          style: TextStyle(
                            color: _getStatusColor(callState.status),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Animated avatar with waves
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Ripple waves
                          if (callState.status == CallStatus.connected ||
                              isConnecting)
                            ...List.generate(3, (index) {
                              return AnimatedBuilder(
                                animation: _waveController,
                                builder: (context, _) {
                                  final progress =
                                      (_waveController.value + index * 0.33) % 1.0;
                                  return Container(
                                    width: 110 + progress * 90,
                                    height: 110 + progress * 90,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: (callState.status == CallStatus.connected
                                                ? AppTheme.activeGreen
                                                : AppTheme.primaryBlue)
                                            .withValues(alpha: 0.25 * (1 - progress)),
                                        width: 1.5,
                                      ),
                                    ),
                                  );
                                },
                              );
                            }),
                          // Pulsing avatar circle
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: isConnecting ? _pulseAnimation.value : 1.0,
                                child: child,
                              );
                            },
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.15),
                                    Colors.white.withValues(alpha: 0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  remoteNumber.length >= 2
                                      ? remoteNumber.substring(0, 2)
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Number
                    Text(
                      formattedNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Duration
                    if (callState.status == CallStatus.connected)
                      CallTimer(durationSeconds: callState.durationSeconds),

                    const Spacer(flex: 2),

                    // Controls
                    if (callState.isActive) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            CallControlButton(
                              icon: callState.isMuted
                                  ? Icons.mic_off_rounded
                                  : Icons.mic_rounded,
                              label: callState.isMuted ? 'Unmute' : 'Mute',
                              isActive: callState.isMuted,
                              onPressed: () {
                                ref.read(callProvider.notifier).toggleMute();
                              },
                            ),
                            CallControlButton(
                              icon: callState.isSpeakerOn
                                  ? Icons.volume_up_rounded
                                  : Icons.volume_down_rounded,
                              label: 'Speaker',
                              isActive: callState.isSpeakerOn,
                              onPressed: () {
                                ref.read(callProvider.notifier).toggleSpeaker();
                              },
                            ),
                            CallControlButton(
                              icon: Icons.bluetooth_rounded,
                              label: 'Bluetooth',
                              isActive: false,
                              onPressed: () {
                                // Bluetooth toggle - future implementation
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      EndCallButton(
                        onPressed: () {
                          if (callState.status == CallStatus.dialing) {
                            ref.read(callProvider.notifier).cancelCall();
                          } else {
                            ref.read(callProvider.notifier).endCall();
                          }
                        },
                      ),
                    ] else ...[
                      // Call ended - show back button
                      ElevatedButton.icon(
                        onPressed: () {
                          ref.read(callProvider.notifier).resetToIdle();
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Back'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
