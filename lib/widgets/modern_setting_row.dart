import 'package:flutter/material.dart';
import '../design_system/constants/decorations.dart';

class ModernSettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const ModernSettingRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionButton(
                context,
                Icons.remove_rounded,
                onDecrement,
                theme.colorScheme.error,
              ),
              const SizedBox(width: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                ),
                child: Text(
                  value.toString(),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              _buildActionButton(
                context,
                Icons.add_rounded,
                onIncrement,
                theme.colorScheme.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    VoidCallback onPressed,
    Color color,
  ) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
      ),
    );
  }
}