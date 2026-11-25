import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../design_system/constants/colors.dart';
import '../../../design_system/constants/decorations.dart';
import '../../../design_system/constants/spacing.dart';
import '../../../design_system/constants/typography.dart';

/// One-drag value picker over a non-linear list of [steps] (stack sizes).
///
/// A vertical drag anywhere on the control moves by snapped steps (up = more),
/// with a haptic tick per step. The visible up/down buttons move one step, the
/// big number can open a keypad ([onTapNumber]) and a one-time "ghost finger"
/// shows the gesture. Reusable for the hero stack (BB steps) and the villain
/// overlay (relative steps): all unit logic lives in the label builders.
///
/// [value] may sit between steps (exact keypad entry): up goes to the first
/// step above it, down to the last step below it. Ends clamp silently.
class StackDragControl extends StatefulWidget {
  /// Ascending step values.
  final List<double> steps;

  /// Current value; need not be one of [steps].
  final double value;
  final String Function(double value) mainLabel;
  final String Function(double value) subLabel;
  final ValueChanged<double> onChanged;
  final VoidCallback? onTapNumber;

  /// SharedPreferences key remembering the hint was shown. Null = no hint.
  final String? hintPrefsKey;

  /// Screen-reader name of the control.
  final String semanticsLabel;
  final String increaseLabel;
  final String decreaseLabel;

  /// Vertical drag distance for one step.
  final double pixelsPerStep;

  const StackDragControl({
    super.key,
    required this.steps,
    required this.value,
    required this.mainLabel,
    required this.subLabel,
    required this.onChanged,
    this.onTapNumber,
    this.hintPrefsKey,
    this.semanticsLabel = '',
    this.increaseLabel = '',
    this.decreaseLabel = '',
    this.pixelsPerStep = 26,
  }) : assert(steps.length > 0);

  @override
  State<StackDragControl> createState() => _StackDragControlState();
}

class _StackDragControlState extends State<StackDragControl>
    with SingleTickerProviderStateMixin {
  static const double _buttonSize = 48;
  static const Duration _hintDuration = Duration(milliseconds: 2400);

  late final AnimationController _hint =
      AnimationController(vsync: this, duration: _hintDuration);
  double _acc = 0;
  late double _cur = widget.value;
  bool _touched = false;
  bool _hintChecked = false;

  @override
  void initState() {
    super.initState();
    _maybeShowHint();
  }

  @override
  void didUpdateWidget(StackDragControl old) {
    super.didUpdateWidget(old);
    _cur = widget.value;
  }

  @override
  void dispose() {
    _hint.dispose();
    super.dispose();
  }

  Future<void> _maybeShowHint() async {
    final key = widget.hintPrefsKey;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(key) == true) return;
      await prefs.setBool(key, true);
    } catch (_) {
      return; // The hint is a convenience only.
    }
    if (!mounted || _touched) return;
    _hintChecked = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    _hint.forward();
  }

  void _stopHint() {
    _touched = true;
    if (_hintChecked && _hint.isAnimating) _hint.stop();
    if (_hint.value != 0) _hint.value = 0;
  }

  /// Next step above/below [from]; null at the ends.
  double? _next(double from, int dir) {
    final s = widget.steps;
    if (dir > 0) {
      for (final v in s) {
        if (v > from) return v;
      }
    } else {
      for (final v in s.reversed) {
        if (v < from) return v;
      }
    }
    return null;
  }

  void _move(int dir) {
    final next = _next(_cur, dir);
    if (next == null) return;
    _cur = next;
    HapticFeedback.selectionClick();
    widget.onChanged(next);
  }

  void _onDrag(DragUpdateDetails d) {
    _acc -= d.delta.dy;
    final px = widget.pixelsPerStep;
    while (_acc.abs() >= px) {
      final dir = _acc > 0 ? 1 : -1;
      _acc -= dir * px;
      _move(dir);
    }
  }

  Widget _arrow(IconData icon, int dir, String label) {
    final enabled = _next(widget.value, dir) != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                _stopHint();
                _move(dir);
              }
            : null,
        child: SizedBox(
          width: _buttonSize,
          height: _buttonSize,
          child: Icon(icon,
              size: 32,
              color:
                  enabled ? AppColors.textPrimary : AppColors.contentDisabled),
        ),
      ),
    );
  }

  Widget _ghost() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _hint,
        builder: (_, __) {
          final t = _hint.value;
          if (t == 0) return const SizedBox.shrink();
          // Down, up, down, settle; fades in and out at the ends.
          final y = t < 0.4
              ? 46 - 92 * (t / 0.4)
              : (t < 0.7
                  ? -46 + 92 * ((t - 0.4) / 0.3)
                  : 46 * (1 - (t - 0.7) / 0.3));
          final o = t < 0.12 ? t / 0.12 : (t > 0.7 ? (1 - t) / 0.3 : 1.0);
          return Opacity(
            opacity: (o * 0.95).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, y),
              child: Container(
                width: _buttonSize - 4,
                height: _buttonSize - 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.textPrimary.withValues(alpha: 0.22),
                  border: Border.all(
                      color: AppColors.textPrimary.withValues(alpha: 0.7),
                      width: 2),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    final canUp = _next(v, 1) != null;
    final canDown = _next(v, -1) != null;
    return Semantics(
      container: true,
      label: widget.semanticsLabel,
      value: widget.mainLabel(v),
      increasedValue: canUp ? widget.mainLabel(_next(v, 1)!) : null,
      decreasedValue: canDown ? widget.mainLabel(_next(v, -1)!) : null,
      onIncrease: canUp ? () => _move(1) : null,
      onDecrease: canDown ? () => _move(-1) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (_) => _stopHint(),
        onVerticalDragStart: (_) => _acc = 0,
        onVerticalDragUpdate: _onDrag,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _arrow(Icons.keyboard_arrow_up_rounded, 1, widget.increaseLabel),
                const SizedBox(height: AppSpacing.xxxs),
                _number(v),
                const SizedBox(height: AppSpacing.xxxs),
                _arrow(Icons.keyboard_arrow_down_rounded, -1,
                    widget.decreaseLabel),
              ],
            ),
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0.55, 0),
                child: _ghost(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _number(double v) {
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(widget.mainLabel(v),
              key: const ValueKey('stack-main'),
              maxLines: 1,
              softWrap: false,
              style: AppTypography.monetaryLarge()),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(widget.subLabel(v),
              key: const ValueKey('stack-sub'),
              maxLines: 1,
              softWrap: false,
              style: AppTypography.dataMono(color: AppColors.textSecondary)),
        ),
      ],
    );
    final tap = widget.onTapNumber;
    if (tap == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _stopHint();
        tap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl, vertical: AppSpacing.xxs),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        ),
        child: child,
      ),
    );
  }
}
