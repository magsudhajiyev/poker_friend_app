import 'package:flutter/material.dart';

import '../../design_system/components/buttons/app_button.dart';
import '../../design_system/components/pickers/card_keyboard.dart';
import '../../design_system/components/sheets/app_sheet.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../models/hand_state_machine.dart' show HoleCards;
import '../../services/hand_flag_service.dart';

/// Localised label of a flag tag.
String flagTagLabel(AppLocalizations l10n, String tag) {
  switch (tag) {
    case 'cooler':
      return l10n.easyLogTagCooler;
    case 'bluff':
      return l10n.easyLogTagBluff;
    case 'hero_call':
      return l10n.easyLogTagHeroCall;
    case 'big_pot':
      return l10n.easyLogTagBigPot;
    case 'mistake':
      return l10n.easyLogTagMistake;
    case 'review':
      return l10n.easyLogTagReview;
    case 'played':
      return l10n.easyLogTagPlayed;
    default:
      return tag;
  }
}

/// Bottom sheet to flag the current hand: REQUIRED hero cards, optional tags.
class FlagSheet {
  FlagSheet._();

  /// [onSave] receives the chosen tags and both hero cards. [initialCards]
  /// pre-fills the card slots when the live hand already knows them.
  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(List<String> tags, HoleCards heroCards)
        onSave,
    List<String> initialTags = const [],
    HoleCards? initialCards,
  }) {
    final l10n = AppLocalizations.of(context);
    return AppSheet.show<void>(
      context: context,
      title: l10n.easyLogFlagSheetTitle,
      heightFraction: 0.85,
      // CardKeyboard uses pan drag-and-drop: a sheet scroll view or
      // drag-to-dismiss would steal the gesture. Only tags+Save scroll.
      scrollable: false,
      enableDrag: false,
      body: FlagSheetBody(
        initialTags: initialTags,
        initialCards: initialCards,
        onSave: onSave,
      ),
    );
  }
}

/// Body of [FlagSheet]; public so tests can host it directly.
class FlagSheetBody extends StatefulWidget {
  final List<String> initialTags;
  final HoleCards? initialCards;
  final Future<void> Function(List<String> tags, HoleCards heroCards) onSave;

  const FlagSheetBody({
    super.key,
    required this.onSave,
    this.initialTags = const [],
    this.initialCards,
  });

  @override
  State<FlagSheetBody> createState() => _FlagSheetBodyState();
}

class _FlagSheetBodyState extends State<FlagSheetBody> {
  late List<String> _tags = HandFlagService.sanitizeTags(widget.initialTags);
  late final List<String> _slots = [
    widget.initialCards?.card1 ?? '',
    widget.initialCards?.card2 ?? '',
  ];
  bool _limitHit = false;
  bool _saving = false;

  void _tapTag(String tag) {
    final next = HandFlagService.toggleTag(_tags, tag);
    setState(() {
      _limitHit = next.length == _tags.length && !_tags.contains(tag);
      _tags = next;
    });
  }

  HoleCards? get _cards {
    if (_slots.any((s) => s.isEmpty)) return null;
    return HoleCards(card1: _slots[0], card2: _slots[1]);
  }

  Future<void> _save() async {
    final cards = _cards;
    if (_saving || cards == null) return;
    setState(() => _saving = true);
    await widget.onSave(_tags, cards);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.easyLogFlagCardsRequired,
          style: AppTypography.ibm(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        CardKeyboard(
          slotCount: 2,
          slots: _slots,
          excludedCards: _slots.where((s) => s.isNotEmpty).toSet(),
          onCardCommitted: (i, c) => setState(() => _slots[i] = c),
          onCardCleared: (i) => setState(() => _slots[i] = ''),
        ),
        const SizedBox(height: AppSpacing.xl),
        Flexible(
          child: SingleChildScrollView(
            child: _buildTagsAndSave(l10n),
          ),
        ),
      ],
    );
  }

  Widget _buildTagsAndSave(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _limitHit ? l10n.easyLogTagLimit : l10n.easyLogFlagTagsHint,
          style: AppTypography.ibm(
            fontSize: 14,
            color: _limitHit ? AppColors.accentDanger : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xxs,
          runSpacing: AppSpacing.xxs,
          children: [
            for (final t in kFlagTags)
              _TagChip(
                label: flagTagLabel(l10n, t),
                selected: _tags.contains(t),
                onTap: () => _tapTag(t),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: l10n.commonSave,
          fullWidth: true,
          onTap: (_saving || _cards == null) ? null : _save,
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accentPrimary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
          border: Border.all(
            color: selected ? AppColors.accentPrimary : AppColors.borderStrong,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.ibm(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.accentPrimary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
