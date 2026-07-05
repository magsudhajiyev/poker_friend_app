import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../utils/poker_positions.dart';
import '../services/skip_hand_scouting_service.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';

/// Bottom sheet that asks "What happened?" after the hero taps Next Hand.
///
/// Returns a [SkipScoutResult] or `null` if dismissed.
class SkipHandScoutingSheet extends StatelessWidget {
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

  /// Named opponents (non-position-name, non-hero) sorted by seat.
  List<MapEntry<int, String>> _namedOpponents() {
    final sorted = activeSeats.toList()..sort();
    final result = <MapEntry<int, String>>[];
    for (final seat in sorted) {
      if (seat == heroSeat) continue;
      final name = playerNames[seat];
      if (name == null || name.isEmpty) continue;
      if (PokerPositions.isPositionName(name)) continue;
      result.add(MapEntry(seat, name));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final named = _namedOpponents();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final sortedSeats = activeSeats.toList()..sort();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppDecorations.radiusXl),
          topRight: Radius.circular(AppDecorations.radiusXl),
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.skipScoutTitle,
                  style: AppTypography.ibm(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textInverse,
                    height: 20 / 15,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 18, color: AppColors.contentInactive),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // "No one raised" pill
            _ActionPill(
              label: l10n.skipScoutNoRaise,
              onTap: () => Navigator.pop(context, const SkipScoutResult.noRaise()),
            ),

            // Opponent chips
            if (named.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: named.map((entry) {
                  final position = PokerPositions.getPositionNameForActivePlayers(
                    entry.key,
                    buttonPosition,
                    sortedSeats,
                  );
                  return _OpponentChip(
                    name: entry.value,
                    position: position,
                    onTap: () => Navigator.pop(
                      context,
                      SkipScoutResult.raised(entry.key),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 16),

            // Divider + Skip link
            const Divider(height: 1, color: Color(0xFFE5E5E5)),
            const SizedBox(height: 12),
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
      ),
    );
  }
}

/// Outlined pill button for "No one raised".
class _ActionPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ActionPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
          border: Border.all(color: AppColors.borderLight),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.ibm(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textInverse,
            height: 20 / 15,
          ),
        ),
      ),
    );
  }
}

/// Tappable chip showing opponent name + position badge.
class _OpponentChip extends StatelessWidget {
  final String name;
  final String position;
  final VoidCallback onTap;

  const _OpponentChip({
    required this.name,
    required this.position,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: AppTypography.ibm(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textInverse,
                height: 20 / 14,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                position,
                style: AppTypography.ibm(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF666666),
                  height: 14 / 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
