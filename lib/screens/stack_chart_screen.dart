import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../services/currency_service.dart';
import '../models/game_types.dart';
import '../services/stack_timeline.dart';
import '../widgets/stack_growth_chart.dart';
import 'hand_actions_page_view.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';
import '../design_system/components/buttons/back_button_circle.dart';

/// Full-screen landscape stack chart with tap-to-view hand details
class StackChartScreen extends StatefulWidget {
  final List<Map<String, dynamic>> stackHistory;
  final List<Map<String, dynamic>> hands;
  final Map<String, dynamic> sessionData;
  final double profitLoss;

  /// Flag results by flag id (easy hand logging); empty for older sessions.
  final Map<String, FlagResolution> resolutions;

  /// Opens the finish screen for these open flags, when available.
  final ValueChanged<List<String>>? onPendingTapped;

  const StackChartScreen({
    super.key,
    required this.stackHistory,
    required this.hands,
    required this.sessionData,
    required this.profitLoss,
    this.resolutions = const {},
    this.onPendingTapped,
  });

  @override
  State<StackChartScreen> createState() => _StackChartScreenState();
}

class _StackChartScreenState extends State<StackChartScreen> {
  int? _touchedSpotIndex;
  static const int _visiblePoints = 30;

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
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
    final history = widget.stackHistory
        .where((e) => e['changeType'] != 'fold_run' && e['changeType'] != 'pending')
        .toList();
    if (history.length < 2) return AppLocalizations.of(context).commonNA;

    final initialEntry = history.firstWhere(
      (e) => e['changeType'] == 'initial',
      orElse: () => history.first,
    );
    final startStack = initialEntry['stackSize']?.toDouble() ?? 0.0;
    if (startStack <= 0) return AppLocalizations.of(context).commonNA;

    // Count actual hand entries (exclude initial, rebuy, final)
    int handCount = 0;
    double totalGrowth = 0.0;
    for (int i = 1; i < history.length; i++) {
      final current = history[i]['stackSize']?.toDouble() ?? 0.0;
      final previous = history[i - 1]['stackSize']?.toDouble() ?? 0.0;
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

  void _openHand(int handNumber) {
    final hand = _findHandByNumber(handNumber);
    if (hand == null) return;

    setState(() => _touchedSpotIndex = null);
    // Restore portrait for hand details screen
    _restorePortraitMode();
    final ourSeat = widget.sessionData['ourSeatNumber'] as int?;
    final index = widget.hands.indexOf(hand);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HandActionsPageView(
          hands: widget.hands,
          initialIndex: index < 0 ? 0 : index,
          ourSeat: ourSeat,
        ),
      ),
    ).then((_) {
      // Re-apply landscape when returning from hand details
      _setLandscapeMode();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lineColor = widget.profitLoss >= 0
        ? AppColors.accentPrimary
        : const Color(0xFFFF6B6B);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
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
          BackButtonCircle(onPressed: () => Navigator.pop(context)),
          const SizedBox(width: 12),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context).stackChartScreenTitle,
                  style: AppTypography.ibm(
                    fontSize: 17,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  sessionName,
                  style: AppTypography.ibm(
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
        borderRadius: BorderRadius.circular(AppDecorations.radius20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label  ',
            style: AppTypography.ibm(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.5),
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: AppTypography.ibm(
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
    return StackGrowthChart(
      stackHistory: widget.stackHistory,
      startingStack: _startingStack(),
      formatValue: _formatAmount,
      height: double.infinity,
      visiblePoints: _visiblePoints,
      selectedIndex: _touchedSpotIndex,
      resolutions: widget.resolutions,
      handLookup: handLookupFromMaps(widget.hands),
      onPendingTapped: widget.onPendingTapped,
      onDotTapped: (i) => setState(() => _touchedSpotIndex = i),
      onHandOpen: _openHand,
    );
  }

  double _startingStack() {
    for (final e in widget.stackHistory) {
      if (e['changeType'] == 'initial') {
        return (e['stackSize'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return 0.0;
  }
}
