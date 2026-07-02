import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/models/call_model.dart';
import '../../domain/models/call_state.dart';
import '../../data/remote/socket_service.dart';
import '../../services/webrtc_service.dart';
import '../../services/permission_service.dart';
import 'socket_provider.dart';

/// Manages the entire call lifecycle.
class CallNotifier extends StateNotifier<CallModel> {
  final SocketService _socketService;
  final WebRTCService _webrtcService;
  final PermissionService _permissionService;
  Timer? _durationTimer;
  DateTime? _callStartTime;
  bool _isRemoteDescriptionSet = false;
  final List<RTCIceCandidate> _bufferedCandidates = [];

  CallNotifier(
    this._socketService,
    this._webrtcService,
    this._permissionService,
  ) : super(CallModel.idle) {
    _setupSocketListeners();
  }

  WebRTCService get webrtcService => _webrtcService;

  void _setupSocketListeners() {
    // Incoming call
    _socketService.on('call:incoming', (data) {
      final callerNumber = data['callerNumber'] as String?;
      final callType = data['callType'] as String? ?? 'voice';

      if (callerNumber != null && !state.isActive) {
        state = state.copyWith(
          status: CallStatus.ringing,
          type: callType == 'video' ? CallType.video : CallType.voice,
          callerNumber: callerNumber,
          remoteNumber: callerNumber,
        );
      } else if (state.isActive) {
        // Already in a call, auto-reject
        _socketService.rejectCall(callerNumber ?? '');
      }
    });

    // Call ringing (caller side)
    _socketService.on('call:ringing', (data) {
      state = state.copyWith(status: CallStatus.dialing);
    });

    // Call accepted
    _socketService.on('call:accepted', (data) async {
      state = state.copyWith(status: CallStatus.connecting);
      await _startWebRTC(isCaller: true);
    });

    // Call rejected
    _socketService.on('call:rejected', (data) {
      state = state.copyWith(status: CallStatus.declined);
      _cleanupCall();
    });

    // Call busy
    _socketService.on('call:busy', (data) {
      state = state.copyWith(status: CallStatus.busy);
      _cleanupCall();
    });

    // Call cancelled
    _socketService.on('call:cancelled', (data) {
      state = state.copyWith(status: CallStatus.cancelled);
      _cleanupCall();
    });

    // Call ended
    _socketService.on('call:ended', (data) {
      state = state.copyWith(status: CallStatus.ended);
      _cleanupCall();
    });

    // Call error
    _socketService.on('call:error', (data) {
      final message = data['message'] as String? ?? 'Call failed';
      debugPrint('Call error: $message');

      if (message.contains('offline')) {
        state = state.copyWith(status: CallStatus.offline);
      } else if (message.contains('not found')) {
        state = state.copyWith(status: CallStatus.unavailable);
      } else {
        state = state.copyWith(status: CallStatus.ended);
      }
      _cleanupCall();
    });

    // SDP Offer (callee receives)
    _socketService.on('call:sdp-offer', (data) async {
      try {
        final sdpMap = data['sdp'] as Map<String, dynamic>;
        final sdp = RTCSessionDescription(
          sdpMap['sdp'] as String?,
          sdpMap['type'] as String?,
        );
        await _webrtcService.setRemoteDescription(sdp);
        _isRemoteDescriptionSet = true;
        _processBufferedCandidates();

        // Create and send answer
        final answer = await _webrtcService.createAnswer();
        _socketService.sendSdpAnswer({
          'sdp': answer.sdp,
          'type': answer.type,
        });
      } catch (e) {
        debugPrint('SDP offer handling error: $e');
      }
    });

    // SDP Answer (caller receives)
    _socketService.on('call:sdp-answer', (data) async {
      try {
        final sdpMap = data['sdp'] as Map<String, dynamic>;
        final sdp = RTCSessionDescription(
          sdpMap['sdp'] as String?,
          sdpMap['type'] as String?,
        );
        await _webrtcService.setRemoteDescription(sdp);
        _isRemoteDescriptionSet = true;
        _processBufferedCandidates();
      } catch (e) {
        debugPrint('SDP answer handling error: $e');
      }
    });

    // ICE Candidate
    _socketService.on('call:ice-candidate', (data) async {
      try {
        final candidateMap = data['candidate'] as Map<String, dynamic>;
        final candidate = RTCIceCandidate(
          candidateMap['candidate'] as String?,
          candidateMap['sdpMid'] as String?,
          candidateMap['sdpMLineIndex'] as int?,
        );
        if (_isRemoteDescriptionSet) {
          await _webrtcService.addIceCandidate(candidate);
        } else {
          _bufferedCandidates.add(candidate);
        }
      } catch (e) {
        debugPrint('ICE candidate handling error: $e');
      }
    });
  }

  /// Initiate a voice call.
  Future<void> makeVoiceCall(String targetNumber, String myNumber) async {
    await _makeCall(targetNumber, myNumber, CallType.voice);
  }

  /// Initiate a video call.
  Future<void> makeVideoCall(String targetNumber, String myNumber) async {
    await _makeCall(targetNumber, myNumber, CallType.video);
  }

