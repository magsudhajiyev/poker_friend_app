import 'package:flutter/material.dart';
import 'dart:ui';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/user_stats_service.dart';
import '../services/session_result_service.dart';
import '../services/currency_service.dart';
import '../models/currency.dart';
import '../services/app_data_cache.dart';
import '../services/subscription_service.dart';
import '../services/logger_service.dart';
import '../services/firebase_service.dart';
import '../utils/stack_analytics.dart';
import 'paywall_screen.dart';
import '../widgets/global_loading_spinner.dart';
import '../design_system/design_system.dart';
import '../design_system/components/cards/error_state_card.dart';
import '../design_system/components/dividers/list_separator.dart';
import '../design_system/components/headers/top_nav_bar.dart';
import '../design_system/components/tabs/animated_segmented_tabs.dart';
import '../widgets/range_grid/range_grid_view.dart';
import '../utils/user_facing_error.dart';

// Shared row colours (negative values / insufficient-data hints).
const Color _kNegativeRed = Color(0xFFE85A5A);
const Color _kHintGrey = Color(0xFF9A9B9E);

class StatisticsScreen extends StatefulWidget {
  @override
  _StatisticsScreenState createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool isLoading = true;
  String? error;

  // Basic statistics
  int totalHands = 0;
  int handsPlayed = 0;
  double vpip = 0.0;
  double pfr = 0.0;
  double threeBet = 0.0;
  double fold3Bet = 0.0;
  double cbet = 0.0;
  double steal = 0.0;
  double checkRaise = 0.0;
  double winRate = 0.0;
  int totalSessions = 0;
  int totalPlayTime = 0;

  // Session financial stats (from session_results)
  double _generalTotalBuyIn = 0;
  double _generalTotalCashOut = 0;
  double _generalNetProfit = 0;
  int _generalSessions = 0;

  double _cashTotalBuyIn = 0;
  double _cashTotalCashOut = 0;
  double _cashNetProfit = 0;
  int _cashSessions = 0;

  double _tournamentTotalBuyIn = 0;
  double _tournamentTotalCashOut = 0;
  double _tournamentNetProfit = 0;
  int _tournamentSessions = 0;
  double _itmPercent = 0;
  double _avgFinish = 0;
  int _bestFinish = 0;
  double _roiPercent = 0;
  int _finalTables = 0;
  double _avgBuyIn = 0;
  double _avgFieldSize = 0;

  // Hourly rates
  double _generalHourlyRate = 0;
  double _cashHourlyRate = 0;
  double _tournamentHourlyRate = 0;
  int _generalTotalMinutes = 0;
  int _cashTotalMinutes = 0;
  int _tournamentTotalMinutes = 0;

  // BB/hour (F2 stack analytics) — from poker_sessions cash sessions with
  // blinds + duration; null until 60 tracked minutes.
  double? _cashBBPerHour;
  int _cashBBMinutes = 0;

  // Opportunity counts for N/A detection
  int threeBetOpportunity = 0;
  int facing3BetCount = 0;
  int cbetOpportunity = 0;
  int stealOpportunity = 0;
  int checkRaiseFlopOpportunity = 0;

