import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../utils/poker_positions.dart';
import '../services/skip_hand_scouting_service.dart';
import '../design_system/components/sheets/app_sheet.dart';
import '../design_system/components/buttons/primary_pill_button.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';

/// Bottom sheet that captures the preflop action after the hero folds and taps
/// Next Hand. Each opponent chip cycles Fold → Call → Raise; raises are badged
/// with their order (1st = open, 2nd = 3-bet). When there is a 3-bet, an
/// opener-response row appears. Returns a [SkipScoutResult] or `null` if
/// dismissed / skipped.
class SkipHandScoutingSheet extends StatefulWidget {
  final Map<int, String> playerNames;
  final Set<int> activeSeats;
  final int heroSeat;
  final int buttonPosition;

  const SkipHandScoutingSheet({
    super.key,
    required this.playerNames,
    required this.activeSeats,
    required this.heroSeat,
    required this.buttonPosition,
  });

  /// Show the sheet and return a result (null = dismissed / skipped).
  static Future<SkipScoutResult?> show({
    required BuildContext context,
    required Map<int, String> playerNames,
    required Set<int> activeSeats,
    required int heroSeat,
    required int buttonPosition,
  }) {
    return showModalBottomSheet<SkipScoutResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SkipHandScoutingSheet(
        playerNames: playerNames,
        activeSeats: activeSeats,
        heroSeat: heroSeat,
        buttonPosition: buttonPosition,
      ),
    );
  }

  @override
  State<SkipHandScoutingSheet> createState() => _SkipHandScoutingSheetState();
}

class _SkipHandScoutingSheetState extends State<SkipHandScoutingSheet> {
  /// seat → chosen action (fold default).
  final Map<int, SkipSeatAction> _seatActions = {};

  /// Seats that raised, in the order they were marked (open, 3-bet, …).
  final List<int> _raiseOrder = [];

  /// Opener's response to a 3-bet (only used when there are ≥2 raises).
  OpenerResponse _openerResponse = OpenerResponse.fold;

  /// Named opponents (non-position-name, non-hero) in preflop action order.
  List<MapEntry<int, String>> _namedOpponents() {
    final sorted = widget.activeSeats.toList()..sort();
    final result = <MapEntry<int, String>>[];
    for (final seat in sorted) {
      if (seat == widget.heroSeat) continue;
      final name = widget.playerNames[seat];
      if (name == null || name.isEmpty) continue;
      if (PokerPositions.isPositionName(name)) continue;
      result.add(MapEntry(seat, name));
    }
    return result;
  }

  void _cycle(int seat) {
    setState(() {
      final current = _seatActions[seat] ?? SkipSeatAction.fold;
      // Leaving raise → drop from order.
      if (current == SkipSeatAction.raise) _raiseOrder.remove(seat);

      final next = SkipSeatAction.values[
          (current.index + 1) % SkipSeatAction.values.length];
      _seatActions[seat] = next;

      // Entering raise → append to order.
      if (next == SkipSeatAction.raise && !_raiseOrder.contains(seat)) {
        _raiseOrder.add(seat);
      }
    });
  }

  bool get _anyRaise => _raiseOrder.isNotEmpty;
  bool get _isThreeBet => _raiseOrder.length >= 2;

