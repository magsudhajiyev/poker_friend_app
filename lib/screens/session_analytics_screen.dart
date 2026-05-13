import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
import '../models/game_types.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import '../services/dealer_service.dart';
import 'session_hands_screen.dart';
import 'hand_actions_page_view.dart';
import 'stack_chart_screen.dart';
import '../widgets/global_bottom_nav_bar.dart';
import '../services/session_export_service.dart';
import '../services/subscription_service.dart';
import '../services/app_data_cache.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'paywall_screen.dart';
import '../l10n/app_localizations.dart';
import '../services/currency_service.dart';


class SessionAnalyticsScreen extends StatefulWidget {
  final Map<String, dynamic> sessionData;
  final String sessionId;

  const SessionAnalyticsScreen({
    super.key,
    required this.sessionData,
    required this.sessionId,
  });

  @override
  State<SessionAnalyticsScreen> createState() => _SessionAnalyticsScreenState();
}

class _SessionAnalyticsScreenState extends State<SessionAnalyticsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _stackHistory = [];
  List<Map<String, dynamic>> _rebuys = [];
  List<Map<String, dynamic>> _hands = [];
  double _totalInvested = 0.0;
  double _finalStack = 0.0;
  double _profitLoss = 0.0;
  int? _touchedSpotIndex;

  bool _isExporting = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadSessionAnalytics();
  }

  Future<void> _handleDeleteSession() async {
    if (_isDeleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          AppLocalizations.of(ctx).sessionAnalyticsDeleteTitle,
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          AppLocalizations.of(ctx).sessionAnalyticsDeleteMessage,
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              AppLocalizations.of(ctx).commonCancel,
              style: GoogleFonts.ibmPlexSans(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              AppLocalizations.of(ctx).commonDelete,
              style: GoogleFonts.ibmPlexSans(
                color: const Color(0xFFFF6B6B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      await FirebaseService.deleteSession(widget.sessionId);
      await LocalStorageService.deleteSession(widget.sessionId);

      AppDataCache.markSessionsDirty();
      AppDataCache.markHomeDirty();
      AppDataCache.markStatsDirty();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).sessionAnalyticsDeleted,
              style: GoogleFonts.ibmPlexSans(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF1A1A2E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).sessionAnalyticsFailedToDelete,
              style: GoogleFonts.ibmPlexSans(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }

  Future<void> _handleSessionExport() async {
    if (_isExporting || _hands.isEmpty) return;

    final isPremium = SubscriptionService.isPremium;
    if (!isPremium) {
      final purchased =
          await PaywallScreen.show(context, featureName: 'Session Export');
      if (purchased != true || !mounted) return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;

    if (email == null || email.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).sessionAnalyticsNoEmailFound),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Show confirmation dialog
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          AppLocalizations.of(ctx).sessionAnalyticsExportSession,
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          AppLocalizations.of(ctx).sessionAnalyticsExportConfirm(_hands.length, email),
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              AppLocalizations.of(ctx).commonCancel,
              style: GoogleFonts.ibmPlexSans(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              AppLocalizations.of(ctx).sessionAnalyticsExport,
              style: GoogleFonts.ibmPlexSans(
                color: const Color(0xFF89F1EC),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isExporting = true);

    try {
      await SessionExportService.exportSession(
        userId: user!.uid,
        userEmail: email,
        session: widget.sessionData,
        hands: _hands,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).sessionAnalyticsExportSent(email)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).sessionAnalyticsExportFailed(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _loadSessionAnalytics() async {
    try {
      Map<String, dynamic>? sessionDetails;
      try {
        sessionDetails = await FirebaseService.getSession(widget.sessionId);
      } catch (e) {
        sessionDetails = await LocalStorageService.getSession(widget.sessionId);
      }

      List<Map<String, dynamic>> hands;
      final dealerSessionIds = (widget.sessionData['dealerSessionIds'] as List<dynamic>?)
          ?.cast<String>();
      final dealerSessionId = widget.sessionData['dealerSessionId'] as String?;

      try {
        if (dealerSessionIds != null && dealerSessionIds.isNotEmpty) {
          // Multi-table event: fetch and merge hands from ALL dealer sessions
          // Apply hand number offsets to match the merged stackHistory numbering
          hands = [];
          int handOffset = 0;
          for (final dsId in dealerSessionIds) {
            final sessionHands = await DealerService.getSessionHands(dsId);
            int maxHandNum = 0;
            for (final hand in sessionHands) {
              final origNum = hand['handNumber'] as int? ?? 0;
              if (origNum > maxHandNum) maxHandNum = origNum;
              hand['handNumber'] = origNum + handOffset;
            }
            hands.addAll(sessionHands);
            handOffset += maxHandNum;
          }
          hands.sort((a, b) =>
              (a['startTime'] ?? '').compareTo(b['startTime'] ?? ''));
        } else if (dealerSessionId != null) {
          hands = await DealerService.getSessionHands(dealerSessionId);
        } else {
          hands = await FirebaseService.getSessionHands(widget.sessionId);
        }
      } catch (e) {
        hands = await LocalStorageService.getSessionHands(widget.sessionId);
      }

      setState(() {
        _stackHistory = List<Map<String, dynamic>>.from(sessionDetails?['stackHistory'] ?? []);
        _rebuys = List<Map<String, dynamic>>.from(sessionDetails?['rebuys'] ?? []);
        _hands = hands;
        _calculateSessionAnalytics();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _calculateSessionAnalytics() {
    final gameType = widget.sessionData['gameType'];
    final isCashGame = gameType == 'cash' || gameType == GameType.cash.name;

    if (_stackHistory.isNotEmpty) {
      _finalStack = _stackHistory.last['stackSize']?.toDouble() ?? 0.0;
    } else {
      _finalStack = widget.sessionData['finalStack']?.toDouble() ?? widget.sessionData['currentStack']?.toDouble() ?? 0.0;
    }

    if (isCashGame) {
      final sessionTotalBuyIn = widget.sessionData['totalBuyIn']?.toDouble() ?? 0.0;
      final initialBuyIn = widget.sessionData['buyInAmount']?.toDouble() ?? 0.0;
      final totalRebuyAmount = _rebuys.fold<double>(0.0, (sum, rebuy) => sum + (rebuy['amount']?.toDouble() ?? 0.0));
      final calculatedTotal = initialBuyIn + totalRebuyAmount;
      _totalInvested = (sessionTotalBuyIn > calculatedTotal) ? sessionTotalBuyIn : calculatedTotal;
      _profitLoss = _finalStack - _totalInvested;
    } else {
      _totalInvested = widget.sessionData['totalBuyIn']?.toDouble()
          ?? widget.sessionData['buyInAmount']?.toDouble()
          ?? 0.0;
      _profitLoss = widget.sessionData['averageGrowth']?.toDouble() ?? 0.0;

      if (_profitLoss == 0.0 && _stackHistory.length > 1) {
        double startingStack = widget.sessionData['startingStack']?.toDouble() ?? 0.0;
        if (startingStack == 0.0 && _stackHistory.isNotEmpty) {
          final initialEntry = _stackHistory.firstWhere(
            (entry) => entry['changeType'] == 'initial',
            orElse: () => _stackHistory.first,
          );
          startingStack = initialEntry['stackSize']?.toDouble() ?? 0.0;
        }
        if (startingStack > 0) {
          double totalGrowth = 0.0;
          int growthCount = 0;
          for (int i = 1; i < _stackHistory.length; i++) {
            final currentStack = _stackHistory[i]['stackSize']?.toDouble() ?? 0.0;
            final previousStack = _stackHistory[i - 1]['stackSize']?.toDouble() ?? startingStack;
            if (previousStack > 0) {
              final handGrowth = ((currentStack - previousStack) / previousStack) * 100;
              totalGrowth += handGrowth;
              growthCount++;
            }
          }
          _profitLoss = growthCount > 0 ? totalGrowth / growthCount : 0.0;
        }
      }
    }
  }

  bool _isCashGame() {
    final gameType = widget.sessionData['gameType'];
    return gameType == 'cash' || gameType == GameType.cash.name;
  }

  String _formatCurrency(double amount) {
    if (_isCashGame()) {
      return CurrencyService.formatCash(amount);
    } else {
      return amount.toStringAsFixed(0);
    }
  }

  String _formatTotalInvested(double amount) {
    return CurrencyService.formatCash(amount);
  }

  String _formatDuration() {
    final startTime = widget.sessionData['startTime'];
    final endTime = widget.sessionData['endTime'];
    if (startTime != null && endTime != null) {
      try {
        final start = DateTime.parse(startTime);
        final end = DateTime.parse(endTime);
        final duration = end.difference(start);
        final hours = duration.inHours;
        final minutes = duration.inMinutes % 60;
        if (hours > 0) {
          return '${hours}h ${minutes}m';
        } else {
          return '${minutes}m';
        }
      } catch (e) {
        return AppLocalizations.of(context).commonNotAvailable;
      }
    }
    return AppLocalizations.of(context).commonNotAvailable;
  }

  String _formatHourlyRate() {
    final startTime = widget.sessionData['startTime'];
    final endTime = widget.sessionData['endTime'];
    if (startTime == null || endTime == null) return AppLocalizations.of(context).commonNotAvailable;
    try {
      final start = DateTime.parse(startTime);
      final end = DateTime.parse(endTime);
      final minutes = end.difference(start).inMinutes;
      if (minutes < 60) return AppLocalizations.of(context).commonNotAvailable;
      final hourly = _profitLoss / (minutes / 60);
      final prefix = hourly >= 0 ? '+' : '';
      return '$prefix${CurrencyService.formatCash(hourly)}/h';
    } catch (e) {
      return AppLocalizations.of(context).commonNotAvailable;
    }
  }

  String _formatFinished() {
    final place = widget.sessionData['finishedPlace'];
    final field = widget.sessionData['fieldSize'];
    if (place != null && field != null) {
      return '$place / $field';
    } else if (place != null) {
      return '$place';
    }
    return AppLocalizations.of(context).commonNotAvailable;
  }

  double _getTournamentCashout() {
    final prize = widget.sessionData['prizeWon']?.toDouble();
    if (prize != null && prize > 0) return prize;
    // Fallback: use final stack for sessions saved before prizeWon was tracked
    return _finalStack;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      bottomNavigationBar: GlobalBottomNavBar(currentScreen: 'sessions'),
      body: Stack(
        children: [
          // Teal radial gradient at top
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
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFF101115),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.sessionAnalyticsTitle,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.sessionAnalyticsHandsLogged(widget.sessionData['handsLogged'] ?? widget.sessionData['totalHands'] ?? _hands.length),
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
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _isExporting || _hands.isEmpty ? null : _handleSessionExport,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF101115),
                            shape: BoxShape.circle,
                          ),
                          child: _isExporting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF89F1EC)),
                                  ),
                                )
                              : Icon(Icons.ios_share,
                                  color: _hands.isEmpty
                                      ? Colors.white.withValues(alpha: 0.25)
                                      : Colors.white,
                                  size: 20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _isDeleting ? null : _handleDeleteSession,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFF101115),
                            shape: BoxShape.circle,
                          ),
                          child: _isDeleting
                              ? const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xFFFF6B6B)),
                                    ),
                                  ),
                                )
                              : const Icon(Icons.delete_outline,
                                  color: Color(0xFFFF6B6B), size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF89F1EC)),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              _buildSessionOverview(),
                              const SizedBox(height: 16),
                              _buildStackChart(),
                              const SizedBox(height: 16),
                              _buildLoggedHandsButton(),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionOverview() {
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
          // Session name
          Text(
            widget.sessionData['sessionName'] ?? l10n.sessionAnalyticsPokerSession,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          // Metrics grid
          Row(
            children: [
              Expanded(child: _buildMetricTile(l10n.sessionAnalyticsTotalInvested, _formatTotalInvested(_totalInvested))),
              const SizedBox(width: 10),
              Expanded(child: _buildMetricTile(
                l10n.sessionAnalyticsCashout,
                _isCashGame()
                  ? _formatCurrency(_finalStack)
                  : CurrencyService.formatCash(_getTournamentCashout()),
              )),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _isCashGame()
                  ? _buildMetricTile(
                      l10n.sessionAnalyticsHourlyRate,
                      _formatHourlyRate(),
                    )
                  : _buildMetricTile(
                      l10n.sessionAnalyticsFinished,
                      _formatFinished(),
                    ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Builder(builder: (_) {
                final pl = _isCashGame() ? _profitLoss : _getTournamentCashout() - _totalInvested;
                return _buildMetricTile(
                  l10n.sessionAnalyticsProfitLoss,
                  '${pl >= 0 ? '+' : ''}${CurrencyService.formatCash(pl)}',
                  valueColor: pl >= 0 ? const Color(0xFF89F1EC) : const Color(0xFFFF6B6B),
                );
              })),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.1),
          ),
          // Rebuys (tournament) / Add-ons (cash)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isCashGame() ? l10n.sessionAnalyticsAddons : l10n.sessionAnalyticsRebuys,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.8),
                    height: 1.0,
                  ),
                ),
                Text(
                  '${_rebuys.length}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF89F1EC),
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String title, String value, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.ibmPlexSans(
              color: valueColor ?? Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStackChart() {
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
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.sessionAnalyticsStackChart,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
              if (_stackHistory.length >= 2)
                GestureDetector(
                  onTap: _openFullScreenChart,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.fullscreen_rounded,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 22,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: _stackHistory.length >= 2 ? _buildLineChart() : _buildNoDataChart(),
          ),
        ],
      ),
    );
  }

  void _openFullScreenChart() {
    setState(() => _touchedSpotIndex = null);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StackChartScreen(
          stackHistory: _stackHistory,
          hands: _hands,
          sessionData: widget.sessionData,
          profitLoss: _profitLoss,
        ),
      ),
    );
  }

  Widget _buildLineChart() {
    final l10n = AppLocalizations.of(context);
    List<FlSpot> spots = [];

    if (_stackHistory.isNotEmpty) {
      for (int i = 0; i < _stackHistory.length; i++) {
        final entry = _stackHistory[i];
        final stackSize = entry['stackSize']?.toDouble() ?? 0.0;
        spots.add(FlSpot(i.toDouble(), stackSize));
      }
    }

    if (spots.isEmpty) {
      final initialStack = widget.sessionData['startingStack']?.toDouble() ?? 0.0;
      spots = [
        FlSpot(0, initialStack),
        FlSpot(1, _finalStack),
      ];
    }

    final double pointWidth = 60.0;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double chartAreaWidth = spots.length > 7
        ? spots.length * pointWidth
        : screenWidth - 92;

    final lineColor = _profitLoss >= 0 ? const Color(0xFF89F1EC) : const Color(0xFFFF6B6B);

    final minY = spots.isNotEmpty ? spots.map((e) => e.y).reduce((a, b) => a < b ? a : b) * 0.9 : 0.0;
    final maxY = spots.isNotEmpty ? spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.1 : 100.0;
    final yInterval = maxY > minY ? (maxY - minY) / 4 : 100.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: chartAreaWidth,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: yInterval,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.white.withOpacity(0.05),
                  strokeWidth: 1,
                );
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: yInterval,
                  reservedSize: 55,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    return Text(
                      _formatCurrency(value),
                      style: GoogleFonts.robotoMono(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 10,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 1,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    if (value != value.roundToDouble()) return const SizedBox.shrink();
                    final idx = value.toInt();
                    if (idx < 0 || idx >= _stackHistory.length) return const SizedBox.shrink();
                    final entry = _stackHistory[idx];
                    final changeType = entry['changeType'] ?? 'unknown';
                    String label;
                    switch (changeType) {
                      case 'initial':
                        label = l10n.sessionAnalyticsStart;
                        break;
                      case 'rebuy':
                        label = l10n.sessionAnalyticsRebuy;
                        break;
                      case 'final':
                        label = l10n.sessionAnalyticsEnd;
                        break;
                      case 'manual_increase':
                      case 'manual_decrease':
                        label = '📝';
                        break;
                      default:
                        label = '#${entry['handNumber'] ?? idx}';
                    }
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 8.0,
                      child: Text(
                        label,
                        style: GoogleFonts.ibmPlexSans(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 10,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minX: -0.3,
            maxX: (spots.length - 1).toDouble() + 0.3,
            minY: minY,
            maxY: maxY,
            lineTouchData: LineTouchData(
              enabled: true,
              handleBuiltInTouches: false,
              touchSpotThreshold: 40,
              touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                if (event is FlTapUpEvent) {
                  final tappedOnSpot = response != null && response.lineBarSpots != null && response.lineBarSpots!.isNotEmpty;
                  final tappedIndex = tappedOnSpot ? response!.lineBarSpots!.first.x.toInt() : null;

                  if (_touchedSpotIndex != null) {
                    if (tappedIndex != null && tappedIndex != _touchedSpotIndex) {
                      // Tapped a different dot — switch tooltip
                      setState(() => _touchedSpotIndex = tappedIndex);
                    } else {
                      // Tapped same dot, tooltip, or empty area — navigate to hand
                      final idx = _touchedSpotIndex!;
                      setState(() => _touchedSpotIndex = null);
                      _navigateToHandFromChart(idx);
                    }
                    return;
                  }
                  if (tappedOnSpot) {
                    setState(() => _touchedSpotIndex = tappedIndex);
                  }
                }
              },
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => const Color(0xFF1C2926),
                tooltipRoundedRadius: 12,
                tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final index = spot.x.toInt();
                    final stackValue = _formatCurrency(spot.y);

                    if (index >= 0 && index < _stackHistory.length) {
                      final entry = _stackHistory[index];
                      final handNumber = entry['handNumber'] as int?;
                      final changeType = entry['changeType'] ?? '';
                      final note = entry['note'] as String?;

                      String detail = stackValue;

                      if (changeType != 'initial' && changeType != 'rebuy' && changeType != 'final' && handNumber != null && handNumber > 0) {
                        final hand = _findHandByNumber(handNumber);
                        final position = hand?['heroPositionName'] as String?;
                        final holeCards = hand?['ourHoleCards'] as Map<String, dynamic>?;
                        final card1 = holeCards?['card1'] as String?;
                        final card2 = holeCards?['card2'] as String?;
                        final hasCards = card1 != null && card1.isNotEmpty && card2 != null && card2.isNotEmpty;

                        if (position != null && position.isNotEmpty) {
                          detail += '  ·  $position';
                        }
                        if (hasCards) {
                          detail += '\n$card1 $card2';
                        }
                      }

                      if (note != null && note.isNotEmpty) {
                        detail += '\n📝 $note';
                      }

                      if (detail != stackValue) {
                        return LineTooltipItem(
                          detail,
                          GoogleFonts.ibmPlexSans(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }
                    }

                    return LineTooltipItem(
                      stackValue,
                      GoogleFonts.ibmPlexSans(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
            showingTooltipIndicators: _touchedSpotIndex != null
                ? [ShowingTooltipIndicators([
                    LineBarSpot(
                      LineChartBarData(spots: spots),
                      0,
                      spots[_touchedSpotIndex!],
                    ),
                  ])]
                : [],
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.3,
                preventCurveOverShooting: true,
                gradient: LinearGradient(
                  colors: [lineColor.withOpacity(0.3), lineColor],
                ),
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                    radius: 4,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: lineColor,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [lineColor.withOpacity(0.1), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic>? _findHandByNumber(int handNumber) {
    for (final hand in _hands) {
      if (hand['handNumber'] == handNumber) return hand;
    }
    return null;
  }

  void _navigateToHandFromChart(int spotIndex) {
    if (spotIndex < 0 || spotIndex >= _stackHistory.length) return;
    final entry = _stackHistory[spotIndex];
    final handNumber = entry['handNumber'] as int?;
    final changeType = entry['changeType'] ?? '';
    if (changeType == 'initial' || changeType == 'rebuy' || changeType == 'final') return;
    if (handNumber == null || handNumber <= 0) return;

    final hand = _findHandByNumber(handNumber);
    if (hand == null) return;

    setState(() => _touchedSpotIndex = null);
    final index = _hands.indexOf(hand);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HandActionsPageView(
          hands: _hands,
          initialIndex: index < 0 ? 0 : index,
          ourSeat: null, // Use per-hand heroSeatNumber instead of stale session-level seat
        ),
      ),
    );
  }

  Widget _buildNoDataChart() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart_rounded,
            color: Colors.white.withOpacity(0.15),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.sessionAnalyticsNoStackHistory,
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white.withOpacity(0.4),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.sessionAnalyticsStackTrackedFuture,
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white.withOpacity(0.25),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoggedHandsButton() {
    return GestureDetector(
      onTap: _navigateToLoggedHands,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF89F1EC),
          borderRadius: BorderRadius.circular(60),
        ),
        child: Center(
          child: Text(
            AppLocalizations.of(context).sessionAnalyticsViewLoggedHands,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.black,
              letterSpacing: -0.43,
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToLoggedHands() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SessionHandsScreen(
          session: {
            'id': widget.sessionId,
            'sessionName': widget.sessionData['sessionName'] ?? AppLocalizations.of(context).sessionAnalyticsPokerSession,
            ...widget.sessionData,
          },
        ),
      ),
    );
  }
}
