import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/components/headers/top_nav_bar.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/daily_challenge_store.dart';
import '../../services/leaderboard_service.dart';

/// Global Daily Challenge leaderboard. Three boards: current streak
/// (headline), today's result, and all-time best streak. Opened from the
/// Daily Challenge screen. Participation is automatic — everyone who finishes
/// a challenge with a username appears.
class LeaderboardScreen extends StatefulWidget {
  final DailyChallengeConfig config;
  const LeaderboardScreen({super.key, required this.config});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

/// One board's loaded data (each PageView page keeps its own).
class _BoardData {
  final bool loading;
  final List<LeaderboardEntry> entries;
  final int? myRank;
  const _BoardData({
    this.loading = true,
    this.entries = const [],
    this.myRank,
  });
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  static const _boards = [
    LeaderboardBoard.streakCurrent,
    LeaderboardBoard.daily,
    LeaderboardBoard.streakBest,
  ];

  String _tabLabel(AppLocalizations l10n, LeaderboardBoard b) => switch (b) {
        LeaderboardBoard.streakCurrent => l10n.leaderboardTabStreak,
        LeaderboardBoard.daily => l10n.leaderboardTabToday,
        LeaderboardBoard.streakBest => l10n.leaderboardTabBest,
      };

  // Medal colors for the top three ranks (gold / silver / bronze) — local
  // constants in the sibling-screen style; no design-system token exists.
  static const _gold = Color(0xFFFFD54F);
  static const _silver = Color(0xFFBFC7CC);
  static const _bronze = Color(0xFFCD8E57);

  late final PageController _pager;
  int _tab = 0;

  /// Per-board cache so swiping back to a loaded board is instant and the
  /// three pages never overwrite each other's data.
  final Map<LeaderboardBoard, _BoardData> _data = {};

  LeaderboardBoard get _board => _boards[_tab];