  void _submit() {
    if (!_anyRaise) {
      Navigator.pop(context, const SkipScoutResult.noRaise());
      return;
    }
    Navigator.pop(
      context,
      SkipScoutResult.detailed(
        seatActions: Map<int, SkipSeatAction>.from(_seatActions),
        raiseOrder: List<int>.from(_raiseOrder),
        openerResponse: _isThreeBet ? _openerResponse : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final named = _namedOpponents();
    final sortedSeats = widget.activeSeats.toList()..sort();

    return AppSheet(
      title: l10n.skipScoutTitle,
      onClose: () => Navigator.pop(context),
      heightFraction: null,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (named.isNotEmpty) ...[
            Text(
              l10n.skipScoutInstruction,
              style: AppTypography.ibm(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
                height: 18 / 13,
              ),
            ),
            const SizedBox(height: 12),
            ...named.map((entry) {
              final position = PokerPositions.getPositionNameForActivePlayers(
                entry.key,
                widget.buttonPosition,
                sortedSeats,
              );
              final action = _seatActions[entry.key] ?? SkipSeatAction.fold;
              final raiseIdx = _raiseOrder.indexOf(entry.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _OpponentRow(
                  name: entry.value,
                  position: position,
                  action: action,
                  raiseOrder: raiseIdx >= 0 ? raiseIdx + 1 : null,
                  onTap: () => _cycle(entry.key),
                ),
              );
            }),
          ],

          // Opener-response step (only when the pot was 3-bet).
          if (_isThreeBet) ...[
            const SizedBox(height: 8),
            Text(
              l10n.skipScoutOpenerFaced3Bet,
              style: AppTypography.ibm(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 20 / 14,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _ResponseChip(
                  label: l10n.skipScoutOpenerFolded,
                  selected: _openerResponse == OpenerResponse.fold,
                  onTap: () =>
                      setState(() => _openerResponse = OpenerResponse.fold),
                ),
                const SizedBox(width: 8),
                _ResponseChip(
                  label: l10n.skipScoutOpenerCalled,
                  selected: _openerResponse == OpenerResponse.call,
                  onTap: () =>
                      setState(() => _openerResponse = OpenerResponse.call),
                ),
                const SizedBox(width: 8),
                _ResponseChip(
                  label: l10n.skipScoutOpener4Bet,
                  selected: _openerResponse == OpenerResponse.fourBet,
                  onTap: () =>
                      setState(() => _openerResponse = OpenerResponse.fourBet),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
          PrimaryPillButton(
            label: _anyRaise ? l10n.skipScoutDone : l10n.skipScoutNoRaise,
            onTap: _submit,
          ),
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  l10n.skipScoutSkip,
                  style: AppTypography.ibm(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 20 / 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A row: opponent name + position badge on the left, a Fold/Call/Raise state
/// chip on the right that cycles on tap.
class _OpponentRow extends StatelessWidget {
  final String name;
  final String position;
  final SkipSeatAction action;
  final int? raiseOrder; // 1-based order badge when raised
  final VoidCallback onTap;

  const _OpponentRow({
    required this.name,
    required this.position,
    required this.action,
    required this.raiseOrder,
    required this.onTap,
  });

  ({Color bg, Color fg, String key}) _style() {
    switch (action) {
      case SkipSeatAction.raise:
        return (bg: AppColors.accentDanger, fg: Colors.white, key: 'raise');
      case SkipSeatAction.call:
        return (bg: AppColors.accentInfo, fg: Colors.white, key: 'call');
      case SkipSeatAction.fold:
        return (bg: AppColors.bgElevated, fg: AppColors.textSecondary, key: 'fold');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = _style();
    final label = switch (action) {
      SkipSeatAction.fold => l10n.skipScoutActionFold,
      SkipSeatAction.call => l10n.skipScoutActionCall,
      SkipSeatAction.raise => l10n.skipScoutActionRaise,
    };

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        ),
        child: Row(
          children: [
            // Name + position badge
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.ibm(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                        height: 20 / 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.bgOverlay,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      position,
                      style: AppTypography.ibm(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        height: 14 / 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Raise-order badge (e.g. "1st", "2nd") when raised
            if (raiseOrder != null) ...[
              Text(
                _ordinal(raiseOrder!),
                style: AppTypography.ibm(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
            ],
            // State chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: s.bg,
                borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
              ),
              child: Text(
                label,
                style: AppTypography.ibm(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: s.fg,
                  height: 18 / 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _ordinal(int n) {
    switch (n) {
      case 1:
        return '1st';
      case 2:
        return '2nd';
      case 3:
        return '3rd';
      default:
        return '${n}th';
    }
  }
}

/// A small selectable chip for the opener-response step.
class _ResponseChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ResponseChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentPrimary : AppColors.bgElevated,
          borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
        ),
        child: Text(
          label,
          style: AppTypography.ibm(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.black : AppColors.textPrimary,
            height: 18 / 13,
          ),
        ),
      ),
    );
  }
}
