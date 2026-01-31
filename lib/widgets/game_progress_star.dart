import 'package:flutter/material.dart';

class GameProgressStar extends StatelessWidget {
  final double progress;

  const GameProgressStar({
    super.key,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.deepOrange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.star, color: Colors.white, size: 28),
          ),
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 4,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
