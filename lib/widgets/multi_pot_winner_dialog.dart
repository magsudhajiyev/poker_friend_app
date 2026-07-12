import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../design_system/components/app_toggle.dart';
import '../design_system/components/bodies/player_selection_list.dart';
import '../design_system/components/sheets/app_sheet.dart';
import '../l10n/app_localizations.dart';
import '../models/game_types.dart';
import '../models/poker_game_state.dart';
import '../services/currency_service.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';

class MultiPotWinnerDialog extends StatefulWidget {
  final List<SidePot> sidePots;
  final List<String> playerNames;
  final Map<int, String> playerIdToName; // Map player ID to name with position
  final GameType gameType;
  final int buttonPosition;
  final int playerCount;
  final int? heroSeat;

  const MultiPotWinnerDialog({
    super.key,
    required this.sidePots,
    required this.playerNames,
    required this.playerIdToName,
    required this.buttonPosition,
    required this.playerCount,
    this.gameType = GameType.cash,
    this.heroSeat,
  });

  /// Show as a bottom sheet and return the result
  static Future<Map<String, dynamic>?> show({
    required BuildContext context,
    required List<SidePot> sidePots,
    required List<String> playerNames,
    required Map<int, String> playerIdToName,
    required int buttonPosition,
    required int playerCount,
    GameType gameType = GameType.cash,
    int? heroSeat,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => MultiPotWinnerDialog(
        sidePots: sidePots,
        playerNames: playerNames,
        playerIdToName: playerIdToName,
        buttonPosition: buttonPosition,
        playerCount: playerCount,
        gameType: gameType,
        heroSeat: heroSeat,
      ),
    );
  }

  @override
  State<MultiPotWinnerDialog> createState() => _MultiPotWinnerDialogState();
}

class _MultiPotWinnerDialogState extends State<MultiPotWinnerDialog> {
  // Map of pot index -> selected winner(s)
  Map<int, int?> singleWinners = {};
  Map<int, Set<int>> choppedWinners = {};
  Map<int, bool> isChoppedPot = {};

  // Track which side pots are auto-awarded to main pot winner
  Set<int> autoAwardedPots = {};

  @override
  void initState() {
    super.initState();
    // Initialize state for each pot
    for (int i = 0; i < widget.sidePots.length; i++) {
      singleWinners[i] = null;
      choppedWinners[i] = <int>{};
      isChoppedPot[i] = false;
    }
  }

  String _getPlayerName(int playerId) {
    final l10n = AppLocalizations.of(context);
    if (widget.heroSeat != null && playerId == widget.heroSeat) {
      return l10n.handToActYou;
    }
    return widget.playerIdToName[playerId] ?? l10n.multiPotPlayerFallback('$playerId');
  }

  String _formatAmount(double amount) {
    return widget.gameType == GameType.cash
        ? CurrencyService.formatCash(amount)
        : CurrencyService.formatChips(amount);
  }

  int _getPositionOrder(int playerId) {
    final buttonPos = widget.buttonPosition;
    final totalPlayers = widget.playerCount;

    int positionFromButton;
    if (playerId > buttonPos) {
      positionFromButton = playerId - buttonPos;
    } else {
      positionFromButton = (totalPlayers - buttonPos) + playerId;
    }

    return positionFromButton;
  }

  Map<int, double> _calculateIndividualShares(int potIndex, double potAmount, Set<int> winners) {
    if (winners.isEmpty) return {};

    // Tournaments chop to whole chips, cash games to cents — otherwise
    // cash chops silently lose the cent remainder.
    final numWinners = winners.length;
    final unit = widget.gameType == GameType.cash ? 0.01 : 1.0;
    final totalUnits = (potAmount / unit).round();
    final baseUnits = totalUnits ~/ numWinners;
    final extraUnits = totalUnits % numWinners;

    final sortedWinners = winners.toList()..sort((a, b) {
      final positionA = _getPositionOrder(a);
      final positionB = _getPositionOrder(b);
      return positionA.compareTo(positionB);
    });

    Map<int, double> shares = {};
    for (int i = 0; i < sortedWinners.length; i++) {
      final winnerId = sortedWinners[i];
      final units = baseUnits + (i < extraUnits ? 1 : 0);
      shares[winnerId] = units * unit;
    }

    return shares;
  }

