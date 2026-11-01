import 'package:flutter/material.dart';

import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';

/// Timed toast with a countdown bar and an Undo action. Replaces the
/// "hand in progress" confirm modal: the action has already happened and the
/// toast is the safety net.
///
/// [onExpire] fires once when the countdown ends; [onUndo] fires once on tap.
/// Give each toast a fresh [Key] so a new action restarts the countdown.
class UndoToast extends StatefulWidget {
  final String message;
  final Duration duration;
  final VoidCallback onUndo;
  final VoidCallback onExpire;

  const UndoToast({
    super.key,
    required this.message,
    required this.onUndo,
    required this.onExpire,
    this.duration = const Duration(seconds: 4),
  });

  @override
  State<UndoToast> createState() => _UndoToastState();
}

class _UndoToastState extends State<UndoToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _finish(widget.onExpire);
      })
      ..forward();
  }

  void _finish(VoidCallback cb) {
    if (_done) return;
    _done = true;
    cb();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        border: Border.all(color: AppColors.borderStrong),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.ibm(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _finish(widget.onUndo),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxs, vertical: AppSpacing.xxs),
                    child: Text(
                      l10n.easyLogUndo,
                      style: AppTypography.ibm(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) => LinearProgressIndicator(
              value: 1 - _c.value,
              minHeight: 3,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation(AppColors.accentPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
