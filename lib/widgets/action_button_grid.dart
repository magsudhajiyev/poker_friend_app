import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/poker_game_state.dart';
import '../design_system/constants/decorations.dart';

class ActionButtonGrid extends StatelessWidget {
  final Function(PlayerAction) onActionSelected;
  final Set<PlayerAction> availableActions;

  const ActionButtonGrid({
    super.key,
    required this.onActionSelected,
    this.availableActions = const {PlayerAction.fold, PlayerAction.check, PlayerAction.call, PlayerAction.bet, PlayerAction.raise},
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.actionGridSelectAction,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.0,
            children: [
              if (availableActions.contains(PlayerAction.fold))
                _buildActionButton(
                  context,
                  action: PlayerAction.fold,
                  label: 'FOLD',
                  icon: Icons.close,
                  color: Colors.red,
                  onTap: () => onActionSelected(PlayerAction.fold),
                ),
              if (availableActions.contains(PlayerAction.check))
                _buildActionButton(
                  context,
                  action: PlayerAction.check,
                  label: 'CHECK',
                  icon: Icons.check,
                  color: Colors.blue,
                  onTap: () => onActionSelected(PlayerAction.check),
                ),
              if (availableActions.contains(PlayerAction.call))
                _buildActionButton(
                  context,
                  action: PlayerAction.call,
                  label: 'CALL',
                  icon: Icons.radio_button_unchecked,
                  color: Colors.green,
                  onTap: () => onActionSelected(PlayerAction.call),
                ),
              if (availableActions.contains(PlayerAction.bet))
                _buildActionButton(
                  context,
                  action: PlayerAction.bet,
                  label: 'BET',
                  icon: Icons.trending_up,
                  color: Colors.orange,
                  onTap: () => onActionSelected(PlayerAction.bet),
                ),
              if (availableActions.contains(PlayerAction.raise))
                _buildActionButton(
                  context,
                  action: PlayerAction.raise,
                  label: 'RAISE',
                  icon: Icons.double_arrow,
                  color: Colors.purple,
                  onTap: () => onActionSelected(PlayerAction.raise),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required PlayerAction action,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 32,
              ),
              SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}