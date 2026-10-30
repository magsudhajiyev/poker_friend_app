import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design_system/components/headers/top_nav_bar.dart';
import '../design_system/components/success_check_overlay.dart';
import '../design_system/components/tabs/animated_segmented_tabs.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';
import '../design_system/constants/sizes.dart';
import '../design_system/constants/spacing.dart';
import '../design_system/constants/typography.dart';
import '../l10n/app_localizations.dart';
import '../services/analytics_service.dart';
import '../services/leak_engine.dart';
import '../services/leak_focus_store.dart';
import '../services/leak_report_service.dart';
import '../services/leak_snapshot_store.dart';
import '../services/range_shape_service.dart';
import '../utils/user_facing_error.dart';
import '../widgets/leak_detector/health_tab.dart';
import '../widgets/leak_detector/leak_card.dart';
import '../widgets/leak_detector/leak_detail.dart';
import '../widgets/leak_detector/leak_format.dart';
import '../widgets/leak_detector/leak_header.dart';
import '../widgets/leak_detector/leak_info_sheet.dart';
import '../widgets/leak_detector/leak_news_section.dart';
import '../widgets/leak_detector/leak_section_header.dart';
import '../widgets/leak_detector/leak_states.dart';
import '../widgets/leak_detector/ranges_tab.dart';
import '../widgets/leak_detector/unlock_section.dart';
import 'hand_actions_page_view.dart';
import 'hand_actions_screen.dart';
import 'logging_mode_selection_screen.dart';
import 'range_grid_screen.dart';
import 'training/drill_setup_screen.dart';

/// Loads the report. Defaults to [LeakReportService.generate]; tests inject
/// a fake so the screen can be pumped without Firebase.
typedef LeakReportLoader = Future<LeakReportBundle> Function();

/// Loads the range-shape layer. Defaults to [RangeShapeService.generate].
typedef RangeShapeLoader = Future<RangeShapeReport> Function();

/// LEAK DETECTOR (feature-flagged) — visual report screen.
///
/// Orchestrator only: loading, focus-goal lifecycle, navigation and
/// analytics live here; every visual piece is in `widgets/leak_detector/`.
/// Three tabs, one per player question: Leaks ("what needs work"), Ranges
/// ("with which hands"), Health ("how am I doing").
class LeakDetectorScreen extends StatefulWidget {
  final LeakReportLoader? loader;
  final RangeShapeLoader? shapeLoader;

  const LeakDetectorScreen({super.key, this.loader, this.shapeLoader});

  @override
  State<LeakDetectorScreen> createState() => _LeakDetectorScreenState();
}

