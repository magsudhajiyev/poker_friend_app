import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../models/game_types.dart';
import '../services/currency_service.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';

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
    final bool isSelected;

    if (isChoppedPot) {
      isSelected = selectedWinners.contains(playerId);
    } else {
      isSelected = selectedWinner == playerId;
    }

    return GestureDetector(
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
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.borderOnInverseSubtle,
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
          border: isSelected
              ? Border.all(color: AppColors.textOnInverse, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.textOnInverse
                      : AppColors.borderLight,
                  width: isSelected ? 2 : 1.5,
                ),
                color: isSelected ? AppColors.textOnInverse : Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child: isChoppedPot
                          ? Icon(Icons.check, size: 11, color: AppColors.bgInverse)
                          : Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.bgInverse,
                              ),
                            ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                playerDisplayName,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textOnInverse,
                  height: 1.44,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      alignment: Alignment.bottomCenter,
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height -
            MediaQuery.of(context).padding.top,
        decoration: BoxDecoration(
          color: AppColors.bgInverse,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppDecorations.radiusXl),
            topRight: Radius.circular(AppDecorations.radiusXl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderOnInverseSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header: spacer | title (centered) | X
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  const SizedBox(width: 28),
                  Expanded(
                    child: Center(
                      child: Text(
                        isChoppedPot
                            ? l10n.winnerSelectionWhoChopped
                            : l10n.winnerSelectionWhoWon,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textOnInverse,
                          letterSpacing: -0.43,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/icons/X.svg',
                          width: 18,
                          height: 18,
                          colorFilter: ColorFilter.mode(
                              AppColors.borderLight, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                child: Column(
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
                                color: AppColors.textOnInverse, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              l10n.winnerSelectionChoppedPot,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textOnInverse,
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
                          color: AppColors.borderOnInverseSubtle,
                          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.winnerSelectionIndividualShares,
                              style: GoogleFonts.ibmPlexSans(
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
                                        style: GoogleFonts.ibmPlexSans(
                                          fontSize: 14,
                                          color: AppColors.textOnInverse,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      _formatAmount(entry.value),
                                      style: GoogleFonts.ibmPlexSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textOnInverse,
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
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textOnInverse,
                        height: 1.44,
                      ),
                    ),
                    if (!isChoppedPot)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          l10n.winnerSelectionLongPressHint,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: AppColors.borderLight,
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
                  ],
                ),
              ),
            ),

            // Bottom buttons
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 24, 16, MediaQuery.of(context).padding.bottom + 24),
              child: Column(
                children: [
                  // Confirm button
                  GestureDetector(
                    onTap: _canSave ? _saveChanges : null,
                    child: Opacity(
                      opacity: _canSave ? 1.0 : 0.35,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.bgPrimary,
                          borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
                        ),
                        child: Center(
                          child: Text(
                            isChoppedPot
                                ? l10n.winnerSelectionConfirmChop
                                : l10n.winnerSelectionConfirmWinner,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.bgInverse,
                              letterSpacing: -0.5,
                              height: 20 / 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Back to single winner (chopped mode only)
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
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Center(
                          child: Text(
                            l10n.winnerSelectionBackToSingle,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textOnInverse,
                              letterSpacing: -0.5,
                              height: 20 / 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
