import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_result_service.dart';
import '../design_system/constants/colors.dart';

/// Full-screen landscape earnings chart with zoom/pan
/// Shows all-time cumulative earnings for tournament and cash games
class EarningsChartScreen extends StatefulWidget {
  const EarningsChartScreen({super.key});

  @override
  State<EarningsChartScreen> createState() => _EarningsChartScreenState();
}

class _EarningsChartScreenState extends State<EarningsChartScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _chartData = [];
  double _tournamentTotal = 0.0;
  double _cashTotal = 0.0;
  DateTime? _firstSessionDate;

  // Min/max values for fixed axes
  double _minValue = 0;
  double _maxValue = 100;

  final TransformationController _transformationController =
      TransformationController();
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _setLandscapeMode();
    _loadAllTimeEarningsData();
  }

  @override
  void dispose() {
    _restorePortraitMode();
    _transformationController.dispose();
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

  Future<void> _loadAllTimeEarningsData() async {
    try {
      final sessionResults = await SessionResultService.getAllSessionResults();

      if (sessionResults.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Group by date and calculate daily totals
      Map<DateTime, Map<String, double>> dailyData = {};

      for (var result in sessionResults) {
        DateTime? date;
        if (result['timestamp'] != null) {
          date = (result['timestamp'] as Timestamp).toDate();
        } else if (result['createdAt'] != null) {
          date = DateTime.tryParse(result['createdAt']);
        }

        if (date == null) continue;

        // Normalize to date only (remove time component)
        final dateKey = DateTime(date.year, date.month, date.day);
        final gameType = result['gameType'] as String? ?? 'cash';
        final amount = (result['amount'] as num?)?.toDouble() ?? 0.0;

        dailyData.putIfAbsent(dateKey, () => {'tournament': 0.0, 'cash': 0.0});
        dailyData[dateKey]![gameType] =
            (dailyData[dateKey]![gameType] ?? 0.0) + amount;
      }

      // Sort by date
      final sortedDates = dailyData.keys.toList()..sort();

      if (sortedDates.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Calculate cumulative totals
      double cumulativeTournament = 0.0;
      double cumulativeCash = 0.0;
      double maxVal = 0.0;
      double minVal = 0.0;

      List<Map<String, dynamic>> chartData = sortedDates.map((date) {
        cumulativeTournament += dailyData[date]!['tournament']!;
        cumulativeCash += dailyData[date]!['cash']!;

        maxVal = math.max(maxVal, math.max(cumulativeTournament, cumulativeCash));
        minVal = math.min(minVal, math.min(cumulativeTournament, cumulativeCash));

        return {
          'date': date,
          'dateLabel': DateFormat('MMM d').format(date),
          'tournament': cumulativeTournament,
          'cash': cumulativeCash,
        };
      }).toList();

      // Calculate nice min/max for axes
      double finalMin = minVal;
      double finalMax = maxVal;

      if (chartData.length == 1) {
        // Single data point - ensure we show both $0 line and the value
        final maxCumulative = math.max(cumulativeTournament, cumulativeCash);
        final minCumulative = math.min(cumulativeTournament, cumulativeCash);

        if (minCumulative < 0) {
          // Have negative values - show negative side
          finalMin = minCumulative * 1.2;
          finalMax = math.max(0, maxCumulative) * 1.2;
          if (finalMax <= 0) finalMax = math.max(100, finalMin.abs() * 0.2);
        } else {
          // All positive
          finalMin = 0;
          finalMax = maxCumulative * 1.2;
          if (finalMax <= 0) finalMax = 100;
        }
      } else {
        // Add padding
        final range = finalMax - finalMin;
        final padding = range > 0 ? range * 0.1 : 100;
        finalMax += padding;
        finalMin -= padding;

        // Always show $0 line
        if (finalMin > 0) finalMin = 0;
        if (finalMax < 0) finalMax = 0;
      }

      // Round to nice values
      finalMax = _roundToNice(finalMax, true);
      finalMin = _roundToNice(finalMin, false);

      setState(() {
        _chartData = chartData;
        _tournamentTotal = cumulativeTournament;
        _cashTotal = cumulativeCash;
        _firstSessionDate = sortedDates.first;
        _minValue = finalMin;
        _maxValue = finalMax;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading earnings data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  double _roundToNice(double value, bool roundUp) {
    if (value == 0) return 0;

    final isNegative = value < 0;
    final absValue = value.abs();

    // For small values
    if (absValue < 10) {
      if (isNegative) {
        // For negative: roundUp means toward 0, roundDown means away from 0
        return roundUp ? 0 : -10;
      }
      return roundUp ? 10 : 0;
    }

    final magnitude = math.pow(10, (math.log(absValue) / math.ln10).floor()).toDouble();
    final normalized = absValue / magnitude;

    double niceValue;
    // For negative values with roundUp=false, we want to round AWAY from zero (more negative)
    // So we invert the rounding logic for negative values when roundUp=false
    final shouldRoundAwayFromZero = isNegative ? !roundUp : roundUp;

    if (shouldRoundAwayFromZero) {
      // Round up (away from zero for positive, away from zero for negative when !roundUp)
      if (normalized <= 1) {
        niceValue = 1;
      } else if (normalized <= 2) {
        niceValue = 2;
      } else if (normalized <= 5) {
        niceValue = 5;
      } else {
        niceValue = 10;
      }
    } else {
      // Round down (toward zero)
      if (normalized < 1) {
        niceValue = 0;
      } else if (normalized < 2) {
        niceValue = 1;
      } else if (normalized < 5) {
        niceValue = 2;
      } else {
        niceValue = 5;
      }
    }

    final result = niceValue * magnitude;
    return isNegative ? -result : result;
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
    setState(() => _currentScale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              AppColors.headerGradientTeal,
              const Color(0xFF161618),
              const Color(0xFF161618),
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.tealAccent),
                )
              : _chartData.isEmpty
                  ? _buildEmptyState()
                  : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Header
        _buildHeader(),
        // Chart area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Chart with zoom/pan
                Expanded(
                  child: _buildChart(),
                ),
                const SizedBox(width: 8),
                // Fixed Y-axis
                _buildYAxis(),
              ],
            ),
          ),
        ),
        // Fixed X-axis
        _buildXAxis(),
        // Zoom indicator
        _buildZoomIndicator(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.show_chart,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No earnings data yet',
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Complete some sessions to see your earnings chart',
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'All-Time Earnings',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_firstSessionDate != null)
                  Text(
                    'Since ${DateFormat('MMM d, yyyy').format(_firstSessionDate!)}',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          // Legend
          _buildLegendItem('Tournament', AppColors.tournamentBlue),
          const SizedBox(width: 16),
          _buildLegendItem('Cash', AppColors.cashGameGreen),
          const SizedBox(width: 24),
          // Total
          _buildTotalBadge(_tournamentTotal + _cashTotal),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.7),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildTotalBadge(double amount) {
    final isNegative = amount < 0;
    final color = isNegative ? const Color(0xFFFF6B6B) : const Color(0xFF5AC95A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '${isNegative ? "-" : ""}\$${amount.abs().toStringAsFixed(0)}',
        style: GoogleFonts.ibmPlexSans(
          fontSize: 16,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildChart() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = math.max(constraints.maxWidth, _chartData.length * 60.0);
        final chartHeight = constraints.maxHeight;

        return ClipRect(
          child: InteractiveViewer(
            transformationController: _transformationController,
            onInteractionUpdate: (details) {
              setState(() {
                _currentScale = _transformationController.value.getMaxScaleOnAxis();
              });
            },
            minScale: 1.0,
            maxScale: 5.0,
            constrained: false,
            boundaryMargin: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: chartWidth,
              height: chartHeight,
              child: CustomPaint(
                painter: EarningsChartPainter(
                  data: _chartData,
                  tournamentColor: AppColors.tournamentBlue,
                  cashColor: AppColors.cashGameGreen,
                  minValue: _minValue,
                  maxValue: _maxValue,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildYAxis() {
    final valueRange = _maxValue - _minValue;
    const numLabels = 5;

    return SizedBox(
      width: 50,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(numLabels + 1, (i) {
          final value = _maxValue - (i * valueRange / numLabels);
          return Text(
            '\$${value.toInt()}',
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 10,
              fontWeight: FontWeight.w400,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildXAxis() {
    if (_chartData.isEmpty) return const SizedBox(height: 24);

    // Determine which labels to show
    List<String> labels;
    if (_chartData.length <= 5) {
      labels = _chartData.map((d) => d['dateLabel'] as String).toList();
    } else {
      // Show first, middle points, and last
      labels = [
        _chartData.first['dateLabel'] as String,
        _chartData[_chartData.length ~/ 2]['dateLabel'] as String,
        _chartData.last['dateLabel'] as String,
      ];
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: labels.map((label) {
                return Text(
                  label,
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 58), // Space for Y-axis
        ],
      ),
    );
  }

  Widget _buildZoomIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F23).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.zoom_in, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${(_currentScale * 100).toInt()}%',
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_currentScale > 1.01) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _resetZoom,
                    child: const Icon(
                      Icons.restart_alt,
                      color: AppColors.tealAccent,
                      size: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

/// Custom painter for earnings chart
class EarningsChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final Color tournamentColor;
  final Color cashColor;
  final double minValue;
  final double maxValue;

  EarningsChartPainter({
    required this.data,
    required this.tournamentColor,
    required this.cashColor,
    required this.minValue,
    required this.maxValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final chartArea = Rect.fromLTWH(0, 0, size.width, size.height);
    final valueRange = maxValue - minValue;
    if (valueRange == 0) return;

    final zeroY = chartArea.bottom - ((0 - minValue) / valueRange) * chartArea.height;

    // Draw horizontal grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const numGridLines = 5;
    for (int i = 0; i <= numGridLines; i++) {
      final y = chartArea.top + (i / numGridLines) * chartArea.height;
      canvas.drawLine(
        Offset(chartArea.left, y),
        Offset(chartArea.right, y),
        gridPaint,
      );
    }

    // Draw zero line (more prominent)
    if (zeroY >= chartArea.top && zeroY <= chartArea.bottom) {
      final zeroPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(chartArea.left, zeroY),
        Offset(chartArea.right, zeroY),
        zeroPaint,
      );
    }

    // Calculate point spacing
    final pointSpacing = data.length > 1
        ? chartArea.width / (data.length - 1)
        : chartArea.width;

    // Calculate tournament points
    final tournamentPoints = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final value = (data[i]['tournament'] as num?)?.toDouble() ?? 0.0;
      final x = data.length == 1
          ? chartArea.right - 20
          : chartArea.left + (i * pointSpacing);
      final y = chartArea.bottom - ((value - minValue) / valueRange) * chartArea.height;
      tournamentPoints.add(Offset(x, y.clamp(chartArea.top, chartArea.bottom)));
    }

    // Calculate cash points
    final cashPoints = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final value = (data[i]['cash'] as num?)?.toDouble() ?? 0.0;
      final x = data.length == 1
          ? chartArea.right - 20
          : chartArea.left + (i * pointSpacing);
      final y = chartArea.bottom - ((value - minValue) / valueRange) * chartArea.height;
      cashPoints.add(Offset(x, y.clamp(chartArea.top, chartArea.bottom)));
    }

    // Draw tournament line
    final tournamentPaint = Paint()
      ..color = tournamentColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (data.length == 1) {
      // Single point - draw line from $0 to value
      final zeroYClamped = zeroY.clamp(chartArea.top, chartArea.bottom);
      final path = Path();
      path.moveTo(chartArea.left, zeroYClamped);
      path.lineTo(tournamentPoints.first.dx, tournamentPoints.first.dy);
      canvas.drawPath(path, tournamentPaint);

      // Draw dot
      final dotPaint = Paint()
        ..color = tournamentColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(tournamentPoints.first, 5, dotPaint);
    } else {
      final path = Path();
      path.moveTo(tournamentPoints.first.dx, tournamentPoints.first.dy);
      for (int i = 1; i < tournamentPoints.length; i++) {
        path.lineTo(tournamentPoints[i].dx, tournamentPoints[i].dy);
      }
      canvas.drawPath(path, tournamentPaint);
    }

    // Draw cash line
    final cashPaint = Paint()
      ..color = cashColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (data.length == 1) {
      // Single point - draw line from $0 to value
      final zeroYClamped = zeroY.clamp(chartArea.top, chartArea.bottom);
      final path = Path();
      path.moveTo(chartArea.left, zeroYClamped);
      path.lineTo(cashPoints.first.dx, cashPoints.first.dy);
      canvas.drawPath(path, cashPaint);

      // Draw dot
      final dotPaint = Paint()
        ..color = cashColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(cashPoints.first, 5, dotPaint);
    } else {
      final path = Path();
      path.moveTo(cashPoints.first.dx, cashPoints.first.dy);
      for (int i = 1; i < cashPoints.length; i++) {
        path.lineTo(cashPoints[i].dx, cashPoints[i].dy);
      }
      canvas.drawPath(path, cashPaint);
    }
  }

  @override
  bool shouldRepaint(covariant EarningsChartPainter oldDelegate) {
    return data != oldDelegate.data ||
        minValue != oldDelegate.minValue ||
        maxValue != oldDelegate.maxValue;
  }
}
