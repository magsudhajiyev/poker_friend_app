import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
import '../design_system/components/backgrounds/gradient_background.dart';
import '../design_system/components/buttons/glassy_icon_button.dart';
import '../models/game_types.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
// Commented out for MVP - SessionAnalyticsService endpoints not deployed yet
// import '../services/session_analytics_service.dart';
// import '../services/auth_service.dart';
import '../services/dealer_service.dart';
import 'session_hands_screen.dart';

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

  // Full Analysis Job State - Commented out for MVP
  // bool _isRequestingAnalysis = false;
  // String? _analysisJobId;
  // String? _analysisSessionId;
  // String _analysisStatus = '';
  // double _analysisProgress = 0.0;
  // String? _analysisError;

  @override
  void initState() {
    super.initState();
    _loadSessionAnalytics();
  }

  Future<void> _loadSessionAnalytics() async {
    try {
      // Load detailed session data including stack history, rebuys, and hands
      Map<String, dynamic>? sessionDetails;
      try {
        sessionDetails = await FirebaseService.getSession(widget.sessionId);
      } catch (e) {
        sessionDetails = await LocalStorageService.getSession(widget.sessionId);
      }

      // Try Firebase first, fall back to local storage
      // For dealer sessions, fetch from dealer_sessions collection
      List<Map<String, dynamic>> hands;
      final isDealerSession = widget.sessionData['isDealerSession'] == true;
      final dealerSessionId = widget.sessionData['dealerSessionId'] as String?;

      try {
        if (isDealerSession && dealerSessionId != null) {
          // Fetch hands from dealer_sessions collection
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

        // Calculate analytics
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

    // Get final stack from stack history or session data
    if (_stackHistory.isNotEmpty) {
      _finalStack = _stackHistory.last['stackSize']?.toDouble() ?? 0.0;
    } else {
      _finalStack = widget.sessionData['finalStack']?.toDouble() ?? widget.sessionData['currentStack']?.toDouble() ?? 0.0;
    }

    if (isCashGame) {
      // CASH GAME: Calculate P/L in dollars
      // Total invested = buy-in + rebuys (in cash, chips = dollars)
      final sessionTotalBuyIn = widget.sessionData['totalBuyIn']?.toDouble() ?? 0.0;
      final initialBuyIn = widget.sessionData['buyInAmount']?.toDouble() ?? 0.0;
      final totalRebuyAmount = _rebuys.fold<double>(0.0, (sum, rebuy) => sum + (rebuy['amount']?.toDouble() ?? 0.0));
      final calculatedTotal = initialBuyIn + totalRebuyAmount;

      _totalInvested = (sessionTotalBuyIn > calculatedTotal) ? sessionTotalBuyIn : calculatedTotal;

      // P/L = Final Stack - Total Invested
      _profitLoss = _finalStack - _totalInvested;
    } else {
      // TOURNAMENT: Use pre-calculated average growth
      // Store total invested as buy-in amount (for display purposes)
      _totalInvested = widget.sessionData['buyInAmount']?.toDouble() ?? 0.0;

      // Use pre-calculated average growth from session data (O(1) instead of O(n))
      _profitLoss = widget.sessionData['averageGrowth']?.toDouble() ?? 0.0;

      // Fallback: If averageGrowth not stored (old sessions), calculate it
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

          // Calculate growth for each hand (excluding initial)
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
      return '\$${amount.toStringAsFixed(2)}';
    } else {
      return amount.toStringAsFixed(0);
    }
  }

  // Always format with $ sign for Total Invested display
  String _formatTotalInvested(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
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
        return 'N/A';
      }
    }
    return 'N/A';
  }

  Widget _buildSessionOverview() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0xFF2A2A2E), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Session Title
          Row(
            children: [
              Image.asset('icons/session.png', width: 20, height: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.sessionData['sessionName'] ?? 'Poker Session',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          // Key Metrics Row
          Row(
            children: [
              Expanded(
                child: _buildMetricCardWithAsset(
                  'Total Invested',
                  _formatTotalInvested(_totalInvested),
                  'icons/wallet.png',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildMetricCardWithAsset(
                  'Final Stack',
                  _formatCurrency(_finalStack),
                  'icons/ante.png',
                ),
              ),
            ],
          ),

          SizedBox(height: 8),

          // Profit/Loss (Cash) or Avg Growth (Tournament) and Duration Row
          Row(
            children: [
              Expanded(
                child: _buildMetricCardWithAsset(
                  _isCashGame() ? 'Profit/Loss' : 'Avg Growth',
                  _isCashGame()
                    ? '${_profitLoss >= 0 ? '+' : ''}${_formatCurrency(_profitLoss)}'
                    : '${_profitLoss >= 0 ? '+' : ''}${_profitLoss.toStringAsFixed(2)}',
                  'icons/progress.png',
                  textColor: _profitLoss >= 0 ? Color(0xFF5AC95A) : Color(0xFFFF6B6B),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildMetricCardWithAsset(
                  'Duration',
                  _formatDuration(),
                  'icons/clock.png',
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          // Session Details
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color(0xFF161618),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _buildDetailRow('Rebuys', '${_rebuys.length}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCardWithAsset(String title, String value, String assetPath, {Color? textColor}) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Color(0xFF161618),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(assetPath, width: 16, height: 16),
              SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: Color(0xFF9A9A9A),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: textColor ?? Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Color(0xFF161618),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: Color(0xFF9A9A9A),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Color(0xFF9A9A9A),
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStackChart() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0xFF2A2A2E), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('icons/stats.png', width: 20, height: 20),
              SizedBox(width: 10),
              Text(
                'Stack Growth',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Chart Container
          Container(
            height: 250,
            child: _stackHistory.length >= 2 ? _buildLineChart() : _buildNoDataChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart() {
    // Prepare chart data from stack history
    List<FlSpot> spots = [];

    if (_stackHistory.isNotEmpty) {
      for (int i = 0; i < _stackHistory.length; i++) {
        final entry = _stackHistory[i];
        final stackSize = entry['stackSize']?.toDouble() ?? 0.0;
        spots.add(FlSpot(i.toDouble(), stackSize));
      }
    }

    // If we don't have stack history, create basic chart with start and end
    if (spots.isEmpty) {
      final initialStack = widget.sessionData['startingStack']?.toDouble() ?? 0.0;
      spots = [
        FlSpot(0, initialStack),
        FlSpot(1, _finalStack),
      ];
    }

    // Calculate chart width: 60 pixels per data point
    final double pointWidth = 60.0;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double chartAreaWidth = spots.length > 7
        ? spots.length * pointWidth
        : screenWidth - 92; // Account for Y-axis (60) and padding (32)

    return Row(
      children: [
        // Fixed Y-axis on the left
        SizedBox(
          width: 60,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: spots.isNotEmpty ? (spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) / 4) : 100,
                    reservedSize: 60,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      return Text(
                        _formatCurrency(value),
                        style: TextStyle(
                          color: Color(0xFF9A9A9A),
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minY: spots.isNotEmpty ? spots.map((e) => e.y).reduce((a, b) => a < b ? a : b) * 0.9 : 0,
              maxY: spots.isNotEmpty ? spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.1 : 100,
              lineBarsData: [],
            ),
          ),
        ),
        // Scrollable chart area
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true, // Start scrolled to the right (showing last 7 points)
            child: SizedBox(
              width: chartAreaWidth,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: spots.isNotEmpty ? (spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) / 5) : 100,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Color(0xFF2A2A2E),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), // Hide left titles in scrollable area
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          if (value.toInt() < _stackHistory.length) {
                            final entry = _stackHistory[value.toInt()];
                            final changeType = entry['changeType'] ?? 'unknown';

                            String label = '';
                            switch (changeType) {
                              case 'initial':
                                label = 'Start';
                                break;
                              case 'rebuy':
                                label = 'Rebuy';
                                break;
                              case 'hand':
                                label = 'Hand';
                                break;
                              default:
                                label = '${value.toInt() + 1}';
                            }

                            return SideTitleWidget(
                              meta: meta,
                              space: 8.0,
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: Color(0xFF9A9A9A),
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }
                          return Container();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Color(0xFF2A2A2E)),
                  ),
                  minX: 0,
                  maxX: (spots.length - 1).toDouble(),
                  minY: spots.isNotEmpty ? spots.map((e) => e.y).reduce((a, b) => a < b ? a : b) * 0.9 : 0,
                  maxY: spots.isNotEmpty ? spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.1 : 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      gradient: LinearGradient(
                        colors: _profitLoss >= 0
                          ? [Color(0xFF5AC95A).withOpacity(0.3), Color(0xFF5AC95A)]
                          : [Color(0xFFFF6B6B).withOpacity(0.3), Color(0xFFFF6B6B)],
                      ),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: _profitLoss >= 0 ? Color(0xFF5AC95A) : Color(0xFFFF6B6B),
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: _profitLoss >= 0
                            ? [Color(0xFF5AC95A).withOpacity(0.1), Colors.transparent]
                            : [Color(0xFFFF6B6B).withOpacity(0.1), Colors.transparent],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoDataChart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart,
            color: Color(0xFF2A2A2E),
            size: 48,
          ),
          SizedBox(height: 12),
          Text(
            'No Stack History Available',
            style: TextStyle(
              color: Color(0xFF9A9A9A),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Stack changes will be tracked in future sessions',
            style: TextStyle(
              color: Color(0xFF6A6A6E),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // Commented out for MVP - SessionAnalyticsService endpoints not deployed yet
  /*
  Widget _buildFullAnalysisButton() {
    // Determine button state based on analysis status
    final bool hasEnoughHands = _hands.length >= 1;
    final bool isAnalyzing = _isRequestingAnalysis ||
        _analysisStatus == SessionAnalyticsService.statusPending ||
        _analysisStatus == SessionAnalyticsService.statusProcessing;
    final bool analysisComplete =
        _analysisStatus == SessionAnalyticsService.statusCompleted;
    final bool analysisFailed =
        _analysisStatus == SessionAnalyticsService.statusFailed;

    // Determine button color based on state
    final Color buttonColor = analysisFailed
        ? Color(0xFFFF6B6B)
        : Color(0xFFBAFF9A);
    final Color textColor = analysisFailed ? Colors.white : Colors.black;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          GestureDetector(
            onTap: !hasEnoughHands || isAnalyzing
                ? null
                : analysisComplete
                    ? _viewAnalysisResults
                    : _requestFullAnalysis,
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: (!hasEnoughHands || isAnalyzing)
                    ? buttonColor.withOpacity(0.5)
                    : buttonColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: isAnalyzing
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(textColor),
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Analyzing... ${(_analysisProgress * 100).toInt()}%',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            analysisComplete
                                ? Icons.analytics
                                : analysisFailed
                                    ? Icons.refresh
                                    : Icons.auto_graph,
                            color: textColor,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text(
                            analysisComplete
                                ? 'View GTO Analysis'
                                : analysisFailed
                                    ? 'Retry Analysis'
                                    : 'Request Full GTO Analysis',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          // Error message if analysis failed
          if (_analysisError != null) ...[
            SizedBox(height: 8),
            Text(
              _analysisError!,
              style: TextStyle(
                color: Color(0xFFFF6B6B),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          // Info text
          if (!hasEnoughHands) ...[
            SizedBox(height: 8),
            Text(
              'Log at least 1 hand to enable full analysis',
              style: TextStyle(
                color: Color(0xFF9A9A9A),
                fontSize: 12,
              ),
            ),
          ] else if (!analysisComplete && !isAnalyzing && !analysisFailed) ...[
            SizedBox(height: 8),
            Text(
              'Analyze ${_hands.length} hands for GTO compliance, leaks & coaching',
              style: TextStyle(
                color: Color(0xFF9A9A9A),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _requestFullAnalysis() async {
    final userId = AuthService.userId;
    if (userId == null) {
      setState(() {
        _analysisError = 'Please sign in to use this feature';
      });
      return;
    }

    if (_hands.isEmpty) {
      setState(() {
        _analysisError = 'No hands to analyze';
      });
      return;
    }

    setState(() {
      _isRequestingAnalysis = true;
      _analysisError = null;
      _analysisProgress = 0.0;
    });

    try {
      // Determine game type
      final gameType = widget.sessionData['gameType'];
      final isCashGame = gameType == 'cash' || gameType == GameType.cash.name;

      // Create session and queue job
      final result = await SessionAnalyticsService.createSession(
        userId: userId,
        sessionName: widget.sessionData['sessionName'] ?? 'Poker Session',
        gameType: isCashGame ? 'cash' : 'mtt',
        hands: _hands,
        stakes: widget.sessionData['stakes'],
        tableSize: widget.sessionData['tableSize'],
        startedAt: widget.sessionData['startTime'] != null
            ? DateTime.tryParse(widget.sessionData['startTime'])
            : null,
        endedAt: widget.sessionData['endTime'] != null
            ? DateTime.tryParse(widget.sessionData['endTime'])
            : null,
      );

      setState(() {
        _analysisSessionId = result['id'];  // API returns 'id' not 'session_id'
        _analysisJobId = result['id'];  // Use session ID for job lookup
        _analysisStatus = result['job_status'] ?? SessionAnalyticsService.statusProcessing;
        _analysisProgress = (result['job_progress'] ?? 0.0) / 100.0;
        _isRequestingAnalysis = false;
      });

      // Start polling for progress
      _pollJobProgress();
    } catch (e) {
      setState(() {
        _isRequestingAnalysis = false;
        _analysisError = e.toString().replaceAll('Exception: ', '');
        _analysisStatus = SessionAnalyticsService.statusFailed;
      });
    }
  }

  Future<void> _pollJobProgress() async {
    final userId = AuthService.userId;
    if (userId == null || _analysisSessionId == null) return;

    while (_analysisStatus == SessionAnalyticsService.statusProcessing ||
        _analysisStatus == SessionAnalyticsService.statusPending) {
      try {
        await Future.delayed(Duration(seconds: 2));

        final progress = await SessionAnalyticsService.getJobProgress(
          userId: userId,
          sessionId: _analysisSessionId!,
        );

        if (!mounted) return;

        setState(() {
          _analysisStatus = progress['status'] ?? '';
          // API returns progress_pct directly, not nested
          _analysisProgress = (progress['progress_pct'] ?? 0.0) / 100.0;
        });

        if (_analysisStatus == SessionAnalyticsService.statusCompleted) {
          // Analysis complete - could show a notification
          break;
        } else if (_analysisStatus == SessionAnalyticsService.statusFailed) {
          setState(() {
            _analysisError = progress['last_error'] ?? 'Analysis failed';
          });
          break;
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _analysisError = 'Failed to get progress: ${e.toString()}';
        });
        break;
      }
    }
  }

  void _viewAnalysisResults() {
    // TODO: Navigate to full analysis results screen
    // For now, show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Full analytics dashboard coming soon!'),
        backgroundColor: Color(0xFF5AC95A),
      ),
    );
  }
  */

  Widget _buildLoggedHandsButton() {
    return Container(
      margin: EdgeInsets.all(16),
      child: GestureDetector(
        onTap: _navigateToLoggedHands,
        child: Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: Color(0xFFBAFF9A),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.style_outlined, color: Colors.black, size: 20),
                SizedBox(width: 10),
                Text(
                  'View Logged Hands',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ],
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
            'sessionName': widget.sessionData['sessionName'] ?? 'Poker Session',
            ...widget.sessionData,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GradientBackground(),
          SafeArea(
            child: Column(
              children: [
                // Glassmorphic Header
                ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                    child: Container(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
                      decoration: BoxDecoration(
                        color: Color(0x03FFFFFF),
                      ),
                      child: Row(
                        children: [
                          GlassyIconButton(
                            icon: Icons.arrow_back,
                            onPressed: () => Navigator.pop(context),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Session Analytics',
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '${_hands.length} hands logged',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Content
                Expanded(
                  child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5AC95A)),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            // Session Overview
                            _buildSessionOverview(),

                            SizedBox(height: 16),

                            // Stack Chart
                            _buildStackChart(),

                            SizedBox(height: 16),

                            // Request Full Analysis Button (Premium Feature)
                            // Commented out for MVP - SessionAnalyticsService endpoints not deployed yet
                            // _buildFullAnalysisButton(),

                            // SizedBox(height: 16),

                            // Logged Hands Button
                            _buildLoggedHandsButton(),

                            SizedBox(height: 32),
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
}