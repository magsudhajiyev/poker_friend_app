import 'package:flutter/material.dart';

import '../../design_system/components/headers/section_header.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/sizes.dart';
import '../../design_system/constants/spacing.dart';

/// [SectionHeader] with consistent spacing below it and an optional info
/// button (44px target) that opens an explainer sheet.
class LeakSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onInfo;
  final String? infoLabel;

  const LeakSectionHeader({
    super.key,
    required this.title,
    this.onInfo,
    this.infoLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (onInfo == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Semantics(header: true, child: SectionHeader(title: title)),
      );
    }
    return Row(
      children: [
        Expanded(
          child: Semantics(header: true, child: SectionHeader(title: title)),
        ),
        IconButton(
          onPressed: onInfo,
          tooltip: infoLabel,
          constraints: const BoxConstraints(
              minWidth: AppSizes.minTapTarget,
              minHeight: AppSizes.minTapTarget),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.info_outline,
              size: AppIconSize.md, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