  // Loading state details
  String? _loadingMessageKey;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    LoggerService.logScreenView('statistics');
    _loadStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics({bool forceRefresh = false}) async {
    // Serve from cache if clean and not forced
    if (!forceRefresh && !AppDataCache.isStatsDirty && AppDataCache.hasStatsCacheData) {
      _restoreFromCache();
      setState(() => isLoading = false);
      return;
    }

    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      await _calculateFromDatabase();
      _saveToCache();
      AppDataCache.clearStatsDirty();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = UserFacingError.message(e);
        isLoading = false;
      });
    }
  }

  void _saveToCache() {
    AppDataCache.cachedOverallStats = {
      'totalHands': totalHands,
      'handsPlayed': handsPlayed,
      'vpip': vpip,
      'pfr': pfr,
      'threeBet': threeBet,
      'fold3Bet': fold3Bet,
      'cbet': cbet,
      'steal': steal,
      'checkRaise': checkRaise,
      'winRate': winRate,
      'totalSessions': totalSessions,
      'totalPlayTime': totalPlayTime,
      'threeBetOpportunity': threeBetOpportunity,
      'facing3BetCount': facing3BetCount,
      'cbetOpportunity': cbetOpportunity,
      'stealOpportunity': stealOpportunity,
      'checkRaiseFlopOpportunity': checkRaiseFlopOpportunity,
      'generalTotalBuyIn': _generalTotalBuyIn,
      'generalTotalCashOut': _generalTotalCashOut,
      'generalNetProfit': _generalNetProfit,
      'generalSessions': _generalSessions,
      'cashTotalBuyIn': _cashTotalBuyIn,
      'cashTotalCashOut': _cashTotalCashOut,
      'cashNetProfit': _cashNetProfit,
      'cashSessions': _cashSessions,
      'tournamentTotalBuyIn': _tournamentTotalBuyIn,
      'tournamentTotalCashOut': _tournamentTotalCashOut,
      'tournamentNetProfit': _tournamentNetProfit,
      'tournamentSessions': _tournamentSessions,
      'itmPercent': _itmPercent,
      'avgFinish': _avgFinish,
      'bestFinish': _bestFinish,
      'roiPercent': _roiPercent,
      'finalTables': _finalTables,
      'avgBuyIn': _avgBuyIn,
      'avgFieldSize': _avgFieldSize,
      'generalHourlyRate': _generalHourlyRate,
      'cashHourlyRate': _cashHourlyRate,
      'tournamentHourlyRate': _tournamentHourlyRate,
      'generalTotalMinutes': _generalTotalMinutes,
      'cashTotalMinutes': _cashTotalMinutes,
      'tournamentTotalMinutes': _tournamentTotalMinutes,
      'cashBBPerHour': _cashBBPerHour,
      'cashBBMinutes': _cashBBMinutes,
    };
  }

  void _restoreFromCache() {
    final overall = AppDataCache.cachedOverallStats!;
    totalHands = overall['totalHands'] as int;
    handsPlayed = overall['handsPlayed'] as int;
    vpip = overall['vpip'] as double;
    pfr = overall['pfr'] as double;
    threeBet = overall['threeBet'] as double;
    fold3Bet = overall['fold3Bet'] as double;
    cbet = overall['cbet'] as double;
    steal = overall['steal'] as double;
    checkRaise = overall['checkRaise'] as double;
    winRate = overall['winRate'] as double;
    totalSessions = overall['totalSessions'] as int;
    totalPlayTime = overall['totalPlayTime'] as int;
    threeBetOpportunity = overall['threeBetOpportunity'] as int;
    facing3BetCount = overall['facing3BetCount'] as int;
    cbetOpportunity = overall['cbetOpportunity'] as int;
    stealOpportunity = overall['stealOpportunity'] as int;
    checkRaiseFlopOpportunity = overall['checkRaiseFlopOpportunity'] as int;
    _generalTotalBuyIn = (overall['generalTotalBuyIn'] as num?)?.toDouble() ?? 0;
    _generalTotalCashOut = (overall['generalTotalCashOut'] as num?)?.toDouble() ?? 0;
    _generalNetProfit = (overall['generalNetProfit'] as num?)?.toDouble() ?? 0;
    _generalSessions = (overall['generalSessions'] as int?) ?? 0;
    _cashTotalBuyIn = (overall['cashTotalBuyIn'] as num?)?.toDouble() ?? 0;
    _cashTotalCashOut = (overall['cashTotalCashOut'] as num?)?.toDouble() ?? 0;
    _cashNetProfit = (overall['cashNetProfit'] as num?)?.toDouble() ?? 0;
    _cashSessions = (overall['cashSessions'] as int?) ?? 0;
    _tournamentTotalBuyIn = (overall['tournamentTotalBuyIn'] as num?)?.toDouble() ?? 0;
    _tournamentTotalCashOut = (overall['tournamentTotalCashOut'] as num?)?.toDouble() ?? 0;
    _tournamentNetProfit = (overall['tournamentNetProfit'] as num?)?.toDouble() ?? 0;
    _tournamentSessions = (overall['tournamentSessions'] as int?) ?? 0;
    _itmPercent = (overall['itmPercent'] as num?)?.toDouble() ?? 0;
    _avgFinish = (overall['avgFinish'] as num?)?.toDouble() ?? 0;
    _bestFinish = (overall['bestFinish'] as int?) ?? 0;
    _roiPercent = (overall['roiPercent'] as num?)?.toDouble() ?? 0;
    _finalTables = (overall['finalTables'] as int?) ?? 0;
    _avgBuyIn = (overall['avgBuyIn'] as num?)?.toDouble() ?? 0;
    _avgFieldSize = (overall['avgFieldSize'] as num?)?.toDouble() ?? 0;
    _generalHourlyRate = (overall['generalHourlyRate'] as num?)?.toDouble() ?? 0;
    _cashHourlyRate = (overall['cashHourlyRate'] as num?)?.toDouble() ?? 0;
    _tournamentHourlyRate = (overall['tournamentHourlyRate'] as num?)?.toDouble() ?? 0;
    _generalTotalMinutes = (overall['generalTotalMinutes'] as int?) ?? 0;
    _cashTotalMinutes = (overall['cashTotalMinutes'] as int?) ?? 0;
    _tournamentTotalMinutes = (overall['tournamentTotalMinutes'] as int?) ?? 0;
    _cashBBPerHour = (overall['cashBBPerHour'] as num?)?.toDouble();
    _cashBBMinutes = (overall['cashBBMinutes'] as int?) ?? 0;
  }

  Future<void> _calculateFromDatabase() async {
    totalHands = 0;
    handsPlayed = 0;
    vpip = 0.0;
    pfr = 0.0;
    threeBet = 0.0;
    fold3Bet = 0.0;
    cbet = 0.0;
    steal = 0.0;
    checkRaise = 0.0;
    winRate = 0.0;
    totalSessions = 0;
    totalPlayTime = 0;

    threeBetOpportunity = 0;
    facing3BetCount = 0;
    cbetOpportunity = 0;
    stealOpportunity = 0;
    checkRaiseFlopOpportunity = 0;

    try {
      setState(() {
        _loadingMessageKey = 'fetching';
      });

      final userId = AuthService.userId;
      if (userId == null) return;

      final userStats = await UserStatsService.getUserStats(userId);
      if (userStats == null) return;

      totalHands = userStats.totalHands;
      handsPlayed = userStats.handsPlayed;
      totalSessions = userStats.totalSessions;
      totalPlayTime = userStats.totalPlayTimeMinutes;

      vpip = userStats.vpipPercentage;
      pfr = userStats.pfrPercentage;
      threeBet = userStats.threeBetPercentage;
      fold3Bet = userStats.fold3betPercentage;
      cbet = userStats.cbetPercentage;
      steal = userStats.stealPercentage;
      checkRaise = userStats.checkRaiseFlopPercentage;

      winRate = userStats.winRate;

      threeBetOpportunity = userStats.threeBetOpportunity;
      facing3BetCount = userStats.facing3BetCount;
      cbetOpportunity = userStats.cbetOpportunity;
      stealOpportunity = userStats.stealOpportunity;
      checkRaiseFlopOpportunity = userStats.checkRaiseFlopOpportunity;

      // Fetch session results for financial stats
      final results = await SessionResultService.getAllSessionResults();
      _computeSessionFinancials(results);

      // BB/hour from poker_sessions (they carry blinds; session_results don't).
      // Non-fatal: statistics still render if the session fetch fails.
      try {
        final sessions = await FirebaseService.getAllSessions();
        final bbRate = StackAnalytics.cashBBPerHour(sessions);
        _cashBBPerHour = bbRate.rate;
        _cashBBMinutes = bbRate.minutes;
      } catch (e) {
        _cashBBPerHour = null;
        _cashBBMinutes = 0;
      }

    } catch (e) {
      debugPrint('Error calculating statistics: $e');
      throw e;
    }
  }

  void _computeSessionFinancials(List<Map<String, dynamic>> results) {
    // Reset
    _generalTotalBuyIn = 0; _generalTotalCashOut = 0; _generalNetProfit = 0; _generalSessions = 0;
    _cashTotalBuyIn = 0; _cashTotalCashOut = 0; _cashNetProfit = 0; _cashSessions = 0;
    _tournamentTotalBuyIn = 0; _tournamentTotalCashOut = 0; _tournamentNetProfit = 0; _tournamentSessions = 0;
    _itmPercent = 0; _avgFinish = 0; _bestFinish = 0; _roiPercent = 0;
    _finalTables = 0; _avgBuyIn = 0; _avgFieldSize = 0;
    _generalHourlyRate = 0; _cashHourlyRate = 0; _tournamentHourlyRate = 0;
    _generalTotalMinutes = 0; _cashTotalMinutes = 0; _tournamentTotalMinutes = 0;

    int itmCount = 0;
    double totalFinishPosition = 0;
    int finishCount = 0;
    double totalFieldSize = 0;
    int fieldSizeCount = 0;

    for (final r in results) {
      final gameType = r['gameType'] as String? ?? 'cash';
      final amount = (r['amount'] as num?)?.toDouble() ?? 0.0;
      final buyIn = (r['buyInAmount'] as num?)?.toDouble();

      // Skip records without buyInAmount (old data)
      if (buyIn == null) continue;

      _generalSessions++;
      _generalTotalBuyIn += buyIn;
      _generalNetProfit += amount;

      final mins = (r['durationMinutes'] as num?)?.toInt() ?? 0;
      _generalTotalMinutes += mins;

      if (gameType == 'cash') {
        _cashSessions++;
        _cashTotalBuyIn += buyIn;
        _cashNetProfit += amount;
        _cashTotalCashOut += buyIn + amount;
        _cashTotalMinutes += mins;
      } else {
        _tournamentSessions++;
        _tournamentTotalBuyIn += buyIn;
        _tournamentNetProfit += amount;
        _tournamentTotalMinutes += mins;

        final prize = (r['prizeWon'] as num?)?.toDouble() ?? 0.0;
        _tournamentTotalCashOut += prize;

        if (prize > 0) itmCount++;

        final place = (r['finishedPlace'] as num?)?.toInt();
        if (place != null && place > 0) {
          totalFinishPosition += place;
          finishCount++;
          if (_bestFinish == 0 || place < _bestFinish) _bestFinish = place;
          if (place <= 9) _finalTables++;
        }

        final field = (r['fieldSize'] as num?)?.toInt();
        if (field != null && field > 0) {
          totalFieldSize += field;
          fieldSizeCount++;
        }
      }
    }

    _generalTotalCashOut = _generalTotalBuyIn + _generalNetProfit;

    // Tournament derived stats
    if (_tournamentSessions > 0) {
      _itmPercent = (itmCount / _tournamentSessions) * 100;
      _avgBuyIn = _tournamentTotalBuyIn / _tournamentSessions;
      if (_tournamentTotalBuyIn > 0) {
        _roiPercent = ((_tournamentTotalCashOut - _tournamentTotalBuyIn) / _tournamentTotalBuyIn) * 100;
      }
    }
    if (finishCount > 0) {
      _avgFinish = totalFinishPosition / finishCount;
    }
    if (fieldSizeCount > 0) {
      _avgFieldSize = totalFieldSize / fieldSizeCount;
    }

    // Hourly rates — only computed when duration data is sufficient.
    // durationMinutes was added recently, so old session_results lack it.
    // Require ≥60 min of tracked duration to avoid absurd rates from tiny samples.
    if (_generalTotalMinutes >= 60) {
      _generalHourlyRate = _generalNetProfit / (_generalTotalMinutes / 60);
    }
    if (_cashTotalMinutes >= 60) {
      _cashHourlyRate = _cashNetProfit / (_cashTotalMinutes / 60);
    }
    if (_tournamentTotalMinutes >= 60) {
      _tournamentHourlyRate = _tournamentNetProfit / (_tournamentTotalMinutes / 60);
    }
  }

  String _getLoadingMessage(AppLocalizations l10n) {
    if (_loadingMessageKey == 'fetching') return l10n.statsFetchingMessage;
    return l10n.statsLoadingMessage;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      extendBody: true,
      body: SafeArea(
        child: error != null
            ? ErrorStateCard(onRetry: () => _loadStatistics(forceRefresh: true))
            : LoadingWrapper(
                isLoading: isLoading,
                loadingMessage: _getLoadingMessage(l10n),
                child: _buildContent(),
              ),
      ),
    );
  }

  Widget _buildContent() {
    final l10n = AppLocalizations.of(context);
    final na = l10n.commonNotAvailable;
    String fmt(double value, int opportunity) =>
        opportunity == 0 ? na : '${value.toStringAsFixed(1)}%';

    final refreshButton = GestureDetector(
      onTap: () => _loadStatistics(forceRefresh: true),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: AppColors.bgSurface,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.refresh_rounded,
          color: AppColors.textPrimary,
          size: 24,
        ),
      ),
    );

    return Column(
      children: [
        Navigator.canPop(context)
            ? TopNavBar(
                title: l10n.statsStats,
                onBack: () => Navigator.pop(context),
                rightAction: refreshButton,
              )
            : TopNavBar.landing(
                title: l10n.statsStats,
                rightAction: refreshButton,
              ),
        const SizedBox(height: 4),
        _buildTabSwitcher(),
        const SizedBox(height: 20),

        // Tab views: classic stats | range grid
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hands logged + 7 core metric cards
                _buildMetricCard(
                  chipLabel: l10n.statsHandsLogged,
                  value: totalHands.toString(),
                  forceActive: true,
                ),
                const ListSeparator(),
                _buildMetricCard(
                  chipLabel: l10n.statsVpip,
                  value: totalHands > 0 ? '${vpip.toStringAsFixed(1)}%' : na,
                ),
                const ListSeparator(),
                _buildMetricCard(
                  chipLabel: l10n.statsPfr,
                  value: totalHands > 0 ? '${pfr.toStringAsFixed(1)}%' : na,
                ),
                const ListSeparator(),
                _buildMetricCard(
                  chipLabel: l10n.stats3Bet,
                  value: fmt(threeBet, threeBetOpportunity),
                ),
                const ListSeparator(),
                _buildMetricCard(
                  chipLabel: l10n.statsFoldTo3Bet,
                  value: fmt(fold3Bet, facing3BetCount),
                ),
                const ListSeparator(),
                _buildMetricCard(
                  chipLabel: l10n.statsCBet,
                  value: fmt(cbet, cbetOpportunity),
                ),
                const ListSeparator(),
                _buildMetricCard(
                  chipLabel: l10n.statsSteal,
                  value: fmt(steal, stealOpportunity),
                ),
                const ListSeparator(),
                _buildMetricCard(
                  chipLabel: l10n.statsCheckRaise,
                  value: fmt(checkRaise, checkRaiseFlopOpportunity),
                ),
                const ListSeparator(),
                _buildMetricCard(
                  chipLabel: l10n.statsWinRate,
                  value: handsPlayed > 0 ? '${winRate.toStringAsFixed(1)}%' : na,
                ),

                const SizedBox(height: 32),
                _buildSectionHeader(l10n.statsGeneral),
                const SizedBox(height: 12),
                _buildLockedSection(
                  child: _buildGeneralSessionStats(),
                  featureName: l10n.statsGeneral,
                ),
                const SizedBox(height: 24),
                _buildSectionHeader(l10n.statsCash),
                const SizedBox(height: 12),
                _buildLockedSection(
                  child: _buildCashSessionStats(),
                  featureName: l10n.statsCash,
                ),
                const SizedBox(height: 24),
                _buildSectionHeader(l10n.statsTournament),
                const SizedBox(height: 12),
                _buildLockedSection(
                  child: _buildTournamentSessionStats(),
                  featureName: l10n.statsTournament,
                ),
                const SizedBox(height: 120),
              ],
            ),
          ),
              const RangeGridView(),
            ],
          ),
        ),
      ],
    );
  }

  /// Stats | Ranges segmented toggle — sliding-pill segmented control.
  Widget _buildTabSwitcher() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedSegmentedTabs(
        controller: _tabController,
        labels: [l10n.statsStats, l10n.statsRanges],
      ),
    );
  }

  Widget _buildMetricCard({
    required String chipLabel,
    required String value,
    bool forceActive = false,
  }) {
    final isNA = !forceActive && !value.contains('%');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
            ),
            child: Text(
              chipLabel,
              style: AppTypography.ibm(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          // Value
          Text(
            value,
            style: AppTypography.ibm(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isNA ? AppColors.textSecondary : AppColors.accentPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatListItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.ibm(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.8),
              height: 1.0,
            ),
          ),
          Text(
            value,
            style: AppTypography.ibm(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.accentPrimary,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 1, color: Colors.white.withOpacity(0.1));
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: AppTypography.ibm(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.accentPrimary,
        letterSpacing: 1.0,
      ),
    );
  }

  /// Wraps [child] with a blur + lock overlay when the user is on the free tier.
  /// Premium users (any paid tier) see the content directly — no overhead.
  Widget _buildLockedSection({required Widget child, required String featureName}) {
    if (SubscriptionService.isPremium) return child;
    final l10n = AppLocalizations.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    return Stack(
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: child,
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(AppDecorations.radius18),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  color: Colors.white,
                  size: screenWidth * 0.07,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.statsLockedTitle,
                  style: AppTypography.ibm(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.statsLockedSubtitle,
                  style: AppTypography.ibm(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => PaywallScreen.show(context, featureName: featureName),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
                    ),
                    child: Text(
                      l10n.statsLockedUpgrade,
                      style: AppTypography.ibm(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildGeneralSessionStats() {
    final l10n = AppLocalizations.of(context);
    return _buildStatsCard(
      children: [
        if (totalSessions > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSessionStatItem(l10n.statsSessions, totalSessions.toString()),
                Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1)),
                _buildSessionStatItem(l10n.statsTotalTime, '${(totalPlayTime / 60).toStringAsFixed(1)}h'),
                Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1)),
                _buildSessionStatItem(
                  l10n.statsAvgSession,
                  totalSessions > 0 ? '${(totalPlayTime / totalSessions).toStringAsFixed(0)}m' : '0m',
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                l10n.statsPlayToSee,
                style: AppTypography.ibm(color: Colors.white.withOpacity(0.4), fontSize: 14),
              ),
            ),
          ),
        if (_generalSessions > 0) ...[
          _buildDivider(),
          _buildStatListItem(l10n.statsTotalBuyIn, _formatAmount(_generalTotalBuyIn)),
          _buildDivider(),
          _buildStatListItem(l10n.statsTotalCashOut, _formatAmount(_generalTotalCashOut)),
          _buildDivider(),
          _buildProfitRow(l10n.statsNetProfit, _generalNetProfit),
          _buildDivider(),
          _buildHourlyRateRow(l10n.statsHourlyRate, _generalHourlyRate, _generalTotalMinutes),
        ],
      ],
    );
  }

  Widget _buildCashSessionStats() {
    final l10n = AppLocalizations.of(context);
    if (_cashSessions == 0) {
      return _buildStatsCard(children: [_buildEmptyState(l10n.statsPlayToSee)]);
    }
    return _buildStatsCard(
      children: [
        _buildStatListItem(l10n.statsSessions, _cashSessions.toString()),
        _buildDivider(),
        _buildStatListItem(l10n.statsTotalBuyIn, _formatAmount(_cashTotalBuyIn)),
        _buildDivider(),
        _buildStatListItem(l10n.statsTotalCashOut, _formatAmount(_cashTotalCashOut)),
        _buildDivider(),
        _buildProfitRow(l10n.statsNetProfit, _cashNetProfit),
        _buildDivider(),
        _buildHourlyRateRow(l10n.statsHourlyRate, _cashHourlyRate, _cashTotalMinutes),
        _buildDivider(),
        _buildBBPerHourRow(l10n),
      ],
    );
  }

  /// BB/hour row (F2). Uses the same 60-minute sufficiency rule as the
  /// hourly-rate row; sourced from full-logging cash sessions with blinds.
  Widget _buildBBPerHourRow(AppLocalizations l10n) {
    final rate = _cashBBPerHour;
    if (rate == null || _cashBBMinutes < StackAnalytics.minMinutesForRate) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.statsBBPerHour,
              style: AppTypography.ibm(
                fontSize: 15, fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.8), height: 1.0,
              ),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                l10n.statsHourlyRateNotAvailable,
                style: AppTypography.ibm(
                  fontSize: 12, fontWeight: FontWeight.w400,
                  color: _kHintGrey, height: 1.2,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }
    final isPositive = rate >= 0;
    final prefix = isPositive ? '+' : '';
    final color = isPositive ? AppColors.accentPrimary : _kNegativeRed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.statsBBPerHour,
            style: AppTypography.ibm(
              fontSize: 15, fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.8), height: 1.0,
            ),
          ),
          Text(
            '$prefix${rate.toStringAsFixed(1)} BB/h',
            style: AppTypography.ibm(
              fontSize: 15, fontWeight: FontWeight.w600,
              color: color, height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentSessionStats() {
    final l10n = AppLocalizations.of(context);
    final na = l10n.commonNotAvailable;
    if (_tournamentSessions == 0) {
      return _buildStatsCard(children: [_buildEmptyState(l10n.statsPlayToSee)]);
    }
    return _buildStatsCard(
      children: [
        _buildStatListItem(l10n.statsSessions, _tournamentSessions.toString()),
        _buildDivider(),
        _buildStatListItem(l10n.statsTotalBuyIn, _formatAmount(_tournamentTotalBuyIn)),
        _buildDivider(),
        _buildStatListItem(l10n.statsTotalCashOut, _formatAmount(_tournamentTotalCashOut)),
        _buildDivider(),
        _buildProfitRow(l10n.statsNetProfit, _tournamentNetProfit),
        _buildDivider(),
        _buildHourlyRateRow(l10n.statsHourlyRate, _tournamentHourlyRate, _tournamentTotalMinutes),
        const SizedBox(height: 8),
        _buildDivider(),
        const SizedBox(height: 8),
        _buildStatListItem(l10n.statsItm, '${_itmPercent.toStringAsFixed(1)}%'),
        _buildDivider(),
        _buildStatListItem(l10n.statsAvgFinish, _avgFinish > 0 ? _avgFinish.ceil().toString() : na),
        _buildDivider(),
        _buildStatListItem(l10n.statsBestFinish, _bestFinish > 0 ? _bestFinish.toString() : na),
        _buildDivider(),
        _buildStatListItem(l10n.statsRoi, '${_roiPercent.toStringAsFixed(1)}%'),
        _buildDivider(),
        _buildStatListItem(l10n.statsFinalTables, _finalTables.toString()),
        _buildDivider(),
        _buildStatListItem(l10n.statsAvgBuyIn, _formatAmount(_avgBuyIn)),
        _buildDivider(),
        _buildStatListItem(l10n.statsAvgFieldSize, _avgFieldSize > 0 ? _avgFieldSize.toStringAsFixed(0) : na),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          message,
          style: AppTypography.ibm(color: Colors.white.withOpacity(0.4), fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildProfitRow(String label, double value) {
    final isPositive = value >= 0;
    final prefix = isPositive ? '+' : '';
    final color = isPositive ? AppColors.accentPrimary : _kNegativeRed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.ibm(
              fontSize: 15, fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.8), height: 1.0,
            ),
          ),
          Text(
            '$prefix${CurrencyService.formatCashRounded(value)}',
            style: AppTypography.ibm(
              fontSize: 15, fontWeight: FontWeight.w600,
              color: color, height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyRateRow(String label, double rate, int totalMinutes) {
    final l10n = AppLocalizations.of(context);
    if (totalMinutes < 60) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.ibm(
                fontSize: 15, fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.8), height: 1.0,
              ),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                l10n.statsHourlyRateNotAvailable,
                style: AppTypography.ibm(
                  fontSize: 12, fontWeight: FontWeight.w400,
                  color: _kHintGrey, height: 1.2,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }
    final isPositive = rate >= 0;
    final prefix = isPositive ? '+' : '';
    final color = isPositive ? AppColors.accentPrimary : _kNegativeRed;
    final currency = CurrencyService.current;
    final formatted = rate.toStringAsFixed(0);
    final rateText = currency.position == SymbolPosition.prefix
        ? '$prefix${currency.symbol}$formatted/h'
        : '$prefix$formatted${currency.symbol}/h';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.ibm(
              fontSize: 15, fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.8), height: 1.0,
            ),
          ),
          Text(
            rateText,
            style: AppTypography.ibm(
              fontSize: 15, fontWeight: FontWeight.w600,
              color: color, height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double value) {
    return CurrencyService.formatCashRounded(value);
  }

  Widget _buildSessionStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.ibm(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.accentPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.ibm(
            color: Colors.white.withOpacity(0.4),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

}
