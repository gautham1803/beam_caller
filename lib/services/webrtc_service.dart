import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../utils/constants.dart';

/// WebRTC service for managing peer connections and media streams.
class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  final StreamController<MediaStream?> _remoteStreamController =
      StreamController<MediaStream?>.broadcast();
  final StreamController<RTCPeerConnectionState> _connectionStateController =
      StreamController<RTCPeerConnectionState>.broadcast();

  Stream<MediaStream?> get onRemoteStream => _remoteStreamController.stream;
  Stream<RTCPeerConnectionState> get onConnectionState =>
      _connectionStateController.stream;

  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isFrontCamera = true;
  bool _isSpeakerOn = false;

  bool get isMuted => _isMuted;
  bool get isCameraOff => _isCameraOff;
  bool get isFrontCamera => _isFrontCamera;
  bool get isSpeakerOn => _isSpeakerOn;

  /// Initialize renderers.
  Future<void> initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  /// Get local media stream (audio only or audio+video).
  Future<MediaStream> getUserMedia(bool isVideo) async {
    final constraints = <String, dynamic>{
      'audio': true,
      'video': isVideo
          ? {
              'facingMode': 'user',
              'width': {'ideal': 1280},
              'height': {'ideal': 720},
            }
          : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    localRenderer.srcObject = _localStream;
    return _localStream!;
  }

  /// Initialize and configure the peer connection.
  Future<void> initPeerConnection({
    required Function(RTCIceCandidate) onIceCandidate,
    required bool isVideo,
  }) async {
    final config = AppConstants.iceServers;

    _peerConnection = await createPeerConnection(config);

    // Add local tracks
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
    }

    // Listen for remote tracks
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        remoteRenderer.srcObject = _remoteStream;
        _remoteStreamController.add(_remoteStream);
      }
    };

    // ICE candidate
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      onIceCandidate(candidate);
    };

    // Connection state
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('🔗 Connection state: $state');
      _connectionStateController.add(state);
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('🧊 ICE state: $state');
    };
  }

  /// Create SDP offer (caller side).
  Future<RTCSessionDescription> createOffer() async {
    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    });
    await _peerConnection!.setLocalDescription(offer);
    return offer;
  }

  /// Create SDP answer (callee side).
  Future<RTCSessionDescription> createAnswer() async {
    final answer = await _peerConnection!.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    });
    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  /// Set remote SDP description.
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    await _peerConnection!.setRemoteDescription(description);
  }

  /// Add ICE candidate from remote peer.
  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    await _peerConnection!.addCandidate(candidate);
  }

  /// Toggle microphone mute.
  void toggleMute() {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      for (final track in audioTracks) {
        track.enabled = _isMuted;
      }
      _isMuted = !_isMuted;
    }
  }

  /// Toggle camera on/off.
  void toggleCamera() {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      for (final track in videoTracks) {
        track.enabled = _isCameraOff;
      }
      _isCameraOff = !_isCameraOff;
    }
  }

  /// Switch between front and back camera.
  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        await Helper.switchCamera(videoTracks[0]);
        _isFrontCamera = !_isFrontCamera;
      }
    }
  }

  /// Toggle speaker.
  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      for (final track in audioTracks) {
        track.enableSpeakerphone(_isSpeakerOn);
      }
    }
  }

  /// Set speaker state.
  void setSpeaker(bool enabled) {
    _isSpeakerOn = enabled;
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      for (final track in audioTracks) {
        track.enableSpeakerphone(enabled);
      }
    }
  }

  /// Clean up and close everything.
  Future<void> dispose() async {
    // Stop local tracks
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }

    // Close peer connection
    if (_peerConnection != null) {
      await _peerConnection!.close();
      _peerConnection = null;
    }

    _remoteStream = null;

    // Dispose renderers
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    await localRenderer.dispose();
    await remoteRenderer.dispose();

    // Close streams
    await _remoteStreamController.close();
    await _connectionStateController.close();

    // Reset state
    _isMuted = false;
    _isCameraOff = false;
    _isFrontCamera = true;
    _isSpeakerOn = false;
  }

  /// Partial cleanup for call end (keeps renderers alive for reuse).
  Future<void> hangUp() async {
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }

    if (_peerConnection != null) {
      await _peerConnection!.close();
      _peerConnection = null;
    }

    _remoteStream = null;
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;

    _isMuted = false;
    _isCameraOff = false;
    _isFrontCamera = true;
    _isSpeakerOn = false;
  }
}
