import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import 'onboarding_sample_data.dart';

/// Onboarding illustration of the leaderboard: podium grows, then "You"
/// climbs from 4th to 1st. Flat card (no blur), one-shot.
class SampleLeaderboardCard extends StatefulWidget {
  final String header;
  final String youLabel;
  final String Function(String letter) playerLabel;
  final String semanticsLabel;
  final Duration startDelay;

  /// When false the widget draws no card chrome (a host provides it).

  const SampleLeaderboardCard({
    super.key,
    required this.header,
    required this.youLabel,
    required this.playerLabel,
    required this.semanticsLabel,
    this.startDelay = const Duration(milliseconds: 1500),
  });

  @override
  State<SampleLeaderboardCard> createState() => _SampleLeaderboardCardState();
}

class _SampleLeaderboardCardState extends State<SampleLeaderboardCard>
    with TickerProviderStateMixin {
  static const List<double> _barFractions = [0.60, 0.44, 0.32];
  static const int _barMs = 450;
  static const int _barStepMs = 90;
  static const Duration _moveDelay = Duration(milliseconds: 900);

  late final AnimationController _podium;
  late final AnimationController _move;
  late final AnimationController _celebrate;
  final _initial = OnboardingSampleData.initialOrder();
  final _last = OnboardingSampleData.finalOrder();
  bool _started = false;
  Timer? _podiumTimer;
  Timer? _moveTimer;

  @override
  void initState() {
    super.initState();
    _podium = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _barMs + _barStepMs * 2),
    );
    _move = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addStatusListener((st) {
        if (st == AnimationStatus.completed && mounted) _celebrate.forward();
      });
    _celebrate = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _podium.value = 1;
      _move.value = 1;
      _celebrate.value = 1;
      return;
    }
    _podiumTimer = Timer(widget.startDelay, () {
      if (mounted) _podium.forward();
    });
    _moveTimer = Timer(widget.startDelay + _moveDelay, () {
      if (mounted) _move.forward();
    });
  }

  @override
  void dispose() {
    _podiumTimer?.cancel();
    _moveTimer?.cancel();
    _podium.dispose();
    _move.dispose();
    _celebrate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: widget.semanticsLabel,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: AppDecorations.borderThin,
            ),
            borderRadius: BorderRadius.circular(AppDecorations.cardRadius),
          ),
          child: _content(),
        ),
      ),
    );
  }

  Widget _content() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headerRow(),
        const SizedBox(height: AppSpacing.sm),
        _podiumView(),
        const SizedBox(height: AppSpacing.sm),
        _rowsView(),
      ],
    );
  }

  Widget _headerRow() =>
      Text(widget.header.toUpperCase(), style: AppTypography.sectionHeader());

  String _name(SampleRow r) =>
      r.isYou ? widget.youLabel : widget.playerLabel(r.letter);

  double _podiumT(int i) {
    final t = _podium.value * (_barMs + _barStepMs * 2) - i * _barStepMs;
    return Curves.easeOutCubic.transform((t / _barMs).clamp(0.0, 1.0));
  }

  /// Displayed accuracy of a row, including the You bump.
  double _acc(SampleRow r) {
    if (!r.isYou) return r.accuracy;
    final t = Curves.easeInOutCubic.transform(_move.value);
    return r.accuracy +
        (OnboardingSampleData.youBumpedAccuracy - r.accuracy) * t;
  }

  Widget _podiumView() {
    final t0 = MediaQuery.textScalerOf(context).scale(1);
    final maxH = AppSpacing.xxxl * 2 * t0.clamp(1.0, 1.3);
    return AnimatedBuilder(
      animation: Listenable.merge([_podium, _move]),
      builder: (_, __) {
        // Podium shows current top 3 by displayed accuracy; visual order
        // is 2nd, 1st, 3rd.
        final top = _currentOrder().take(3).toList();
        final slots = [1, 0, 2];
        return SizedBox(
          height: maxH + AppSpacing.lg,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final s in slots) Expanded(child: _bar(top[s], s, maxH)),
            ],
          ),
        );
      },
    );
  }

  Widget _bar(SampleRow r, int place, double maxH) {
    final t = _podiumT(place);
    final acc = _acc(r) * t;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxs),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(acc.toStringAsFixed(1),
                style: AppTypography.mono(
                    fontSize: 12,
                    color: r.isYou
                        ? AppColors.accentPrimary
                        : AppColors.textPrimary)),
          ),
          const SizedBox(height: AppSpacing.xxxs),
          Container(
            height: maxH * _barFractions[place] * t,
            decoration: BoxDecoration(
              color: r.isYou
                  ? AppColors.accentPrimary
                  : Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppDecorations.radiusSm)),
            ),
          ),
        ],
      ),
    );
  }

  List<SampleRow> _currentOrder() {
    final rows = [
      for (final r in _initial)
        SampleRow(letter: r.letter, accuracy: _acc(r), isYou: r.isYou)
    ]..sort((a, b) => b.accuracy.compareTo(a.accuracy));
    return rows;
  }

  Widget _rowsView() {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final rowH = AppSpacing.xxxl * scale.clamp(1.0, 1.5);
    return AnimatedBuilder(
      animation: Listenable.merge([_move, _celebrate]),
      builder: (_, __) {
        final t = Curves.easeInOutCubic.transform(_move.value);
        return SizedBox(
          height: rowH * _initial.length,
          child: Stack(
            children: [
              for (var i = 0; i < _initial.length; i++)
                _positioned(_initial[i], i, rowH, t),
            ],
          ),
        );
      },
    );
  }

  Widget _positioned(SampleRow r, int from, double rowH, double t) {
    final to = _last.indexWhere((x) => x.letter == r.letter);
    final slot = from + (to - from) * t;
    return Positioned(
      top: slot * rowH,
      left: 0,
      right: 0,
      height: rowH,
      child: _rowTile(r, rowH, (slot.round() + 1)),
    );
  }

  Widget _rowTile(SampleRow r, double h, int rank) {
    final color = r.isYou ? AppColors.accentPrimary : AppColors.textPrimary;
    // 0 -> 1 -> 0 pulse over the celebration (0 when idle or finished).
    final pulse = r.isYou ? math.sin(_celebrate.value * math.pi) : 0.0;
    final won = r.isYou && _move.value >= 1;
    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: r.isYou
          ? BoxDecoration(
              color: AppColors.accentPrimary
                  .withValues(alpha: 0.12 + 0.18 * pulse),
              borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
            )
          : null,
      child: Row(
        children: [
          SizedBox(
            width: AppSpacing.xl,
            child: Text('$rank',
                style: AppTypography.mono(fontSize: 14, color: color)),
          ),
          Expanded(
            child: Text(_name(r),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium(color: color)),
          ),
          if (won) ...[
            Icon(Icons.emoji_events_rounded, size: 16, color: color),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Text('${_acc(r).toStringAsFixed(1)}%',
              style: AppTypography.mono(fontSize: 14, color: color)),
        ],
      ),
    );
    return r.isYou
        ? Transform.scale(scale: 1 + 0.04 * pulse, child: tile)
        : tile;
  }
}
