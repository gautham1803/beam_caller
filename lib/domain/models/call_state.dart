/// Represents all possible states of a call.
enum CallStatus {
  idle,
  dialing,
  ringing,
  connecting,
  connected,
  ended,
  busy,
  declined,
  cancelled,
  missed,
  offline,
  unavailable,
}

/// Type of call.
enum CallType {
  voice,
  video,
}
