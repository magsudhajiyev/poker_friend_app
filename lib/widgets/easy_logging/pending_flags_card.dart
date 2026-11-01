import 'package:flutter/material.dart';

import '../../design_system/components/buttons/app_button.dart';
import '../../design_system/components/modals/confirm_dialog.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../services/hand_flag_service.dart';
import '../playing_card_face.dart';
import 'flag_sheet.dart' show flagTagLabel;

/// Pending queue on session details: flagged hands waiting to be finished.
/// Renders nothing when [flags] is empty.
class PendingFlagsCard extends StatelessWidget {
  final List<FlaggedHandRef> flags;
  final void Function(FlaggedHandRef ref) onFinish;
  final Future<void> Function(FlaggedHandRef ref) onDelete;

  const PendingFlagsCard({
    super.key,
    required this.flags,
    required this.onFinish,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (flags.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radius18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.easyLogPendingCount(flags.length),
            style: AppTypography.ibm(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          for (final f in flags)
            _FlagRow(
              ref: f,
              onFinish: () => onFinish(f),
              onDelete: () => _confirmDelete(context, f),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, FlaggedHandRef f) async {
    final l10n = AppLocalizations.of(context);
    final ok = await ConfirmDialog.confirm(
      context,
      title: l10n.easyLogDeleteFlagTitle,
      message: l10n.easyLogDeleteFlagBody,
      confirmLabel: l10n.easyLogDelete,
    );
    if (ok) await onDelete(f);
  }
}

class _FlagRow extends StatelessWidget {
  final FlaggedHandRef ref;
  final VoidCallback onFinish;
  final VoidCallback onDelete;

  const _FlagRow({
    required this.ref,
    required this.onFinish,
    required this.onDelete,
  });

  /// The two stored hero cards; an empty string marks a missing card.
  static List<String> _cards(Map<String, dynamic>? m) => [
        for (final k in const ['card1', 'card2'])
          (m?[k] is String) ? m![k] as String : '',
      ];

  String _summary() {
    final parts = <String>[];
    final pos = ref.heroPositionName;
    if (pos != null && pos.isNotEmpty) parts.add(pos);
    final bb = ref.heroStackBB;
    if (bb != null) parts.add('${bb.round()} BB');
    return parts.join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tags = ref.tags.map((t) => flagTagLabel(l10n, t)).join(', ');
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          _HeroCards(cards: _cards(ref.heroCards)),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _summary(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.ibm(
                      fontSize: 14, color: AppColors.textPrimary),
                ),
                if (tags.isNotEmpty)
                  Text(
                    tags,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.ibm(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          AppButton(
            label: l10n.easyLogFinish,
            variant: AppButtonVariant.primarySmall,
            onTap: onFinish,
          ),
          const SizedBox(width: AppSpacing.xxs),
          AppButton(
            label: l10n.easyLogDelete,
            variant: AppButtonVariant.secondarySmall,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

/// Two small hero cards. A missing card shows a neutral "?" placeholder, so
/// older stubs keep the same row width and never crash.
class _HeroCards extends StatelessWidget {
  final List<String> cards;

  const _HeroCards({required this.cards});

  @override
  Widget build(BuildContext context) {
    final w = PlayingCardFace.responsiveWidth(
      context,
      fraction: 0.065,
      min: 24,
      max: 32,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 2; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xxxs),
          cards[i].length >= 2
              ? PlayingCardFace(cards[i], width: w)
              : _CardPlaceholder(width: w),
        ],
      ],
    );
  }
}

class _CardPlaceholder extends StatelessWidget {
  final double width;

  const _CardPlaceholder({required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width * 1.3,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(AppDecorations.legendDotRadius),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Text(
        '?',
        style: AppTypography.mono(
          fontSize: width * 0.5,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
