import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/components/app_text_field.dart';
import '../../design_system/components/buttons/app_button.dart';
import '../../design_system/components/sheets/app_sheet.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../models/hand_state_machine.dart';
import '../../screens/hand_actions_screen.dart';
import '../../services/analytics_service.dart';
import '../../services/firebase_service.dart';
import '../../services/logger_service.dart';
import '../../models/single_hand_group.dart';
import '../../services/single_hand_service.dart';

/// What the player chose on the result sheet.
enum SingleHandChoice { another, done }

/// What the hand screen returns to the flow once a hand is saved.
class SingleHandOutcome {
  final SingleHandChoice choice;
  final SingleHandGroup group;
  const SingleHandOutcome(this.choice, this.group);
}

/// Shown after a single hand is saved: star, note, tags, then View / Log
/// another / Done. Annotations are written straight to the saved hand.
class SingleHandResultSheet extends StatefulWidget {
  final HandRecord hand;
  final SingleHandSaveResult saved;

  const SingleHandResultSheet({
    super.key,
    required this.hand,
    required this.saved,
  });

  /// Null (system back) counts as [SingleHandChoice.done].
  static Future<SingleHandChoice?> show(
    BuildContext context, {
    required HandRecord hand,
    required SingleHandSaveResult saved,
  }) {
    return showModalBottomSheet<SingleHandChoice>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => SingleHandResultSheet(hand: hand, saved: saved),
    );
  }

  @override
  State<SingleHandResultSheet> createState() => _SingleHandResultSheetState();
}

class _SingleHandResultSheetState extends State<SingleHandResultSheet> {
  final _notesCtl = TextEditingController();
  final _tags = <String>{};
  bool _starred = false;
  String _savedNotes = '';

  String get _sessionId => widget.saved.sessionId;
  String get _handId => widget.saved.handId;

  @override
  void dispose() {
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _write({bool? star, List<String>? tags, String? notes}) async {
    try {
      await FirebaseService.updateHandAnnotations(
        sessionId: _sessionId,
        handId: _handId,
        isStarred: star,
        tags: tags,
        notes: notes,
      );
    } catch (e) {
      LoggerService.log('SingleHand annotate failed: $e',
          level: LogLevel.WARNING);
    }
  }

  void _toggleStar() {
    setState(() => _starred = !_starred);
    widget.hand.isStarred = _starred;
    AnalyticsService.singleHandPostAction('star');
    unawaited(_write(star: _starred));
  }

  void _toggleTag(String tag) {
    setState(() => _tags.contains(tag) ? _tags.remove(tag) : _tags.add(tag));
    widget.hand.tags = _tags.toList();
    AnalyticsService.singleHandPostAction('tag');
    unawaited(_write(tags: widget.hand.tags));
  }

  /// Writes the note once, when the player leaves the sheet or the field.
  Future<void> _flushNotes() async {
    final text = _notesCtl.text.trim();
    if (text == _savedNotes) return;
    _savedNotes = text;
    widget.hand.notes = text;
    AnalyticsService.singleHandPostAction('note');
    await _write(notes: text);
  }

  Future<void> _finish(SingleHandChoice choice, String action) async {
    await _flushNotes();
    AnalyticsService.singleHandPostAction(action);
    if (mounted) Navigator.pop(context, choice);
  }

  Future<void> _view() async {
    await _flushNotes();
    AnalyticsService.singleHandPostAction('view');
    if (!mounted) return;
    final map = widget.hand.toMap()
      ..['id'] = _handId
      ..['sessionId'] = _sessionId
      ..['handNumber'] = widget.saved.handNumber
      ..['playerNames'] = {
        for (final e in widget.saved.playerNames.entries) '${e.key}': e.value
      };
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          HandActionsScreen(hand: map, ourSeat: widget.hand.heroSeatNumber),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Stored value (English, same as HandReviewDialog's tags) -> shown label.
    final tags = {
      'Bluff': l10n.singleHandTagBluff,
      'Hero Call': l10n.singleHandTagHeroCall,
      'Bad Beat': l10n.singleHandTagBadBeat,
      'Big Pot': l10n.singleHandTagBigPot,
      'Review': l10n.singleHandTagReview,
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(SingleHandChoice.done, 'done');
      },
      child: AppSheet(
        title: l10n.singleHandSavedTitle,
        heightFraction: null,
        onClose: () => _finish(SingleHandChoice.done, 'done'),
        trailing: _StarButton(on: _starred, onTap: _toggleStar),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              label: l10n.singleHandNotesHint,
              hint: l10n.singleHandNotesHint,
              controller: _notesCtl,
              maxLines: 4,
              minLines: 2,
              keyboardType: TextInputType.multiline,
              showClearButton: false,
              onChanged: (_) {},
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.singleHandTags,
              style: AppTypography.ibm(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Wrap(
              spacing: AppSpacing.xxs,
              runSpacing: AppSpacing.xxs,
              children: [
                for (final t in tags.entries)
                  _TagChip(
                      label: t.value,
                      selected: _tags.contains(t.key),
                      onTap: () => _toggleTag(t.key)),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: l10n.singleHandViewHand,
              variant: AppButtonVariant.secondaryLarge,
              fullWidth: true,
              onTap: _view,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: l10n.singleHandLogAnother,
                    variant: AppButtonVariant.secondaryLarge,
                    onTap: () =>
                        _finish(SingleHandChoice.another, 'log_another'),
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
                Expanded(
                  child: AppButton(
                    label: l10n.singleHandDone,
                    onTap: () => _finish(SingleHandChoice.done, 'done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StarButton extends StatelessWidget {
  final bool on;
  final VoidCallback onTap;
  const _StarButton({required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Icon(
        on ? Icons.star_rounded : Icons.star_border_rounded,
        size: 32,
        color: on ? AppColors.warningAmber : AppColors.contentInactive,
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TagChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accentPrimary.withValues(alpha: 0.15)
              : Colors.transparent,
          border: Border.all(
              color:
                  selected ? AppColors.accentPrimary : AppColors.borderStrong),
          borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
        ),
        child: Text(
          label,
          style: AppTypography.ibm(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.accentPrimary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
