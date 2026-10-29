import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_system/components/headers/section_header.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import 'onboarding_motion.dart';

/// "How it works" timeline for the onboarding carousel. Mirrors the paywall's
/// "How Does the Free Trial Work?" explainer (value_proposition_screen.dart):
/// green icon nodes on a connected capsule rail, title + optional body per
/// step, and the same top-to-bottom fade + slide-up stagger. Hugs its content
/// (one page of a PageView). Reduced motion shows the final state at once.
class ChallengeFactsRow extends StatefulWidget {
  final String header;
  final List<(IconData, String)> facts;

  /// Optional one-line explanation under each fact title (same order).
  final List<String>? bodies;
  final Duration startDelay;

  const ChallengeFactsRow({
    super.key,
    required this.header,
    required this.facts,
    this.bodies,
    this.startDelay = const Duration(milliseconds: 1000),
  });

  @override
  State<ChallengeFactsRow> createState() => _ChallengeFactsRowState();
}

class _ChallengeFactsRowState extends State<ChallengeFactsRow>
    with SingleTickerProviderStateMixin {
  static const _nodeSize = 36.0;
  static const _railWidth = 5.0;

  late final AnimationController _controller;
  Timer? _timer;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (OnboardingMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _timer = Timer(widget.startDelay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Same window maths as the paywall: starts spread over [0, 0.7], each block
  /// takes 0.3 of the timeline, easeInOutCubic, 28 px slide-up.
  Widget _staggered(int index, int total, Widget child) {
    final span = total <= 1 ? 0.0 : 0.7 / (total - 1);
    final start = (index * span).clamp(0.0, 0.7);
    final end = (start + 0.3).clamp(0.0, 1.0);
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeInOutCubic),
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (context, _) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, (1 - curve.value) * 28),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.facts.length + 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _staggered(0, total, SectionHeader(title: widget.header)),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < widget.facts.length; i++)
          _staggered(
            i + 1,
            total,
            _stepRow(
              widget.facts[i].$1,
              widget.facts[i].$2,
              _bodyAt(i),
              isFirst: i == 0,
              isLast: i == widget.facts.length - 1,
            ),
          ),
      ],
    );
  }

  String? _bodyAt(int i) {
    final b = widget.bodies;
    return (b != null && i < b.length && b[i].isNotEmpty) ? b[i] : null;
  }

  Widget _stepRow(IconData icon, String title, String? body,
      {required bool isFirst, required bool isLast}) {
    return Semantics(
      container: true,
      label: body == null ? title : '$title. $body',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _rail(icon, isFirst: isFirst, isLast: isLast),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _text(title, body, isLast: isLast)),
          ],
        ),
      ),
    );
  }

  Widget _rail(IconData icon, {required bool isFirst, required bool isLast}) {
    Widget seg(bool hidden) => Expanded(
          child: Container(
            width: _railWidth,
            color: hidden ? Colors.transparent : AppColors.accentPrimary,
          ),
        );
    return SizedBox(
      width: _nodeSize,
      child: Column(
        children: [
          seg(isFirst),
          Container(
            width: _nodeSize,
            height: _nodeSize,
            decoration: BoxDecoration(
              color: AppColors.accentPrimary,
              borderRadius: BorderRadius.circular(_nodeSize),
            ),
            child: Icon(icon, color: AppColors.paper, size: 20),
          ),
          seg(isLast),
        ],
      ),
    );
  }

  Widget _text(String title, String? body, {required bool isLast}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _nodeSize),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.ibm(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            if (body != null) ...[
              const SizedBox(height: 2),
              Text(
                body,
                style: AppTypography.ibm(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
