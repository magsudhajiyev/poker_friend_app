import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../design_system/components/app_toggle.dart';
import '../l10n/app_localizations.dart';
import '../models/game_types.dart';
import '../models/poker_game_state.dart';

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

  String _formatCurrency(double amount) {
    if (widget.gameType == GameType.cash) {
      return '\$${amount.toStringAsFixed(2)}';
    } else {
      return '${amount.toInt()}';
    }
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

    final numWinners = winners.length;
    final baseShare = (potAmount / numWinners).floor().toDouble();
    final extraChips = (potAmount % numWinners).toInt();

    final sortedWinners = winners.toList()..sort((a, b) {
      final positionA = _getPositionOrder(a);
      final positionB = _getPositionOrder(b);
      return positionA.compareTo(positionB);
    });

    Map<int, double> shares = {};
    for (int i = 0; i < sortedWinners.length; i++) {
      final winnerId = sortedWinners[i];
      final extraChip = i < extraChips ? 1.0 : 0.0;
      shares[winnerId] = baseShare + extraChip;
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
    final isSelected = singleWinners[potIndex] == playerId;

    return GestureDetector(
      onTap: () {
        setState(() {
          singleWinners[potIndex] = playerId;
          _updateAutoAwards();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF101115) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF73D4CF) : const Color(0xFF1B1E24),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Radio dot
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF73D4CF) : const Color(0xFF555555),
                  width: 1,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF73D4CF),
                          border: Border.all(color: const Color(0xFF73D4CF), width: 2),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                playerName,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 17,
                  color: Colors.white,
                  fontWeight: FontWeight.w400,
                  height: 1.44,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerCheckbox(int potIndex, int playerId, String playerName) {
    final isSelected = choppedWinners[potIndex]?.contains(playerId) ?? false;

    return GestureDetector(
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF101115) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF73D4CF) : const Color(0xFF1B1E24),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: isSelected ? const Color(0xFF73D4CF) : Colors.transparent,
                border: Border.all(
                  color: isSelected ? const Color(0xFF73D4CF) : const Color(0xFF555555),
                  width: 1,
                ),
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(Icons.check, size: 14, color: Colors.black),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                playerName,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 17,
                  color: Colors.white,
                  fontWeight: FontWeight.w400,
                  height: 1.44,
                ),
              ),
            ),
            if (isSelected) ...[
              // Show share amount if chopped
              if (choppedWinners[potIndex]!.length > 1)
                Text(
                  _formatCurrency(
                    _calculateIndividualShares(
                      potIndex,
                      widget.sidePots[potIndex].amount,
                      choppedWinners[potIndex]!,
                    )[playerId] ?? 0,
                  ),
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    color: const Color(0xFF89F1EC),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ],
        ),
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
          color: const Color(0xFF101115),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  potName,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    height: 1.64,
                  ),
                ),
                Text(
                  _formatCurrency(sidePot.amount),
                  style: GoogleFonts.ibmPlexSans(
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
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                color: const Color(0xFF8C8C8C),
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
        color: const Color(0xFF101115),
        borderRadius: BorderRadius.circular(16),
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
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 15,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  height: 1.64,
                ),
              ),
              Text(
                _formatCurrency(sidePot.amount),
                style: GoogleFonts.ibmPlexSans(
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
              color: const Color(0xFF02050B),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF1B1E24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isChopped ? l10n.multiPotChoppedPot : l10n.multiPotSingleWinner,
                  style: GoogleFonts.ibmPlexSans(
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
            style: GoogleFonts.ibmPlexSans(
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        border: Border.all(color: const Color(0xFF262626)),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF2E5A59),
            blurRadius: 64,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Close button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF35373C),
                      borderRadius: BorderRadius.circular(88),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'icons/figma_icons/close.svg',
                        width: 15,
                        height: 15,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
                // Title
                Text(
                  l10n.multiPotSelectWinnersTitle,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 17,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.43,
                  ),
                ),
                // Save button
                GestureDetector(
                  onTap: _isFormValid() ? _onSave : null,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _isFormValid()
                          ? const Color(0xFF89F1EC)
                          : const Color(0xFF35373C),
                      borderRadius: BorderRadius.circular(88),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'icons/figma_icons/check.svg',
                        width: 24,
                        height: 24,
                        colorFilter: ColorFilter.mode(
                          _isFormValid()
                              ? const Color(0xFF1A4A4A)
                              : const Color(0xFF8C8C8C),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 34, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    Text(
                      l10n.multiPotMultiplePots,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 17,
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                        height: 1.44,
                      ),
                    ),
                    const SizedBox(height: 34),

                    // Pot sections
                    ...List.generate(
                      widget.sidePots.length,
                      (index) => _buildPotSection(index),
                    ),

                    // Bottom buttons
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          // Save button
                          GestureDetector(
                            onTap: _isFormValid() ? _onSave : null,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _isFormValid()
                                    ? const Color(0xFF89F1EC)
                                    : const Color(0xFF35373C),
                                borderRadius: BorderRadius.circular(110),
                              ),
                              child: Center(
                                child: Text(
                                  l10n.commonSave,
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 17,
                                    color: _isFormValid()
                                        ? Colors.black
                                        : const Color(0xFF8C8C8C),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.5,
                                    height: 24 / 17,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Cancel button
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(110),
                                border: Border.all(
                                  color: const Color(0xFFD3FFFD),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  l10n.commonCancel,
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 17,
                                    color: const Color(0xFFD3FFFD),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.5,
                                    height: 24 / 17,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
