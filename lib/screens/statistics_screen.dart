import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/user_stats_service.dart';
import '../services/session_result_service.dart';
import '../services/currency_service.dart';
import '../models/currency.dart';
import '../services/app_data_cache.dart';
import '../widgets/global_loading_spinner.dart';
import '../widgets/global_bottom_nav_bar.dart';
import '../design_system/design_system.dart';
import '../design_system/components/cards/error_state_card.dart';

class StatisticsScreen extends StatefulWidget {
  @override
  _StatisticsScreenState createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
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
    _loadStatistics();
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
        error = e.toString();
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

    } catch (e) {
      print('Error calculating statistics: $e');
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
    final screenWidth = MediaQuery.of(context).size.width;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: Stack(
        children: [
          // Teal radial gradient at top (matches opponent detail / home screens)
          Positioned(
            top: -screenWidth * 0.5,
            right: -screenWidth * 0.25,
            child: Transform.scale(
              scaleX: 1.0,
              scaleY: 0.7,
              child: Container(
                width: screenWidth * 1.5,
                height: screenWidth * 1.2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.5,
                    colors: [
                      const Color(0xFF1A4A4A),
                      const Color(0xFF133538).withOpacity(0.7),
                      const Color(0xFF133538).withOpacity(0.3),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.3, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: error != null
                ? ErrorStateCard(onRetry: () => _loadStatistics(forceRefresh: true))
                : LoadingWrapper(
                    isLoading: isLoading,
                    loadingMessage: _getLoadingMessage(l10n),
                    child: _buildContent(),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: GlobalBottomNavBar(currentScreen: 'statistics'),
    );
  }

  Widget _buildContent() {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        // Header with back button on left, refresh on right
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Row(
            children: [
              // Back button (left side)
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFF101115),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.statsTitle,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.statsSubtitle,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.6),
                        fontWeight: FontWeight.w400,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              // Refresh button (right side)
              GestureDetector(
                onTap: () => _loadStatistics(forceRefresh: true),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3C3C43).withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverallStats(),
                const SizedBox(height: 32),
                _buildSectionHeader(l10n.statsGeneral),
                const SizedBox(height: 12),
                _buildGeneralSessionStats(),
                const SizedBox(height: 24),
                _buildSectionHeader(l10n.statsCash),
                const SizedBox(height: 12),
                _buildCashSessionStats(),
                const SizedBox(height: 24),
                _buildSectionHeader(l10n.statsTournament),
                const SizedBox(height: 12),
                _buildTournamentSessionStats(),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverallStats() {
    final l10n = AppLocalizations.of(context);
    final na = l10n.commonNotAvailable;
    String formatStat(double value, int opportunity) {
      if (opportunity == 0) return na;
      return '${value.toStringAsFixed(1)}%';
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131616),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.statsTitle,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatListItem(l10n.statsHandsPlayed, handsPlayed.toString()),
          _buildDivider(),
          _buildStatListItem('VPIP', totalHands > 0 ? '${vpip.toStringAsFixed(1)}%' : na),
          _buildDivider(),
          _buildStatListItem('PFR', totalHands > 0 ? '${pfr.toStringAsFixed(1)}%' : na),
          _buildDivider(),
          _buildStatListItem('3-Bet', formatStat(threeBet, threeBetOpportunity)),
          _buildDivider(),
          _buildStatListItem(l10n.statsFoldTo3Bet, formatStat(fold3Bet, facing3BetCount)),
          _buildDivider(),
          _buildStatListItem('C-Bet', formatStat(cbet, cbetOpportunity)),
          _buildDivider(),
          _buildStatListItem('Steal', formatStat(steal, stealOpportunity)),
          _buildDivider(),
          _buildStatListItem('Check/Raise', formatStat(checkRaise, checkRaiseFlopOpportunity)),
          _buildDivider(),
          _buildStatListItem(l10n.statsWinRate, handsPlayed > 0 ? '${winRate.toStringAsFixed(1)}%' : na),
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
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.8),
              height: 1.0,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF89F1EC),
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: Colors.white.withOpacity(0.1),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.ibmPlexSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF87ED81),
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildStatsCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131616),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(20),
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
                style: GoogleFonts.ibmPlexSans(color: Colors.white.withOpacity(0.4), fontSize: 14),
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
      ],
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
          style: GoogleFonts.ibmPlexSans(color: Colors.white.withOpacity(0.4), fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildProfitRow(String label, double value) {
    final isPositive = value >= 0;
    final prefix = isPositive ? '+' : '';
    final color = isPositive ? const Color(0xFF87ED81) : const Color(0xFFE85A5A);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15, fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.8), height: 1.0,
            ),
          ),
          Text(
            '$prefix${CurrencyService.formatCashRounded(value)}',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15, fontWeight: FontWeight.w600,
              color: color, height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyRateRow(String label, double rate, int totalMinutes) {
    final na = AppLocalizations.of(context).commonNotAvailable;
    if (totalMinutes == 0) {
      return _buildStatListItem(label, na);
    }
    final isPositive = rate >= 0;
    final prefix = isPositive ? '+' : '';
    final color = isPositive ? const Color(0xFF87ED81) : const Color(0xFFE85A5A);
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
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15, fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.8), height: 1.0,
            ),
          ),
          Text(
            rateText,
            style: GoogleFonts.ibmPlexSans(
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
          style: GoogleFonts.ibmPlexSans(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF89F1EC),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white.withOpacity(0.4),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

}
