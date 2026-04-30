import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/user_stats_service.dart';
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

    } catch (e) {
      print('Error calculating statistics: $e');
      throw e;
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
                _buildSessionStats(),
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

  Widget _buildSessionStats() {
    final l10n = AppLocalizations.of(context);
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
            l10n.statsSessionStatistics,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          if (totalSessions > 0)
            Row(
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
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  l10n.statsPlayToSee,
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
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
