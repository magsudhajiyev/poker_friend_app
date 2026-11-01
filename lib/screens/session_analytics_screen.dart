import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui' as ui;
import '../models/game_types.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import '../services/dealer_service.dart';
import 'session_hands_screen.dart';
import 'hand_actions_page_view.dart';
import 'stack_chart_screen.dart';
import '../services/flag_resolution_loader.dart';
import '../services/stack_timeline.dart';
import '../widgets/stack_growth_chart.dart';
import '../services/session_export_service.dart';
import '../services/subscription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_data_cache.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'paywall_screen.dart';
import '../l10n/app_localizations.dart';
import '../services/currency_service.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';
import '../design_system/components/buttons/back_button_circle.dart';
import '../design_system/components/buttons/secondary_pill_button.dart';
import '../design_system/components/dialogs/app_dialog.dart';
import '../design_system/components/dialogs/dialog_action_bar.dart';
import '../design_system/components/modals/confirm_dialog.dart';
import '../utils/user_facing_error.dart';
import '../onboarding/onboarding_state.dart';
import '../onboarding/onboarding_tour.dart';


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
  Map<String, FlagResolution> _resolutions = const {};

  bool _isExporting = false;
  bool _isDeleting = false;

  // Phase-6 onboarding: spotlights for the stack chart + "View Logged Hands"
  final GlobalKey _loggedHandsButtonKey = GlobalKey();
  final GlobalKey _stackChartKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadSessionAnalytics();
    _scheduleOnboardingTour();
  }

  /// Phase 6 — spotlight "View Logged Hands" after the session-card handoff.
  void _scheduleOnboardingTour() async {
    if (!OnboardingState.isOnboardingActive ||
        OnboardingState.currentPhase != 6 ||
        !OnboardingState.handListTourPending) return;
    OnboardingState.handListTourPending = false;

    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      if (!_isLoading && _loggedHandsButtonKey.currentContext != null) break;
    }
    if (!mounted) return;
    if (_loggedHandsButtonKey.currentContext == null) {
      finishOnboardingTour(context);
      return;
    }

    HandListTour(
      loggedHandsButtonKey: _loggedHandsButtonKey,
      stackChartKey: _stackChartKey,
    ).show(context);
  }

  Future<void> _handleDeleteSession() async {
    if (_isDeleting) return;

    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmDialog.confirm(
      context,
      title: l10n.sessionAnalyticsDeleteTitle,
      message: l10n.sessionAnalyticsDeleteMessage,
      confirmLabel: l10n.commonDelete,
    );

    if (!confirmed || !mounted) return;

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
              style: AppTypography.ibm(color: Colors.white),
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
              style: AppTypography.ibm(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }

  static const int _maxMonthlySessionExportsPro = 30;
  static const String _sessionExportCountKey = 'monthly_session_export_count';
  static const String _sessionExportMonthKey = 'monthly_session_export_month';

  static String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}';
  }

  Future<void> _handleSessionExport() async {
    if (_isExporting || _hands.isEmpty) return;

    // Gate free users at paywall
    if (!SubscriptionService.isPremium) {
      final purchased =
          await PaywallScreen.show(context, featureName: 'Session Export');
      if (purchased != true || !mounted) return;
      if (!SubscriptionService.isPremium) return;
    }

    // Elite/Club: unlimited — skip quota
    if (!SubscriptionService.isElite) {
      // Pro: monthly quota
      final prefs = await SharedPreferences.getInstance();
      final storedMonth = prefs.getString(_sessionExportMonthKey) ?? '';
      final currentMonth = _currentMonthKey();

      if (storedMonth != currentMonth) {
        await prefs.setString(_sessionExportMonthKey, currentMonth);
        await prefs.setInt(_sessionExportCountKey, 0);
      }

      final int usedCount = prefs.getInt(_sessionExportCountKey) ?? 0;

      if (usedCount >= _maxMonthlySessionExportsPro) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        AppDialog.show<void>(
          context,
          title: l10n.quotaExportLimitTitle,
          body: Text(
            l10n.quotaSessionExportLimitPro(_maxMonthlySessionExportsPro),
            style: AppTypography.ibm(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          actions: DialogActionBar(
            cancelLabel: l10n.quotaOk,
            confirmLabel: l10n.quotaUpgradeToElite,
            confirmColor: AppColors.accentPrimary,
            confirmTextColor: AppColors.textInverse,
            onConfirm: () =>
                PaywallScreen.show(context, featureName: 'Unlimited Exports'),
          ),
        );
        return;
      }

      // Increment counter after successful export (done after confirm)
      await prefs.setInt(_sessionExportCountKey, usedCount + 1);
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
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmDialog.confirm(
      context,
      title: l10n.sessionAnalyticsExportSession,
      message: l10n.sessionAnalyticsExportConfirm(_hands.length, email),
      confirmLabel: l10n.sessionAnalyticsExport,
      confirmColor: AppColors.accentPrimary,
      confirmTextColor: AppColors.textInverse,
    );

    if (!confirmed || !mounted) return;

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
            content: Text(AppLocalizations.of(context).sessionAnalyticsExportFailed(UserFacingError.message(e))),
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

      final stackHistory = List<Map<String, dynamic>>.from(sessionDetails?['stackHistory'] ?? []);
      var rebuys = List<Map<String, dynamic>>.from(sessionDetails?['rebuys'] ?? []);
      if (rebuys.isEmpty) {
        // Full hand-logging sessions don't persist a 'rebuys' array, but every
        // rebuy is recorded in stackHistory — derive them (same as DealerService)
        rebuys = stackHistory
            .where((entry) => entry['changeType'] == 'rebuy')
            .map((entry) => {
                  'amount': entry['changeAmount'],
                  'stackSize': entry['stackSize'],
                  'timestamp': entry['timestamp'],
                })
            .toList();
      }

      setState(() {
        _stackHistory = stackHistory;
        _rebuys = rebuys;
        _hands = hands;
        _calculateSessionAnalytics();
        _isLoading = false;
      });
      _loadResolutions();
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

  double? _getTournamentCashout() {
    // prizeWon == 0 is a valid recorded cashout (busted out of the money).
    // Only null (never recorded) means we can't show it — chips ≠ money.
    final prize = widget.sessionData['prizeWon']?.toDouble();
    return prize;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      extendBody: true,
      body: Stack(
        children: [
          Column(
              children: [
                // Header — matches TopNavBar geometry (statusBar + 56 + 12).
                // Wrapped in a Hero paired with the source card in
                // SessionHistoryScreen so tapping a session grows the
                // card into this header instead of a plain push.
                Hero(
                  tag: 'sessionCard_${widget.sessionId}',
                  flightShuttleBuilder:
                      (context, animation, direction, from, to) => Material(
                    color: Colors.transparent,
                    child: to.widget,
                  ),
                  child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top,
                    bottom: 12,
                  ),
                  child: SizedBox(
                    height: 56,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: BackButtonCircle(
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.sessionAnalyticsTitle,
                              style: AppTypography.ibm(
                                fontSize: 17,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                height: 22 / 17,
                                letterSpacing: -0.43,
                              ),
                            ),
                            Text(
                              l10n.sessionAnalyticsHandsLogged(widget.sessionData['handsLogged'] ?? widget.sessionData['totalHands'] ?? _hands.length),
                              style: AppTypography.ibm(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w400,
                                height: 18 / 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _isExporting || _hands.isEmpty ? null : _handleSessionExport,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: AppColors.bgSurface,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: _isExporting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          AppColors.accentPrimary),
                                    ),
                                  )
                                : Icon(Icons.ios_share,
                                    color: _hands.isEmpty
                                        ? Colors.white.withValues(alpha: 0.25)
                                        : Colors.white,
                                    size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _isDeleting ? null : _handleDeleteSession,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: AppColors.bgSurface,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: _isDeleting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          AppColors.accentDanger),
                                    ),
                                  )
                                : SvgPicture.asset(
                                    'icons/figma_icons/delete.svg',
                                    width: 20,
                                    height: 20,
                                    colorFilter: const ColorFilter.mode(
                                        AppColors.accentDanger, BlendMode.srcIn),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                    ),
                  ),
                ),
                ),
                // Content
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentPrimary),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              _buildSessionOverview(),
                              // Section divider — replaces the card
                              // boundary the two blocks used to have.
                              const SizedBox(height: 28),
                              Container(
                                height: 1,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                              const SizedBox(height: 24),
                              _buildStackChart(),
                              const SizedBox(height: 32),
                              _buildLoggedHandsButton(),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSessionOverview() {
    final l10n = AppLocalizations.of(context);
    final tournamentCashout = _isCashGame() ? null : _getTournamentCashout();
    final pl = _isCashGame()
        ? _profitLoss
        : tournamentCashout != null
            ? tournamentCashout - _totalInvested
            : null;
    final plColor = pl != null
        ? (pl >= 0 ? AppColors.accentPrimary : const Color(0xFFFF6B6B))
        : Colors.white;
    final plText = pl != null
        ? '${pl >= 0 ? '+' : ''}${CurrencyService.formatCash(pl)}'
        : l10n.sessionAnalyticsNotAvailableFull;

    // Flat layout — no card fill/border. Session name doubles as the
    // section header; the horizontal padding comes from the outer
    // SingleChildScrollView so content sits flush with the trash/share
    // buttons in the top nav.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Session name
          Text(
            widget.sessionData['sessionName'] ?? l10n.sessionAnalyticsPokerSession,
            style: AppTypography.ibm(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          // Hero Profit / Loss — eyebrow label above the number, both
          // tinted the same accent colour (green for profit, red for
          // loss) so the state reads at a glance. The label uses the
          // actual word ("Profit" or "Loss") rather than the generic
          // "Profit/Loss" split.
          if (pl != null)
            Text(
              pl >= 0
                  ? l10n.sessionAnalyticsProfit
                  : l10n.sessionAnalyticsLoss,
              style: AppTypography.ibm(
                color: plColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            )
          else
            Text(
              l10n.sessionAnalyticsProfitLoss,
              style: AppTypography.ibm(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            plText,
            style: AppTypography.grotesk(
              color: plColor,
              fontSize: 34,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 24),
          // 2x2 label rows — bare, no inner cards
          Row(
            children: [
              Expanded(child: _buildMetricTile(
                l10n.sessionAnalyticsTotalInvested,
                _formatTotalInvested(_totalInvested),
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildMetricTile(
                l10n.sessionAnalyticsCashout,
                _isCashGame()
                    ? _formatCurrency(_finalStack)
                    : tournamentCashout != null
                        ? CurrencyService.formatCash(tournamentCashout)
                        : l10n.sessionAnalyticsNotAvailableFull,
              )),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _isCashGame()
                  ? _buildMetricTile(l10n.sessionAnalyticsHourlyRate, _formatHourlyRate())
                  : _buildMetricTile(l10n.sessionAnalyticsFinished, _formatFinished())),
              const SizedBox(width: 16),
              Expanded(child: _buildMetricTile(
                _isCashGame() ? l10n.sessionAnalyticsAddons : l10n.sessionAnalyticsRebuys,
                '${_rebuys.length}',
                valueColor: _rebuys.isNotEmpty ? AppColors.accentPrimary : null,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String title, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.ibm(
            color: Colors.white.withOpacity(0.5),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.ibm(
            color: valueColor ?? Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStackChart() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      key: _stackChartKey,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.sessionAnalyticsStackChart,
                  style: AppTypography.ibm(
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
          resolutions: _resolutions,
          onPendingTapped: _finishFlags,
        ),
      ),
    );
  }

  Widget _buildLineChart() {
    return StackGrowthChart(
      stackHistory: _stackHistory,
      startingStack: _stackHistory.first['stackSize']?.toDouble() ?? 0.0,
      formatValue: _formatCurrency,
      height: 250,
      selectedIndex: _touchedSpotIndex,
      resolutions: _resolutions,
      handLookup: handLookupFromMaps(_hands),
      onPendingTapped: _finishFlags,
      onDotTapped: (i) => setState(() => _touchedSpotIndex = i),
      onHandOpen: _openHand,
    );
  }

  Future<void> _loadResolutions() async {
    if (FlagResolutionLoader.pendingIds(_stackHistory).isEmpty) return;
    final r = await FlagResolutionLoader.load(widget.sessionId, _stackHistory);
    if (mounted) setState(() => _resolutions = r);
  }

  Future<void> _finishFlags(List<String> flagIds) async {
    final done =
        await FlagResolutionLoader.finish(context, widget.sessionId, flagIds);
    if (done && mounted) await _loadResolutions();
  }

  void _openHand(int handNumber) {
    final hand = _findHandByNumber(handNumber);
    if (hand == null) return;
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

  Map<String, dynamic>? _findHandByNumber(int handNumber) {
    for (final hand in _hands) {
      if (hand['handNumber'] == handNumber) return hand;
    }
    return null;
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
            style: AppTypography.ibm(
              color: Colors.white.withOpacity(0.4),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.sessionAnalyticsStackTrackedFuture,
            style: AppTypography.ibm(
              color: Colors.white.withOpacity(0.25),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoggedHandsButton() {
    return KeyedSubtree(
      key: _loggedHandsButtonKey,
      child: SecondaryPillButton(
        label: AppLocalizations.of(context).sessionAnalyticsViewLoggedHands,
        onTap: _navigateToLoggedHands,
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
