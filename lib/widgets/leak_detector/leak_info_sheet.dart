import 'package:flutter/material.dart';

import '../../design_system/components/sheets/app_sheet.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';

/// Explainer bottom sheet on the shared [AppSheet] scaffold. [summary] is an
/// optional highlighted first line; [paragraphs] render as body copy.
Future<void> showLeakInfoSheet(
  BuildContext context, {
  required String title,
  String? summary,
  required List<String> paragraphs,
}) {
  return AppSheet.show<void>(
    context: context,
    title: title,
    heightFraction: null,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary != null) ...[
          Text(summary,
              style: AppTypography.dataMonoSm(color: AppColors.accentPrimary)),
          const SizedBox(height: AppSpacing.xs),
        ],
        for (var i = 0; i < paragraphs.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xs),
          Text(paragraphs[i],
              style: AppTypography.bodyMd(color: AppColors.textSecondary)),
        ],
      ],
    ),
  );
}