class _LeakDetectorScreenState extends State<LeakDetectorScreen>
    with TickerProviderStateMixin {
  LeakReportBundle? _bundle;
  String? _error;

  /// What changed since the previous visit (null on first run).
  LeakSnapshotDiff? _diff;

  /// The leak the player committed to fixing + the shelf of fixed leaks.
  LeakFocusGoal? _focus;
  List<FixedLeak> _fixed = const [];

  /// Opening ranges vs baseline charts; loaded after the main report.
  RangeShapeReport? _shape;

  /// Game type most analysed hands belong to: grid deep links open on it.
  String _dominantGameType = 'cash';

  /// Only the top leak greets a first-time load expanded.
  String? _initiallyExpandedId;

  /// Selected position on the Ranges tab (null = first sufficient).
  String? _shapePos;

  late final TabController _tabs = TabController(length: 3, vsync: this)
    ..addListener(_onTabChanged);
  int _lastTabIndex = 0;

  /// One-shot entrance; no looping animations on this screen (battery).
  late final AnimationController _entrance =
      AnimationController(vsync: this, duration: AppMotion.entrance);

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

  void _onTabChanged() {
    if (_tabs.indexIsChanging || _tabs.index == _lastTabIndex) return;
    _lastTabIndex = _tabs.index;
    HapticFeedback.selectionClick();
    AnalyticsService.capture('leak_tab_viewed',
        {'tab': const ['leaks', 'ranges', 'health'][_tabs.index]});
  }

  // ── Loading ─────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _bundle = null;
      _error = null;
    });
    await _generateAndApply(firstLoad: true);
  }

  /// Pull-to-refresh: same pipeline, keeps the current report on screen
  /// until the new one lands.
  Future<void> _refresh() => _generateAndApply(firstLoad: false);

  Future<void> _generateAndApply({required bool firstLoad}) async {
    try {
      final previous = await LeakSnapshotStore.load();
      final bundle = await (widget.loader ?? LeakReportService.generate)();
      final current = LeakSnapshot.fromReport(bundle.report, DateTime.now());
      final diff = previous != null
          ? LeakSnapshotDiff.compute(previous, current)
          : null;
      // Persist AFTER diffing so "since last visit" survives hot reloads.
      await LeakSnapshotStore.save(current);

      var focus = await LeakFocusStore.loadFocus();
      var fixed = await LeakFocusStore.loadFixed();
      final justFixed = await _graduateFocus(bundle.report, focus);
      if (justFixed != null) {
        fixed = [justFixed, ...fixed];
        focus = null;
      }

      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _diff = diff;
        _focus = focus;
        _fixed = fixed;
        _dominantGameType = _dominantGame(bundle);
        final leaks = bundle.report.leaks;
        if (firstLoad && leaks.isNotEmpty) _initiallyExpandedId = leaks.first.id;
      });
      if (firstLoad) _playEntrance();
      unawaited(_loadShape());
      if (justFixed != null) _celebrate(justFixed);
      if (firstLoad) _trackViewed(bundle.report, diff);
    } catch (e) {
      if (!mounted) return;
      if (firstLoad) {
        setState(() => _error = UserFacingError.message(e));
      } else {
        _showRefreshFailed();
      }
    }
  }

  /// A focused leak whose verdict flipped to healthy graduates to the
  /// FIXED LEAKS shelf: the one big payoff moment this screen has.
  Future<FixedLeak?> _graduateFocus(
      LeakReport report, LeakFocusGoal? focus) async {
    if (focus == null) return null;
    final finding =
        report.findings.where((x) => x.id == focus.findingId).firstOrNull;
    if (finding == null || finding.verdict != LeakVerdict.healthy) return null;
    final fixed = FixedLeak(
      findingId: focus.findingId,
      title: focus.title,
      startedAt: focus.startedAt,
      fixedAt: DateTime.now(),
      startValue: focus.startValue,
      fixedValue: finding.value,
    );
    await LeakFocusStore.recordFixed(fixed);
    return fixed;
  }

  String _dominantGame(LeakReportBundle bundle) {
    var mtt = 0;
    var cash = 0;
    for (final hand in bundle.handsByRef.values) {
      hand['gameType'] == 'tournament' ? mtt++ : cash++;
    }
    return mtt > cash ? 'tournament' : 'cash';
  }

  void _playEntrance() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward(from: 0);
    }
  }

  void _celebrate(FixedLeak fixed) {
    HapticFeedback.heavyImpact(); // big-win tier
    SuccessCheckOverlay.show(context);
    AnalyticsService.capture('leak_goal_fixed', {
      'finding_id': fixed.findingId,
      'days_to_fix': fixed.daysToFix,
    });
  }

  void _trackViewed(LeakReport report, LeakSnapshotDiff? diff) {
    AnalyticsService.capture('leak_report_viewed', {
      'hands': report.handsAnalyzed,
      'leaks': report.leaks.length,
      'healthy': report.healthy.length,
      'insufficient': report.insufficient.length,
      'has_previous_visit': diff != null,
      'changes_since_last': diff?.changes.length ?? 0,
    });
  }

  void _showRefreshFailed() {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l10n.leakRefreshFailed,
            style: AppTypography.bodySmMedium(color: AppColors.textPrimary)),
        backgroundColor: AppColors.bgElevated,
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _loadShape() async {
    try {
      final shape =
          await (widget.shapeLoader ?? RangeShapeService.generate)();
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
      // Shape is a bonus layer: never let it break the report.
    }
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            TopNavBar(
              title: l10n.leakTitle,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                      maxWidth: AppSizes.contentMaxWidth),
                  child: _buildBody(l10n),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_error != null) {
      return LeakErrorView(message: _error!, onRetry: _load);
    }
    final report = _report;
    if (report == null) return const LeakLoadingSkeleton();
    if (report.handsAnalyzed == 0) {
      return LeakEmptyView(onLogHand: _logHand, onRefresh: _refresh);
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _reveal(0, LeakHeader(report: report, lastVisit: _lastVisit(l10n))),
              const SizedBox(height: AppSpacing.xs),
              _reveal(
                1,
                AnimatedSegmentedTabs(controller: _tabs, labels: [
                  l10n.leakTabLeaks,
                  l10n.leakTabRanges,
                  l10n.leakTabHealth,
                ]),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              LeakTabList(
                  storageKey: 'leaks',
                  onRefresh: _refresh,
                  children: _leaksTab(report, l10n)),
              LeakTabList(
                  storageKey: 'ranges',
                  onRefresh: _refresh,
                  children: [_rangesTab(l10n)]),
              LeakTabList(
                  storageKey: 'health',
                  onRefresh: _refresh,
                  children: [_healthTab(report, l10n)]),
            ],
          ),
        ),
      ],
    );
  }

  String? _lastVisit(AppLocalizations l10n) {
    final prev = _diff?.previousAt;
    return prev == null ? null : leakRelativeDate(l10n, prev);
  }

  /// Staggered fade + rise for section [index] on first load.
  Widget _reveal(int index, Widget child) =>
      LeakReveal(animation: _entrance, index: index, child: child);

  // ── Leaks tab ───────────────────────────────────────────────────────

  List<Widget> _leaksTab(LeakReport report, AppLocalizations l10n) {
    const sectionGap = SizedBox(height: AppSpacing.xl);
    const cardGap = SizedBox(height: AppSpacing.xs);
    final leaks = report.leaks;
    // Nearest-to-unlock first: scarcity becomes a goal ladder.
    final insufficient = [...report.insufficient]..sort((a, b) =>
        (a.minSample - a.sampleCount).compareTo(b.minSample - b.sampleCount));
    final news = _diff != null && _diff!.changes.isNotEmpty;
    var i = 1;
    return [
      if (news) ...[
        _reveal(i++, LeakNewsSection(
            diff: _diff!, onJumpToHealth: () => _tabs.animateTo(2))),
        cardGap,
      ],
      if (leaks.isNotEmpty)
        ..._leakSections(leaks, l10n, i)
      else if (report.handsAnalyzed > 0) ...[
        if (report.coachSummary.isNotEmpty) ...[
          _reveal(i, _coachNote(report.coachSummary, l10n)),
          cardGap,
        ],
        LeakSectionHeader(title: l10n.leakSectionNoLeaks),
        Text(l10n.leakNoLeaksBody,
            style: AppTypography.bodyMd(color: AppColors.textSecondary)),
      ],
      if (insufficient.isNotEmpty) ...[
        sectionGap,
        _reveal(i + 4, UnlockSection(findings: insufficient)),
      ],
    ];
  }

  /// The focused leak owns the hero slot even when a new leak
  /// out-severities it: the player committed to THIS one.
  List<Widget> _leakSections(
      List<LeakFinding> leaks, AppLocalizations l10n, int start) {
    final focusLeak = _focus != null
        ? leaks.where((l) => l.id == _focus!.findingId).firstOrNull
        : null;
    final hero = focusLeak ?? leaks.first;
    final rest = leaks.where((l) => l.id != hero.id).toList();
    return [
      _reveal(
        start,
        LeakSectionHeader(
            title: focusLeak != null
                ? l10n.leakSectionFocus
                : l10n.leakSectionFixFirst),
      ),
      _leakCard(hero, hero: true, order: start + 1),
      if (rest.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.xl),
        _reveal(start + 2, LeakSectionHeader(title: l10n.leakSectionAlso)),
        for (var i = 0; i < rest.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xs),
          _leakCard(rest[i], hero: false, order: start + 3 + i),
        ],
      ],
    ];
  }

  Widget _leakCard(LeakFinding f, {required bool hero, required int order}) {
    return KeyedSubtree(
      key: ValueKey('leak-${f.id}'),
      child: _reveal(
        order,
        LeakCard(
          finding: f,
          emphasis: hero,
          handsByRef: _bundle?.handsByRef ?? const {},
          delta: LeakDelta.compute(f, _diff?.previousOf(f.id)),
          focus: _focus?.findingId == f.id ? _focus : null,
          initiallyExpanded: f.id == _initiallyExpandedId,
          actions: _actionsFor(f, hero: hero),
        ),
      ),
    );
  }

  Widget _coachNote(String summary, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.tintBg(AppColors.accentPrimary),
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        border: Border.all(color: AppColors.tintBorder(AppColors.accentPrimary)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.leakCoachRead.toUpperCase(),
              style: AppTypography.sectionHeader(
                  color: AppColors.accentPrimary)),
          const SizedBox(height: AppSpacing.xxs),
          Text(summary,
              style: AppTypography.bodyMd(color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  // ── Card actions (navigation + analytics) ───────────────────────────

  LeakCardActions _actionsFor(LeakFinding f, {required bool hero}) {
    final isFocus = _focus?.findingId == f.id;
    return LeakCardActions(
      onToggle: (open) {
        if (open) {
          AnalyticsService.capture('leak_card_expanded', {'finding_id': f.id});
        }
      },
      onShowBandInfo: () => _showBandSheet(f),
      onSetFocus: hero && _focus == null ? () => _setFocus(f) : null,
      onClearFocus: isFocus ? () => _clearFocus(f) : null,
      onOpenHand: (ref, hand) => _openHand(f, hand),
      onReviewAll: (hands) => _reviewAll(f, hands),
      onPractice: _drillPresetFor(f.id) == null ? null : () => _practice(f),
      onSeeHands: _gridFilterFor(f.id) == null ? null : () => _openGrid(f),
    );
  }

  Future<void> _setFocus(LeakFinding f) async {
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
  }

  Future<void> _clearFocus(LeakFinding f) async {
    await LeakFocusStore.clearFocus();
    if (!mounted) return;
    setState(() => _focus = null);
    AnalyticsService.capture('leak_goal_cleared', {'finding_id': f.id});
  }

  void _openHand(LeakFinding f, Map<String, dynamic> hand) {
    AnalyticsService.capture('leak_example_opened', {'finding_id': f.id});
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HandActionsScreen(
          hand: hand,
          ourSeat: hand['heroSeatNumber'] as int?,
        ),
      ),
    );
  }

  /// One-tap swipeable review of a finding's example hands.
  void _reviewAll(LeakFinding f, List<Map<String, dynamic>> hands) {
    AnalyticsService.capture('leak_review_queue_opened',
        {'finding_id': f.id, 'hands': hands.length});
    Navigator.push(
      context,
      MaterialPageRoute(
        // ourSeat deliberately null: each page falls back to its own hand's
        // heroSeatNumber (session_hands precedent).
        builder: (_) => HandActionsPageView(hands: hands),
      ),
    );
  }

  void _practice(LeakFinding f) {
    AnalyticsService.capture('leak_practice_tapped', {'finding_id': f.id});
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _drillPresetFor(f.id)!),
    );
  }

  /// Preflop leaks map onto a Range Grid view: the leak says HOW OFTEN, the
  /// grid shows WITH WHICH HANDS. Position slices carry their group into the
  /// filter. Postflop detectors have no preflop range view.
  ({String? posGroup, String scenario})? _gridFilterFor(String findingId) {
    final parts = findingId.split('@');
    const posGroups = {'EP', 'MP', 'CO', 'BTN', 'SB', 'BB'};
    final slicePos =
        parts.length > 1 && posGroups.contains(parts[1]) ? parts[1] : null;
    switch (parts.first) {
      case 'limp_habit':
      case 'fold_to_3bet':
        return (posGroup: slicePos, scenario: 'rfi');
      case 'bb_vs_steal':
        return (posGroup: 'BB', scenario: 'vs_raise');
      default:
        return null;
    }
  }

  /// RFI leaks have a home inside this screen (Ranges tab): switch tabs
  /// instead of leaving. Defend spots have no shape card, so they push the
  /// full pre-filtered grid.
  void _openGrid(LeakFinding f) {
    final filter = _gridFilterFor(f.id)!;
    final hasShapeHome =
        filter.scenario == 'rfi' && (_shape?.sufficient.isNotEmpty ?? false);
    AnalyticsService.capture('leak_grid_opened', {
      'finding_id': f.id,
      'pos_group': filter.posGroup ?? 'all',
      'scenario': filter.scenario,
      'game_type': _dominantGameType,
      'in_screen': hasShapeHome,
    });
    if (hasShapeHome) {
      final known = _shape!.sufficient.any((p) => p.posGroup == filter.posGroup);
      if (filter.posGroup != null && known) {
        setState(() => _shapePos = filter.posGroup);
      }
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
  }

  /// Preflop leaks map to a preset drill session; postflop spots have no
  /// drill equivalent yet (drills are preflop-only).
  Widget? _drillPresetFor(String findingId) {
    switch (findingId.split('@').first) {
      case 'fold_to_3bet':
      case 'bb_vs_steal':
      case 'limp_habit':
        return const DrillSetupScreen(presetStackBB: 40, presetAnte: true);
      default:
        return null;
    }
  }

  void _showBandSheet(LeakFinding f) {
    final l10n = AppLocalizations.of(context);
    showLeakInfoSheet(
      context,
      title: f.title,
      summary: l10n.leakBandSheetSummary(leakPct(f.bandLow), leakPct(f.bandHigh),
          leakPct(f.value), f.sampleCount, f.minSample),
      paragraphs: [
        l10n.leakBandSheetOrigin,
        l10n.leakBandSheetMinSample(f.minSample),
      ],
    );
  }

  void _logHand() => Navigator.push(context, LoggingModeSelectionScreen.route());

  // ── Ranges + Health tabs ────────────────────────────────────────────

  Widget _rangesTab(AppLocalizations l10n) {
    return RangesTab(
      shape: _shape,
      selectedPos: _shapePos,
      onSelectPos: (pos) => setState(() => _shapePos = pos),
      onOpenGrid: (p) {
        AnalyticsService.capture('leak_shape_grid_opened',
            {'pos_group': p.posGroup, 'game_type': _dominantGameType});
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
      onPractice: (p) {
        AnalyticsService.capture(
            'leak_shape_practice_tapped', {'pos_group': p.posGroup});
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const DrillSetupScreen(presetStackBB: 40, presetAnte: true),
          ),
        );
      },
      onInfo: () => showLeakInfoSheet(
        context,
        title: l10n.leakShapeInfoTitle,
        paragraphs: [l10n.leakShapeInfoBody, l10n.leakShapeInfoLegend],
      ),
    );
  }

  Widget _healthTab(LeakReport report, AppLocalizations l10n) {
    return HealthTab(
      report: report,
      fixed: _fixed,
      onDrill: (sp) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              DrillSetupScreen(presetStackBB: sp.presetStackBB, presetAnte: true),
        ),
      ),
      onMoneyInfo: () => showLeakInfoSheet(
        context,
        title: l10n.leakMoneyInfoTitle,
        paragraphs: [l10n.leakMoneyInfoBody],
      ),
    );
  }
}
