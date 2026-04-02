import 'package:flutter/material.dart';

/// Reusable toggle switch matching the app's design system.
///
/// ON state: teal track (#1B4341), teal border (#4B9A96), mint thumb (#73D4CF)
/// OFF state: dark track (#39393D), grey border (#555555), grey thumb (#8C8C8C)
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
      child: Container(
        width: 50,
        height: 20,
        decoration: BoxDecoration(
          color: value ? const Color(0xFF1B4341) : const Color(0xFF39393D),
          borderRadius: BorderRadius.circular(74),
          border: Border.all(
            color: value ? const Color(0xFF4B9A96) : const Color(0xFF555555),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(2),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 15,
            decoration: BoxDecoration(
              color: value ? const Color(0xFF73D4CF) : const Color(0xFF8C8C8C),
              borderRadius: BorderRadius.circular(43),
            ),
          ),
        ),
      ),
    );
  }
}
