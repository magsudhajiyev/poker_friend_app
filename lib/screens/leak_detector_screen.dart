import 'package:flutter/material.dart';

import '../design_system/components/headers/top_nav_bar.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';
import '../design_system/constants/spacing.dart';
import '../design_system/components/tween_number.dart';
import '../design_system/constants/typography.dart';
import '../services/leak_engine.dart';
import '../services/leak_report_service.dart';
import '../utils/user_facing_error.dart';
import 'hand_actions_screen.dart';
import 'training/drill_setup_screen.dart';

/// LEAK DETECTOR (feature-flagged experiment) — visual report screen.
///
/// Design: numbers live in gauges and tiles, words live behind taps.
/// - Stat strip: hands / leaks / solid as tiles, not sentences.
/// - Every finding is a band gauge: the healthy zone is a tinted segment,
///   your value is a status-colored marker. Read at a glance.
/// - Leak cards collapse to title + gauge; meaning/cost/fix, breakdowns,
///   example hands and the practice button expand on tap (top leak starts
///   expanded).
/// - Healthy checks are a 2-column grid of mini-gauge tiles; low-data
///   detectors show progress-to-unlock bars.
///
/// PRE-GA TODO: strings are intentionally English-only while the feature
/// is admin-flagged; localize before any public rollout.
class LeakDetectorScreen extends StatefulWidget {
  const LeakDetectorScreen({super.key});

  @override
  State<LeakDetectorScreen> createState() => _LeakDetectorScreenState();
}

