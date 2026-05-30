import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/stack_bucket.dart';

/// Segmented ring widget showing a player's stack range.
/// Long-press and drag to select a range without lifting finger.
class StackRangeCircle extends StatefulWidget {
  final double currentStack;
  final double bigBlind;
  final StackConfidence confidence;
  final bool isHero;
  final bool isInteractive;
  final void Function(StackRange range) onRangeSelected;
  final String Function(double) formatCurrency;

  const StackRangeCircle({
    super.key,
    required this.currentStack,
    required this.bigBlind,
    required this.confidence,
    required this.isHero,
    required this.isInteractive,
    required this.onRangeSelected,
    required this.formatCurrency,
  });

  @override
  State<StackRangeCircle> createState() => _StackRangeCircleState();
}

class _StackRangeCircleState extends State<StackRangeCircle> {
  OverlayEntry? _overlayEntry;
  final ValueNotifier<StackRange> _hoveredNotifier = ValueNotifier(StackRange.average);
  final GlobalKey _anchorKey = GlobalKey();
  Offset _overlayCenter = Offset.zero;

  static const double _compactSize = 28.0;
  static const double _expandedSize = 160.0;

  static const int _segmentCount = 7;
  static const double _gapDeg = 3.0;
  static const double _segmentDeg = (360.0 - _gapDeg * _segmentCount) / _segmentCount;
  static final double _segmentRad = _segmentDeg * pi / 180;
  static final double _gapRad = _gapDeg * pi / 180;
  static const double _startAngle = -pi / 2;

  StackRange get _currentRange {
    if (widget.bigBlind <= 0) return StackRange.average;
    return StackBucketHelper.getRangeForBB(widget.currentStack / widget.bigBlind);
  }

