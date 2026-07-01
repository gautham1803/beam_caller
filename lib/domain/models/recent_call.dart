/// Represents a record of a past voice or video call.
class RecentCall {
  final int id;
  final String caller;
  final String receiver;
  final String type;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int duration;

  const RecentCall({
    required this.id,
    required this.caller,
    required this.receiver,
    required this.type,
    required this.startedAt,
    this.endedAt,
    required this.duration,
  });

  factory RecentCall.fromJson(Map<String, dynamic> json) {
    return RecentCall(
      id: json['id'] as int,
      caller: json['caller'] as String,
      receiver: json['receiver'] as String,
      type: json['type'] as String? ?? 'voice',
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      duration: json['duration'] as int? ?? 0,
    );
  }

  /// Whether the user was caller or receiver, and whether it was missed.
  bool isMissed(String myNumber) {
    // If we are the receiver and duration is 0 and endedAt is present
    // it was probably declined, cancelled, or missed.
    return receiver == myNumber && duration == 0;
  }

  bool isIncoming(String myNumber) {
    return receiver == myNumber;
  }
}
