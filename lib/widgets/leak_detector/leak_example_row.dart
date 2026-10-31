import 'package:flutter/material.dart';

import '../../design_system/constants/colors.dart';
import '../../design_system/constants/sizes.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../services/leak_engine.dart';
import '../playing_card_face.dart';
import 'leak_format.dart';

/// One of the player's own hands behind a finding: hole cards as card faces
/// plus a wrapped context line ("#142 · EP · wet board · top pair+").
///
/// At least [AppSizes.listRowMin] tall. When the full hand record is not
/// available the row is visibly disabled and says why.
class LeakExampleRow extends StatelessWidget {
  final LeakExample example;
  final bool available;
  final VoidCallback? onTap;

  const LeakExampleRow({
    super.key,
    required this.example,
    required this.available,
    this.onTap,
  });

  String get _details => [
        '#${example.handNumber}',
        if (example.posGroup != null) example.posGroup!,
        if (example.textureLabel != null) example.textureLabel!,
        if (example.strengthLabel != null) example.strengthLabel!,
      ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cards = splitHoleCards(example.holeCards);
    final width = PlayingCardFace.responsiveWidth(context);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.listRowMin),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxs),
        child: Row(
          children: [
            for (final c in cards) ...[
              _dim(PlayingCardFace(c, width: width)),
              const SizedBox(width: AppSpacing.xxxs),
            ],
            if (cards.isNotEmpty) const SizedBox(width: AppSpacing.xxs),
            Expanded(child: _text(l10n)),
            if (available)
              const Icon(Icons.chevron_right,
                  size: AppIconSize.md, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
    return Semantics(
      button: available,
      enabled: available,
      excludeSemantics: true,
      label: [
        l10n.leakExampleSemantics(example.handNumber, _details),
        if (!available) l10n.leakHandUnavailable,
      ].join('. '),
      child: InkWell(
        onTap: available ? onTap : null,
        child: row,
      ),
    );
  }

  /// Dims decoration when the hand cannot be opened.
  Widget _dim(Widget w) => available
      ? w
      : Opacity(opacity: AppColors.disabledOpacity, child: w);

  Widget _text(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _dim(Text(_details,
            style: AppTypography.bodySmMedium(color: AppColors.textPrimary))),
        if (!available)
          Text(l10n.leakHandUnavailable, style: AppTypography.caption()),
      ],
    );
  }
}
