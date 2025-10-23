import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../design_system/poker_friend_theme.dart';
import '../models/game_types.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
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
      // Load detailed session data including stack history, rebuys, and hands
      Map<String, dynamic>? sessionDetails;
      try {
        sessionDetails = await FirebaseService.getSession(widget.sessionId);
      } catch (e) {
        sessionDetails = await LocalStorageService.getSession(widget.sessionId);
      }

      // Try Firebase first, fall back to local storage
      List<Map<String, dynamic>> hands;
      try {
        hands = await FirebaseService.getSessionHands(widget.sessionId);
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
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PokerFriendColors.dark3,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Session Title
          Row(
            children: [
              Image.asset('icons/session.png', width: 24, height: 24),
              SizedBox(width: 12),
              Text(
                widget.sessionData['sessionName'] ?? 'Poker Session',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Key Metrics Row
          Row(
            children: [
              Expanded(
                child: _buildMetricCardWithAsset(
                  'Total Invested',
                  _formatTotalInvested(_totalInvested),
                  'icons/wallet_original.png',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildMetricCardWithAsset(
                  'Final Stack',
                  _formatCurrency(_finalStack),
                  'icons/ante.png',
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

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
                  textColor: _profitLoss >= 0 ? PokerFriendColors.green : PokerFriendColors.red,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildMetricCardWithAsset(
                  'Duration',
                  _formatDuration(),
                  'icons/clock.png',
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Session Details
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PokerFriendColors.dark4,
              borderRadius: BorderRadius.circular(8),
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
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PokerFriendColors.dark1,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(assetPath, width: 20, height: 20),
              SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: PokerFriendColors.dark10,
                  fontSize: 12,
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
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PokerFriendColors.dark1,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: PokerFriendColors.dark10,
                  fontSize: 12,
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
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: PokerFriendColors.dark9,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
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
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PokerFriendColors.dark3,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('icons/stats.png', width: 24, height: 24),
              SizedBox(width: 12),
              Text(
                'Stack Growth',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

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
                          color: PokerFriendColors.dark9,
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
                        color: PokerFriendColors.dark6,
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
                              axisSide: meta.axisSide,
                              space: 8.0,
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: PokerFriendColors.dark9,
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
                    border: Border.all(color: PokerFriendColors.dark6),
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
                          ? [PokerFriendColors.green.withOpacity(0.3), PokerFriendColors.green]
                          : [PokerFriendColors.red.withOpacity(0.3), PokerFriendColors.red],
                      ),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: _profitLoss >= 0 ? PokerFriendColors.green : PokerFriendColors.red,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: _profitLoss >= 0
                            ? [PokerFriendColors.green.withOpacity(0.1), Colors.transparent]
                            : [PokerFriendColors.red.withOpacity(0.1), Colors.transparent],
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
            color: PokerFriendColors.dark6,
            size: 48,
          ),
          SizedBox(height: 12),
          Text(
            'No Stack History Available',
            style: TextStyle(
              color: PokerFriendColors.dark9,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Stack changes will be tracked in future sessions',
            style: TextStyle(
              color: PokerFriendColors.dark8,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoggedHandsButton() {
    return Container(
      margin: EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [PokerFriendColors.blue, PokerFriendColors.blue.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ElevatedButton(
          onPressed: _navigateToLoggedHands,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFFcb5242),
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.style_outlined, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Text(
                'View Logged Hands',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
            ],
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
      backgroundColor: PokerFriendColors.dark1,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Session Analytics',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
        ? Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(PokerFriendColors.red),
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

                // Logged Hands Button
                _buildLoggedHandsButton(),

                SizedBox(height: 32),
              ],
            ),
          ),
    );
  }
}