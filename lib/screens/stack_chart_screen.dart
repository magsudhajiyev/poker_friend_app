import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/game_types.dart';
import 'hand_actions_screen.dart';

/// Full-screen landscape stack chart with tap-to-view hand details
class StackChartScreen extends StatefulWidget {
  final List<Map<String, dynamic>> stackHistory;
  final List<Map<String, dynamic>> hands;
  final Map<String, dynamic> sessionData;
  final double profitLoss;

  const StackChartScreen({
    super.key,
    required this.stackHistory,
    required this.hands,
    required this.sessionData,
    required this.profitLoss,
  });

  @override
  State<StackChartScreen> createState() => _StackChartScreenState();
}

class _StackChartScreenState extends State<StackChartScreen> {
  int? _touchedSpotIndex;

  @override
  void initState() {
    super.initState();
    _setLandscapeMode();
  }

  @override
  void dispose() {
    _restorePortraitMode();
    super.dispose();
  }

  void _setLandscapeMode() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _restorePortraitMode() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
      } catch (_) {
        return 'N/A';
      }
    }
    return 'N/A';
  }

  String _formatAvgGrowth() {
    if (widget.stackHistory.length < 2) return 'N/A';

    final initialEntry = widget.stackHistory.firstWhere(
      (e) => e['changeType'] == 'initial',
      orElse: () => widget.stackHistory.first,
    );
    final startStack = initialEntry['stackSize']?.toDouble() ?? 0.0;
    if (startStack <= 0) return 'N/A';

    // Count actual hand entries (exclude initial, rebuy, final)
    int handCount = 0;
    double totalGrowth = 0.0;
    for (int i = 1; i < widget.stackHistory.length; i++) {
      final current = widget.stackHistory[i]['stackSize']?.toDouble() ?? 0.0;
      final previous = widget.stackHistory[i - 1]['stackSize']?.toDouble() ?? 0.0;
      if (previous > 0) {
        totalGrowth += ((current - previous) / previous) * 100;
        handCount++;
      }
    }
    if (handCount == 0) return 'N/A';
    final avg = totalGrowth / handCount;
    return '${avg >= 0 ? '+' : ''}${avg.toStringAsFixed(2)}%';
  }

  Map<String, dynamic>? _findHandByNumber(int handNumber) {
    for (final hand in widget.hands) {
      if (hand['handNumber'] == handNumber) return hand;
    }
    return null;
  }

  void _navigateToHandFromChart(int spotIndex) {
    if (spotIndex < 0 || spotIndex >= widget.stackHistory.length) return;
    final entry = widget.stackHistory[spotIndex];
    final handNumber = entry['handNumber'] as int?;
    final changeType = entry['changeType'] ?? '';
    if (changeType == 'initial' || changeType == 'rebuy' || changeType == 'final') return;
    if (handNumber == null || handNumber <= 0) return;

    final hand = _findHandByNumber(handNumber);
    if (hand == null) return;

    setState(() => _touchedSpotIndex = null);
    // Restore portrait for hand details screen
    _restorePortraitMode();
    final ourSeat = widget.sessionData['ourSeatNumber'] as int?;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HandActionsScreen(hand: hand, ourSeat: ourSeat),
      ),
    ).then((_) {
      // Re-apply landscape when returning from hand details
      _setLandscapeMode();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lineColor = widget.profitLoss >= 0
        ? const Color(0xFF89F1EC)
        : const Color(0xFFFF6B6B);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              const Color(0xFF1A4A4A),
              const Color(0xFF161618),
              const Color(0xFF161618),
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(lineColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: _buildChart(lineColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color lineColor) {
    final avgGrowth = _formatAvgGrowth();
    final duration = _formatDuration();
    final sessionName = widget.sessionData['sessionName'] ?? 'Poker Session';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFF101115),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Stack Growth',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 17,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  sessionName,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Info pills
          _buildInfoPill('Avg Growth', avgGrowth, lineColor),
          const SizedBox(width: 10),
          _buildInfoPill('Duration', duration, Colors.white),
          const SizedBox(width: 10),
          _buildInfoPill(
            _isCashGame() ? 'P/L' : 'Stack',
            _isCashGame()
                ? '${widget.profitLoss >= 0 ? '+' : ''}${_formatCurrency(widget.profitLoss)}'
                : _formatCurrency(widget.stackHistory.isNotEmpty
                    ? widget.stackHistory.last['stackSize']?.toDouble() ?? 0.0
                    : 0.0),
            lineColor,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPill(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label  ',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.5),
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              color: valueColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(Color lineColor) {
    List<FlSpot> spots = [];
    for (int i = 0; i < widget.stackHistory.length; i++) {
      final entry = widget.stackHistory[i];
      final stackSize = entry['stackSize']?.toDouble() ?? 0.0;
      spots.add(FlSpot(i.toDouble(), stackSize));
    }

    if (spots.isEmpty) return const SizedBox.shrink();

    final minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b) * 0.9;
    final maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.1;
    final yInterval = maxY > minY ? (maxY - minY) / 4 : 100.0;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.white.withValues(alpha: 0.06),
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
              reservedSize: 60,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Text(
                  _formatCurrency(value),
                  style: GoogleFonts.robotoMono(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value != value.roundToDouble()) return const SizedBox.shrink();
                final idx = value.toInt();
                if (idx < 0 || idx >= widget.stackHistory.length) return const SizedBox.shrink();
                final entry = widget.stackHistory[idx];
                final changeType = entry['changeType'] ?? 'unknown';
                String label;
                switch (changeType) {
                  case 'initial':
                    label = 'Start';
                    break;
                  case 'rebuy':
                    label = 'Rebuy';
                    break;
                  case 'final':
                    label = 'End';
                    break;
                  default:
                    label = '#${entry['handNumber'] ?? idx}';
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 6.0,
                  child: Text(
                    label,
                    style: GoogleFonts.ibmPlexSans(
                      color: Colors.white.withValues(alpha: 0.3),
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
              if (_touchedSpotIndex != null) {
                // Tooltip is showing — any tap navigates to that hand
                final idx = _touchedSpotIndex!;
                setState(() => _touchedSpotIndex = null);
                _navigateToHandFromChart(idx);
                return;
              }
              if (response != null &&
                  response.lineBarSpots != null &&
                  response.lineBarSpots!.isNotEmpty) {
                final tappedIndex = response.lineBarSpots!.first.x.toInt();
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

                if (index >= 0 && index < widget.stackHistory.length) {
                  final entry = widget.stackHistory[index];
                  final handNumber = entry['handNumber'] as int?;
                  final changeType = entry['changeType'] ?? '';

                  if (changeType != 'initial' &&
                      changeType != 'rebuy' &&
                      changeType != 'final' &&
                      handNumber != null &&
                      handNumber > 0) {
                    final hand = _findHandByNumber(handNumber);
                    final position = hand?['heroPositionName'] as String?;
                    final holeCards = hand?['ourHoleCards'] as Map<String, dynamic>?;
                    final card1 = holeCards?['card1'] as String?;
                    final card2 = holeCards?['card2'] as String?;
                    final hasCards = card1 != null &&
                        card1.isNotEmpty &&
                        card2 != null &&
                        card2.isNotEmpty;

                    String detail = stackValue;
                    if (position != null && position.isNotEmpty) {
                      detail += '  ·  $position';
                    }
                    if (hasCards) {
                      detail += '\n$card1 $card2';
                    }
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
            ? [
                ShowingTooltipIndicators([
                  LineBarSpot(
                    LineChartBarData(spots: spots),
                    0,
                    spots[_touchedSpotIndex!],
                  ),
                ])
              ]
            : [],
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(
              colors: [lineColor.withValues(alpha: 0.3), lineColor],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 4,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: lineColor,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [lineColor.withValues(alpha: 0.15), Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
