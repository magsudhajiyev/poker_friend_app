import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design_system/components/headers/top_nav_bar.dart';
import '../design_system/components/success_check_overlay.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';
import '../design_system/constants/spacing.dart';
import '../design_system/components/tween_number.dart';
import '../design_system/constants/typography.dart';
import '../design_system/components/scale_tap_feedback.dart';
import '../design_system/components/tabs/animated_segmented_tabs.dart';
import '../services/analytics_service.dart';
import '../services/leak_engine.dart';
import '../services/leak_focus_store.dart';
import '../services/leak_report_service.dart';
import '../services/leak_snapshot_store.dart';
import '../services/range_shape_service.dart';
import '../utils/user_facing_error.dart';
import '../widgets/leak_shape_mini_grid.dart';
import 'hand_actions_page_view.dart';
import 'hand_actions_screen.dart';
import 'range_grid_screen.dart';
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
    with TickerProviderStateMixin {
  LeakReportBundle? _bundle;
  String? _error;
  final Set<String> _expanded = {};

  /// What changed since the previous visit (null on first run).
  LeakSnapshotDiff? _diff;

  /// The leak the player committed to fixing (investment loop, R2) and
  /// the permanent trophy shelf of leaks already fixed.
  LeakFocusGoal? _focus;
  List<FixedLeak> _fixed = const [];

  /// RANGE SHAPE (R11): player's opening ranges vs the baseline charts.
  /// Loaded after the main report so it never delays first paint.
  RangeShapeReport? _shape;

  /// The game type most of the player's analyzed hands belong to — grid
  /// deep links open on THIS tab so an MTT player lands on MTT ranges,
  /// not an empty cash grid.
  String _dominantGameType = 'cash';

  /// Tab IA (one tab per player question): 0 Leaks ("what needs work"),
  /// 1 Ranges ("with which hands"), 2 Health ("how am I doing").
  late final TabController _tabs = TabController(length: 3, vsync: this)
    ..addListener(_onTabChanged);
  int _lastTabIndex = 0;

  /// Collapsed by default — returning users see the signal in one line.
  bool _newsExpanded = false;

  /// Selected position on the Ranges tab (null = first sufficient).
  String? _shapePos;

  void _onTabChanged() {
    if (_tabs.indexIsChanging || _tabs.index == _lastTabIndex) return;
    _lastTabIndex = _tabs.index;
    HapticFeedback.selectionClick();
    AnalyticsService.capture('leak_tab_viewed',
        {'tab': const ['leaks', 'ranges', 'health'][_tabs.index]});
  }

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
    _tabs.dispose();
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _bundle = null;
      _error = null;
    });
    await _generateAndApply(firstLoad: true);
  }

  /// Pull-to-refresh entry — same pipeline, but keeps the current report
  /// on screen until the new one lands.
  Future<void> _refresh() => _generateAndApply(firstLoad: false);

  Future<void> _generateAndApply({required bool firstLoad}) async {
    try {
      final previous = await LeakSnapshotStore.load();
      final bundle = await LeakReportService.generate();
      final current =
          LeakSnapshot.fromReport(bundle.report, DateTime.now());
      final diff = previous != null
          ? LeakSnapshotDiff.compute(previous, current)
          : null;
      // Persist AFTER diffing so "since last visit" survives hot reloads
      // of the same session but updates on every fresh report.
      await LeakSnapshotStore.save(current);

      // Focus goal lifecycle: a focused leak whose verdict flipped to
      // healthy graduates to the FIXED LEAKS shelf — the one big payoff
      // moment this screen has, so it earns the full celebration.
      var focus = await LeakFocusStore.loadFocus();
      var fixed = await LeakFocusStore.loadFixed();
      FixedLeak? justFixed;
      if (focus != null) {
        final finding = bundle.report.findings
            .where((x) => x.id == focus!.findingId)
            .firstOrNull;
        if (finding != null && finding.verdict == LeakVerdict.healthy) {
          justFixed = FixedLeak(
            findingId: focus.findingId,
            title: focus.title,
            startedAt: focus.startedAt,
            fixedAt: DateTime.now(),
            startValue: focus.startValue,
            fixedValue: finding.value,
          );
          await LeakFocusStore.recordFixed(justFixed);
          fixed = [justFixed, ...fixed];
          focus = null;
        }
      }

      var mtt = 0;
      var cash = 0;
      for (final hand in bundle.handsByRef.values) {
        hand['gameType'] == 'tournament' ? mtt++ : cash++;
      }

      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _diff = diff;
        _focus = focus;
        _fixed = fixed;
        _dominantGameType = mtt > cash ? 'tournament' : 'cash';
        // Progressive disclosure: only the top leak greets you open.
        final leaks = bundle.report.leaks;
        if (firstLoad && leaks.isNotEmpty) _expanded.add(leaks.first.id);
      });
      if (firstLoad) _entrance.forward(from: 0);
      unawaited(_loadShape());

      if (justFixed != null) {
        HapticFeedback.heavyImpact(); // big-win tier (poker_hand ladder)
        SuccessCheckOverlay.show(context);
        AnalyticsService.capture('leak_goal_fixed', {
          'finding_id': justFixed.findingId,
          'days_to_fix': justFixed.daysToFix,
        });
      }
      if (firstLoad) {
        AnalyticsService.capture('leak_report_viewed', {
          'hands': bundle.report.handsAnalyzed,
          'leaks': bundle.report.leaks.length,
          'healthy': bundle.report.healthy.length,
          'insufficient': bundle.report.insufficient.length,
          'has_previous_visit': diff != null,
          'changes_since_last': diff?.changes.length ?? 0,
        });
      }
    } catch (e) {
      // First load shows the error state; a failed refresh keeps the
      // current report (non-fatal).
      if (firstLoad && mounted) {
        setState(() => _error = UserFacingError.message(e));
      }
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
      return _loadingSkeleton();
    }

    return Column(
      children: [
        // Global header: one compact stats line + the tab switcher.
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _reveal(0, _compactStats(report)),
              const SizedBox(height: AppSpacing.xxs),
              _reveal(0, _updatedStamp(report)),
              const SizedBox(height: AppSpacing.sm),
              _reveal(1,
                  AnimatedSegmentedTabs(controller: _tabs, labels: const [
                // Poker-player vocabulary, English like the rest of the
                // screen (pre-GA).
                'Leaks', 'Ranges', 'Health',
              ])),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _tabList('leaks', _leaksTabChildren(report)),
              _tabList('ranges', _rangesTabChildren()),
              _tabList('health', _healthTabChildren(report)),
            ],
          ),
        ),
      ],
    );
  }

  /// Every tab is its own pull-to-refresh list with a preserved scroll
  /// position. Kept alive so swiping between tabs composites the existing
  /// page instead of rebuilding it (and replaying entrance animations)
  /// mid-gesture.
  Widget _tabList(String storageKey, List<Widget> children) {
    return _KeepAliveTab(
      child: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.accentPrimary,
        backgroundColor: AppColors.bgSurface,
        child: ListView(
          key: PageStorageKey('leak_tab_$storageKey'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          children: [...children, const SizedBox(height: 120)],
        ),
      ),
    );
  }

  // ── Tab 1: LEAKS — "what needs my work" ─────────────────────────────

  List<Widget> _leaksTabChildren(LeakReport report) {
    final leaks = report.leaks;
    // Nearest-to-unlock first: scarcity becomes a goal ladder, not a
    // disappointment list.
    final insufficient = [...report.insufficient]..sort((a, b) =>
        (a.minSample - a.sampleCount).compareTo(b.minSample - b.sampleCount));
    final news = _diff != null && _diff!.changes.isNotEmpty;

    return [
      if (news) ...[
        _reveal(1, _newsSection(_diff!)),
        const SizedBox(height: AppSpacing.md),
      ],
      if (leaks.isNotEmpty) ...[
        // The focused leak owns the hero slot even when a new leak
        // out-severities it — the player committed to THIS one.
        ...(() {
          final focusLeak = _focus != null
              ? leaks.where((l) => l.id == _focus!.findingId).firstOrNull
              : null;
          final hero = focusLeak ?? leaks.first;
          final rest = leaks.where((l) => l.id != hero.id).toList();
          return <Widget>[
            _reveal(
                2,
                _sectionTitle(
                    focusLeak != null ? 'YOUR FOCUS' : 'YOUR #1 LEAK')),
            _reveal(2, _heroCard(hero, report.coachSummary)),
            if (rest.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _reveal(3, _sectionTitle('ALSO DETECTED')),
              for (var i = 0; i < rest.length; i++)
                _reveal(3 + i, _leakRow(rest[i])),
            ],
            const SizedBox(height: AppSpacing.lg),
          ];
        })(),
      ] else if (report.handsAnalyzed > 0) ...[
        if (report.coachSummary.isNotEmpty) ...[
          _reveal(1, _coachNote(report.coachSummary)),
          const SizedBox(height: AppSpacing.lg),
        ],
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
      if (insufficient.isNotEmpty) ...[
        _reveal(5, _sectionTitle('UNLOCK WITH MORE HANDS')),
        for (var i = 0; i < insufficient.length; i++)
          _reveal(5, _unlockCard(insufficient[i], isNext: i == 0)),
      ],
    ];
  }

  /// "Also detected" leaks render as compact one-line rows so they don't
  /// compete with the hero; tapping swaps in the full coaching card.
  Widget _leakRow(LeakFinding f) {
    if (_expanded.contains(f.id)) return _leakCard(f);
    final status = _statusColor(f);
    return ScaleTapFeedback(
      onTap: () => _toggleExpanded(f),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xxs),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          border: Border.all(color: status.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Text(f.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.ibm(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
            if (_deltaChip(f) != null) _deltaChip(f)!,
            Expanded(
              flex: 3,
              child: _BandGauge(
                value: f.value,
                bandLow: f.bandLow,
                bandHigh: f.bandHigh,
                markerColor: status,
                height: 4,
                markerRadius: 3.5,
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            Text(_pct(f.value),
                style: AppTypography.mono(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: status)),
            const Icon(Icons.keyboard_arrow_down,
                size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  /// News collapsed to one line by default; expands to the full card.
  Widget _newsSection(LeakSnapshotDiff diff) {
    if (_newsExpanded) {
      return GestureDetector(
        onTap: () => setState(() => _newsExpanded = false),
        child: _sinceLastVisitCard(diff),
      );
    }
    final n = diff.changes.length;
    return ScaleTapFeedback(
      onTap: () => setState(() => _newsExpanded = true),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.accentSecondary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          border: Border.all(
              color: AppColors.accentSecondary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome,
                size: 13, color: AppColors.accentSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$n ${n == 1 ? 'change' : 'changes'} since your last visit'
                '${diff.handsDelta > 0 ? ' · +${diff.handsDelta} hands' : ''}',
                style: AppTypography.ibm(
                    fontSize: 13, color: Colors.white),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down,
                size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  // ── Tab 2: RANGES — "with which hands" ──────────────────────────────

  List<Widget> _rangesTabChildren() {
    final shape = _shape;
    if (shape == null) {
      return [
        const SizedBox(height: AppSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.accentPrimary),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text('Comparing your opens against the charts…',
                style: AppTypography.ibm(
                    fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      ];
    }

    final sufficient = shape.sufficient;
    if (sufficient.isEmpty) {
      return [
        const SizedBox(height: AppSpacing.md),
        _sectionTitle('RANGE SHAPE · OPENING'),
        Text(
          'Once a position reaches '
          '${RangeShapeService.minPositionSpots} first-in spots, your '
          'actual opening range appears here cell-by-cell against the '
          'baseline chart.',
          style: AppTypography.ibm(
              fontSize: 13, color: AppColors.textSecondary, height: 1.45),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (shape.insufficient.any((p) => p.sampledSpots > 0))
          Text(
            'Progress: ${shape.insufficient.where((p) => p.sampledSpots > 0).map((p) => '${p.posGroup} ${p.sampledSpots}/${RangeShapeService.minPositionSpots}').join(' · ')}',
            style: AppTypography.mono(
                fontSize: 11, color: AppColors.textSecondary),
          ),
      ];
    }

    final selected = sufficient
            .where((p) => p.posGroup == _shapePos)
            .firstOrNull ??
        sufficient.first;

    return [
      _sectionTitle('RANGE SHAPE · OPENING'),
      _positionChipRow(shape, selected.posGroup),
      const SizedBox(height: AppSpacing.xs),
      _fadeRise(_shapeCard(selected)),
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          'vs the app\'s baseline opening charts (~100BB) — '
          'directional, not a verdict.',
          style:
              AppTypography.ibm(fontSize: 10, color: AppColors.textDisabled),
        ),
      ),
      if (shape.insufficient.any((p) => p.sampledSpots > 0)) ...[
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'More opens unlock: ${shape.insufficient.where((p) => p.sampledSpots > 0).map((p) => '${p.posGroup} ${p.sampledSpots}/${RangeShapeService.minPositionSpots}').join(' · ')}',
          style: AppTypography.mono(
              fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    ];
  }

  /// EP · MP · CO · BTN · SB chips — sufficient positions are selectable,
  /// locked ones show their progress and stay dimmed.
  Widget _positionChipRow(RangeShapeReport shape, String selectedPos) {
    return Row(
      children: [
        for (final p in shape.positions) ...[
          Expanded(
            child: ScaleTapFeedback(
              onTap: p.sufficient
                  ? () {
                      HapticFeedback.selectionClick();
                      setState(() => _shapePos = p.posGroup);
                    }
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: p.posGroup == selectedPos
                      ? AppColors.accentPrimary.withValues(alpha: 0.15)
                      : AppColors.bgSurface,
                  borderRadius:
                      BorderRadius.circular(AppDecorations.radiusSm),
                  border: Border.all(
                    color: p.posGroup == selectedPos
                        ? AppColors.accentPrimary
                        : AppColors.borderStrong,
                  ),
                ),
                child: Column(
                  children: [
                    Text(p.posGroup,
                        style: AppTypography.mono(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: p.sufficient
                                ? (p.posGroup == selectedPos
                                    ? AppColors.accentPrimary
                                    : Colors.white)
                                : AppColors.textDisabled)),
                    if (!p.sufficient)
                      Text(
                          '${p.sampledSpots}/${RangeShapeService.minPositionSpots}',
                          style: AppTypography.mono(
                              fontSize: 8,
                              color: AppColors.textDisabled)),
                  ],
                ),
              ),
            ),
          ),
          if (p != shape.positions.last) const SizedBox(width: 6),
        ],
      ],
    );
  }

  // ── Tab 3: HEALTH — "how am I doing" ────────────────────────────────

  List<Widget> _healthTabChildren(LeakReport report) {
    final healthy = report.healthy;
    return [
      if (healthy.isNotEmpty) ...[
        _sectionTitle('LOOKING SOLID'),
        _healthyGrid(healthy),
        const SizedBox(height: AppSpacing.lg),
      ],
      if (_fixed.isNotEmpty) ...[
        _sectionTitle('FIXED LEAKS'),
        _fixedShelf(),
        const SizedBox(height: AppSpacing.lg),
      ],
      if (report.positionNets.isNotEmpty) ...[
        _sectionTitle('MONEY BY POSITION'),
        _moneyCard(report),
      ],
      if (healthy.isEmpty && _fixed.isEmpty && report.positionNets.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xl),
          child: Text(
            'Healthy checks, fixed leaks and the money view land here as '
            'your sample grows.',
            textAlign: TextAlign.center,
            style: AppTypography.ibm(
                fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
    ];
  }

  /// Static skeleton of the report layout (no looping animations on this
  /// screen — battery) with an honest "working" line: read-time
  /// aggregation really is re-crunching every hand.
  Widget _loadingSkeleton() {
    Widget block(double height, {double? width}) => Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: AppColors.bgSurface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: block(64)),
            const SizedBox(width: AppSpacing.xxs),
            Expanded(child: block(64)),
            const SizedBox(width: AppSpacing.xxs),
            Expanded(child: block(64)),
          ]),
          const SizedBox(height: AppSpacing.md),
          block(170),
          const SizedBox(height: AppSpacing.xs),
          block(84),
          const SizedBox(height: AppSpacing.xs),
          block(84),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.accentPrimary),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('Re-reading every hand you\'ve logged…',
                  style: AppTypography.ibm(
                      fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _updatedStamp(LeakReport report) {
    final prev = _diff?.previousAt;
    final suffix = prev == null
        ? ''
        : ' · last visit ${_relativeDate(prev)}';
    return Text(
      'Based on ${report.handsAnalyzed} hands · updated just now'
      '$suffix · pull to refresh',
      style: AppTypography.ibm(fontSize: 11, color: AppColors.textDisabled),
    );
  }

  String _relativeDate(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inDays >= 30) return '${(d.inDays / 30).floor()}mo ago';
    if (d.inDays >= 1) return '${d.inDays}d ago';
    if (d.inHours >= 1) return '${d.inHours}h ago';
    return 'today';
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

  /// One-line stats header: the three former tiles compressed so the tabs
  /// and the hero fit above the fold.
  Widget _compactStats(LeakReport report) {
    Widget seg(int value, String label, Color color) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenNumber(
                value: value.toDouble(),
                format: (v) => v.round().toString(),
                animateOnMount: true,
                duration: const Duration(milliseconds: 700),
                style: AppTypography.mono(
                    fontSize: 17, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(width: 4),
            Text(label,
                style: AppTypography.ibm(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: AppColors.textSecondary)),
          ],
        );
    Widget dot() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text('·',
              style: AppTypography.mono(
                  fontSize: 14, color: AppColors.textDisabled)),
        );
    return Row(
      children: [
        seg(report.handsAnalyzed, 'HANDS', Colors.white),
        dot(),
        seg(
            report.leaks.length,
            report.leaks.length == 1 ? 'LEAK' : 'LEAKS',
            report.leaks.isEmpty
                ? AppColors.accentPrimary
                : AppColors.accentTertiary),
        dot(),
        seg(report.healthy.length, 'SOLID', AppColors.accentPrimary),
      ],
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

  // ── Range shape (R11) ───────────────────────────────────────────────

  /// One-shot fade + 12px rise for content that arrives after the main
  /// entrance stagger already finished (async sections).
  Widget _fadeRise(Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: c),
      ),
      child: child,
    );
  }

  Future<void> _loadShape() async {
    try {
      final shape = await RangeShapeService.generate();
      if (!mounted) return;
      setState(() => _shape = shape);
      if (shape.sufficient.isNotEmpty) {
        AnalyticsService.capture('leak_shape_viewed', {
          'positions': shape.sufficient.length,
          'missed_cells': shape.sufficient
              .fold<int>(0, (n, p) => n + p.missedOpens.length),
          'loose_cells': shape.sufficient
              .fold<int>(0, (n, p) => n + p.looseOpens.length),
        });
      }
    } catch (_) {
      // Shape is a bonus layer — never let it break the report.
    }
  }

  Widget _shapeCard(PositionShape p) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        border: Border.all(
          color: p.hasDeviations
              ? AppColors.accentTertiary.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius:
                      BorderRadius.circular(AppDecorations.radiusSm),
                ),
                child: Text(p.posGroup,
                    style: AppTypography.mono(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'you open ${_pct(p.playerOpenFreq)} of spots · '
                  'chart ≈${_pct(p.chartOpenPct)}',
                  style: AppTypography.mono(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
              Text('${p.sampledSpots} spots',
                  style: AppTypography.mono(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Full width with hand labels — the point is seeing WHICH hands.
          LeakShapeMiniGrid(
            posGroup: p.posGroup,
            aggregates: p.aggregates,
          ),
          if (p.hasDeviations) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final d in p.missedOpens)
                  _shapeChip(
                      '${d.handClass} folded ×${d.offActions}',
                      AppColors.accentTertiary),
                for (final d in p.looseOpens)
                  _shapeChip(
                      '${d.handClass} opened ×${d.offActions}',
                      AppColors.accentDanger),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: ScaleTapFeedback(
                  onTap: () {
                    AnalyticsService.capture('leak_shape_grid_opened', {
                      'pos_group': p.posGroup,
                      'game_type': _dominantGameType,
                    });
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RangeGridScreen(
                          initialPosGroup: p.posGroup,
                          initialScenario: 'rfi',
                          initialGameType: _dominantGameType,
                        ),
                      ),
                    );
                  },
                  child: _shapeCta(
                      Icons.grid_on, 'Open in grid', outlined: true),
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: ScaleTapFeedback(
                  onTap: () {
                    AnalyticsService.capture('leak_shape_practice_tapped',
                        {'pos_group': p.posGroup});
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DrillSetupScreen(
                            presetStackBB: 40, presetAnte: true),
                      ),
                    );
                  },
                  child: _shapeCta(Icons.fitness_center, 'Practice opens',
                      outlined: false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shapeChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(text,
          style: AppTypography.mono(fontSize: 11, color: Colors.white)),
    );
  }

  Widget _shapeCta(IconData icon, String label, {required bool outlined}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: outlined ? null : AppColors.accentPrimary,
        borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
        border: outlined
            ? Border.all(
                color: AppColors.accentPrimary.withValues(alpha: 0.6))
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 13,
              color:
                  outlined ? AppColors.accentPrimary : Colors.black),
          const SizedBox(width: 6),
          Text(label,
              style: AppTypography.ibm(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: outlined
                      ? AppColors.accentPrimary
                      : Colors.black)),
        ],
      ),
    );
  }

  // ── Since last visit (snapshot diff) ────────────────────────────────

  Widget _sinceLastVisitCard(LeakSnapshotDiff diff) {
    (IconData, Color, String) lineFor(LeakChange c) => switch (c.kind) {
          LeakChangeKind.becameHealthy => (
              Icons.check_circle_outline,
              AppColors.accentPrimary,
              '${c.title} — back in the healthy range'
            ),
          LeakChangeKind.unlocked => (
              Icons.lock_open_rounded,
              AppColors.accentSecondary,
              '${c.title} unlocked — enough spots for a verdict'
            ),
          LeakChangeKind.improved => (
              Icons.trending_flat,
              AppColors.accentPrimary,
              '${c.title} improving · ${_pct(c.previousValue ?? 0)} → '
                  '${_pct(c.currentValue)}'
            ),
          LeakChangeKind.becameLeak => (
              Icons.warning_amber_rounded,
              AppColors.accentDanger,
              '${c.title} slipped outside the band'
            ),
          LeakChangeKind.worsened => (
              Icons.trending_up,
              AppColors.accentDanger,
              '${c.title} drifting · ${_pct(c.previousValue ?? 0)} → '
                  '${_pct(c.currentValue)}'
            ),
        };

    final shown = diff.changes.take(4).toList();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accentSecondary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        border: Border.all(
            color: AppColors.accentSecondary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  size: 13, color: AppColors.accentSecondary),
              const SizedBox(width: 6),
              Text('SINCE YOUR LAST VISIT',
                  style: AppTypography.ibm(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: AppColors.accentSecondary)),
              const Spacer(),
              if (diff.handsDelta > 0)
                Text('+${diff.handsDelta} hands',
                    style: AppTypography.mono(
                        fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final c in shown) ...[
            Builder(builder: (context) {
              final (icon, color, text) = lineFor(c);
              // Good news lives on the Health tab — tap through to it.
              final jumpsToHealth = c.kind == LeakChangeKind.becameHealthy;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: jumpsToHealth ? () => _tabs.animateTo(2) : null,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 14, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(text,
                            style: AppTypography.ibm(
                                fontSize: 13,
                                color: Colors.white,
                                height: 1.35)),
                      ),
                      if (jumpsToHealth)
                        const Icon(Icons.chevron_right,
                            size: 14, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              );
            }),
          ],
          if (diff.changes.length > shown.length)
            Text('+${diff.changes.length - shown.length} more changes',
                style: AppTypography.ibm(
                    fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  /// Small "vs last visit" movement chip for a finding header. Color says
  /// whether the move was TOWARD the healthy band (good) or away (bad);
  /// the arrow says which way the raw number moved.
  Widget? _deltaChip(LeakFinding f) {
    final prev = _diff?.previousOf(f.id);
    if (prev == null || prev.verdict == LeakVerdict.insufficientData) {
      return null;
    }
    final deltaPts = ((f.value - prev.value) * 100).round();
    if (deltaPts == 0) return null;

    double dist(double v) => v < f.bandLow
        ? f.bandLow - v
        : (v > f.bandHigh ? v - f.bandHigh : 0);
    final moved = dist(prev.value) - dist(f.value);
    final color = moved > 0.001
        ? AppColors.accentPrimary
        : moved < -0.001
            ? AppColors.accentDanger
            : AppColors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(deltaPts > 0 ? Icons.arrow_upward : Icons.arrow_downward,
              size: 9, color: color),
          const SizedBox(width: 2),
          Text('${deltaPts.abs()}pt',
              style: AppTypography.mono(
                  fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  // ── Hero card (the one thing to fix) ────────────────────────────────

  Widget _heroCard(LeakFinding f, String coachSummary) {
    final status = _statusColor(f);
    final expanded = _expanded.contains(f.id);
    final confirmed = f.verdict == LeakVerdict.confirmed;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        border: Border.all(color: status.withValues(alpha: 0.55), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: status.withValues(alpha: 0.14),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            status.withValues(alpha: 0.10),
            AppColors.bgSurface,
          ],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
          onTap: () => _toggleExpanded(f),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (_deltaChip(f) != null) _deltaChip(f)!,
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: status.withValues(alpha: 0.18),
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
                const SizedBox(height: AppSpacing.xxs),
                Text(f.title,
                    style: AppTypography.ibm(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.25)),
                if (coachSummary.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(coachSummary,
                      style: AppTypography.ibm(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.45)),
                ],
                const SizedBox(height: AppSpacing.sm),
                _BandGauge(
                  value: f.value,
                  bandLow: f.bandLow,
                  bandHigh: f.bandHigh,
                  markerColor: status,
                ),
                const SizedBox(height: 6),
                _gaugeCaption(f),
                if (_focus?.findingId == f.id) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _focusStrip(f),
                ] else if (_focus == null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _workOnThisButton(f),
                ],
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

  /// "Work on this" — turns the hero leak into the player's active goal.
  Widget _workOnThisButton(LeakFinding f) {
    return ScaleTapFeedback(
      onTap: () async {
        HapticFeedback.selectionClick();
        final goal = LeakFocusGoal(
          findingId: f.id,
          title: f.title,
          startedAt: DateTime.now(),
          startValue: f.value,
          startSampleCount: f.sampleCount,
        );
        await LeakFocusStore.saveFocus(goal);
        if (!mounted) return;
        setState(() => _focus = goal);
        AnalyticsService.capture('leak_goal_set', {'finding_id': f.id});
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.accentPrimary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
          border: Border.all(
              color: AppColors.accentPrimary.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.flag_outlined,
                size: 14, color: AppColors.accentPrimary),
            const SizedBox(width: 6),
            Text('Work on this',
                style: AppTypography.ibm(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentPrimary)),
          ],
        ),
      ),
    );
  }

  /// Progress-since-committed strip on the focused leak. Spots and points
  /// only — honest counting, the celebration waits for the verdict flip.
  Widget _focusStrip(LeakFinding f) {
    final focus = _focus!;
    final days = DateTime.now().difference(focus.startedAt).inDays;
    final spotsAdded =
        (f.sampleCount - focus.startSampleCount).clamp(0, 1 << 30);
    final toBand = f.aboveBand ? f.value - f.bandHigh : f.bandLow - f.value;
    final ptsToGo = (toBand * 100).ceil().clamp(0, 100);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag, size: 13, color: AppColors.accentPrimary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Day ${days + 1} · +$spotsAdded spots · '
              '${_pct(focus.startValue)} → ${_pct(f.value)} · '
              '${ptsToGo}pt to the band',
              style: AppTypography.mono(
                  fontSize: 11, color: AppColors.textPrimary),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              await LeakFocusStore.clearFocus();
              if (!mounted) return;
              setState(() => _focus = null);
              AnalyticsService.capture(
                  'leak_goal_cleared', {'finding_id': f.id});
            },
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close,
                  size: 14, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  /// The trophy case: every leak the player has fixed, permanently.
  Widget _fixedShelf() {
    return Column(
      children: [
        for (final fl in _fixed)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.xxs),
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.accentTertiary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
              border: Border.all(
                  color: AppColors.accentTertiary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.accentTertiary.withValues(alpha: 0.15),
                    borderRadius:
                        BorderRadius.circular(AppDecorations.radius10),
                  ),
                  child: const Icon(Icons.emoji_events,
                      size: 18, color: AppColors.accentTertiary),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fl.title,
                          style: AppTypography.ibm(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(
                          '${_pct(fl.startValue)} → ${_pct(fl.fixedValue)}'
                          ' · fixed in ${fl.daysToFix < 1 ? '<1' : fl.daysToFix}d',
                          style: AppTypography.mono(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _toggleExpanded(LeakFinding f) {
    setState(() {
      if (!_expanded.remove(f.id)) {
        _expanded.add(f.id);
        AnalyticsService.capture(
            'leak_card_expanded', {'finding_id': f.id});
      }
    });
  }

  /// "you X% · healthy A–B% ⓘ · N spots" line with the band-rationale
  /// sheet behind the info glyph.
  Widget _gaugeCaption(LeakFinding f) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showBandSheet(f),
          child: Row(
            children: [
              Text(
                  'you ${_pct(f.value)} · healthy '
                  '${_pct(f.bandLow)}–${_pct(f.bandHigh)}',
                  style: AppTypography.mono(
                      fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(width: 4),
              const Icon(Icons.info_outline,
                  size: 12, color: AppColors.textDisabled),
            ],
          ),
        ),
        Text('${f.sampleCount} spots',
            style: AppTypography.mono(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  void _showBandSheet(LeakFinding f) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDecorations.radiusXl)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(f.title,
                  style: AppTypography.ibm(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                  'healthy ${_pct(f.bandLow)}–${_pct(f.bandHigh)} · '
                  'you ${_pct(f.value)} · ${f.sampleCount} spots '
                  '(verdicts need ${f.minSample}+)',
                  style: AppTypography.mono(
                      fontSize: 12, color: AppColors.accentPrimary)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Where this range comes from: population norms that online '
                'trackers and training material converged on over millions '
                'of hands, widened for live play and small samples so we '
                'under-flag rather than over-flag. It is a reference zone, '
                'not solver output — being outside it is a signal worth '
                'checking, not a verdict on a single hand.',
                style: AppTypography.ibm(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Below ${f.minSample} spots you\'ll see "not enough data" — '
                'never a verdict. Small-sample honesty is the whole point.',
                style: AppTypography.ibm(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
          onTap: () => _toggleExpanded(f),
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
                    if (_deltaChip(f) != null) _deltaChip(f)!,
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
                _gaugeCaption(f),
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
          for (final ex in f.examples) _exampleRow(ex, f.id),
          if (f.examples.length > 1) _reviewAllButton(f),
        ],
        if (_gridFilterFor(f.id) != null) ...[
          const SizedBox(height: AppSpacing.xs),
          _gridLinkButton(f),
        ],
        if (_drillPresetFor(f.id) != null) ...[
          const SizedBox(height: AppSpacing.xs),
          GestureDetector(
            onTap: () {
              AnalyticsService.capture(
                  'leak_practice_tapped', {'finding_id': f.id});
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => _drillPresetFor(f.id)!),
              );
            },
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

  /// One-tap swipeable review of all of a finding's example hands —
  /// reading becomes a 2-minute ritual instead of five separate taps.
  Widget _reviewAllButton(LeakFinding f) {
    final hands = <Map<String, dynamic>>[
      for (final ex in f.examples)
        if (_bundle?.handsByRef[ex.ref] != null)
          _bundle!.handsByRef[ex.ref]!,
    ];
    if (hands.length < 2) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerRight,
      child: ScaleTapFeedback(
        onTap: () {
          AnalyticsService.capture('leak_review_queue_opened', {
            'finding_id': f.id,
            'hands': hands.length,
          });
          Navigator.push(
            context,
            MaterialPageRoute(
              // ourSeat deliberately null: each page falls back to its
              // own hand's heroSeatNumber (session_hands precedent).
              builder: (_) => HandActionsPageView(hands: hands),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Review all ${hands.length} hands',
                  style: AppTypography.ibm(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentSecondary)),
              const SizedBox(width: 2),
              const Icon(Icons.swipe_right_alt,
                  size: 15, color: AppColors.accentSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exampleRow(LeakExample ex, String findingId) {
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
          : () {
              AnalyticsService.capture(
                  'leak_example_opened', {'finding_id': findingId});
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HandActionsScreen(
                    hand: hand,
                    ourSeat: hand['heroSeatNumber'] as int?,
                  ),
                ),
              );
            },
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

  /// Preflop leaks map onto a Range Grid view: the leak says HOW OFTEN,
  /// the grid shows WITH WHICH HANDS. Position slices carry their group
  /// into the filter. Postflop detectors have no preflop range view.
  ({String? posGroup, String scenario})? _gridFilterFor(String findingId) {
    final parts = findingId.split('@');
    const posGroups = {'EP', 'MP', 'CO', 'BTN', 'SB', 'BB'};
    final slicePos =
        parts.length > 1 && posGroups.contains(parts[1]) ? parts[1] : null;
    switch (parts.first) {
      case 'limp_habit':
      case 'fold_to_3bet':
        // Both are about the hands you choose to enter pots with.
        return (posGroup: slicePos, scenario: 'rfi');
      case 'bb_vs_steal':
        return (posGroup: 'BB', scenario: 'vs_raise');
      default:
        return null;
    }
  }

  Widget _gridLinkButton(LeakFinding f) {
    final filter = _gridFilterFor(f.id)!;
    // RFI leaks have a home inside this screen (Ranges tab) — switch tabs
    // instead of leaving. Defend spots (BB vs steal) have no shape card,
    // so they still push the full pre-filtered grid.
    final hasShapeHome = filter.scenario == 'rfi' &&
        (_shape?.sufficient.isNotEmpty ?? false);
    return ScaleTapFeedback(
      onTap: () {
        AnalyticsService.capture('leak_grid_opened', {
          'finding_id': f.id,
          'pos_group': filter.posGroup ?? 'all',
          'scenario': filter.scenario,
          'game_type': _dominantGameType,
          'in_screen': hasShapeHome,
        });
        if (hasShapeHome) {
          setState(() {
            if (filter.posGroup != null &&
                _shape!.sufficient
                    .any((p) => p.posGroup == filter.posGroup)) {
              _shapePos = filter.posGroup;
            }
          });
          _tabs.animateTo(1);
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RangeGridScreen(
              initialPosGroup: filter.posGroup,
              initialScenario: filter.scenario,
              initialGameType: _dominantGameType,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
          border: Border.all(
              color: AppColors.accentPrimary.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.grid_on,
                size: 14, color: AppColors.accentPrimary),
            const SizedBox(width: 6),
            Text('See the hands behind it',
                style: AppTypography.ibm(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentPrimary)),
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

  /// Progress-to-unlock card: a goal ("N more spots"), not a shortfall.
  /// The nearest detector gets the NEXT tag and an accent border — it's
  /// the screen's call to action when there's nothing to fix yet.
  Widget _unlockCard(LeakFinding f, {required bool isNext}) {
    final progress = (f.sampleCount / f.minSample).clamp(0.0, 1.0);
    final remaining = (f.minSample - f.sampleCount).clamp(0, f.minSample);
    final accent =
        isNext ? AppColors.accentSecondary : AppColors.textSecondary;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xxs),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        border: Border.all(
          color: isNext
              ? AppColors.accentSecondary.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, p, _) => CustomPaint(
                painter: _UnlockRingPainter(
                  progress: p,
                  color: accent,
                  trackColor: Colors.white.withValues(alpha: 0.08),
                ),
                child: Center(
                  child: Text('$remaining',
                      style: AppTypography.mono(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(f.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.ibm(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                    if (isNext) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentSecondary
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                              AppDecorations.radiusFull),
                        ),
                        child: Text('NEXT',
                            style: AppTypography.ibm(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: AppColors.accentSecondary)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                    remaining == 1
                        ? '1 more spot for a verdict'
                        : '$remaining more spots for a verdict',
                    style: AppTypography.ibm(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text('${f.sampleCount}/${f.minSample}',
              style: AppTypography.mono(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// Thin circular progress ring for the unlock cards (static paint; the
/// one-shot fill animation is driven by the TweenAnimationBuilder above).
class _UnlockRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  const _UnlockRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.5;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708, // start at 12 o'clock
      6.2832 * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_UnlockRingPainter old) =>
      old.progress != progress || old.color != color;
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

/// Keeps a [TabBarView] page mounted while off-screen so tab swipes don't
/// rebuild heavy content (the shape grid) or replay one-shot entrance
/// animations mid-gesture.
class _KeepAliveTab extends StatefulWidget {
  final Widget child;
  const _KeepAliveTab({required this.child});

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
