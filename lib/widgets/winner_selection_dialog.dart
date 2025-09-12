import 'package:flutter/material.dart';
import '../models/game_types.dart';

class WinnerSelectionDialog extends StatefulWidget {
  final List<int> activePlayers;
  final List<String> playerNames;
  final double potAmount;
  final GameType gameType;

  const WinnerSelectionDialog({
    super.key,
    required this.activePlayers,
    required this.playerNames,
    required this.potAmount,
    this.gameType = GameType.cash,
  });

  @override
  State<WinnerSelectionDialog> createState() => _WinnerSelectionDialogState();
}

class _WinnerSelectionDialogState extends State<WinnerSelectionDialog> {
  int? selectedWinner;

  String _formatCurrency(double amount) {
    if (widget.gameType == GameType.cash) {
      return '\$${amount.toStringAsFixed(2)}';
    } else {
      return '${amount.toInt()}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Who won this hand?'),
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
          const SizedBox(height: 16),
          const Text('Select the winner:'),
          const SizedBox(height: 12),
          ...widget.activePlayers.map((playerId) {
            final playerName = playerId <= widget.playerNames.length 
                ? widget.playerNames[playerId - 1] 
                : 'Player $playerId';
            
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
          onPressed: selectedWinner != null
              ? () {
                  Navigator.of(context).pop(selectedWinner);
                }
              : null,
          child: const Text('Confirm Winner'),
        ),
      ],
    );
  }
}