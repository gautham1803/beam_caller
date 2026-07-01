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
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
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

    return PopScope(
      canPop: !callState.isActive,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 1),

                // Status text
                Text(
                  _getStatusText(callState.status),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 32),

                // Animated wave circles
                SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (callState.status == CallStatus.connected)
                        ...List.generate(3, (index) {
                          return AnimatedBuilder(
                            animation: _waveController,
                            builder: (context, _) {
                              final progress =
                                  (_waveController.value + index * 0.33) % 1.0;
                              return Container(
                                width: 120 + progress * 80,
                                height: 120 + progress * 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppTheme.primaryBlue
                                        .withValues(alpha: 0.3 * (1 - progress)),
                                    width: 2,
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 48,
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
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
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
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