  @override
  void initState() {
    super.initState();
    _pager = PageController(initialPage: _tab);
    _load(_board);
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  Future<void> _load(LeaderboardBoard board) async {
    setState(() => _data[board] = const _BoardData(loading: true));
    final dayKey = DailyChallengeStore.dayKey(widget.config.day);
    final results = await Future.wait([
      LeaderboardService.top(board, dayKey: dayKey),
      LeaderboardService.myRank(board, dayKey: dayKey),
    ]);
    if (!mounted) return;
    setState(() {
      _data[board] = _BoardData(
        loading: false,
        entries: results[0] as List<LeaderboardEntry>,
        myRank: results[1] as int?,
      );
    });
  }

  /// Tab tapped — animate the PageView; onPageChanged does the rest.
  void _pickTab(int i) {
    if (i == _tab) return;
    HapticFeedback.selectionClick();
    _pager.animateToPage(
      i,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  /// Fired by both a swipe and a programmatic animateToPage.
  void _onPageChanged(int i) {
    if (i == _tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = i);
    if (!_data.containsKey(_boards[i])) _load(_boards[i]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TopNavBar(
              title: l10n.dailyChallengeLeaderboard,
              subtitle: _subtitleFor(l10n, _board),
              onBack: () => Navigator.pop(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            _segmented(l10n),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: PageView.builder(
                controller: _pager,
                onPageChanged: _onPageChanged,
                itemCount: _boards.length,
                itemBuilder: (_, i) => _body(l10n, _boards[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitleFor(AppLocalizations l10n, LeaderboardBoard b) => switch (b) {
        LeaderboardBoard.streakCurrent => l10n.leaderboardSubtitleStreak,
        LeaderboardBoard.daily => l10n.leaderboardSubtitleToday,
        LeaderboardBoard.streakBest => l10n.leaderboardSubtitleBest,
      };

  Widget _segmented(AppLocalizations l10n) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
          ),
          child: Row(
            children: [
              for (var i = 0; i < _boards.length; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickTab(i),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                      decoration: BoxDecoration(
                        color: i == _tab
                            ? AppColors.accentPrimary
                            : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(AppDecorations.pillRadius),
                      ),
                      child: Center(
                        child: Text(
                          _tabLabel(l10n, _boards[i]),
                          style: AppTypography.ibm(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: i == _tab ? Colors.black : Colors.white,
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

  Widget _body(AppLocalizations l10n, LeaderboardBoard board) {
    final data = _data[board] ?? const _BoardData();
    if (data.loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accentPrimary));
    }
    if (data.entries.isEmpty) {
      return _empty(l10n, board);
    }
    final showMyRankFooter =
        data.myRank != null && !data.entries.any((e) => e.isMe);
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.bottomPadding),
            itemCount: data.entries.length,
            itemBuilder: (_, i) => _row(board, data.entries[i]),
          ),
        ),
        if (showMyRankFooter) _myRankFooter(l10n, data.myRank!),
      ],
    );
  }

  Widget _empty(AppLocalizations l10n, LeaderboardBoard board) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events_outlined,
                  size: 40, color: AppColors.contentInactive),
              const SizedBox(height: AppSpacing.sm),
              Text(
                board == LeaderboardBoard.daily
                    ? l10n.leaderboardEmptyToday
                    : l10n.leaderboardEmptyStreak,
                textAlign: TextAlign.center,
                style: AppTypography.ibm(
                    fontSize: 15, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );

  Widget _row(LeaderboardBoard board, LeaderboardEntry e) {
    final highlight = e.isMe;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xxs),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.accentPrimary.withValues(alpha: 0.14)
            : AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.cardRadius),
        border: highlight
            ? Border.all(color: AppColors.accentPrimary, width: 1)
            : null,
      ),
      child: Row(
        children: [
          SizedBox(width: 34, child: _rankBadge(e.rank)),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              e.isMe ? '${e.username} (you)' : e.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.ibm(
                fontSize: 16,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          if (e.perfect)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.xxs),
              child: Icon(Icons.star_rounded,
                  size: 16, color: AppColors.accentTertiary),
            ),
          Text(
            _valueLabel(board, e),
            style: AppTypography.mono(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.accentPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankBadge(int rank) {
    final medal = switch (rank) {
      1 => _gold,
      2 => _silver,
      3 => _bronze,
      _ => null,
    };
    return Text(
      '$rank',
      textAlign: TextAlign.center,
      style: AppTypography.mono(
        fontSize: rank <= 3 ? 17 : 15,
        fontWeight: FontWeight.w700,
        color: medal ?? AppColors.textSecondary,
      ),
    );
  }

  /// The right-aligned value per board: streak count, or today's score + time.
  String _valueLabel(LeaderboardBoard board, LeaderboardEntry e) {
    switch (board) {
      case LeaderboardBoard.streakCurrent:
      case LeaderboardBoard.streakBest:
        return '${e.value}🔥';
      case LeaderboardBoard.daily:
        final score = (e.score ?? 0);
        final scoreStr =
            score == score.roundToDouble() ? score.toInt().toString() : score.toString();
        final time = e.durationMs != null ? _fmtTime(e.durationMs!) : '';
        return time.isEmpty ? '$scoreStr/5' : '$scoreStr/5 · $time';
    }
  }

  String _fmtTime(int ms) {
    final s = (ms / 1000).round();
    final m = s ~/ 60;
    final r = s % 60;
    return m > 0 ? '${m}m${r.toString().padLeft(2, '0')}s' : '${r}s';
  }

  Widget _myRankFooter(AppLocalizations l10n, int rank) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.separatorDark),
          ),
        ),
        child: Row(
          children: [
            Text(l10n.leaderboardYourRank,
                style: AppTypography.ibm(
                    fontSize: 14, color: AppColors.textSecondary)),
            const Spacer(),
            Text('#$rank',
                style: AppTypography.mono(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentPrimary)),
          ],
        ),
      );
}
