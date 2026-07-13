import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/game_types.dart';
import '../onboarding/onboarding_state.dart';
import '../services/currency_service.dart';
import '../design_system/components/bodies/player_selection_list.dart';
import '../design_system/components/sheets/app_sheet.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';
import '../design_system/constants/typography.dart';

class WinnerSelectionDialog extends StatefulWidget {
  final List<int> activePlayers;
  final List<String> playerNames;
  final double potAmount;
  final GameType gameType;
  final int buttonPosition;
  final int playerCount;
  final int? heroSeat;

  const WinnerSelectionDialog({
    super.key,
    required this.activePlayers,
    required this.playerNames,
    required this.potAmount,
    required this.buttonPosition,
    required this.playerCount,
    this.gameType = GameType.cash,
    this.heroSeat,
  });

  /// Present as a modal bottom sheet and resolve with the caller-selected
  /// winner map (null if dismissed).
  static Future<Map<String, dynamic>?> show({
    required BuildContext context,
    required List<int> activePlayers,
    required List<String> playerNames,
    required double potAmount,
    required int buttonPosition,
    required int playerCount,
    GameType gameType = GameType.cash,
    int? heroSeat,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WinnerSelectionDialog(
        activePlayers: activePlayers,
        playerNames: playerNames,
        potAmount: potAmount,
        buttonPosition: buttonPosition,
        playerCount: playerCount,
        gameType: gameType,
        heroSeat: heroSeat,
      ),
    );
  }

  @override
  State<WinnerSelectionDialog> createState() => _WinnerSelectionDialogState();
}

class _WinnerSelectionDialogState extends State<WinnerSelectionDialog> {
  int? selectedWinner;
  Set<int> selectedWinners = <int>{};
  bool isChoppedPot = false;

  String _formatAmount(double amount) {
    return widget.gameType == GameType.cash
        ? CurrencyService.formatCash(amount)
        : CurrencyService.formatChips(amount);
  }

  double _getSharePerWinner() {
    if (isChoppedPot && selectedWinners.isNotEmpty) {
      return widget.potAmount / selectedWinners.length;
    }
    return widget.potAmount;
  }

