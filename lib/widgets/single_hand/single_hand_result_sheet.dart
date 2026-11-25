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
import '../../design_system/components/dividers/list_separator.dart';
import '../../models/single_hand_group.dart';
import '../../models/single_hand_setup.dart';
import '../../services/free_tier_limits.dart';
import '../../services/single_hand_service.dart';
import '../../utils/user_facing_error.dart';

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

  /// Setup v2 only: shows "Saved to <group>" with a Change action. [setup]
  /// and [newGroupName] describe a new group when the player picks one.
  final bool showGroupChange;
  final SingleHandSetup? setup;
  final String? newGroupName;

  /// Called after the hand was moved, so the caller can follow the new group.
  final ValueChanged<SingleHandMoveResult>? onMoved;

  const SingleHandResultSheet({
    super.key,
    required this.hand,
    required this.saved,
    this.showGroupChange = false,
    this.setup,
    this.newGroupName,
    this.onMoved,
  });

  /// Null (system back) counts as [SingleHandChoice.done].
  static Future<SingleHandChoice?> show(
    BuildContext context, {
    required HandRecord hand,
    required SingleHandSaveResult saved,
    bool showGroupChange = false,
    SingleHandSetup? setup,
    String? newGroupName,
    ValueChanged<SingleHandMoveResult>? onMoved,
  }) {
    return showModalBottomSheet<SingleHandChoice>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => SingleHandResultSheet(
        hand: hand,
        saved: saved,
        showGroupChange: showGroupChange,
        setup: setup,
        newGroupName: newGroupName,
        onMoved: onMoved,
      ),
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

  late String _sessionId = widget.saved.sessionId;
  late String _handId = widget.saved.handId;
  late int _handNumber = widget.saved.handNumber;
  late SingleHandGroup _group = widget.saved.group;
  bool _moving = false;

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

  /// Moves the saved hand to another recent group, or to a new one.
  Future<void> _changeGroup() async {
    if (_moving) return;
    final l10n = AppLocalizations.of(context);
    List<SingleHandGroup> groups = const [];
    try {
      groups = await SingleHandService.recentGroups();
    } catch (e) {
      LoggerService.log('SingleHand recent groups failed: $e',
          level: LogLevel.WARNING);
    }
    if (!mounted) return;
    final pick = await AppSheet.show<_MovePick>(
      context: context,
      title: l10n.singleHandV2MoveTitle,
      heightFraction: null,
      body: _MoveGroupList(
          groups: groups.where((g) => g.sessionId != _sessionId).toList()),
    );
    if (pick == null || !mounted) return;
    await _move(pick.group);
  }

  Future<void> _move(SingleHandGroup? to) async {
    setState(() => _moving = true);
    try {
      final r = await SingleHandService.moveHandToGroup(
        fromGroupId: _sessionId,
        handId: _handId,
        handNumber: _handNumber,
        toGroupId: to?.sessionId,
        setup: widget.setup,
        groupName: widget.newGroupName,
      );
      if (!mounted) return;
      final g = r.group;
      setState(() {
        _sessionId = r.sessionId;
        _handId = r.handId;
        _handNumber = r.handNumber;
        _group = g;
      });
      widget.onMoved?.call(SingleHandMoveResult(
        handId: r.handId,
        sessionId: r.sessionId,
        handNumber: r.handNumber,
        group: g,
      ));
    } on SingleHandGroupFullException {
      if (mounted) await FreeTierLimits.showHandsLimitDialog(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(UserFacingError.message(e)),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _moving = false);
    }
  }

  Widget _savedToRow(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.singleHandV2SavedTo(_group.name, _group.handCount),
              key: const ValueKey('saved-to'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _moving ? null : _changeGroup,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxs, vertical: AppSpacing.xxs),
              child: Text(
                l10n.singleHandChange,
                key: const ValueKey('saved-to-change'),
                style: AppTypography.ibm(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _moving
                      ? AppColors.contentDisabled
                      : AppColors.accentPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
      ..['handNumber'] = _handNumber
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
            if (widget.showGroupChange) _savedToRow(l10n),
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

class _MovePick {
  final SingleHandGroup? group; // null = new group
  const _MovePick(this.group);
}

class _MoveGroupList extends StatelessWidget {
  final List<SingleHandGroup> groups;
  const _MoveGroupList({required this.groups});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget row(String title, String? sub, SingleHandGroup? g) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context, _MovePick(g)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.listRowLabel()),
                    if (sub != null)
                      Text(sub,
                          style: AppTypography.bodySmall(
                              color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        row(l10n.singleHandNewGroup, null, null),
        for (final g in groups) ...[
          const ListSeparator(),
          row(g.name, l10n.singleHandGroupHands(g.handCount), g),
        ],
      ],
    );
  }
}