  @override
  void dispose() {
    _removeOverlay();
    _hoveredNotifier.dispose();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Offset _getAnchorCenter() {
    final renderBox = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return Offset.zero;
    final pos = renderBox.localToGlobal(Offset.zero);
    return Offset(
      pos.dx + renderBox.size.width / 2,
      pos.dy + renderBox.size.height / 2,
    );
  }

  void _onLongPressStart(LongPressStartDetails details) {
    if (!widget.isInteractive || widget.isHero) return;
    _hoveredNotifier.value = _currentRange;
    final anchorCenter = _getAnchorCenter();

    // Clamp center so the expanded ring stays within screen bounds
    final screenSize = MediaQuery.of(context).size;
    const padding = 8.0;
    final half = _expandedSize / 2;
    final clampedX = anchorCenter.dx.clamp(padding + half, screenSize.width - half - padding);
    final clampedY = anchorCenter.dy.clamp(padding + half, screenSize.height - half - padding);
    _overlayCenter = Offset(clampedX, clampedY);

    HapticFeedback.mediumImpact();

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => _ExpandedRangeOverlay(
        center: _overlayCenter,
        size: _expandedSize,
        currentRange: _currentRange,
        hoveredNotifier: _hoveredNotifier,
        confidence: widget.confidence,
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_overlayEntry == null) return;
    final globalPos = details.globalPosition;
    final dx = globalPos.dx - _overlayCenter.dx;
    final dy = globalPos.dy - _overlayCenter.dy;

    if (dx * dx + dy * dy < 20 * 20) return;

    final angle = atan2(dy, dx);
    final normalized = (angle - _startAngle + 2 * pi) % (2 * pi);
    final stepSize = _segmentRad + _gapRad;
    final index = (normalized / stepSize).floor().clamp(0, _segmentCount - 1);
    final newSegment = StackRange.values[index];

    if (newSegment != _hoveredNotifier.value) {
      _hoveredNotifier.value = newSegment;
      HapticFeedback.selectionClick();
    }
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_overlayEntry == null) return;
    final selected = _hoveredNotifier.value;
    _removeOverlay();
    widget.onRangeSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isHero) {
      return Text(
        widget.formatCurrency(widget.currentStack),
        style: GoogleFonts.ibmPlexSans(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.none,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      );
    }

    final range = _currentRange;
    final label = StackBucketHelper.rangeLabel(range);

    return GestureDetector(
      onLongPressStart: _onLongPressStart,
      onLongPressMoveUpdate: _onLongPressMoveUpdate,
      onLongPressEnd: _onLongPressEnd,
      onLongPressCancel: () => _removeOverlay(),
      child: Column(
        key: _anchorKey,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _compactSize,
            height: _compactSize,
            child: CustomPaint(
              painter: _CompactRingPainter(
                currentRange: range,
                confidence: widget.confidence,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.robotoMono(
              fontSize: 11,
              color: _activeLilac.withValues(alpha: _confidenceAlpha(widget.confidence)),
              fontWeight: FontWeight.w500,
              fontStyle: widget.confidence == StackConfidence.low
                  ? FontStyle.italic
                  : FontStyle.normal,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  double _confidenceAlpha(StackConfidence confidence) {
    switch (confidence) {
      case StackConfidence.high:   return 1.0;
      case StackConfidence.medium: return 0.65;
      case StackConfidence.low:    return 0.4;
    }
  }
}

// Shared donut ring palette
const Color _activeLilac = Color(0xFFD4A5F0);
const List<Color> _inactiveShades = [
  Color(0xFF3D3548),
  Color(0xFF4A4255),
  Color(0xFF3A3345),
  Color(0xFF484058),
  Color(0xFF3D3548),
  Color(0xFF4A4255),
  Color(0xFF3A3345),
];

/// Compact ring painter — thick donut, lilac active segment.
class _CompactRingPainter extends CustomPainter {
  final StackRange currentRange;
  final StackConfidence confidence;

  static const int _segmentCount = 7;
  static const double _gapDeg = 3.0;
  static const double _segmentDeg = (360.0 - _gapDeg * _segmentCount) / _segmentCount;
  static final double _segmentRad = _segmentDeg * pi / 180;
  static final double _gapRad = _gapDeg * pi / 180;
  static const double _startAngle = -pi / 2;

  _CompactRingPainter({
    required this.currentRange,
    required this.confidence,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = size.width * 0.22;
    final radius = (size.width / 2) - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    for (int i = 0; i < _segmentCount; i++) {
      final range = StackRange.values[i];
      final startAngle = _startAngle + i * (_segmentRad + _gapRad);
      final isActive = range == currentRange;

      final color = isActive
          ? _activeLilac.withValues(alpha: _opacityForConfidence())
          : _inactiveShades[i];

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(rect, startAngle, _segmentRad, false, paint);
    }
  }

  double _opacityForConfidence() {
    switch (confidence) {
      case StackConfidence.high:   return 1.0;
      case StackConfidence.medium: return 0.75;
      case StackConfidence.low:    return 0.4;
    }
  }

  @override
  bool shouldRepaint(_CompactRingPainter old) =>
      old.currentRange != currentRange || old.confidence != confidence;
}

/// Passive overlay showing the expanded ring — no gesture handling.
/// Driven by [hoveredNotifier] from the parent widget's long-press.
class _ExpandedRangeOverlay extends StatefulWidget {
  final Offset center;
  final double size;
  final StackRange currentRange;
  final ValueNotifier<StackRange> hoveredNotifier;
  final StackConfidence confidence;

  const _ExpandedRangeOverlay({
    required this.center,
    required this.size,
    required this.currentRange,
    required this.hoveredNotifier,
    required this.confidence,
  });

  @override
  State<_ExpandedRangeOverlay> createState() => _ExpandedRangeOverlayState();
}

class _ExpandedRangeOverlayState extends State<_ExpandedRangeOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _animController.forward();
    widget.hoveredNotifier.addListener(_onHoveredChanged);
  }

  void _onHoveredChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.hoveredNotifier.removeListener(_onHoveredChanged);
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final half = widget.size / 2;
    final hovered = widget.hoveredNotifier.value;

    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Semi-transparent background
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.85)),
            ),
            // The ring selector
            Positioned(
              left: widget.center.dx - half,
              top: widget.center.dy - half,
              child: AnimatedBuilder(
                animation: _scaleAnim,
                builder: (_, __) => Transform.scale(
                  scale: _scaleAnim.value,
                  child: SizedBox(
                    width: widget.size,
                    height: widget.size,
                    child: CustomPaint(
                      painter: _ExpandedRingPainter(
                        currentRange: widget.currentRange,
                        hoveredRange: hovered,
                        confidence: widget.confidence,
                      ),
                      child: Center(
                        child: Text(
                          StackBucketHelper.rangeLabel(hovered),
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.none,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Expanded ring painter — thick donut, lilac hovered segment.
class _ExpandedRingPainter extends CustomPainter {
  final StackRange currentRange;
  final StackRange hoveredRange;
  final StackConfidence confidence;

  static const int _segmentCount = 7;
  static const double _gapDeg = 3.0;
  static const double _segmentDeg = (360.0 - _gapDeg * _segmentCount) / _segmentCount;
  static final double _segmentRad = _segmentDeg * pi / 180;
  static final double _gapRad = _gapDeg * pi / 180;
  static const double _startAngle = -pi / 2;

  _ExpandedRingPainter({
    required this.currentRange,
    required this.hoveredRange,
    required this.confidence,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 24.0;
    final radius = (size.width / 2) - strokeWidth / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);

    for (int i = 0; i < _segmentCount; i++) {
      final range = StackRange.values[i];
      final startAngle = _startAngle + i * (_segmentRad + _gapRad);
      final isHovered = range == hoveredRange;

      final color = isHovered ? _activeLilac : _inactiveShades[i];

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHovered ? 28.0 : strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(rect, startAngle, _segmentRad, false, paint);
    }

  }

  @override
  bool shouldRepaint(_ExpandedRingPainter old) =>
      old.currentRange != currentRange ||
      old.hoveredRange != hoveredRange ||
      old.confidence != confidence;
}
