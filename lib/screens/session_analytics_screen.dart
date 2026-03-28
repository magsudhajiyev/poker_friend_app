import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
import '../models/game_types.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadSessionAnalytics();
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
      final isDealerSession = widget.sessionData['isDealerSession'] == true;
      final dealerSessionId = widget.sessionData['dealerSessionId'] as String?;

      try {
        if (isDealerSession && dealerSessionId != null) {
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
      _totalInvested = widget.sessionData['buyInAmount']?.toDouble() ?? 0.0;
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
      return '\$${amount.toStringAsFixed(2)}';
    } else {
      return amount.toStringAsFixed(0);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Teal radial gradient at top
          Positioned(
            top: -screenWidth * 0.3,
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
                          decoration: BoxDecoration(
                            color: const Color(0xFF3C3C43).withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Session Analytics',
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
                              '${_hands.length} hands logged',
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
            widget.sessionData['sessionName'] ?? 'Poker Session',
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
              Expanded(child: _buildMetricTile('Total Invested', _formatTotalInvested(_totalInvested))),
              const SizedBox(width: 10),
              Expanded(child: _buildMetricTile('Final Stack', _formatCurrency(_finalStack))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  _isCashGame() ? 'Profit/Loss' : 'Avg Growth',
                  _isCashGame()
                      ? '${_profitLoss >= 0 ? '+' : ''}${_formatCurrency(_profitLoss)}'
                      : '${_profitLoss >= 0 ? '+' : ''}${_profitLoss.toStringAsFixed(2)}',
                  valueColor: _profitLoss >= 0 ? const Color(0xFF89F1EC) : const Color(0xFFFF6B6B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _buildMetricTile('Duration', _formatDuration())),
            ],
          ),
          const SizedBox(height: 16),
          // Rebuys row
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rebuys',
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
            'Stack Growth',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.2,
            ),
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

  Widget _buildLineChart() {
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

    return Row(
      children: [
        // Fixed Y-axis
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
                        style: GoogleFonts.robotoMono(
                          color: Colors.white.withOpacity(0.3),
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
            reverse: true,
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
                        color: Colors.white.withOpacity(0.05),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                                style: GoogleFonts.ibmPlexSans(
                                  color: Colors.white.withOpacity(0.3),
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
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (spots.length - 1).toDouble(),
                  minY: spots.isNotEmpty ? spots.map((e) => e.y).reduce((a, b) => a < b ? a : b) * 0.9 : 0,
                  maxY: spots.isNotEmpty ? spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.1 : 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
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
            Icons.show_chart_rounded,
            color: Colors.white.withOpacity(0.15),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'No Stack History Available',
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white.withOpacity(0.4),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Stack changes will be tracked in future sessions',
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
            'View Logged Hands',
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
            'sessionName': widget.sessionData['sessionName'] ?? 'Poker Session',
            ...widget.sessionData,
          },
        ),
      ),
    );
  }
}
