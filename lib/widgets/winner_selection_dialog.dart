import 'package:flutter/material.dart';
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

    // Sort winners by position (earliest first to get extra chips)
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
    // Calculate position order based on seat number relative to button
    // Lower numbers = earlier in position (closer to left of button)

    final buttonPos = widget.buttonPosition;
    final totalPlayers = widget.playerCount;

    // Calculate how many seats after the button this player is
    // Button is last to act, so position 0 is earliest (UTG)
    int positionFromButton;
    if (playerId > buttonPos) {
      positionFromButton = playerId - buttonPos;
    } else {
      positionFromButton = (totalPlayers - buttonPos) + playerId;
    }

    return positionFromButton;
  }

  List<Widget> _buildIndividualSharesDisplay() {
    final shares = _calculateIndividualShares();
    if (shares.isEmpty) return [];

    return [
      const Text(
        'Individual shares:',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.grey,
        ),
      ),
      const SizedBox(height: 4),
      ...shares.entries.map((entry) {
        final playerId = entry.key;
        final amount = entry.value;
        final playerName = playerId <= widget.playerNames.length
            ? widget.playerNames[playerId - 1]
            : 'Player $playerId';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                playerName,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                ),
              ),
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
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isChoppedPot ? 'Who chopped this pot?' : 'Who won this hand?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pot Size: ${_formatCurrency(widget.potAmount)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          if (isChoppedPot && selectedWinners.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._buildIndividualSharesDisplay(),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Switch(
                value: isChoppedPot,
                onChanged: (value) {
                  setState(() {
                    isChoppedPot = value;
                    // Clear selections when switching modes
                    selectedWinner = null;
                    selectedWinners.clear();
                  });
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isChoppedPot ? 'Chopped Pot' : 'Single Winner',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(isChoppedPot ? 'Select all winners:' : 'Select the winner:'),
          const SizedBox(height: 12),
          ...widget.activePlayers.map((playerId) {
            final playerName = playerId <= widget.playerNames.length
                ? widget.playerNames[playerId - 1]
                : 'Player $playerId';

            if (isChoppedPot) {
              return CheckboxListTile(
                title: Text(playerName),
                value: selectedWinners.contains(playerId),
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      selectedWinners.add(playerId);
                    } else {
                      selectedWinners.remove(playerId);
                    }
                  });
                },
                dense: true,
              );
            } else {
              return RadioListTile<int>(
                title: Text(playerName),
                value: playerId,
                groupValue: selectedWinner,
                onChanged: (value) {
                  setState(() {
                    selectedWinner = value;
                  });
                },
                dense: true,
              );
            }
          }).toList(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(null);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isChoppedPot
              ? (selectedWinners.isNotEmpty
                  ? () {
                      Navigator.of(context).pop({
                        'isChoppedPot': true,
                        'winners': selectedWinners.toList(),
                        'individualShares': _calculateIndividualShares(),
                        'sharePerWinner': _getSharePerWinner(), // Keep for backward compatibility
                      });
                    }
                  : null)
              : (selectedWinner != null
                  ? () {
                      Navigator.of(context).pop({
                        'isChoppedPot': false,
                        'winner': selectedWinner,
                        'sharePerWinner': widget.potAmount,
                      });
                    }
                  : null),
          child: Text(isChoppedPot ? 'Confirm Winners' : 'Confirm Winner'),
        ),
      ],
    );
  }
}