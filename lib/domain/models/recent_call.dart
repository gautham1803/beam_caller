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
    // Handle id that might come as int or num
    final rawId = json['id'];
    final id = rawId is int ? rawId : (rawId as num).toInt();

    // Handle started_at that might be null (shouldn't happen but be safe)
    DateTime startedAt;
    try {
      startedAt = json['started_at'] != null
          ? DateTime.parse(json['started_at'].toString())
          : DateTime.now();
    } catch (_) {
      startedAt = DateTime.now();
    }

    // Handle ended_at
    DateTime? endedAt;
    if (json['ended_at'] != null) {
      try {
        endedAt = DateTime.parse(json['ended_at'].toString());
      } catch (_) {
        endedAt = null;
      }
    }

    return RecentCall(
      id: id,
      caller: json['caller']?.toString() ?? '',
      receiver: json['receiver']?.toString() ?? '',
      type: json['type']?.toString() ?? 'voice',
      startedAt: startedAt,
      endedAt: endedAt,
      duration: json['duration'] is int
          ? json['duration'] as int
          : (json['duration'] as num?)?.toInt() ?? 0,
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