  Map<int, double> _calculateIndividualShares() {
    if (!isChoppedPot || selectedWinners.isEmpty) {
      return {};
    }

    // Tournaments chop to whole chips, cash games to cents — otherwise
    // cash chops silently lose the cent remainder.
    final numWinners = selectedWinners.length;
    final unit = widget.gameType == GameType.cash ? 0.01 : 1.0;
    final totalUnits = (widget.potAmount / unit).round();
    final baseUnits = totalUnits ~/ numWinners;
    final extraUnits = totalUnits % numWinners;

    final sortedWinners = selectedWinners.toList()
      ..sort((a, b) {
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

  String _getPlayerDisplayName(int playerId) {
    if (widget.heroSeat != null && playerId == widget.heroSeat) {
      return AppLocalizations.of(context).handToActYou;
    }

    final playerIndex = widget.activePlayers.indexOf(playerId);

    if (playerIndex >= 0 && playerIndex < widget.playerNames.length) {
      return widget.playerNames[playerIndex];
    }

    return AppLocalizations.of(context).multiPotPlayerFallback('$playerId');
  }

  void _saveChanges() {
    if (isChoppedPot) {
      if (selectedWinners.isNotEmpty) {
        Navigator.pop(context, {
          'isChoppedPot': true,
          'winners': selectedWinners.toList(),
          'individualShares': _calculateIndividualShares(),
          'sharePerWinner': _getSharePerWinner(),
        });
      }
    } else {
      if (selectedWinner != null) {
        Navigator.pop(context, {
          'isChoppedPot': false,
          'winner': selectedWinner,
          'sharePerWinner': widget.potAmount,
        });
      }
    }
  }

  bool get _canSave {
    if (isChoppedPot) return selectedWinners.isNotEmpty;
    return selectedWinner != null;
  }

  Widget _buildPlayerRow(int playerId) {
    final playerDisplayName = _getPlayerDisplayName(playerId);
    final bool isSelected = isChoppedPot
        ? selectedWinners.contains(playerId)
        : selectedWinner == playerId;
    return PlayerSelectionRow(
      label: playerDisplayName,
      selected: isSelected,
      mode: isChoppedPot
          ? PlayerSelectionMode.checkbox
          : PlayerSelectionMode.radio,
      accentColor: AppColors.accentSecondary,
      onTap: () {
        if (isChoppedPot) {
          setState(() {
            if (selectedWinners.contains(playerId)) {
              selectedWinners.remove(playerId);
            } else {
              selectedWinners.add(playerId);
            }
          });
        } else {
          setState(() {
            selectedWinner = selectedWinner == playerId ? null : playerId;
          });
        }
      },
      onLongPress: () {
        if (!isChoppedPot) {
          setState(() {
            isChoppedPot = true;
            selectedWinner = null;
            selectedWinners.clear();
            selectedWinners.add(playerId);
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppSheet(
      title: isChoppedPot
          ? l10n.winnerSelectionWhoChopped
          : l10n.winnerSelectionWhoWon,
      heightFraction: 0.75,
      body: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Chopped pot indicator
                    if (isChoppedPot)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.accentPrimary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
                          border: Border.all(color: AppColors.accentPrimary),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.call_split,
                                color: AppColors.textPrimary, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              l10n.winnerSelectionChoppedPot,
                              style: AppTypography.ibm(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                                height: 1.44,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Individual shares display for chopped pot
                    if (isChoppedPot && selectedWinners.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.bgElevated,
                          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.winnerSelectionIndividualShares,
                              style: AppTypography.ibm(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.borderLight,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._calculateIndividualShares()
                                .entries
                                .map((entry) {
                              final playerDisplayName =
                                  _getPlayerDisplayName(entry.key);
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        playerDisplayName,
                                        style: AppTypography.ibm(
                                          fontSize: 14,
                                          color: AppColors.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      _formatAmount(entry.value),
                                      style: AppTypography.ibm(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Instruction label
                    Text(
                      isChoppedPot
                          ? l10n.winnerSelectionSelectAllWinners
                          : l10n.winnerSelectionTapTheWinner,
                      style: AppTypography.ibm(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                        height: 1.44,
                      ),
                    ),
                    if (!isChoppedPot)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          l10n.winnerSelectionLongPressHint,
                          style: AppTypography.ibm(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: AppColors.borderLight,
                          ),
                        ),
                      ),

                    // Tour tip — chop pot hint
                    if (!isChoppedPot && OnboardingState.isGuidedHandActive)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.accentPrimary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                            border: Border.all(
                              color: AppColors.accentPrimary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.touch_app_rounded,
                                color: AppColors.accentPrimary,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Tip: Press and hold a player to split the pot between multiple winners',
                                  style: AppTypography.ibm(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.accentPrimary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Player rows
                    ...widget.activePlayers.map((playerId) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildPlayerRow(playerId),
                      );
                    }),
                    const SizedBox(height: 24),
                    // Confirm button
                    GestureDetector(
                      onTap: _canSave ? _saveChanges : null,
                      child: Opacity(
                        opacity: _canSave ? 1.0 : 0.35,
                        child: Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.bgInverse,
                            borderRadius: BorderRadius.circular(
                                AppDecorations.radiusFull),
                          ),
                          child: Center(
                            child: Text(
                              isChoppedPot
                                  ? l10n.winnerSelectionConfirmChop
                                  : l10n.winnerSelectionConfirmWinner,
                              style: AppTypography.ibm(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textInverse,
                                letterSpacing: -0.5,
                                height: 20 / 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (isChoppedPot) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            isChoppedPot = false;
                            selectedWinners.clear();
                            selectedWinner = null;
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(
                                AppDecorations.radiusFull),
                            border:
                                Border.all(color: AppColors.borderLight),
                          ),
                          child: Center(
                            child: Text(
                              l10n.winnerSelectionBackToSingle,
                              style: AppTypography.ibm(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.5,
                                height: 20 / 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }
}
