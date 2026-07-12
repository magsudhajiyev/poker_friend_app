import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../constants/typography.dart';

/// Paragraph text used as an [AppDialog] / [AppSheet] body.
///
/// 15px Regular body text on [AppColors.textSecondary]. Line height 22.
/// Used by [ConfirmDialog], onboarding complete, event success, cards, and any
/// other simple message-only modal.
class MessageBody extends StatelessWidget {
  final String message;
  final TextAlign textAlign;

  const MessageBody(
    this.message, {
    super.key,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      textAlign: textAlign,
      style: AppTypography.ibm(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 22 / 15,
      ),
    );
  }
}
