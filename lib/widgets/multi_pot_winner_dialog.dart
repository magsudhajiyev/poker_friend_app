import 'package:flutter/material.dart';
import '../models/game_types.dart';
import '../models/poker_game_state.dart';

class MultiPotWinnerDialog extends StatefulWidget {
  final List<SidePot> sidePots;
  final List<String> playerNames;
  final Map<int, String> playerIdToName; // Map player ID to name with position
  final GameType gameType;
  final int buttonPosition;
  final int playerCount;

  const MultiPotWinnerDialog({
    super.key,
    required this.sidePots,
    required this.playerNames,
    required this.playerIdToName,
    required this.buttonPosition,
    required this.playerCount,
    this.gameType = GameType.cash,
  });

  @override
  State<MultiPotWinnerDialog> createState() => _MultiPotWinnerDialogState();
}

class _MultiPotWinnerDialogState extends State<MultiPotWinnerDialog> {
  // Map of pot index -> selected winner(s)
  Map<int, int?> singleWinners = {};
  Map<int, Set<int>> choppedWinners = {};
  Map<int, bool> isChoppedPot = {};

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

  String _formatCurrency(double amount) {
    if (widget.gameType == GameType.cash) {
      return '\$${amount.toStringAsFixed(2)}';
    } else {
      return '${amount.toInt()}';
    }
  }

  int _getPositionOrder(int playerId) {
    // Calculate position order based on seat number relative to button
    // Lower numbers = earlier in position (out of position gets extra chips)
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

    // Sort winners by position (earliest/out-of-position first to get extra chips)
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

  Widget _buildPotSection(int potIndex) {
    final sidePot = widget.sidePots[potIndex];
    final potName = potIndex == 0 ? 'Main Pot' : 'Side Pot $potIndex';
    final isChopped = isChoppedPot[potIndex] ?? false;
    final eligiblePlayers = sidePot.eligiblePlayers;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pot header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  potName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _formatCurrency(sidePot.amount),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Chopped pot toggle
            Row(
              children: [
                Switch(
                  value: isChopped,
                  onChanged: (value) {
                    setState(() {
                      isChoppedPot[potIndex] = value;
                      // Clear selections when switching modes
                      singleWinners[potIndex] = null;
                      choppedWinners[potIndex] = <int>{};
                    });
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isChopped ? 'Chopped Pot' : 'Single Winner',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Individual shares display for chopped pots
            if (isChopped && (choppedWinners[potIndex]?.isNotEmpty ?? false)) ...[
              const Text(
                'Individual shares:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              ..._calculateIndividualShares(
                potIndex,
                sidePot.amount,
                choppedWinners[potIndex]!,
              ).entries.map((entry) {
                final playerId = entry.key;
                final amount = entry.value;
                final playerName = widget.playerIdToName[playerId] ?? 'Player $playerId';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          playerName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatCurrency(amount),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 8),
            ],

            // Winner selection
            Text(
              isChopped ? 'Select all winners:' : 'Select the winner:',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),

            // List of eligible players
            ...eligiblePlayers.map((playerId) {
              final playerName = widget.playerIdToName[playerId] ?? 'Player $playerId';

              if (isChopped) {
                return CheckboxListTile(
                  title: Text(playerName),
                  value: choppedWinners[potIndex]?.contains(playerId) ?? false,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        choppedWinners[potIndex]!.add(playerId);
                      } else {
                        choppedWinners[potIndex]!.remove(playerId);
                      }
                    });
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                );
              } else {
                return RadioListTile<int>(
                  title: Text(playerName),
                  value: playerId,
                  groupValue: singleWinners[potIndex],
                  onChanged: (value) {
                    setState(() {
                      singleWinners[potIndex] = value;
                    });
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                );
              }
            }).toList(),
          ],
        ),
      ),
    );
  }

  bool _isFormValid() {
    // Check if all pots have a winner selected
    for (int i = 0; i < widget.sidePots.length; i++) {
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
    // Build result structure: map of pot index -> winner info
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Winners'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Multiple pots - select winner for each pot',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(
              widget.sidePots.length,
              (index) => _buildPotSection(index),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isFormValid()
              ? () {
                  Navigator.pop(context, _buildResult());
                }
              : null,
          child: const Text('Confirm Winners'),
        ),
      ],
    );
  }
}
