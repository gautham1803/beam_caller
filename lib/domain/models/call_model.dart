import 'call_state.dart';

/// Represents the current state of a call.
class CallModel {
  final CallStatus status;
  final CallType type;
  final String? callerNumber;
  final String? receiverNumber;
  final String? remoteNumber;
  final DateTime? startTime;
  final int durationSeconds;
  final int? callId;
  final bool isMuted;
  final bool isSpeakerOn;
  final bool isCameraOff;
  final bool isFrontCamera;

  const CallModel({
    this.status = CallStatus.idle,
    this.type = CallType.voice,
    this.callerNumber,
    this.receiverNumber,
    this.remoteNumber,
    this.startTime,
    this.durationSeconds = 0,
    this.callId,
    this.isMuted = false,
    this.isSpeakerOn = false,
    this.isCameraOff = false,
    this.isFrontCamera = true,
  });

  CallModel copyWith({
    CallStatus? status,
    CallType? type,
    String? callerNumber,
    String? receiverNumber,
    String? remoteNumber,
    DateTime? startTime,
    int? durationSeconds,
    int? callId,
    bool? isMuted,
    bool? isSpeakerOn,
    bool? isCameraOff,
    bool? isFrontCamera,
  }) {
    return CallModel(
      status: status ?? this.status,
      type: type ?? this.type,
      callerNumber: callerNumber ?? this.callerNumber,
      receiverNumber: receiverNumber ?? this.receiverNumber,
      remoteNumber: remoteNumber ?? this.remoteNumber,
      startTime: startTime ?? this.startTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      callId: callId ?? this.callId,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isCameraOff: isCameraOff ?? this.isCameraOff,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
    );
  }

  bool get isActive =>
      status == CallStatus.dialing ||
      status == CallStatus.ringing ||
      status == CallStatus.connecting ||
      status == CallStatus.connected;

  static const idle = CallModel();
}
