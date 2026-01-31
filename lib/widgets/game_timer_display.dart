import 'package:flutter/material.dart';

class GameTimerDisplay extends StatelessWidget {
  final int remainingSeconds;

  const GameTimerDisplay({
    super.key,
    required this.remainingSeconds,
  });

  @override
  Widget build(BuildContext context) {
    String minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    String seconds = (remainingSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        "$minutes:$seconds",
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: remainingSeconds < 60 ? Colors.red : Colors.blue.shade900,
        ),
      ),
    );
  }
}