  Future<void> _makeCall(
    String targetNumber,
    String myNumber,
    CallType callType,
  ) async {
    if (state.isActive) return;

    // Check permissions
    final hasPerms = await _permissionService.requestCallPermissions(
      includeCamera: callType == CallType.video,
    );

    final micGranted = hasPerms[Permission.microphone] ?? false;
    if (!micGranted) {
      debugPrint('Microphone permission denied');
      return;
    }

    if (callType == CallType.video) {
      final camGranted = hasPerms[Permission.camera] ?? false;
      if (!camGranted) {
        debugPrint('Camera permission denied');
        return;
      }
    }

    state = state.copyWith(
      status: CallStatus.dialing,
      type: callType,
      callerNumber: myNumber,
      receiverNumber: targetNumber,
      remoteNumber: targetNumber,
    );

    _socketService.startCall(
      targetNumber,
      myNumber,
      callType == CallType.video ? 'video' : 'voice',
    );
  }

  /// Accept an incoming call.
  Future<void> acceptCall() async {
    if (state.status != CallStatus.ringing) return;

    // Request permissions
    final hasPerms = await _permissionService.requestCallPermissions(
      includeCamera: state.type == CallType.video,
    );

    final micGranted = hasPerms[Permission.microphone] ?? false;
    if (!micGranted) {
      rejectCall();
      return;
    }

    state = state.copyWith(status: CallStatus.connecting);
    _socketService.acceptCall(state.callerNumber!);

    await _startWebRTC(isCaller: false);
  }

  /// Reject an incoming call.
  void rejectCall() {
    if (state.status != CallStatus.ringing) return;

    _socketService.rejectCall(state.callerNumber!);
    state = state.copyWith(status: CallStatus.declined);
    _cleanupCall();
  }

  /// Cancel outgoing call.
  void cancelCall() {
    if (state.status != CallStatus.dialing) return;

    _socketService.cancelCall();
    state = state.copyWith(status: CallStatus.cancelled);
    _cleanupCall();
  }

  /// End active call.
  void endCall() {
    _socketService.endCall();
    state = state.copyWith(status: CallStatus.ended);
    _cleanupCall();
  }

  /// Toggle mute.
  void toggleMute() {
    _webrtcService.toggleMute();
    state = state.copyWith(isMuted: _webrtcService.isMuted);
  }

  /// Toggle speaker.
  void toggleSpeaker() {
    _webrtcService.toggleSpeaker();
    state = state.copyWith(isSpeakerOn: _webrtcService.isSpeakerOn);
  }

  /// Toggle camera.
  void toggleCamera() {
    _webrtcService.toggleCamera();
    state = state.copyWith(isCameraOff: _webrtcService.isCameraOff);
  }

  /// Switch camera.
  Future<void> switchCamera() async {
    await _webrtcService.switchCamera();
    state = state.copyWith(isFrontCamera: _webrtcService.isFrontCamera);
  }

  /// Reset to idle state.
  void resetToIdle() {
    state = CallModel.idle;
  }

  Future<void> _startWebRTC({required bool isCaller}) async {
    try {
      await _webrtcService.initRenderers();
      await _webrtcService.getUserMedia(state.type == CallType.video);

      // Set speaker on for voice calls (earpiece for video)
      _webrtcService.setSpeaker(state.type == CallType.voice);

      await _webrtcService.initPeerConnection(
        onIceCandidate: (candidate) {
          _socketService.sendIceCandidate({
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          });
        },
        isVideo: state.type == CallType.video,
      );

      // Listen for connection established
      _webrtcService.onConnectionState.listen((connectionState) {
        if (connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _callStartTime = DateTime.now();
          state = state.copyWith(
            status: CallStatus.connected,
            startTime: _callStartTime,
          );
          _startDurationTimer();
        } else if (connectionState == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            connectionState == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          endCall();
        }
      });

      if (isCaller) {
        // Create and send offer
        final offer = await _webrtcService.createOffer();
        _socketService.sendSdpOffer({
          'sdp': offer.sdp,
          'type': offer.type,
        });
      }
    } catch (e) {
      debugPrint('WebRTC start error: $e');
      state = state.copyWith(status: CallStatus.ended);
      _cleanupCall();
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_callStartTime != null) {
        final duration = DateTime.now().difference(_callStartTime!).inSeconds;
        state = state.copyWith(durationSeconds: duration);
      }
    });
  }

  void _processBufferedCandidates() {
    if (!_isRemoteDescriptionSet) return;
    for (final candidate in _bufferedCandidates) {
      _webrtcService.addIceCandidate(candidate).catchError((e) {
        debugPrint('Error adding buffered ICE candidate: $e');
      });
    }
    _bufferedCandidates.clear();
  }

  void _cleanupCall() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _callStartTime = null;
    _isRemoteDescriptionSet = false;
    _bufferedCandidates.clear();

    Future.delayed(const Duration(seconds: 2), () {
      if (!state.isActive) {
        _webrtcService.hangUp();
        state = CallModel.idle;
      }
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _webrtcService.dispose();
    super.dispose();
  }
}

final webrtcServiceProvider = Provider((ref) => WebRTCService());
final permissionServiceProvider = Provider((ref) => PermissionService());

final callProvider = StateNotifierProvider<CallNotifier, CallModel>((ref) {
  final socketService = ref.read(socketServiceProvider);
  final webrtcService = ref.read(webrtcServiceProvider);
  final permissionService = ref.read(permissionServiceProvider);
  return CallNotifier(socketService, webrtcService, permissionService);
});
