/// Represents a user identified by their 6-digit number.
class UserModel {
  final String number;
  final String deviceId;
  final bool isOnline;
  final String? lastSeen;
  final String? lastSeenText;

  const UserModel({
    required this.number,
    required this.deviceId,
    this.isOnline = false,
    this.lastSeen,
    this.lastSeenText,
  });

  UserModel copyWith({
    String? number,
    String? deviceId,
    bool? isOnline,
    String? lastSeen,
    String? lastSeenText,
  }) {
    return UserModel(
      number: number ?? this.number,
      deviceId: deviceId ?? this.deviceId,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      lastSeenText: lastSeenText ?? this.lastSeenText,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      number: json['number'] as String,
      deviceId: json['device_id'] as String? ?? '',
      isOnline: json['online'] as bool? ?? false,
      lastSeen: json['last_seen'] as String?,
      lastSeenText: json['last_seen_text'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'device_id': deviceId,
      'online': isOnline,
      'last_seen': lastSeen,
      'last_seen_text': lastSeenText,
    };
  }
}
