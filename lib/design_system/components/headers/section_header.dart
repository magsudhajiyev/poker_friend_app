import 'package:flutter/material.dart';
import '../../constants/typography.dart';

/// Section header with lime green uppercase title
///
/// Used to introduce sections throughout the app (e.g., "RECENT ACTIVITY",
/// "RECENT SESSIONS", "POSITIONAL STATISTICS").
///
/// Usage:
/// ```dart
/// SectionHeader(title: 'RECENT ACTIVITY')
/// ```
class SectionHeader extends StatelessWidget {
  final String title;
  final EdgeInsets? padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Text(
        title.toUpperCase(),
        style: AppTypography.sectionHeader(),
      ),
    );
  }
}
