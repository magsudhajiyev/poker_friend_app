import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/constants/colors.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../services/analytics_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/daily_challenge_store.dart';
import '../../services/daily_replay_limits.dart';
import '../../services/subscription_service.dart';
import '../paywall_screen.dart';
import 'daily_replay_screen.dart';

/// PAST CHALLENGES calendar — pick a past day to replay (unranked).
///
/// A month grid from the challenge epoch to yesterday. Each day cell reflects
/// its state for the current tier:
/// - replayable + played  → score-tinted, a dot, tap to replay
/// - replayable + unplayed → neutral, tap to replay
/// - locked by tier window → lock icon, tap opens the paywall (upsell)
/// - before epoch / today / future → disabled/empty
///
/// The tier window comes from [DailyReplayLimits]; the screen rebuilds on
/// `premiumStatusStream` so a purchase unlocks older days immediately. Nothing
/// here writes a result — replaying is handled by [DailyReplayScreen], which is
/// non-persisting by design.
class DailyChallengeCalendarScreen extends StatefulWidget {
  const DailyChallengeCalendarScreen({super.key});

  @override
  State<DailyChallengeCalendarScreen> createState() =>
      _DailyChallengeCalendarScreenState();
}

class _DailyChallengeCalendarScreenState
    extends State<DailyChallengeCalendarScreen> {
  final DateTime _today = DailyChallengeService.dateOnly(
      DailyChallengeService.today());
  late final DateTime _epoch =
      DailyChallengeService.dateOnly(DailyChallengeService.epoch);

  /// Month currently shown (first of month). Starts on the current month.
  late DateTime _month = DateTime(_today.year, _today.month);

  /// Ranked results (from the real daily play) — streak/leaderboard source.
  Map<String, DailyChallengeResult> _played = const {};
  /// Saved REPLAY results (unranked). Persisted in a separate store so they
  /// survive restarts without touching streaks. Takes precedence over [_played]
  /// in [_resultFor] (latest replay wins).
  Map<String, DailyChallengeResult> _replayed = {};
  bool _loaded = false;
  StreamSubscription<bool>? _premiumSub;

  @override
  void initState() {
    super.initState();
    _load();
    _premiumSub = SubscriptionService.premiumStatusStream.listen((_) {
      if (mounted) setState(() {}); // tier changed → window updates
    });
    AnalyticsService.capture('daily_replay_calendar_opened', const {});
  }

  @override
  void dispose() {
    _premiumSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final played = await DailyChallengeStore.allResults();
    final replayed = await DailyReplayStore.allResults();
    if (!mounted) return;
    setState(() {
      _played = played;
      _replayed = replayed;
      _loaded = true;
    });
  }

  bool get _canGoPrev =>
      _month.isAfter(DateTime(_epoch.year, _epoch.month));
  bool get _canGoNext =>
      _month.isBefore(DateTime(_today.year, _today.month));

  void _prevMonth() {
    if (!_canGoPrev) return;
    HapticFeedback.selectionClick();
    setState(() => _month = DateTime(_month.year, _month.month - 1));
  }

  void _nextMonth() {
    if (!_canGoNext) return;
    HapticFeedback.selectionClick();
    setState(() => _month = DateTime(_month.year, _month.month + 1));
  }

  /// A known result for [day]: the stored (ranked) one, or one from a replay
  /// done this session. Session replays take precedence (freshest run shown).
  DailyChallengeResult? _resultFor(DateTime day) {
    final key = DailyChallengeStore.dayKey(day);
    return _replayed[key] ?? _played[key];
  }

  Future<void> _onDayTap(DateTime day) async {
    if (DailyReplayLimits.isReplayable(day, _today)) {
      HapticFeedback.selectionClick();
      // If the day already has a result (stored, or replayed this session),
      // open straight on the breakdown instead of restarting.
      final result = await Navigator.of(context).push<DailyChallengeResult>(
        MaterialPageRoute(
          builder: (_) => DailyReplayScreen(
            day: day,
            initialResult: _resultFor(day),
          ),
        ),
      );
      // Cache the run so re-tapping this day shows the breakdown.
      if (result != null && mounted) {
        setState(() => _replayed[DailyChallengeStore.dayKey(day)] = result);
      }
      return;
    }
    if (DailyReplayLimits.isLockedByTier(day, _today)) {
      // Upsell: free users -> Pro (index 0); Pro users wanting older -> Elite.
      final preselect = SubscriptionService.isPro ? 1 : 0;
      final l10n = AppLocalizations.of(context);
      await PaywallScreen.show(context,
          featureName: l10n.replayFeatureName, preselectedTier: preselect);
      if (mounted) setState(() {}); // reflect any purchase
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        title: Text(
          l10n.replayCalendarTitle,
          style: AppTypography.ibm(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _windowBanner(l10n),
                  _monthHeader(l10n),
                  const SizedBox(height: AppSpacing.xs),
                  _weekdayLabels(l10n),
                  const SizedBox(height: AppSpacing.xxs),
                  Expanded(child: _grid()),
                  _legend(l10n),
                ],
              ),
      ),
    );
  }

  // ── Tier-window banner ────────────────────────────────────────────────────

  Widget _windowBanner(AppLocalizations l10n) {
    final window = DailyReplayLimits.replayWindowDays();
    final String text;
    final bool showUpgrade;
    if (window == 0) {
      text = l10n.replayWindowFree;
      showUpgrade = true;
    } else if (window == null) {
      text = l10n.replayWindowUnlimited;
      showUpgrade = false;
    } else {
      text = l10n.replayWindowPro(window);
      showUpgrade = true;
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            window == null ? Icons.lock_open_rounded : Icons.lock_rounded,
            color: window == null
                ? AppColors.accentPrimary
                : AppColors.textSecondary,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: AppTypography.ibm(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
          if (showUpgrade)
            TextButton(
              onPressed: () async {
                final preselect = SubscriptionService.isPro ? 1 : 0;
                await PaywallScreen.show(context,
                    featureName: l10n.replayFeatureName,
                    preselectedTier: preselect);
                if (mounted) setState(() {});
              },
              child: Text(
                l10n.replayUpgrade,
                style: AppTypography.ibm(
                  color: AppColors.accentPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Month header ──────────────────────────────────────────────────────────

  Widget _monthHeader(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      child: Row(
        children: [
          // Hide (not grey out) an arrow when there's no month that way — a
          // dead-looking button reads as broken. The SizedBox keeps the title
          // centered. Arrows reappear automatically as the archive spans more
          // months.
          _navArrow(Icons.chevron_left_rounded,
              enabled: _canGoPrev, onTap: _prevMonth),
          Expanded(
            child: Text(
              _monthLabel(l10n, _month),
              textAlign: TextAlign.center,
              style: AppTypography.ibm(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _navArrow(Icons.chevron_right_rounded,
              enabled: _canGoNext, onTap: _nextMonth),
        ],
      ),
    );
  }

  /// A month-nav arrow, or an equal-width blank when disabled (hidden, not
  /// greyed) so the month title stays centered.
  Widget _navArrow(IconData icon,
      {required bool enabled, required VoidCallback onTap}) {
    if (!enabled) return const SizedBox(width: 48);
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: AppColors.textPrimary),
    );
  }

  String _monthLabel(AppLocalizations l10n, DateTime m) =>
      MaterialLocalizations.of(context).formatMonthYear(m);

  Widget _weekdayLabels(AppLocalizations l10n) {
    final ml = MaterialLocalizations.of(context);
    // narrowWeekdays is Sunday-first; the grid below is Monday-first, so
    // rotate to [Mon..Sun].
    final nw = ml.narrowWeekdays;
    final labels = [nw[1], nw[2], nw[3], nw[4], nw[5], nw[6], nw[0]];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          for (final d in labels)
            Expanded(
              child: Center(
                child: Text(
                  d,
                  style: AppTypography.ibm(
                    color: AppColors.textDisabled,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Grid ────────────────────────────────────────────────────────────────

  Widget _grid() {
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // Monday-first leading blanks: weekday 1=Mon..7=Sun.
    final leading = first.weekday - 1;
    final cells = <Widget>[];
    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add(_dayCell(DateTime(_month.year, _month.month, d)));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: GridView.count(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        children: cells,
      ),
    );
  }

  Widget _dayCell(DateTime day) {
    final beforeEpoch = day.isBefore(_epoch);
    final isTodayOrFuture = !day.isBefore(_today);
    if (beforeEpoch || isTodayOrFuture) {
      // Outside the challenge range entirely — faint, non-interactive.
      return _cellShell(
        child: Text(
          '${day.day}',
          style: AppTypography.ibm(
            color: AppColors.textDisabled.withValues(alpha: 0.4),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      );
    }

    final replayable = DailyReplayLimits.isReplayable(day, _today);
    final locked = DailyReplayLimits.isLockedByTier(day, _today);
    final result = _resultFor(day);

    Color bg = AppColors.surfaceDark;
    Widget content;
    if (locked) {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${day.day}',
              style: AppTypography.ibm(
                color: AppColors.textDisabled,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              )),
          const SizedBox(height: 2),
          Icon(Icons.lock_rounded,
              size: 11, color: AppColors.textDisabled),
        ],
      );
    } else {
      // Replayable. Tint the background if it was played, by score band.
      if (result != null) {
        final s = result.score; // 0..100
        final c = s >= 80
            ? AppColors.accentPrimary
            : s >= 50
                ? AppColors.accentTertiary
                : AppColors.accentDanger;
        bg = c.withValues(alpha: 0.18);
      }
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${day.day}',
              style: AppTypography.ibm(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              )),
          if (result != null) ...[
            const SizedBox(height: 3),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.accentPrimary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      );
    }

    return GestureDetector(
      onTap: (replayable || locked) ? () => _onDayTap(day) : null,
      child: _cellShell(bg: bg, child: content),
    );
  }

  Widget _cellShell({required Widget child, Color? bg}) {
    return Container(
      decoration: BoxDecoration(
        color: bg ?? Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  // ── Legend ────────────────────────────────────────────────────────────────

  Widget _legend(AppLocalizations l10n) {
    Widget item(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 4),
            Text(label,
                style: AppTypography.ibm(
                  color: AppColors.textDisabled,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                )),
          ],
        );
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xxs,
        children: [
          item(AppColors.accentPrimary, l10n.replayLegendGood),
          item(AppColors.accentTertiary, l10n.replayLegendOk),
          item(AppColors.accentDanger, l10n.replayLegendLow),
        ],
      ),
    );
  }
}
