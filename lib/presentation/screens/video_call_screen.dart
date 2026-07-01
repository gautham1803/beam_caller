import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../domain/models/call_state.dart';
import '../../utils/theme.dart';
import '../providers/call_provider.dart';
import '../widgets/call_controls.dart';
import '../widgets/call_timer.dart';

/// Active video call screen with remote/local video and controls.
class VideoCallScreen extends ConsumerStatefulWidget {
  const VideoCallScreen({super.key});

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  bool _showControls = true;
  Timer? _hideControlsTimer;
  Offset _localVideoOffset = const Offset(16, 80);

  @override
  void initState() {
    super.initState();
    _startHideControlsTimer();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _startHideControlsTimer();
      }
    });
  }

  String _getStatusText(CallStatus status) {
    switch (status) {
      case CallStatus.dialing:
        return 'Calling...';
      case CallStatus.connecting:
        return 'Connecting...';
      case CallStatus.connected:
        return '';
      default:
        return '';
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callProvider);
    final webrtcService = ref.read(callProvider.notifier).webrtcService;
    final screenSize = MediaQuery.of(context).size;

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
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleControls,
          child: Stack(
            children: [
              // Remote Video (full screen)
              Positioned.fill(
                child: callState.status == CallStatus.connected
                    ? RTCVideoView(
                        webrtcService.remoteRenderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF0D47A1),
                              Color(0xFF1565C0),
                              Color(0xFF1976D2),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: Colors.white,
                                  size: 48,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                formattedNumber,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _getStatusText(callState.status),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),

              // Local Video Preview (draggable PiP)
              if (callState.status == CallStatus.connected &&
                  !callState.isCameraOff)
                Positioned(
                  right: _localVideoOffset.dx,
                  top: _localVideoOffset.dy,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _localVideoOffset = Offset(
                          (_localVideoOffset.dx - details.delta.dx)
                              .clamp(0, screenSize.width - 120),
                          (_localVideoOffset.dy + details.delta.dy)
                              .clamp(0, screenSize.height - 180),
                        );
                      });
                    },
                    child: Container(
                      width: 120,
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: RTCVideoView(
                        webrtcService.localRenderer,
                        mirror: true,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  ),
                ),

              // Top bar (animated)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                top: _showControls ? 0 : -100,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 16,
                    right: 16,
                    bottom: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formattedNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (callState.status == CallStatus.connected)
                        CallTimer(
                            durationSeconds: callState.durationSeconds),
                    ],
                  ),
                ),
              ),

              // Bottom controls (animated)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                bottom: _showControls ? 0 : -200,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: 24,
                    bottom: MediaQuery.of(context).padding.bottom + 24,
                    left: 24,
                    right: 24,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (callState.isActive) ...[
                        Row(
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
                              icon: callState.isCameraOff
                                  ? Icons.videocam_off_rounded
                                  : Icons.videocam_rounded,
                              label: 'Camera',
                              isActive: callState.isCameraOff,
                              onPressed: () {
                                ref.read(callProvider.notifier).toggleCamera();
                              },
                            ),
                            CallControlButton(
                              icon: Icons.cameraswitch_rounded,
                              label: 'Flip',
                              onPressed: () {
                                ref.read(callProvider.notifier).switchCamera();
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
                          ],
                        ),
                        const SizedBox(height: 24),
                        EndCallButton(
                          onPressed: () {
                            if (callState.status == CallStatus.dialing) {
                              ref.read(callProvider.notifier).cancelCall();
                            } else {
                              ref.read(callProvider.notifier).endCall();
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