class _LeakDetectorScreenState extends State<LeakDetectorScreen>
    with SingleTickerProviderStateMixin {
  LeakReportBundle? _bundle;
  String? _error;
  final Set<String> _expanded = {};

  /// One-shot entrance: sections fade/slide in staggered when the report
  /// lands. No looping animations anywhere on this screen (battery).
  late final AnimationController _entrance = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));

  LeakReport? get _report => _bundle?.report;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _bundle = null;
      _error = null;
    });
    try {
      final bundle = await LeakReportService.generate();
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        // Progressive disclosure: only the top leak greets you open.
        final leaks = bundle.report.leaks;
        if (leaks.isNotEmpty) _expanded.add(leaks.first.id);
      });
      _entrance.forward(from: 0);
    } catch (e) {
      if (mounted) setState(() => _error = UserFacingError.message(e));
    }
  }

  Color _statusColor(LeakFinding f) {
    if (!f.isLeak) return AppColors.accentPrimary;
    return f.severity > 0.5 ? AppColors.accentDanger : AppColors.accentTertiary;
  }

  String _pct(double v) => '${(v * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            TopNavBar(
              title: 'Leak Detector',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: AppTypography.ibm(
                      fontSize: 15, color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.md),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final report = _report;
    if (report == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final leaks = report.leaks;
    final healthy = report.healthy;
    final insufficient = report.insufficient;

    return ListView(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      children: [
        _reveal(0, _statStrip(report)),
        const SizedBox(height: AppSpacing.md),
        if (report.coachSummary.isNotEmpty) ...[
          _reveal(1, _coachNote(report.coachSummary)),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (leaks.isNotEmpty) ...[
          _reveal(2, _sectionTitle('DETECTED LEAKS')),
          for (var i = 0; i < leaks.length; i++)
            _reveal(3 + i, _leakCard(leaks[i])),
          const SizedBox(height: AppSpacing.lg),
        ] else if (report.handsAnalyzed > 0) ...[
          _reveal(2, _sectionTitle('NO LEAKS DETECTED')),
          _reveal(
            3,
            Text(
              'Nothing outside healthy ranges yet — keep logging, the '
              'detectors sharpen with every hand.',
              style: AppTypography.ibm(
                  fontSize: 14, color: AppColors.textSecondary, height: 1.4),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (report.positionNets.isNotEmpty) ...[
          _reveal(4, _sectionTitle('MONEY BY POSITION')),
          _reveal(4, _moneyCard(report)),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (healthy.isNotEmpty) ...[
          _reveal(5, _sectionTitle('LOOKING SOLID')),
          _reveal(5, _healthyGrid(healthy)),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (insufficient.isNotEmpty) ...[
          _reveal(6, _sectionTitle('UNLOCK WITH MORE HANDS')),
          for (final f in insufficient) _reveal(6, _unlockRow(f)),
        ],
        const SizedBox(height: 120),
      ],
    );
  }

  /// Staggered fade + 12px rise for section [index] (0-based order on the
  /// page), driven by the one-shot entrance controller.
  Widget _reveal(int index, Widget child) {
    final start = (0.08 * index).clamp(0.0, 0.5);
    final curved = CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, (start + 0.45).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
                begin: const Offset(0, 0.04), end: Offset.zero)
            .animate(curved),
        child: child,
      ),
    );
  }

  // ── Header pieces ───────────────────────────────────────────────────

  Widget _statStrip(LeakReport report) {
    return Row(
      children: [
        _statTile('${report.handsAnalyzed}', 'HANDS', Colors.white),
        const SizedBox(width: AppSpacing.xxs),
        _statTile(
            '${report.leaks.length}',
            report.leaks.length == 1 ? 'LEAK' : 'LEAKS',
            report.leaks.isEmpty
                ? AppColors.accentPrimary
                : AppColors.accentTertiary),
        const SizedBox(width: AppSpacing.xxs),
        _statTile('${report.healthy.length}', 'SOLID', AppColors.accentPrimary),
      ],
    );
  }

  Widget _statTile(String value, String label, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          children: [
            TweenNumber(
                value: double.tryParse(value) ?? 0,
                format: (v) => v.round().toString(),
                animateOnMount: true,
                duration: const Duration(milliseconds: 700),
                style: AppTypography.mono(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: valueColor)),
            const SizedBox(height: 2),
            Text(label,
                style: AppTypography.ibm(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _coachNote(String summary) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        border:
            Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.record_voice_over_outlined,
                  size: 14, color: AppColors.accentPrimary),
              const SizedBox(width: 6),
              Text("COACH'S READ",
                  style: AppTypography.ibm(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: AppColors.accentPrimary)),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(summary,
              style: AppTypography.ibm(
                  fontSize: 13, color: Colors.white, height: 1.45)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(text,
            style: AppTypography.ibm(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.accentTertiary,
              letterSpacing: 1.0,
            )),
      );

  // ── Leak cards (collapsed gauge → expanded coaching) ────────────────

  Widget _leakCard(LeakFinding f) {
    final status = _statusColor(f);
    final expanded = _expanded.contains(f.id);
    final confirmed = f.verdict == LeakVerdict.confirmed;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        border: Border.all(color: status.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
          onTap: () => setState(() {
            expanded ? _expanded.remove(f.id) : _expanded.add(f.id);
          }),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(f.title,
                          style: AppTypography.ibm(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: status.withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(AppDecorations.radiusFull),
                      ),
                      child: Text(confirmed ? 'CONFIRMED' : 'EMERGING',
                          style: AppTypography.ibm(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: status)),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(Icons.keyboard_arrow_down,
                          size: 18, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _BandGauge(
                  value: f.value,
                  bandLow: f.bandLow,
                  bandHigh: f.bandHigh,
                  markerColor: status,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        'you ${_pct(f.value)} · healthy '
                        '${_pct(f.bandLow)}–${_pct(f.bandHigh)}',
                        style: AppTypography.mono(
                            fontSize: 11, color: AppColors.textSecondary)),
                    Text('${f.sampleCount} spots',
                        style: AppTypography.mono(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: expanded
                      ? _expandedDetail(f)
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _expandedDetail(LeakFinding f) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Text(f.meaning,
            style: AppTypography.ibm(
                fontSize: 14, color: Colors.white, height: 1.4)),
        const SizedBox(height: AppSpacing.xxs),
        Text(f.cost,
            style: AppTypography.ibm(
                fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppColors.accentPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          ),
          child: Text('THE FIX — ${f.fix}',
              style: AppTypography.ibm(
                  fontSize: 13, color: Colors.white, height: 1.4)),
        ),
        if (f.slices.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final s in f.slices) _sliceChip(s)],
          ),
        ],
        if (f.examples.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text('FROM YOUR HANDS',
              style: AppTypography.ibm(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          for (final ex in f.examples) _exampleRow(ex),
        ],
        if (_drillPresetFor(f.id) != null) ...[
          const SizedBox(height: AppSpacing.xs),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => _drillPresetFor(f.id)!),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accentPrimary,
                borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
              ),
              child: Center(
                child: Text('Practice this spot',
                    style: AppTypography.ibm(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sliceChip(LeakSlice s) {
    final color = s.flagged ? AppColors.accentDanger : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: s.flagged
            ? AppColors.accentDanger.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
        border: s.flagged
            ? Border.all(color: AppColors.accentDanger.withValues(alpha: 0.35))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (s.flagged) ...[
            Icon(Icons.warning_amber_rounded, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text('${s.label} ${_pct(s.value)}',
              style: AppTypography.mono(fontSize: 11, color: Colors.white)),
          const SizedBox(width: 3),
          Text('n=${s.sampleCount}',
              style: AppTypography.mono(fontSize: 10, color: color)),
        ],
      ),
    );
  }

  Widget _exampleRow(LeakExample ex) {
    final hand = _bundle?.handsByRef[ex.ref];
    final parts = <String>[
      '#${ex.handNumber}',
      if (ex.posGroup != null) ex.posGroup!,
      if (ex.holeCards != null) ex.holeCards!,
      if (ex.textureLabel != null) ex.textureLabel!,
      if (ex.strengthLabel != null) ex.strengthLabel!,
    ];
    return InkWell(
      onTap: hand == null
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HandActionsScreen(
                    hand: hand,
                    ourSeat: hand['heroSeatNumber'] as int?,
                  ),
                ),
              ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Text(parts.join(' · '),
                  style:
                      AppTypography.mono(fontSize: 12, color: Colors.white)),
            ),
            if (hand != null)
              const Icon(Icons.chevron_right,
                  size: 15, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  /// Preflop leaks map to a preset drill session; postflop spots have no
  /// drill equivalent yet (drills are preflop-only) — no button there.
  Widget? _drillPresetFor(String findingId) {
    final base = findingId.split('@').first;
    switch (base) {
      case 'fold_to_3bet':
      case 'bb_vs_steal':
      case 'limp_habit':
        return const DrillSetupScreen(presetStackBB: 40, presetAnte: true);
      default:
        return null;
    }
  }

  // ── Money view (BB by position, worst drillable spots) ──────────────

  Widget _moneyCard(LeakReport report) {
    final maxAbs = report.positionNets
        .map((p) => p.netBBTotal.abs())
        .fold<double>(1, (m, v) => v > m ? v : m);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in report.positionNets) _positionBarRow(p, maxAbs),
          if (report.worstSpots.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('WORST SPOTS — TOTAL BB LOST',
                style: AppTypography.ibm(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            for (final sp in report.worstSpots) _spotRow(sp),
          ],
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Directional only — live samples swing hard. Blinds include '
            'forced posts.',
            style: AppTypography.ibm(
                fontSize: 10, color: AppColors.textDisabled),
          ),
        ],
      ),
    );
  }

  Widget _positionBarRow(PositionNet p, double maxAbs) {
    final positive = p.netBBTotal >= 0;
    final frac = (p.netBBTotal.abs() / maxAbs).clamp(0.02, 1.0);
    final color = positive ? AppColors.accentPrimary : AppColors.accentDanger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(p.pos,
                style: AppTypography.mono(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
          // Diverging bar: zero line in the middle, loss grows left (red),
          // profit grows right (teal).
          Expanded(
            child: SizedBox(
              height: 12,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final half = constraints.maxWidth / 2;
                  final barWidth = half * frac;
                  return Stack(
                    children: [
                      Positioned(
                        left: half - 0.5,
                        top: 0,
                        bottom: 0,
                        child: Container(
                            width: 1,
                            color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: barWidth),
                        duration: const Duration(milliseconds: 550),
                        curve: Curves.easeOutCubic,
                        builder: (context, w, _) => Positioned(
                          left: positive ? half : half - w,
                          top: 3,
                          child: Container(
                            width: w,
                            height: 6,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.horizontal(
                                left: Radius.circular(positive ? 0 : 3),
                                right: Radius.circular(positive ? 3 : 0),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          SizedBox(
            width: 88,
            child: Text(
              '${positive ? '+' : ''}${p.netBBTotal.toStringAsFixed(0)}bb '
              '· ${p.hands}h',
              textAlign: TextAlign.right,
              style: AppTypography.mono(fontSize: 11, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _spotRow(SpotNet sp) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(sp.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.ibm(fontSize: 13, color: Colors.white)),
          ),
          Text(
            '${sp.netBBTotal.toStringAsFixed(0)}bb · ${sp.hands}h',
            style: AppTypography.mono(
                fontSize: 11, color: AppColors.accentDanger),
          ),
          const SizedBox(width: AppSpacing.xxs),
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DrillSetupScreen(
                    presetStackBB: sp.presetStackBB, presetAnte: true),
              ),
            ),
            borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
              ),
              child: Text('Drill',
                  style: AppTypography.ibm(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentPrimary)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Healthy grid + unlock rows ──────────────────────────────────────

  Widget _healthyGrid(List<LeakFinding> healthy) {
    return Wrap(
      spacing: AppSpacing.xxs,
      runSpacing: AppSpacing.xxs,
      children: [for (final f in healthy) _healthyTile(f)],
    );
  }

  Widget _healthyTile(LeakFinding f) {
    final width = (MediaQuery.of(context).size.width -
            AppSpacing.md * 2 -
            AppSpacing.xxs) /
        2;
    return Container(
      width: width,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(f.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.ibm(
                  fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(_pct(f.value),
                  style: AppTypography.mono(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: _BandGauge(
                  value: f.value,
                  bandLow: f.bandLow,
                  bandHigh: f.bandHigh,
                  markerColor: AppColors.accentPrimary,
                  height: 4,
                  markerRadius: 3.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _unlockRow(LeakFinding f) {
    final progress = (f.sampleCount / f.minSample).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(f.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.ibm(fontSize: 13, color: Colors.white)),
          ),
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 4,
                child: Stack(
                  children: [
                    Container(color: Colors.white.withValues(alpha: 0.06)),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, p, _) => FractionallySizedBox(
                        widthFactor: p,
                        child: Container(color: AppColors.accentPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          SizedBox(
            width: 44,
            child: Text('${f.sampleCount}/${f.minSample}',
                textAlign: TextAlign.right,
                style: AppTypography.mono(
                    fontSize: 11, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

/// Bullet-style band gauge: recessive track, tinted healthy-band segment,
/// status-colored value marker with a surface ring (dataviz mark specs:
/// thin marks, ring separation on overlap, color carries status while
/// text stays in text tokens).
class _BandGauge extends StatelessWidget {
  final double value;
  final double bandLow;
  final double bandHigh;
  final Color markerColor;
  final double height;
  final double markerRadius;

  const _BandGauge({
    required this.value,
    required this.bandLow,
    required this.bandHigh,
    required this.markerColor,
    this.height = 6,
    this.markerRadius = 5,
  });

  @override
  Widget build(BuildContext context) {
    // Micro-animation: the marker sweeps from the healthy-band center out
    // to the measured value — the gauge "takes its reading" on arrival.
    final bandCenter = (bandLow + bandHigh) / 2;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        final shown = bandCenter + (value.clamp(0.0, 1.0) - bandCenter) * t;
        return SizedBox(
          height: markerRadius * 2 + 4,
          child: CustomPaint(
            size: Size.infinite,
            painter: _BandGaugePainter(
              value: shown,
              bandLow: bandLow,
              bandHigh: bandHigh,
              markerColor: markerColor,
              trackHeight: height,
              markerRadius: markerRadius,
            ),
          ),
        );
      },
    );
  }
}

class _BandGaugePainter extends CustomPainter {
  final double value;
  final double bandLow;
  final double bandHigh;
  final Color markerColor;
  final double trackHeight;
  final double markerRadius;

  _BandGaugePainter({
    required this.value,
    required this.bandLow,
    required this.bandHigh,
    required this.markerColor,
    required this.trackHeight,
    required this.markerRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final radius = Radius.circular(trackHeight / 2);

    // Track — recessive.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, cy - trackHeight / 2, size.width, trackHeight),
        radius,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.07),
    );

    // Healthy band — teal tint, the "good zone" reference.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bandLow * size.width, cy - trackHeight / 2,
            (bandHigh - bandLow) * size.width, trackHeight),
        radius,
      ),
      Paint()..color = AppColors.accentPrimary.withValues(alpha: 0.28),
    );

    // Marker — surface ring first, then the status dot (keeps the dot
    // legible when it sits on the band).
    final cx = (value * size.width)
        .clamp(markerRadius + 1, size.width - markerRadius - 1);
    canvas.drawCircle(Offset(cx, cy), markerRadius + 2,
        Paint()..color = AppColors.bgSurface);
    canvas.drawCircle(
        Offset(cx, cy), markerRadius, Paint()..color = markerColor);
  }

  @override
  bool shouldRepaint(_BandGaugePainter old) =>
      old.value != value ||
      old.bandLow != bandLow ||
      old.bandHigh != bandHigh ||
      old.markerColor != markerColor;
}
