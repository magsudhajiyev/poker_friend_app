import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../design_system/constants/colors.dart';
import '../../../design_system/constants/decorations.dart';
import '../../../design_system/constants/spacing.dart';
import '../../../design_system/constants/typography.dart';
import '../../../l10n/app_localizations.dart';

/// Oval table with one seat per entry of [positions] (clockwise order, e.g.
/// `SingleHandSetup.positionsFor`). The hero is always drawn at the bottom:
/// picking another seat rotates the table. Tap a seat to sit there; swipe the
/// table sideways (or use the arrows) to move one seat. A "D" chip marks the
/// button.
class MiniTableSeatPicker extends StatefulWidget {
  final List<String> positions;
  final String heroPosition;
  final ValueChanged<String> onChanged;

  const MiniTableSeatPicker({
    super.key,
    required this.positions,
    required this.heroPosition,
    required this.onChanged,
  });

  @override
  State<MiniTableSeatPicker> createState() => _MiniTableSeatPickerState();
}

class _MiniTableSeatPickerState extends State<MiniTableSeatPicker> {
  static const double _minTarget = 44;
  static const double _swipeDistance = 36;
  static const Duration _tapGuard = Duration(milliseconds: 300);

  /// Continuous hero index; differs from the plain index by whole laps so the
  /// rotation always takes the short way round.
  late double _rot = _heroIndex.toDouble();
  double _drag = 0;
  DateTime _swipedAt = DateTime.fromMillisecondsSinceEpoch(0);

  int get _heroIndex =>
      math.max(0, widget.positions.indexOf(widget.heroPosition));

  @override
  void didUpdateWidget(MiniTableSeatPicker old) {
    super.didUpdateWidget(old);
    final n = widget.positions.length;
    if (old.positions.length != n) {
      _rot = _heroIndex.toDouble();
      return;
    }
    var delta = (_heroIndex - old.positions.indexOf(old.heroPosition)) % n;
    if (delta > n / 2) delta -= n;
    _rot += delta;
  }

  void _pick(String position) {
    if (DateTime.now().difference(_swipedAt) < _tapGuard) return;
    if (position != widget.heroPosition) widget.onChanged(position);
  }

  void _step(int dir, {bool swipe = false}) {
    if (swipe) _swipedAt = DateTime.now();
    final n = widget.positions.length;
    widget.onChanged(widget.positions[(_heroIndex + dir) % n]);
  }

  void _onDragEnd() => _drag = 0;

  void _onDragUpdate(DragUpdateDetails d) {
    _drag += d.delta.dx;
    // The table follows the finger: dragging left spins the seats left, so
    // the seat that was right of the hero (previous in the list) comes down.
    if (_drag <= -_swipeDistance) {
      _drag = 0;
      _step(-1, swipe: true);
    } else if (_drag >= _swipeDistance) {
      _drag = 0;
      _step(1, swipe: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Row(
      children: [
        _arrowButton(Icons.chevron_left, l10n.singleHandV2PrevSeat, -1),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: (_) => _onDragEnd(),
            onHorizontalDragCancel: _onDragEnd,
            child: LayoutBuilder(builder: (context, c) {
              final w = c.maxWidth;
              final crowded = widget.positions.length >= 7;
              final h = math.min(w * (crowded ? 0.8 : 0.62), 280.0);
              return SizedBox(
                width: w,
                height: h,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: _rot),
                  duration:
                      reduce ? Duration.zero : const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  builder: (_, rot, __) => _table(l10n, w, h, rot),
                ),
              );
            }),
          ),
        ),
        _arrowButton(Icons.chevron_right, l10n.singleHandV2NextSeat, 1),
      ],
    );
  }

  Widget _arrowButton(IconData icon, String label, int dir) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _step(dir),
        child: SizedBox(
          width: _minTarget,
          height: _minTarget,
          child: Icon(icon, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  /// Centre of seat [i] for the continuous hero index [rot]; the hero sits at
  /// the bottom (90 deg in y-down screen space), seats follow clockwise.
  Offset _seatCenter(int i, double rot, double w, double h, double seatW,
      {double scale = 1}) {
    final n = widget.positions.length;
    final a = math.pi / 2 + (i - rot) * 2 * math.pi / n;
    final rx = (w - seatW) / 2 * scale;
    final ry = (h - _minTarget) / 2 * scale;
    return Offset(w / 2 + rx * math.cos(a), h / 2 + ry * math.sin(a));
  }

  Widget _table(AppLocalizations l10n, double w, double h, double rot) {
    final seatW = (w * 0.17).clamp(48.0, 66.0);
    final felt = Container(
      margin: EdgeInsets.symmetric(
          horizontal: seatW / 2 + AppSpacing.xxs, vertical: _minTarget / 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(h),
        color: AppColors.bgSurface,
        border: Border.all(color: AppColors.borderStrong),
      ),
    );
    final btn = widget.positions.indexOf('BTN');
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: felt),
        for (var i = 0; i < widget.positions.length; i++)
          _seat(l10n, i, rot, w, h, seatW),
        if (btn >= 0) _dealer(btn, rot, w, h, seatW),
      ],
    );
  }

  Widget _dealer(int btn, double rot, double w, double h, double seatW) {
    const size = 22.0;
    final c = _seatCenter(btn, rot, w, h, seatW, scale: 0.72);
    return Positioned(
      left: c.dx - size / 2,
      top: c.dy - size / 2,
      width: size,
      height: size,
      child: ExcludeSemantics(
        child: Container(
          alignment: Alignment.center,
          decoration: const BoxDecoration(
              shape: BoxShape.circle, color: AppColors.bgInverse),
          child: Text('D',
              style: AppTypography.caption(color: AppColors.textInverse)
                  .copyWith(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _seat(AppLocalizations l10n, int i, double rot, double w, double h,
      double seatW) {
    final pos = widget.positions[i];
    final hero = pos == widget.heroPosition;
    final c = _seatCenter(i, rot, w, h, seatW);
    return Positioned(
      left: c.dx - seatW / 2,
      top: c.dy - _minTarget / 2,
      width: seatW,
      height: _minTarget,
      child: Semantics(
        button: true,
        selected: hero,
        label: hero
            ? l10n.singleHandV2SeatYou(pos)
            : l10n.singleHandV2SeatSit(pos),
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _pick(pos),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
              color: hero ? AppColors.accentPrimary : AppColors.bgElevated,
              border: Border.all(
                  color:
                      hero ? AppColors.accentPrimary : AppColors.borderStrong),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(pos,
                    style: AppTypography.labelChip(
                        color: hero
                            ? AppColors.textInverse
                            : AppColors.textPrimary)),
                if (hero)
                  Text(l10n.singleHandV2You,
                      style: AppTypography.caption(color: AppColors.textInverse)),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}
