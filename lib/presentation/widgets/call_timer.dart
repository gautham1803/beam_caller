import 'package:flutter/material.dart';

/// Live call duration display in MM:SS format.
class CallTimer extends StatelessWidget {
  final int durationSeconds;

  const CallTimer({super.key, required this.durationSeconds});

  String get _formatted {
    final minutes = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (durationSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatted,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: Colors.white70,
        letterSpacing: 2,
      ),
    );
  }
}
