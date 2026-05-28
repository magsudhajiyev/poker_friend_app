import 'package:flutter/material.dart';

/// Toggle switch matching Figma v2 spec (node: Toggle).
///
/// Dimensions: 38×24px, thumb 18×18px round, radius 74px.
/// Off: `#0C0C0C` track + `#3A3A3C` border, `#B9B9B9` thumb.
/// On:  `#0C0C0C` track (no border), white thumb.
class AppToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const AppToggle({
    super.key,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 38,
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0xFF0C0C0C),
          borderRadius: BorderRadius.circular(74),
          border: value
              ? null
              : Border.all(color: const Color(0xFF3A3A3C), width: 1),
        ),
        padding: const EdgeInsets.all(3),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: value ? Colors.white : const Color(0xFFB9B9B9),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
