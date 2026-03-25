import 'package:flutter/material.dart';

/// Rounded pill badge showing average earnings
/// Used in the Earnings section header
class AvgBadge extends StatelessWidget {
  final String text;

  const AvgBadge({
    Key? key,
    required this.text,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF89F1EC), // Mint background
        borderRadius: BorderRadius.circular(140),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'IBMPlexSans',
          fontWeight: FontWeight.w500,
          fontSize: 15,
          color: Colors.black,
        ),
      ),
    );
  }
}
