import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../services/coach_persona.dart';
import 'onboarding_motion.dart';
import 'typewriter_bubble.dart';

/// Three tappable coach tiles (mascot, name, short tag). Tapping one picks it,
/// bounces it, and types its greeting in a speech bubble underneath.
/// All strings come from the caller ([tagsById], [hint]); persona names and
/// greetings are English by design.
class CoachTrio extends StatefulWidget {
  final CoachPersona selected;
  final ValueChanged<CoachPersona> onPick;
  final Map<String, String> tagsById;
  final String hint;

  const CoachTrio({
    super.key,
    required this.selected,
    required this.onPick,
    required this.tagsById,
    required this.hint,
  });

  /// Warm the image cache with the three idle stills.
  static Future<void> precache(BuildContext context) => Future.wait([
        for (final p in CoachPersonas.all)
          for (final face in const ['idle', 'happy'])
            precacheImage(
                ResizeImage(AssetImage(_asset(p.id, face)), width: _cacheWidth),
                context),
      ]);

  static const int _cacheWidth = 240; // 2x the 120 max display size
  static String _asset(String id, String face) =>
      'assets/mascots/${id}_$face.png';

  @override
  State<CoachTrio> createState() => _CoachTrioState();
}

class _CoachTrioState extends State<CoachTrio> with TickerProviderStateMixin {
  static const _delay = Duration(milliseconds: 200);
  static const int _stepMs = 110, _itemMs = 380;
  static const int _entranceMs = 2 * _stepMs + _itemMs;

  late final AnimationController _entrance = AnimationController(
      vsync: this, duration: const Duration(milliseconds: _entranceMs));
  late final AnimationController _idle = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3200));
  late final AnimationController _bounce = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300));
  Timer? _startTimer;
  String? _tappedId;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = OnboardingMotion.reduced(context);
    if (!_started) {
      _started = true;
      if (reduced) {
        _entrance.duration = const Duration(milliseconds: 250);
        _entrance.forward();
      } else {
        _startTimer = Timer(_delay, () {
          if (mounted) _entrance.forward();
        });
      }
    }
    // TickerMode muting is automatic; reduced motion needs an explicit stop.
    if (reduced) {
      _idle.stop();
    } else if (!_idle.isAnimating) {
      _idle.repeat();
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _entrance.dispose();
    _idle.dispose();
    _bounce.dispose();
    super.dispose();
  }

  void _tap(CoachPersona p) {
    setState(() => _tappedId = p.id);
    if (!OnboardingMotion.reduced(context)) _bounce.forward(from: 0);
    // Voice can be added later (coach speech); intentionally silent here.
    widget.onPick(p);
  }

  @override
  Widget build(BuildContext context) {
    final tapped = _tappedId == null ? null : CoachPersonas.byId(_tappedId);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(builder: (context, c) => _row(context, c.maxWidth)),
        const SizedBox(height: AppSpacing.md),
        if (tapped == null)
          Text(widget.hint,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(color: AppColors.textSecondary))
        else
          TypewriterBubble(text: tapped.greeting),
      ],
    );
  }

  Widget _row(BuildContext context, double w) {
    final scroll = w < 340 || MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final mascot = ((w - 48) / 3 * 0.92).clamp(72.0, 120.0);
    final personas = CoachPersonas.all;
    final tiles = [
      for (var i = 0; i < personas.length; i++)
        _tile(context, personas[i], i, mascot, scroll),
    ];
    if (scroll) {
      return ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => const LinearGradient(
          colors: [AppColors.paper, AppColors.paper, Colors.transparent],
          stops: [0, 0.9, 1],
        ).createShader(r),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: tiles),
        ),
      );
    }
    return Row(children: tiles.map((t) => Expanded(child: t)).toList());
  }

  Widget _tile(
      BuildContext context, CoachPersona p, int i, double mascot, bool scroll) {
    final tile = _tileBody(context, p, i, mascot);
    final padded = Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxs),
        child: tile);
    return scroll
        ? SizedBox(width: mascot + AppSpacing.xxxl, child: padded)
        : padded;
  }

  Widget _tileBody(BuildContext context, CoachPersona p, int i, double mascot) {
    final isSel = p.id == widget.selected.id;
    final happy = p.id == _tappedId;
    return Semantics(
      button: true,
      selected: isSel,
      label: _semanticLabel(p),
      excludeSemantics: true,
      onTap: () => _tap(p),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _tap(p),
        child: Container(
          padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xs, horizontal: AppSpacing.xxs),
          decoration: _tileDecoration(false),
          foregroundDecoration: isSel ? _tileDecoration(true) : null,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _animatedMascot(p, i, mascot, happy),
            const SizedBox(height: AppSpacing.xxs),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(p.name,
                  maxLines: 1,
                  style: AppTypography.cardTitle(color: AppColors.textPrimary)),
            ),
            const SizedBox(height: AppSpacing.xxxs),
            Text(widget.tagsById[p.id] ?? '',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall(color: AppColors.textSecondary)),
          ]),
        ),
      ),
    );
  }

  String _semanticLabel(CoachPersona p) {
    final tag = widget.tagsById[p.id];
    return tag == null || tag.isEmpty ? p.name : '${p.name}, $tag';
  }

  BoxDecoration _tileDecoration(bool ring) => BoxDecoration(
        color: ring ? null : AppColors.textPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        border: Border.all(
            color: ring
                ? AppColors.accentPrimary
                : AppColors.textPrimary.withValues(alpha: 0.10),
            width: ring
                ? AppDecorations.borderThin * 2
                : AppDecorations.borderThin),
      );

  Widget _animatedMascot(CoachPersona p, int i, double size, bool happy) {
    final reduced = OnboardingMotion.reduced(context);
    final slot = staggerInterval(i, 3,
        stepFraction: _stepMs / _entranceMs,
        durationFraction: _itemMs / _entranceMs);
    final img = RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: Image.asset(
          CoachTrio._asset(p.id, happy ? 'happy' : 'idle'),
          cacheWidth: CoachTrio._cacheWidth,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
        ),
      ),
    );
    return AnimatedBuilder(
      animation: Listenable.merge([_entrance, _idle, _bounce]),
      child: img,
      builder: (context, child) {
        final t = slot.transform(_entrance.value);
        final opacity = t.clamp(0.0, 1.0);
        if (reduced) return Opacity(opacity: opacity, child: child);
        final eased = Curves.easeOutBack.transform(t);
        final bob = 3 * math.sin(2 * math.pi * (_idle.value + i / 3));
        final pop = p.id == _tappedId
            ? 1 + 0.08 * math.sin(_bounce.value * math.pi)
            : 1.0;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, (1 - eased) * 12 + bob),
            child: Transform.scale(
                scale: (0.85 + 0.15 * eased) * pop, child: child),
          ),
        );
      },
    );
  }
}
