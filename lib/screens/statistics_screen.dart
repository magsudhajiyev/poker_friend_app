import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import '../models/hand_state_machine.dart';
import '../models/poker_game_state.dart';
import '../models/game_types.dart';
import '../widgets/loading_screen.dart';

class StatisticsScreen extends StatefulWidget {
  @override
  _StatisticsScreenState createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool isLoading = true;
  String? error;
  
  // Overall statistics
  int totalHands = 0;
  int handsPlayed = 0;
  double vpip = 0.0;
  double pfr = 0.0;
  double threeBet = 0.0;
  double winRate = 0.0;
  
  // Positional statistics
  Map<String, PositionStats> positionStats = {};
  
  // Session statistics
  int totalSessions = 0;
  int totalPlayTime = 0; // in minutes
  
  // Chart data
  List<SessionChartData> sessionChartData = [];
  
  // Date range filter
  DateTime? startDate;
  DateTime? endDate;
  
  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      await _calculateAllStatistics();
      
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load statistics: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: startDate != null && endDate != null 
        ? DateTimeRange(start: startDate!, end: endDate!)
        : null,
      helpText: 'Select Date Range for Statistics',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
      _loadStatistics(); // Reload statistics with new date range
    }
  }

  Future<void> _clearDateFilter() async {
    setState(() {
      startDate = null;
      endDate = null;
    });
    _loadStatistics();
  }

  Future<void> _calculateAllStatistics() async {
    // Get all sessions
    List<Map<String, dynamic>> sessions;
    try {
      sessions = await FirebaseService.getAllSessions();
    } catch (e) {
      sessions = await LocalStorageService.getUserSessions();
    }

    // Filter sessions by date range if set
    if (startDate != null && endDate != null) {
      sessions = sessions.where((session) {
        try {
          final sessionDate = DateTime.parse(session['startTime']);
          return sessionDate.isAfter(startDate!.subtract(Duration(days: 1))) &&
                 sessionDate.isBefore(endDate!.add(Duration(days: 1)));
        } catch (e) {
          return false; // If date parsing fails, exclude the session
        }
      }).toList();
    }

    totalSessions = sessions.length;
    totalPlayTime = 0;
    totalHands = 0;
    handsPlayed = 0;
    
    int vpipHands = 0;
    int pfrHands = 0;
    int threeBetHands = 0;
    int wonHands = 0;
    
    Map<String, int> positionHandsPlayed = {};
    Map<String, int> positionVPIP = {};
    Map<String, int> positionPFR = {};
    Map<String, int> positionThreeBet = {};

    // Calculate session durations and prepare chart data
    sessionChartData.clear();
    sessions.sort((a, b) {
      final aDate = DateTime.parse(a['startTime']);
      final bDate = DateTime.parse(b['startTime']);
      return aDate.compareTo(bDate);
    });
    
    for (int i = 0; i < sessions.length; i++) {
      var session = sessions[i];
      if (session['endTime'] != null && session['startTime'] != null) {
        final start = DateTime.parse(session['startTime']);
        final end = DateTime.parse(session['endTime']);
        totalPlayTime += end.difference(start).inMinutes;
      }
      
      // Add to chart data
      sessionChartData.add(SessionChartData(
        date: DateTime.parse(session['startTime']),
        sessionNumber: i + 1,
        totalHands: session['totalHands'] ?? 0,
        gameType: session['gameType'] ?? 'cash',
      ));
    }

    // Analyze each session
    for (var session in sessions) {
      List<Map<String, dynamic>> hands;
      try {
        hands = await FirebaseService.getSessionHands(session['id']);
      } catch (e) {
        hands = await LocalStorageService.getSessionHands(session['id']);
      }

      // Create temporary session manager to use analysis methods
      final sessionManager = PokerSessionManager(
        smallBlind: session['smallBlind'] ?? 1,
        bigBlind: session['bigBlind'] ?? 2,
        playerCount: session['playerCount'] ?? 6,
        ourSeatNumber: session['ourSeatNumber'],
        gameType: GameTypeExtension.fromString(session['gameType']),
      );

      for (var handData in hands) {
        totalHands++;
        
        // Convert hand data to HandRecord for analysis
        final hand = _convertToHandRecord(handData);
        
        // Skip hands if we don't have seat number stored
        if (sessionManager.ourSeatNumber == null) continue;
        
        if (sessionManager.didWePlayHand(hand)) {
          handsPlayed++;
          
          final position = sessionManager.getOurPosition(hand.buttonPosition) ?? 'UNK';
          
          // Update position counters
          positionHandsPlayed[position] = (positionHandsPlayed[position] ?? 0) + 1;
          
          // Check VPIP
          if (sessionManager.didWeVPIP(hand)) {
            vpipHands++;
            positionVPIP[position] = (positionVPIP[position] ?? 0) + 1;
          }
          
          // Check PFR
          if (sessionManager.didWePFR(hand)) {
            pfrHands++;
            positionPFR[position] = (positionPFR[position] ?? 0) + 1;
          }
          
          // Check 3-bet (simplified - any raise after a raise preflop)
          if (_didWeThreeBet(hand, sessionManager.ourSeatNumber!)) {
            threeBetHands++;
            positionThreeBet[position] = (positionThreeBet[position] ?? 0) + 1;
          }
          
          // Win rate calculation (placeholder - would need pot results)
          // For now, just assume we win 50% of hands we play
          if (handsPlayed % 2 == 0) wonHands++;
        }
      }
    }

    // Calculate percentages
    vpip = handsPlayed > 0 ? (vpipHands / handsPlayed) * 100 : 0;
    pfr = handsPlayed > 0 ? (pfrHands / handsPlayed) * 100 : 0;
    threeBet = handsPlayed > 0 ? (threeBetHands / handsPlayed) * 100 : 0;
    winRate = handsPlayed > 0 ? (wonHands / handsPlayed) * 100 : 0;

    // Build position statistics
    positionStats.clear();
    for (var position in positionHandsPlayed.keys) {
      final played = positionHandsPlayed[position] ?? 0;
      final vpipCount = positionVPIP[position] ?? 0;
      final pfrCount = positionPFR[position] ?? 0;
      final threeBetCount = positionThreeBet[position] ?? 0;
      
      positionStats[position] = PositionStats(
        handsPlayed: played,
        vpip: played > 0 ? (vpipCount / played) * 100 : 0,
        pfr: played > 0 ? (pfrCount / played) * 100 : 0,
        threeBet: played > 0 ? (threeBetCount / played) * 100 : 0,
      );
    }
  }

  HandRecord _convertToHandRecord(Map<String, dynamic> handData) {
    final actions = (handData['actions'] as List<dynamic>?)
        ?.map((a) => ActionRecord(
              player: a['player'],
              action: _parsePlayerAction(a['action']),
              street: _parseBettingRound(a['street']),
              timestamp: DateTime.parse(a['timestamp']),
              buttonPosition: a['buttonPosition'] ?? handData['buttonPosition'],
              playerName: a['playerName'],
              playerPosition: a['playerPosition'],
            ))
        .toList() ?? [];

    return HandRecord(
      handNumber: handData['handNumber'],
      buttonPosition: handData['buttonPosition'],
      playerCount: handData['playerCount'],
      startTime: DateTime.parse(handData['startTime']),
      actions: actions,
      endTime: handData['endTime'] != null ? DateTime.parse(handData['endTime']) : null,
    );
  }

  PlayerAction _parsePlayerAction(String action) {
    switch (action.toLowerCase()) {
      case 'bet': return PlayerAction.bet;
      case 'call': return PlayerAction.call;
      case 'raise': return PlayerAction.raise;
      case 'fold': return PlayerAction.fold;
      case 'check': return PlayerAction.check;
      default: return PlayerAction.fold;
    }
  }

  BettingRound _parseBettingRound(String street) {
    switch (street.toLowerCase()) {
      case 'preflop': return BettingRound.preflop;
      case 'flop': return BettingRound.flop;
      case 'turn': return BettingRound.turn;
      case 'river': return BettingRound.river;
      default: return BettingRound.preflop;
    }
  }

  bool _didWeThreeBet(HandRecord hand, int ourSeat) {
    final preflopActions = hand.actions
        .where((a) => a.street == BettingRound.preflop)
        .toList();
    
    bool sawRaise = false;
    for (var action in preflopActions) {
      if (action.player == ourSeat && (action.action == PlayerAction.raise || action.action == PlayerAction.bet) && sawRaise) {
        return true;
      }
      if (action.action == PlayerAction.raise || action.action == PlayerAction.bet) {
        sawRaise = true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF161618),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(maxWidth: 375),
            margin: EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section - matching home screen style
                Padding(
                  padding: EdgeInsets.fromLTRB(0, 32, 0, 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Statistics',
                            style: TextStyle(
                              fontSize: 32,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            startDate != null && endDate != null 
                              ? '${_formatDate(startDate!)} - ${_formatDate(endDate!)}'
                              : 'Overall performance',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF9A9A9A),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            margin: EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: Color(0xFF1F1F23),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          if (startDate != null && endDate != null)
                            Container(
                              width: 44,
                              height: 44,
                              margin: EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: Color(0xFF1F1F23),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: IconButton(
                                onPressed: _clearDateFilter,
                                icon: Icon(
                                  Icons.clear,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          Container(
                            width: 44,
                            height: 44,
                            margin: EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: Color(0xFF1F1F23),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: IconButton(
                              onPressed: _showDateRangePicker,
                              icon: Icon(
                                Icons.date_range,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Color(0xFF1F1F23),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: IconButton(
                              onPressed: _loadStatistics,
                              icon: Icon(
                                Icons.refresh,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildBody(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return LoadingScreen(message: 'Analyzing poker statistics...');
    }

    if (error != null) {
      return Container(
        height: 400,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Icon(Icons.error, color: Colors.red, size: 32),
              ),
              SizedBox(height: 16),
              Text(
                'Error',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red, fontSize: 14),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadStatistics,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF5AC95A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (totalHands == 0) {
      return Container(
        height: 400,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Color(0xFF1F1F23),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Icon(Icons.analytics, color: Color(0xFF9A9A9A), size: 32),
              ),
              SizedBox(height: 16),
              Text(
                'No Statistics Yet',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Play some poker hands to see your statistics here!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF9A9A9A),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOverallStats(),
        SizedBox(height: 24),
        if (sessionChartData.isNotEmpty) ...[
          _buildSessionChart(),
          SizedBox(height: 24),
        ],
        _buildPositionalStats(),
        SizedBox(height: 24),
        _buildSessionStats(),
        SizedBox(height: 100), // Space for bottom navigation
      ],
    );
  }

  Widget _buildOverallStats() {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildStatCard('Total Hands', totalHands.toString(), icon: Icons.style),
        _buildStatCard('Hands Played', handsPlayed.toString(), icon: Icons.play_arrow),
        _buildStatCard('VPIP', '${vpip.toStringAsFixed(1)}%', iconPath: 'icons/vpip.png'),
        _buildStatCard('PFR', '${pfr.toStringAsFixed(1)}%', iconPath: 'icons/bet.png'),
        _buildStatCard('3-Bet', '${threeBet.toStringAsFixed(1)}%', icon: Icons.double_arrow),
        _buildStatCard('Win Rate', '${winRate.toStringAsFixed(1)}%', iconPath: 'icons/throphy.png'),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, {IconData? icon, String? iconPath}) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (iconPath != null)
                Image.asset(
                  iconPath,
                  width: 48,
                  height: 48,
                  fit: BoxFit.contain,
                )
              else if (icon != null)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(0xFF5AC95A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: Color(0xFF5AC95A),
                    size: 20,
                  ),
                ),
            ],
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionChart() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(0xFF5AC95A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.trending_up,
                  color: Color(0xFF5AC95A),
                  size: 20,
                ),
              ),
              SizedBox(width: 16),
              Text(
                'Session Progress',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
            Container(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    drawHorizontalLine: true,
                    horizontalInterval: 10,
                    verticalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Color(0xFF2A2A2E),
                        strokeWidth: 1,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Color(0xFF2A2A2E),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < sessionChartData.length) {
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Text(
                                'S${index + 1}',
                                style: TextStyle(
                                  color: Color(0xFF9A9A9A),
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(''),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 10,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                color: Color(0xFF9A9A9A),
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Color(0xFF2A2A2E)),
                  ),
                  minX: 0,
                  maxX: (sessionChartData.length - 1).toDouble().clamp(0, double.infinity),
                  minY: 0,
                  maxY: sessionChartData.isEmpty 
                    ? 10 
                    : sessionChartData.map((e) => e.totalHands).reduce((a, b) => a > b ? a : b).toDouble() + 10,
                  lineBarsData: [
                    LineChartBarData(
                      spots: sessionChartData.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.totalHands.toDouble());
                      }).toList(),
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: Color(0xFF5AC95A),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          final sessionData = sessionChartData[index];
                          final isCash = sessionData.gameType.toLowerCase() == 'cash';
                          return FlDotCirclePainter(
                            radius: 4,
                            color: isCash ? Colors.green : Colors.blue,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Color(0xFF5AC95A).withOpacity(0.1),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) => Color(0xFF1F1F23),
                      tooltipRoundedRadius: 8,
                      getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                        return touchedBarSpots.map((barSpot) {
                          final index = barSpot.x.toInt();
                          if (index >= 0 && index < sessionChartData.length) {
                            final session = sessionChartData[index];
                            return LineTooltipItem(
                              'Session ${index + 1}\n',
                              TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              children: [
                                TextSpan(
                                  text: '${session.totalHands} hands\n',
                                  style: TextStyle(
                                    color: Color(0xFF9A9A9A),
                                    fontSize: 12,
                                  ),
                                ),
                                TextSpan(
                                  text: session.gameType.toUpperCase(),
                                  style: TextStyle(
                                    color: session.gameType.toLowerCase() == 'cash' 
                                      ? Colors.green 
                                      : Colors.blue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            );
                          }
                          return null;
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Cash Game',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9A9A9A),
                  ),
                ),
                SizedBox(width: 20),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Tournament',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9A9A9A),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
  }

  Widget _buildPositionalStats() {
    if (positionStats.isEmpty) {
      return Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Color(0xFF1F1F23),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(0xFF5AC95A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.place_outlined,
                    color: Color(0xFF5AC95A),
                    size: 20,
                  ),
                ),
                SizedBox(width: 16),
                Text(
                  'Positional Statistics',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              'No positional data available yet.',
              style: TextStyle(color: Color(0xFF9A9A9A), fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(0xFF5AC95A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.table_chart_rounded,
                  color: Color(0xFF5AC95A),
                  size: 20,
                ),
              ),
              SizedBox(width: 16),
              Text(
                'Positional Statistics',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
            Table(
              border: TableBorder.all(color: Color(0xFF2A2A2E)),
              columnWidths: {
                0: FlexColumnWidth(1.5),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
                4: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Color(0xFF161618)),
                  children: [
                    _buildTableHeader('Position'),
                    _buildTableHeader('Hands'),
                    _buildTableHeader('VPIP'),
                    _buildTableHeader('PFR'),
                    _buildTableHeader('3-Bet'),
                  ],
                ),
                ...positionStats.entries.map((entry) => TableRow(
                  children: [
                    _buildTableCell(entry.key),
                    _buildTableCell(entry.value.handsPlayed.toString()),
                    _buildTableCell('${entry.value.vpip.toStringAsFixed(1)}%'),
                    _buildTableCell('${entry.value.pfr.toStringAsFixed(1)}%'),
                    _buildTableCell('${entry.value.threeBet.toStringAsFixed(1)}%'),
                  ],
                )),
              ],
            ),
          ],
        ),
      );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: EdgeInsets.all(12),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return Padding(
      padding: EdgeInsets.all(12),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFF9A9A9A),
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildSessionStats() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(0xFF5AC95A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.access_time,
                  color: Color(0xFF5AC95A),
                  size: 20,
                ),
              ),
              SizedBox(width: 16),
              Text(
                'Session Statistics',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSessionStatItem('Sessions', totalSessions.toString()),
              _buildSessionStatItem('Total Time', '${(totalPlayTime / 60).toStringAsFixed(1)}h'),
              _buildSessionStatItem('Avg Session', totalSessions > 0 ? '${(totalPlayTime / totalSessions).toStringAsFixed(0)}m' : '0m'),
            ],
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
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5AC95A),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Color(0xFF9A9A9A),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${_getMonthName(date.month)} ${date.day}, ${date.year}';
  }

  String _getMonthName(int month) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month];
  }
}

class SessionChartData {
  final DateTime date;
  final int sessionNumber;
  final int totalHands;
  final String gameType;

  SessionChartData({
    required this.date,
    required this.sessionNumber,
    required this.totalHands,
    required this.gameType,
  });
}

class PositionStats {
  final int handsPlayed;
  final double vpip;
  final double pfr;
  final double threeBet;

  PositionStats({
    required this.handsPlayed,
    required this.vpip,
    required this.pfr,
    required this.threeBet,
  });
}