import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/game_types.dart';

class WinnerSelectionDialog extends StatefulWidget {
  final List<int> activePlayers;
  final List<String> playerNames;
  final double potAmount;
  final GameType gameType;
  final int buttonPosition;
  final int playerCount;

  const WinnerSelectionDialog({
    super.key,
    required this.activePlayers,
    required this.playerNames,
    required this.potAmount,
    required this.buttonPosition,
    required this.playerCount,
    this.gameType = GameType.cash,
  });

  @override
  State<WinnerSelectionDialog> createState() => _WinnerSelectionDialogState();
}

class _WinnerSelectionDialogState extends State<WinnerSelectionDialog> {
  int? selectedWinner;
  Set<int> selectedWinners = <int>{};
  bool isChoppedPot = false;

  String _formatCurrency(double amount) {
    if (widget.gameType == GameType.cash) {
      return '\$${amount.toStringAsFixed(2)}';
    } else {
      return '${amount.toInt()}';
    }
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

    final numWinners = selectedWinners.length;
    final baseShare = (widget.potAmount / numWinners).floor().toDouble();
    final extraChips = (widget.potAmount % numWinners).toInt();

    final sortedWinners = selectedWinners.toList()..sort((a, b) {
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
    final playerIndex = widget.activePlayers.indexOf(playerId);

    if (playerIndex >= 0 && playerIndex < widget.playerNames.length) {
      return widget.playerNames[playerIndex];
    }

    return 'Player $playerId';
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
          // Single-tap in normal mode → immediately select and save
          selectedWinner = playerId;
          _saveChanges();
        }
      },
      onLongPress: () {
        // Long-press enters chopped pot mode with this player pre-selected
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF101115),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            // Radio/Checkbox circle
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF89F1EC) : const Color(0xFF555555),
                  width: isSelected ? 2 : 1.5,
                ),
                color: isSelected ? const Color(0xFF89F1EC) : Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: isChoppedPot ? 10 : 8,
                        height: isChoppedPot ? 10 : 8,
                        decoration: BoxDecoration(
                          shape: isChoppedPot ? BoxShape.rectangle : BoxShape.circle,
                          color: isChoppedPot ? Colors.transparent : Colors.black,
                          borderRadius: isChoppedPot ? BorderRadius.circular(2) : null,
                        ),
                        child: isChoppedPot
                            ? const Icon(Icons.check, size: 10, color: Colors.black)
                            : null,
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
                  color: Colors.white,
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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      alignment: Alignment.bottomCenter,
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
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
          mainAxisSize: MainAxisSize.min,
          children: [
            // Overlay Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // X close button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Color(0xFF35373C),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'icons/figma_icons/close.svg',
                          width: 16,
                          height: 16,
                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),
                  // Title
                  Expanded(
                    child: Center(
                      child: Text(
                        isChoppedPot ? 'Who chopped this pot?' : 'Who won this hand?',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: -0.43,
                        ),
                      ),
                    ),
                  ),
                  // Green checkmark button
                  GestureDetector(
                    onTap: _canSave ? _saveChanges : null,
                    child: Opacity(
                      opacity: _canSave ? 1.0 : 0.4,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: Color(0xFF54E98A),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            'icons/figma_icons/check.svg',
                            width: 16,
                            height: 16,
                            colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                          ),
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
                padding: const EdgeInsets.fromLTRB(16, 34, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Chopped pot indicator (only visible in chopped mode)
                    if (isChoppedPot)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B4341),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF4B9A96)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.call_split, color: Color(0xFF73D4CF), size: 18),
                            const SizedBox(width: 10),
                            Text(
                              'Chopped Pot',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF73D4CF),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF101115),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Individual shares:',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF8C8C8C),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._calculateIndividualShares().entries.map((entry) {
                              final playerDisplayName = _getPlayerDisplayName(entry.key);
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        playerDisplayName,
                                        style: GoogleFonts.ibmPlexSans(
                                          fontSize: 14,
                                          color: const Color(0xFF89F1EC),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      _formatCurrency(entry.value),
                                      style: GoogleFonts.ibmPlexSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF89F1EC),
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

                    const SizedBox(height: 24),

                    // "Select the winner:" label
                    Text(
                      isChoppedPot ? 'Select all winners:' : 'Tap the winner:',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                        height: 1.44,
                      ),
                    ),
                    if (!isChoppedPot)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Long-press for chopped pot',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),

                    // Player rows
                    ...widget.activePlayers.map((playerId) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildPlayerRow(playerId),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Bottom buttons — only show in chopped pot mode (single-tap handles normal mode)
            if (isChoppedPot)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 34, 16, 34),
                child: Column(
                  children: [
                    // Save button
                    GestureDetector(
                      onTap: _canSave ? _saveChanges : null,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _canSave
                              ? const Color(0xFF89F1EC)
                              : const Color(0xFF89F1EC).withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(110),
                        ),
                        child: Center(
                          child: Text(
                            'Confirm Chop',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                              letterSpacing: -0.5,
                              height: 24 / 17,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Back to single winner
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
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(110),
                          border: Border.all(
                            color: const Color(0xFFD3FFFD),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Back to Single Winner',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFD3FFFD),
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
          ],
        ),
      ),
    );
  }
}
