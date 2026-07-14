import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// Canonical toggle switch — iOS-style green.
///
/// - Track ON: `accentPrimary` green
/// - Track OFF: white @ 20% opacity (reads as muted grey on dark surfaces)
/// - Thumb: white circle
/// - Dimensions: 38×24 track, 18×18 thumb, 74 radius, 3px inset padding
///
/// Use this for every boolean toggle in the app. Do NOT reach for
/// `Switch`, `Switch.adaptive`, or `CupertinoSwitch` — they don't match
/// the design system.
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
        duration: const Duration(milliseconds: 180),
        width: 38,
        height: 24,
        decoration: BoxDecoration(
          color: value
              ? AppColors.accentPrimary
              : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(74),
        ),
        padding: const EdgeInsets.all(3),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