  bool _isMainPotWinnerEligibleFor(int potIndex) {
    final mainPotWinner = isChoppedPot[0] == true
        ? null
        : singleWinners[0];

    if (mainPotWinner == null) return false;

    return widget.sidePots[potIndex].eligiblePlayers.contains(mainPotWinner);
  }

  void _updateAutoAwards() {
    autoAwardedPots.clear();

    int? currentWinner = isChoppedPot[0] == true ? null : singleWinners[0];

    for (int i = 1; i < widget.sidePots.length; i++) {
      if (currentWinner != null &&
          widget.sidePots[i].eligiblePlayers.contains(currentWinner)) {
        autoAwardedPots.add(i);
        singleWinners[i] = currentWinner;
        isChoppedPot[i] = false;
        choppedWinners[i] = <int>{};
      } else {
        if (isChoppedPot[i] == true) {
          currentWinner = null;
        } else if (singleWinners[i] != null) {
          currentWinner = singleWinners[i];
        } else {
          currentWinner = null;
        }
      }
    }
  }

  bool _isFormValid() {
    for (int i = 0; i < widget.sidePots.length; i++) {
      if (autoAwardedPots.contains(i)) continue;

      final isChopped = isChoppedPot[i] ?? false;
      if (isChopped) {
        if (choppedWinners[i]?.isEmpty ?? true) {
          return false;
        }
      } else {
        if (singleWinners[i] == null) {
          return false;
        }
      }
    }
    return true;
  }

  Map<String, dynamic> _buildResult() {
    Map<int, Map<String, dynamic>> potResults = {};

    for (int i = 0; i < widget.sidePots.length; i++) {
      final isChopped = isChoppedPot[i] ?? false;
      final sidePot = widget.sidePots[i];

      if (isChopped) {
        final winners = choppedWinners[i]!;
        potResults[i] = {
          'isChoppedPot': true,
          'winners': winners.toList(),
          'individualShares': _calculateIndividualShares(i, sidePot.amount, winners),
          'potAmount': sidePot.amount,
        };
      } else {
        potResults[i] = {
          'isChoppedPot': false,
          'winner': singleWinners[i],
          'potAmount': sidePot.amount,
        };
      }
    }

    return {
      'potResults': potResults,
      'sidePots': widget.sidePots,
    };
  }

  void _onSave() {
    if (_isFormValid()) {
      Navigator.pop(context, _buildResult());
    }
  }

