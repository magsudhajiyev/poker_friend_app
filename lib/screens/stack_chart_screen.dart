import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../l10n/app_localizations.dart';
import '../services/currency_service.dart';
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
  late double _viewStart;
  static const int _visiblePoints = 30;

  @override
  void initState() {
    super.initState();
    _setLandscapeMode();
    _viewStart = _computeDefaultViewStart();
  }

  double _computeDefaultViewStart() {
    final total = widget.stackHistory.length;
    if (total <= _visiblePoints) return -0.5;
    return total - _visiblePoints - 0.5;
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

  String _formatAmount(double amount) {
    if (_isCashGame()) {
      return CurrencyService.formatCash(amount);
    } else {
      return CurrencyService.formatChips(amount);
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
        return AppLocalizations.of(context).commonNA;
      }
    }
    return AppLocalizations.of(context).commonNA;
  }

  String _formatAvgGrowth() {
    if (widget.stackHistory.length < 2) return AppLocalizations.of(context).commonNA;

    final initialEntry = widget.stackHistory.firstWhere(
      (e) => e['changeType'] == 'initial',
      orElse: () => widget.stackHistory.first,
    );
    final startStack = initialEntry['stackSize']?.toDouble() ?? 0.0;
    if (startStack <= 0) return AppLocalizations.of(context).commonNA;

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
    if (handCount == 0) return AppLocalizations.of(context).commonNA;
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
    final sessionName = widget.sessionData['sessionName'] ?? AppLocalizations.of(context).stackChartScreenPokerSession;

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
                  AppLocalizations.of(context).stackChartScreenTitle,
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
          _buildInfoPill(AppLocalizations.of(context).stackChartScreenAvgGrowth, avgGrowth, lineColor),
          const SizedBox(width: 10),
          _buildInfoPill(AppLocalizations.of(context).stackChartScreenDuration, duration, Colors.white),
          const SizedBox(width: 10),
          _buildInfoPill(
            _isCashGame() ? AppLocalizations.of(context).stackChartScreenProfitLoss : AppLocalizations.of(context).stackChartScreenStack,
            _isCashGame()
                ? '${widget.profitLoss >= 0 ? '+' : ''}${_formatAmount(widget.profitLoss)}'
                : _formatAmount(widget.stackHistory.isNotEmpty
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

    // Compute Y bounds based on visible window for dynamic scaling
    final viewStartIdx = _viewStart.floor().clamp(0, spots.length - 1);
    final viewEndIdx = (_viewStart + (_visiblePoints - 1) + 1).ceil().clamp(0, spots.length - 1);
    final visibleSpots = spots.sublist(viewStartIdx, viewEndIdx + 1);
    final rawMinY = visibleSpots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    final rawMaxY = visibleSpots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final yPadding = rawMaxY > rawMinY ? (rawMaxY - rawMinY) * 0.15 : rawMaxY * 0.1;
    final minY = rawMinY - yPadding;
    final maxY = rawMaxY + yPadding;
    final yRange = maxY > minY ? maxY - minY : 100.0;
    final yInterval = yRange / 4;

    // Viewport
    final viewWindow = (_visiblePoints - 1).toDouble() + 1.0;
    final viewMinX = _viewStart;
    final viewMaxX = _viewStart + viewWindow;

    // Scroll bounds
    final totalMaxX = (spots.length - 1).toDouble() + 0.5;
    const scrollMin = -0.5;
    final scrollMax = (totalMaxX - viewWindow).clamp(scrollMin, double.infinity);

    return GestureDetector(
      onHorizontalDragUpdate: spots.length > _visiblePoints
          ? (details) {
              final chartWidth = context.size?.width ?? 300;
              final unitsPerPixel = viewWindow / chartWidth;
              final delta = -details.delta.dx * unitsPerPixel;
              setState(() {
                _viewStart = (_viewStart + delta).clamp(scrollMin, scrollMax);
                // Dismiss tooltip on scroll
                if (_touchedSpotIndex != null) {
                  _touchedSpotIndex = null;
                }
              });
            }
          : null,
      child: LineChart(
      LineChartData(
        clipData: const FlClipData.all(),
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
                  _formatAmount(value),
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
                    label = AppLocalizations.of(context).stackChartScreenStart;
                    break;
                  case 'rebuy':
                    label = AppLocalizations.of(context).stackChartScreenRebuy;
                    break;
                  case 'final':
                    label = AppLocalizations.of(context).stackChartScreenEnd;
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
        minX: viewMinX,
        maxX: viewMaxX,
        minY: minY,
        maxY: maxY,
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: false,
          touchSpotThreshold: 40,
          touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
            if (event is FlTapUpEvent) {
              final hasTappedSpot = response != null &&
                  response.lineBarSpots != null &&
                  response.lineBarSpots!.isNotEmpty;
              final tappedIndex = hasTappedSpot
                  ? response.lineBarSpots!.first.x.toInt()
                  : null;

              if (_touchedSpotIndex != null) {
                if (tappedIndex == _touchedSpotIndex) {
                  // Tapped same dot again — navigate to hand details
                  final idx = _touchedSpotIndex!;
                  setState(() => _touchedSpotIndex = null);
                  _navigateToHandFromChart(idx);
                } else if (tappedIndex != null) {
                  // Tapped a different dot — switch tooltip
                  setState(() => _touchedSpotIndex = tappedIndex);
                } else {
                  // Tapped empty area — dismiss tooltip
                  setState(() => _touchedSpotIndex = null);
                }
                return;
              }
              if (tappedIndex != null) {
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
                final stackValue = _formatAmount(spot.y);

                if (index >= 0 && index < widget.stackHistory.length) {
                  final entry = widget.stackHistory[index];
                  final handNumber = entry['handNumber'] as int?;
                  final changeType = entry['changeType'] ?? '';
                  final note = entry['note'] as String?;

                  String detail = stackValue;

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
            curveSmoothness: 0.3,
            preventCurveOverShooting: true,
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
    ),
    );
  }
}