  Widget _buildPlayerRadio(int potIndex, int playerId, String playerName) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PlayerSelectionRow(
        label: playerName,
        selected: singleWinners[potIndex] == playerId,
        mode: PlayerSelectionMode.radio,
        onTap: () {
          setState(() {
            singleWinners[potIndex] = playerId;
            _updateAutoAwards();
          });
        },
      ),
    );
  }

  Widget _buildPlayerCheckbox(int potIndex, int playerId, String playerName) {
    final isSelected = choppedWinners[potIndex]?.contains(playerId) ?? false;
    final winners = choppedWinners[potIndex] ?? <int>{};
    Widget? trailing;
    if (isSelected && winners.length > 1) {
      final share = _calculateIndividualShares(
              potIndex, widget.sidePots[potIndex].amount, winners)[playerId] ??
          0;
      trailing = Text(
        _formatAmount(share),
        style: AppTypography.ibm(
          fontSize: 14,
          color: AppColors.accentPrimary,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PlayerSelectionRow(
        label: playerName,
        selected: isSelected,
        mode: PlayerSelectionMode.checkbox,
        trailing: trailing,
        onTap: () {
          setState(() {
            if (isSelected) {
              choppedWinners[potIndex]!.remove(playerId);
            } else {
              choppedWinners[potIndex]!.add(playerId);
            }
            _updateAutoAwards();
          });
        },
      ),
    );
  }

  Widget _buildPotSection(int potIndex) {
    final l10n = AppLocalizations.of(context);
    final sidePot = widget.sidePots[potIndex];
    final potName = potIndex == 0 ? l10n.multiPotMainPot : l10n.multiPotSidePot(potIndex);
    final isChopped = isChoppedPot[potIndex] ?? false;
    final eligiblePlayers = sidePot.eligiblePlayers;
    final isAutoAwarded = autoAwardedPots.contains(potIndex);

    // Auto-awarded simplified view
    if (isAutoAwarded && potIndex > 0) {
      final autoAwardWinner = singleWinners[potIndex]!;
      final winnerName = _getPlayerName(autoAwardWinner);
      final isMainPotWinner = singleWinners[0] == autoAwardWinner;
      final awardReason = isMainPotWinner ? l10n.multiPotMainPotWinner : l10n.multiPotEligibleFromPrevious;

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  potName,
                  style: AppTypography.ibm(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    height: 1.64,
                  ),
                ),
                Text(
                  _formatAmount(sidePot.amount),
                  style: AppTypography.ibm(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    height: 1.64,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.multiPotAutoAwarded(winnerName, awardReason),
              style: AppTypography.ibm(
                fontSize: 13,
                color: AppColors.textDisabled,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pot header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                potName,
                style: AppTypography.ibm(
                  fontSize: 15,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  height: 1.64,
                ),
              ),
              Text(
                _formatAmount(sidePot.amount),
                style: AppTypography.ibm(
                  fontSize: 15,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  height: 1.64,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Single Winner toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(AppDecorations.radius18),
              border: Border.all(color: AppColors.neutral800),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isChopped ? l10n.multiPotChoppedPot : l10n.multiPotSingleWinner,
                  style: AppTypography.ibm(
                    fontSize: 17,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                    height: 1.44,
                  ),
                ),
                AppToggle(
                  value: !isChopped,
                  onChanged: (value) {
                    setState(() {
                      isChoppedPot[potIndex] = !value;
                      singleWinners[potIndex] = null;
                      choppedWinners[potIndex] = <int>{};
                      _updateAutoAwards();
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Winner selection label
          Text(
            isChopped ? l10n.multiPotSelectAllWinners : l10n.multiPotSelectTheWinner,
            style: AppTypography.ibm(
              fontSize: 15,
              color: Colors.white,
              fontWeight: FontWeight.w500,
              height: 1.64,
            ),
          ),
          const SizedBox(height: 14),

          // Player list
          ...eligiblePlayers.map((playerId) {
            final playerName = _getPlayerName(playerId);
            if (isChopped) {
              return _buildPlayerCheckbox(potIndex, playerId, playerName);
            } else {
              return _buildPlayerRadio(potIndex, playerId, playerName);
            }
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final valid = _isFormValid();
    return AppSheet(
      title: l10n.multiPotSelectWinnersTitle,
      trailing: _SaveCheck(enabled: valid, onTap: _onSave),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.multiPotMultiplePots,
            style: AppTypography.ibm(
              fontSize: 17,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w400,
              height: 1.44,
            ),
          ),
          const SizedBox(height: 24),
          Column(
            children: List.generate(
              widget.sidePots.length,
              (index) => _buildPotSection(index),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SaveCheck extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _SaveCheck({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: enabled ? AppColors.accentPrimary : AppColors.neutral700,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: SvgPicture.asset(
            'icons/figma_icons/check.svg',
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(
              enabled ? AppColors.textInverse : AppColors.textDisabled,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}
