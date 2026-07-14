import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import '../services/subscription_service.dart';
import '../services/free_tier_limits.dart';
import '../utils/poker_positions.dart';
import '../widgets/loading_screen.dart';
import '../design_system/components/scale_tap_feedback.dart';
import '../design_system/components/skeleton.dart';
import '../design_system/components/cards/error_state_card.dart';
import '../design_system/components/cards/swipe_to_delete_cell.dart';
import '../design_system/components/headers/top_nav_bar.dart';
import '../design_system/components/modals/confirm_dialog.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../services/app_data_cache.dart';
import '../screens/paywall_screen.dart';
import 'session_analytics_screen.dart';
import '../services/currency_service.dart';
import '../services/logger_service.dart';
import '../design_system/constants/decorations.dart';
import '../utils/lazy_pagination.dart';
import '../utils/user_facing_error.dart';
import '../onboarding/onboarding_state.dart';
import '../onboarding/onboarding_tour.dart';

class SessionHistoryScreen extends StatefulWidget {
  final String? targetSessionId;
  
  const SessionHistoryScreen({Key? key, this.targetSessionId}) : super(key: key);
  
  @override
  _SessionHistoryScreenState createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> sessions = [];
  bool isLoading = true;
  String? error;
  // One scroll controller per tab (gameType label) — two ListViews can't
  // share one. Created lazily in _buildSessionsList.
  final Map<String, ScrollController> _scrollControllers = {};
  // U8: how many cards are currently rendered per tab (lazy window).
  final Map<String, int> _visibleCounts = {};
  late TabController _tabController;

  // Phase-6 onboarding: spotlight for the tutorial session card
  final GlobalKey _tourSessionCardKey = GlobalKey();
  String? _tourHighlightSessionId;

  ScrollController _controllerFor(String gameType) =>
      _scrollControllers.putIfAbsent(gameType, () => ScrollController());

  List<Map<String, dynamic>> get cashSessions => _filterSessionsForTier(
      sessions.where((session) => session['gameType'] == 'cash').toList());

  List<Map<String, dynamic>> get tournamentSessions => _filterSessionsForTier(
      sessions.where((session) => session['gameType'] == 'tournament').toList());

  /// Filter sessions based on user's subscription tier.
  /// Elite/Club: all time. Pro: 90 days. Free: 30 days.
  List<Map<String, dynamic>> _filterSessionsForTier(List<Map<String, dynamic>> sessionList) {
    final cutoff = FreeTierLimits.sessionHistoryCutoff();
    if (cutoff == null) return sessionList;

    return sessionList.where((session) {
      try {
        return DateTime.parse(session['startTime']).isAfter(cutoff);
      } catch (_) {
        return true;
      }
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    LoggerService.logScreenView('session_history');
    _tabController = TabController(length: 2, vsync: this);
    _loadSessions();
    _scheduleOnboardingTour();
  }

  /// Phase 6 — spotlight the tutorial session card after the tour's
  /// Sessions-nav handoff, then let the user tap it for real.
  void _scheduleOnboardingTour() async {
    if (!OnboardingState.isOnboardingActive ||
        OnboardingState.currentPhase != 6 ||
        !OnboardingState.sessionHistoryTourPending) return;
    OnboardingState.sessionHistoryTourPending = false;

    // Wait for the session list to load
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      if (!isLoading) break;
    }
    if (!mounted) return;

    // Find the tutorial session (exact id → newest tutorial → newest)
    Map<String, dynamic> target = sessions.firstWhere(
      (s) => s['id'] == OnboardingState.tourSessionId,
      orElse: () => sessions.firstWhere(
        (s) => s['isTutorial'] == true,
        orElse: () => sessions.isNotEmpty ? sessions.first : const {},
      ),
    );
    if (target.isEmpty) {
      finishOnboardingTour(context);
      return;
    }

    setState(() => _tourHighlightSessionId = target['id'] as String?);
    // Switches to the right tab, expands the lazy window and scrolls the
    // card into view so the GlobalKey attaches
    _scrollToSession(target['id'] as String);

    // Wait for the card key to attach
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      if (_tourSessionCardKey.currentContext != null) break;
    }
    if (!mounted) return;
    if (_tourSessionCardKey.currentContext == null) {
      finishOnboardingTour(context);
      return;
    }

    // The tab-switch + itemHeight-based scroll are still in flight when the key
    // attaches, so measuring the card now yields a stale RenderBox (the
    // spotlight lands partially off the card — worse for tournaments, which add
    // a tab animation). Re-align precisely and let it settle before spotlighting.
    await Scrollable.ensureVisible(
      _tourSessionCardKey.currentContext!,
      alignment: 0.5,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    SessionHistoryTour(sessionCardKey: _tourSessionCardKey).show(context);
  }

  @override
  void dispose() {
    for (final c in _scrollControllers.values) {
      c.dispose();
    }
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    try {
      // Serve from cache if data hasn't changed
      if (!AppDataCache.isSessionsDirty && AppDataCache.cachedSessions != null) {
        setState(() {
          sessions = AppDataCache.cachedSessions!;
          isLoading = false;
        });
        if (widget.targetSessionId != null) {
          _scrollToSession(widget.targetSessionId!);
        }
        return;
      }

      setState(() {
        isLoading = true;
        error = null;
      });

      List<Map<String, dynamic>> loadedSessions;
      try {
        // Try Firebase first
        loadedSessions = await FirebaseService.getAllSessions();
      } catch (e) {
        // Fallback to local storage
        loadedSessions = await LocalStorageService.getUserSessions();
      }

      // Store in cache
      AppDataCache.cachedSessions = loadedSessions;
      AppDataCache.clearSessionsDirty();

      setState(() {
        sessions = loadedSessions;
        isLoading = false;
      });

      // Auto-scroll to the target session if specified
      if (widget.targetSessionId != null) {
        _scrollToSession(widget.targetSessionId!);
      }
    } catch (e) {
      setState(() {
        error = AppLocalizations.of(context).sessionHistoryFailedLoad(UserFacingError.message(e));
        isLoading = false;
      });
    }
  }

  void _scrollToSession(String sessionId) {
    final l10n = AppLocalizations.of(context);
    // Find the target within its own tab's filtered list.
    final target = sessions.firstWhere(
      (s) => s['id'] == sessionId,
      orElse: () => const {},
    );
    if (target.isEmpty) return;
    final isTournament =
        (target['gameType'] ?? 'cash').toString().toLowerCase() == 'tournament';
    final gameType =
        isTournament ? l10n.sessionHistoryTournament : l10n.sessionHistoryCash;
    final list = isTournament ? tournamentSessions : cashSessions;
    final targetIndex = list.indexWhere((s) => s['id'] == sessionId);
    if (targetIndex == -1) return;

    // Switch to the right tab and expand its lazy window so the target card
    // is actually built before we scroll to it (U8).
    _tabController.animateTo(isTournament ? 1 : 0);
    setState(() {
      final needed = targetIndex + LazyPagination.pageSize;
      final current = _visibleCounts[gameType] ?? LazyPagination.pageSize;
      if (needed > current) {
        _visibleCounts[gameType] = needed > list.length ? list.length : needed;
      }
    });

    Future.delayed(const Duration(milliseconds: 350), () {
      const double itemHeight = 140.0;
      final controller = _controllerFor(gameType);
      if (controller.hasClients) {
        final offset = (targetIndex * itemHeight)
            .clamp(0.0, controller.position.maxScrollExtent);
        controller.animateTo(
          offset,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Widget _buildIcon(String path, double size, Color color) {
    if (path.endsWith('.svg')) {
      return SvgPicture.asset(
        path,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    } else {
      return Image.asset(
        path,
        width: size,
        height: size,
        color: color,
      );
    }
  }

  Widget _buildFreeTierStatusIndicator() {
    // Muted inline hint chip. Reads as info (not error), and the "Upgrade"
    // link on the right is the tap target for the paywall.
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () async {
          await PaywallScreen.show(
            context,
            featureName: l10n.sessionHistoryFullHistory,
          );
          if (mounted) setState(() {});
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/icons/Info.svg',
                width: 14,
                height: 14,
                colorFilter: const ColorFilter.mode(
                  AppColors.textSecondary,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                l10n.sessionLast30Days,
                style: AppTypography.ibm(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 3,
                height: 3,
                decoration: const BoxDecoration(
                  color: AppColors.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.sessionUpgradeForFullHistory,
                style: AppTypography.ibm(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Locked-history teaser rendered after the last visible session on a
  /// free tier. Shows a padlock + "Older sessions" + CTA to upgrade,
  /// leveraging visible FOMO instead of the top-of-screen warning.
  Widget _buildLockedHistoryTeaser() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: GestureDetector(
        onTap: () async {
          await PaywallScreen.show(
            context,
            featureName: l10n.sessionHistoryFullHistory,
          );
          if (mounted) setState(() {});
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: AppColors.borderStrong.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Older sessions',
                      style: AppTypography.ibm(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Upgrade to Pro to see your full history',
                      style: AppTypography.ibm(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SvgPicture.asset(
                'assets/icons/CaretRight.svg',
                width: 16,
                height: 16,
                colorFilter: const ColorFilter.mode(
                  AppColors.textSecondary,
                  BlendMode.srcIn,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      extendBody: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TopNavBar.landing(
            title: l10n.sessionHistoryTitle,
          ),
          const SizedBox(height: 16),
          if (!SubscriptionService.isPremium) ...[
            _buildFreeTierStatusIndicator(),
            const SizedBox(height: 16),
          ],
          // Tab switcher — white pill outer, dark active indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AnimatedBuilder(
              animation: _tabController.animation!,
              builder: (context, _) {
                final t = _tabController.animation!.value;
                return Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
                  ),
                  child: Row(
                    children: [
                      // Cash tab
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _tabController.animateTo(0),
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Color.lerp(AppColors.bgElevated, Colors.transparent, t),
                              borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
                            ),
                            child: Center(
                              child: Text(
                                l10n.sessionHistoryCash,
                                style: AppTypography.ibm(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.5,
                                  color: Color.lerp(AppColors.textPrimary, AppColors.textSecondary, t),
                                  height: 24 / 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Tournament tab
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _tabController.animateTo(1),
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Color.lerp(Colors.transparent, AppColors.bgElevated, t),
                              borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
                            ),
                            child: Center(
                              child: Text(
                                l10n.sessionHistoryTournament,
                                style: AppTypography.ibm(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.5,
                                  color: Color.lerp(AppColors.textSecondary, AppColors.textPrimary, t),
                                  height: 24 / 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSessionsList(cashSessions, l10n.sessionHistoryCash),
                _buildSessionsList(tournamentSessions, l10n.sessionHistoryTournament),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList(List<Map<String, dynamic>> sessionList, String gameType) {
    final l10n = AppLocalizations.of(context);
    if (isLoading) {
      return _buildSkeletonList();
    }

    if (error != null) {
      return ErrorStateCard(onRetry: _loadSessions);
    }

    if (sessionList.isEmpty) {
      final isCash = gameType == l10n.sessionHistoryCash;
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 52,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              isCash
                  ? _buildIcon('icons/figma_icons/dollar.svg', 32, AppColors.accentPrimary)
                  : SvgPicture.asset(
                      'assets/icons/Trophy_green.svg',
                      width: 32,
                      height: 32,
                    ),
            const SizedBox(height: 4),
            Text(
              l10n.sessionNoSessions(gameType),
              style: AppTypography.ibm(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                height: 20 / 17,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.sessionPlayToSee(gameType),
              textAlign: TextAlign.center,
              style: AppTypography.ibm(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 22 / 15,
              ),
            ),
          ],
        ),
        ),
      );
    }

    // U8 lazy render: build only a growing window of cards so a long history
    // doesn't construct hundreds at once. Keyed per tab (gameType) so cash
    // and tournament page independently.
    final total = sessionList.length;
    final visible = _visibleCounts[gameType] ?? LazyPagination.pageSize;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification &&
            LazyPagination.hasMore(total, visible)) {
          final metrics = notification.metrics;
          // Near the bottom → reveal the next page.
          if (metrics.pixels >=
              metrics.maxScrollExtent -
                  (LazyPagination.prefetchThreshold * 120)) {
            setState(() {
              _visibleCounts[gameType] =
                  LazyPagination.nextVisible(total, visible);
            });
          }
        }
        return false;
      },
      child: Builder(
        builder: (context) {
          final baseCount = LazyPagination.itemCount(total, visible);
          // Render a locked-history teaser after the very last session on
          // the free tier (only when there are no more pages to load).
          final showTeaser = !SubscriptionService.isPremium &&
              !LazyPagination.hasMore(total, visible) &&
              sessionList.isNotEmpty;
          final itemCount = baseCount + (showTeaser ? 1 : 0);
          return ListView.builder(
            controller: _controllerFor(gameType),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (showTeaser && index == itemCount - 1) {
                return _buildLockedHistoryTeaser();
              }
              if (LazyPagination.isLoaderIndex(index, total, visible)) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accentSecondary,
                      ),
                    ),
                  ),
                );
              }
              final session = sessionList[index];
              return SwipeToDeleteCell(
                key: ValueKey('history-${session['id']}'),
                onDelete: () => _confirmDeleteSession(session),
                child: _buildSessionCard(session),
              );
            },
          );
        },
      ),
    );
  }

  /// Confirms + deletes a session (invoked from a swipe-to-delete cell).
  /// Removes both Firebase and local mirrors, then refreshes the list.
  Future<void> _confirmDeleteSession(Map<String, dynamic> session) async {
    final l10n = AppLocalizations.of(context);
    final sessionId = session['id'] as String?;
    if (sessionId == null) return;

    ConfirmDialog.show(
      context,
      title: l10n.sessionAnalyticsDeleteTitle,
      message: l10n.sessionAnalyticsDeleteMessage,
      confirmLabel: l10n.commonDelete,
      onConfirm: () async {
        try {
          await FirebaseService.deleteSession(sessionId);
          await LocalStorageService.deleteSession(sessionId);
        } catch (_) {}
        if (!mounted) return;
        AppDataCache.markSessionsDirty();
        AppDataCache.markHomeDirty();
        await _loadSessions();
      },
    );
  }

  /// Placeholder rendered while sessions load. Sketches 6 session card
  /// rows with shimmering [Skeleton] bars so the layout doesn't shift when
  /// data arrives.
  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 6,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 160, height: 18),
                  const SizedBox(height: 8),
                  Row(children: [
                    Skeleton(width: 46, height: 14, borderRadius: BorderRadius.circular(999)),
                    const SizedBox(width: 6),
                    Skeleton(width: 78, height: 14, borderRadius: BorderRadius.circular(999)),
                  ]),
                ],
              ),
            ),
            Skeleton(width: 60, height: 20),
            const SizedBox(width: 12),
            Skeleton(width: 12, height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final l10n = AppLocalizations.of(context);
    final startTime = DateTime.parse(session['startTime']);
    final isTournament = (session['gameType'] ?? 'cash').toLowerCase() == 'tournament';

    final sessionName = session['sessionName'] != null && session['sessionName'].isNotEmpty
        ? session['sessionName']
        : l10n.sessionHistorySessionId(session['id'].substring(0, 8));

    // P/L calculation.
    // Tournament rule (see diary 2026-05-15): chips are NOT money — never
    // subtract a money buy-in from a chip stack. P/L is only known when
    // prizeWon was recorded (0 prize = busted = -totalBuyIn). Without it,
    // show no P/L rather than a nonsense chips-minus-money number.
    final totalBuyIn = (session['totalBuyIn'] ?? session['buyInAmount'] ?? 0).toDouble();
    final double? profitLoss;
    if (isTournament) {
      final prizeRaw = session['prizeWon'];
      profitLoss =
          prizeRaw != null ? (prizeRaw as num).toDouble() - totalBuyIn : null;
    } else {
      // Cash: stacks are money, so final stack - total buy-in is real P/L.
      // Old records without buy-in data can't produce a meaningful number.
      final stackRaw = session['currentStack'] ?? session['finalStack'];
      profitLoss = (totalBuyIn > 0 && stackRaw != null)
          ? (stackRaw as num).toDouble() - totalBuyIn
          : null;
    }

    // Duration
    String duration = '—';
    final endTimeRaw = session['endTime'];
    if (endTimeRaw != null) {
      try {
        final end = DateTime.parse(endTimeRaw);
        final diff = end.difference(startTime);
        final hours = diff.inHours;
        final minutes = diff.inMinutes % 60;
        duration = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
      } catch (_) {}
    }

    final dateText = DateFormat('MMM d, yyyy').format(startTime);

    final plColor = profitLoss == null
        ? AppColors.textDisabled
        : profitLoss > 0
            ? AppColors.accentSecondary
            : profitLoss < 0
                ? AppColors.accentDanger
                : AppColors.accentTertiary;
    final plText = profitLoss == null
        ? '—'
        : profitLoss > 0
            ? '+${CurrencyService.formatCash(profitLoss)}'
            : CurrencyService.formatCash(profitLoss);

    return ScaleTapFeedback(
      key: session['id'] == _tourHighlightSessionId
          ? _tourSessionCardKey
          : null,
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SessionAnalyticsScreen(
              sessionData: session,
              sessionId: session['id'],
            ),
          ),
        );
        if (mounted && AppDataCache.isSessionsDirty) {
          _loadSessions();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.borderDefault, width: 1),
          ),
        ),
        child: Row(
          children: [
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          sessionName,
                          style: AppTypography.ibm(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 22 / 17,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (session['isTutorial'] == true) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentSecondary
                                .withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(AppDecorations.radiusFull),
                          ),
                          child: Text(
                            l10n.sessionTutorialBadge,
                            style: AppTypography.ibm(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentSecondary,
                              height: 14 / 11,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      const SizedBox(width: 8),
                      Text(
                        plText,
                        style: AppTypography.ibm(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: plColor,
                          height: 22 / 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildChip('icons/figma_icons/clock.svg', duration),
                      const SizedBox(width: 6),
                      _buildChip('icons/figma_icons/calendar.svg', dateText),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SvgPicture.asset(
              'assets/icons/CaretRight.svg',
              width: 16,
              height: 16,
              colorFilter: const ColorFilter.mode(AppColors.contentInactive, BlendMode.srcIn),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String iconPath, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: AppTypography.ibm(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 16 / 11,
            ),
          ),
        ],
      ),
    );
  }

  void _showHandDetails(Map<String, dynamic> hand, {int? ourSeat}) {
    final l10n = AppLocalizations.of(context);
    final actions = List<Map<String, dynamic>>.from(hand['actions'] ?? []);
    final boardCards = hand['boardCards'] as Map<String, dynamic>?;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sessionHandDetails(hand['handNumber'] as int)),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.sessionHistoryButtonPosition(PokerPositions.getPositionName(hand['buttonPosition'], hand['buttonPosition'], hand['playerCount']))),
              Text(l10n.sessionHistoryPlayerCount(hand['playerCount'].toString())),
              Text(l10n.sessionHistoryStartTime(DateFormat('MMM dd, HH:mm:ss').format(DateTime.parse(hand['startTime'])))),
              
              // Hole Cards Section
              if (hand['ourHoleCards'] != null) ...[
                SizedBox(height: 16),
                Text(l10n.sessionYourCards, style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                _buildHoleCardsDisplay(hand['ourHoleCards']),
              ],

              // Board Cards Section
              if (boardCards != null) ...[
                SizedBox(height: 16),
                Text(l10n.sessionBoardCards, style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                _buildBoardCardsDisplay(boardCards),
              ],

              // Pot Tracking Section
              if (_hasAnyPotData(hand)) ...[
                SizedBox(height: 16),
                Text(l10n.sessionPotByStreet, style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                _buildPotTrackingDisplay(hand, boardCards),
              ],

              // Winner Section
              SizedBox(height: 16),
              _buildWinnerDisplay(hand),

              SizedBox(height: 16),
              Text(l10n.sessionActions, style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              if (actions.isEmpty)
                Text(l10n.sessionNoActionsRecorded)
              else
                ...actions.map((action) {
                  // Get the player name and position from the stored action record
                  final playerSeat = action['player'] as int;
                  final storedPlayerName = action['playerName'] as String?;
                  final storedPlayerPosition = action['playerPosition'] as String?;
                  
                  String displayName;
                  if (storedPlayerName != null && storedPlayerName.isNotEmpty) {
                    // Check if stored name is just a position name (like UTG, BB, etc.)
                    bool isPositionName = PokerPositions.isPositionName(storedPlayerName);
                    
                    if (isPositionName) {
                      // If it's just a position name, show seat number with current position
                      if (storedPlayerPosition != null && storedPlayerPosition.isNotEmpty) {
                        displayName = AppLocalizations.of(context).sessionHistorySeatWithPosition(playerSeat.toString(), storedPlayerPosition);
                      } else {
                        displayName = AppLocalizations.of(context).sessionHistorySeat(playerSeat.toString());
                      }
                    } else {
                      // Use custom player name with position: "Gringo (SB)"
                      if (storedPlayerPosition != null && storedPlayerPosition.isNotEmpty) {
                        displayName = '$storedPlayerName ($storedPlayerPosition)';
                      } else {
                        // Fallback to custom player name only
                        displayName = storedPlayerName;
                      }
                    }
                  } else {
                    // Fallback to seat number with position
                    if (storedPlayerPosition != null && storedPlayerPosition.isNotEmpty) {
                      displayName = AppLocalizations.of(context).sessionHistorySeatWithPosition(playerSeat.toString(), storedPlayerPosition);
                    } else {
                      displayName = AppLocalizations.of(context).sessionHistorySeat(playerSeat.toString());
                    }
                  }
                  
                  // Check if this is the hero's action
                  final isHero = ourSeat != null && playerSeat == ourSeat;

                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontFamily: 'monospace', color: Colors.white),
                        children: [
                          TextSpan(text: '${_getActionIcon(action['action'])} '),
                          TextSpan(
                            text: displayName,
                            style: TextStyle(
                              color: isHero ? AppColors.profitGreen : Colors.white,
                              fontWeight: isHero ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          TextSpan(text: ' ${_formatAction(action['action'])} (${_formatStreet(action['street'])})'),
                        ],
                      ),
                    ),
                  );
                }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }

  Widget _buildHoleCardsDisplay(Map<String, dynamic> holeCards) {
    final card1 = holeCards['card1'] as String?;
    final card2 = holeCards['card2'] as String?;
    
    return Row(
      children: [
        if (card1 != null) _buildCard(card1),
        if (card1 != null && card2 != null) SizedBox(width: 8),
        if (card2 != null) _buildCard(card2),
        if (card1 == null && card2 == null)
          Text(AppLocalizations.of(context).sessionNoCardsRecorded, style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
      ],
    );
  }

  Widget _buildBoardCardsDisplay(Map<String, dynamic> boardCards) {
    final flop = List<String>.from(boardCards['flop'] ?? []);
    final turn = boardCards['turn'] as String?;
    final river = boardCards['river'] as String?;
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (flop.isNotEmpty) ...[
          Text('${AppLocalizations.of(context).sessionHistoryFlop} ', style: TextStyle(fontSize: 12)),
          ...flop.map((card) => _buildCard(card)),
        ],
        if (turn != null) ...[
          SizedBox(width: 16),
          Text('${AppLocalizations.of(context).sessionHistoryTurn} ', style: TextStyle(fontSize: 12)),
          _buildCard(turn),
        ],
        if (river != null) ...[
          SizedBox(width: 16),
          Text('${AppLocalizations.of(context).sessionHistoryRiver} ', style: TextStyle(fontSize: 12)),
          _buildCard(river),
        ],
      ],
    );
  }
  
  Widget _buildCard(String card) {
    final color = _getCardColor(card);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
        color: Colors.white,
      ),
      child: Text(
        card,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
  
  Color _getCardColor(String card) {
    if (card.contains('♥') || card.contains('♦')) {
      return Colors.red;
    }
    return Colors.black;
  }

  String _getActionIcon(String action) {
    switch (action.toLowerCase()) {
      case 'bet': return '💰';
      case 'call': return '✅';
      case 'raise': return '📈';
      case 'fold': return '❌';
      default: return '•';
    }
  }

  String _formatAction(String action) {
    return action.toUpperCase();
  }

  String _formatStreet(String street) {
    switch (street.toLowerCase()) {
      case 'preflop': return AppLocalizations.of(context).sessionHistoryPreflop;
      case 'flop': return AppLocalizations.of(context).sessionHistoryFlop;
      case 'turn': return AppLocalizations.of(context).sessionHistoryTurn;
      case 'river': return AppLocalizations.of(context).sessionHistoryRiver;
      default: return street;
    }
  }

  Future<void> _syncLocalToFirebase() async {
    final l10n = AppLocalizations.of(context);
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant2,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 16),
            Text(l10n.sessionSyncingToCloud, style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    try {
      // Perform sync
      final result = await FirebaseService.syncLocalSessionsToFirebase();

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show result
      if (mounted) {
        final success = result['success'] == true;
        final message = result['message'] ?? l10n.sessionHistorySyncCompleted;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: Duration(seconds: 4),
          ),
        );

        // Reload sessions if successful
        if (success) {
          await _loadSessions();
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.sessionHistorySyncFailed(UserFacingError.message(e))),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showClearConfirmation() {
    final l10n = AppLocalizations.of(context);
    ConfirmDialog.show(
      context,
      title: l10n.sessionClearAllTitle,
      message: '${l10n.sessionClearAllDescription}\n\n${l10n.sessionClearAllWarning}',
      confirmLabel: l10n.sessionClearAll,
      onConfirm: _clearAllSessions,
    );
  }

  Future<void> _clearAllSessions() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // Clear from Firebase first
      try {
        await FirebaseService.clearUserSessions();
      } catch (e) {
        // Continue with local clearing even if Firebase fails
      }

      // Clear from local storage
      try {
        await LocalStorageService.clearUserSessions();
      } catch (e) {
        // Ignore error
      }

      // Refresh the sessions list
      await _loadSessions();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).sessionClearedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        error = AppLocalizations.of(context).sessionHistoryClearFailed(UserFacingError.message(e));
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).sessionHistoryClearFailed(UserFacingError.message(e))),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _hasAnyPotData(Map<String, dynamic> hand) {
    final preflopPot = (hand['preflopPot'] ?? 0).toDouble();
    final flopPot = (hand['flopPot'] ?? 0).toDouble();
    final turnPot = (hand['turnPot'] ?? 0).toDouble();
    final riverPot = (hand['riverPot'] ?? 0).toDouble();
    
    return preflopPot > 0 || flopPot > 0 || turnPot > 0 || riverPot > 0;
  }
  
  Widget _buildPotTrackingDisplay(Map<String, dynamic> hand, Map<String, dynamic>? boardCards) {
    final preflopPot = (hand['preflopPot'] ?? 0).toDouble();
    final flopPot = (hand['flopPot'] ?? 0).toDouble();
    final turnPot = (hand['turnPot'] ?? 0).toDouble();
    final riverPot = (hand['riverPot'] ?? 0).toDouble();
    final totalPot = (hand['potAmount'] ?? 0).toDouble();
    
    // Determine game type for currency formatting
    final gameTypeStr = hand['handGameType'] ?? hand['gameType'] ?? 'cash';
    final isCashGame = gameTypeStr == 'cash';
    
    String formatAmount(double amount) {
      if (amount <= 0) return '--';
      if (isCashGame) {
        return CurrencyService.formatCash(amount);
      } else {
        return '${amount.toInt()}';
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${AppLocalizations.of(context).sessionHistoryPreflop}', style: TextStyle(fontSize: 12)),
            Text(formatAmount(preflopPot), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        SizedBox(height: 4),
        if (boardCards?['flop'] != null && (boardCards!['flop'] as List).isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${AppLocalizations.of(context).sessionHistoryFlop}', style: TextStyle(fontSize: 12)),
              Text(formatAmount(flopPot), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          SizedBox(height: 4),
        ],
        if (boardCards?['turn'] != null && (boardCards!['turn'] as String).isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${AppLocalizations.of(context).sessionHistoryTurn}', style: TextStyle(fontSize: 12)),
              Text(formatAmount(turnPot), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          SizedBox(height: 4),
        ],
        if (boardCards?['river'] != null && (boardCards!['river'] as String).isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${AppLocalizations.of(context).sessionHistoryRiver}', style: TextStyle(fontSize: 12)),
              Text(formatAmount(riverPot), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          SizedBox(height: 4),
        ],
        Divider(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppLocalizations.of(context).sessionFinalPot, style: TextStyle(fontWeight: FontWeight.bold)),
            Text(formatAmount(totalPot), style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildWinnerDisplay(Map<String, dynamic> hand) {
    final isChoppedPot = hand['isChoppedPot'] == true;
    final winnerId = hand['winnerId'] as int?;
    final choppedWinners = hand['choppedWinners'] as List<dynamic>?;
    final individualShares = hand['individualShares'] as Map<String, dynamic>?;
    final potAmount = (hand['potAmount'] ?? 0).toDouble();
    final gameTypeStr = hand['handGameType'] ?? hand['gameType'] ?? 'cash';
    final isCashGame = gameTypeStr == 'cash';

    String formatAmount(double amount) {
      if (isCashGame) {
        return CurrencyService.formatCash(amount);
      } else {
        return '${amount.toInt()}';
      }
    }

    if (isChoppedPot && choppedWinners != null && choppedWinners.isNotEmpty) {
      // Chopped pot display
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.call_split, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text(
                AppLocalizations.of(context).sessionChoppedPot(choppedWinners.length),
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
              ),
            ],
          ),
          SizedBox(height: 8),
          if (individualShares != null && individualShares.isNotEmpty) ...[
            ...individualShares.entries.map((entry) {
              final playerId = int.parse(entry.key);
              final amount = (entry.value as num).toDouble();
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('🏆 ${AppLocalizations.of(context).sessionHistoryPlayerWins(playerId)}',
                         style: TextStyle(fontWeight: FontWeight.w500, color: Colors.green)),
                    Text(formatAmount(amount),
                         style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              );
            }).toList(),
          ] else ...[
            // Fallback to equal shares
            ...choppedWinners.map((winnerId) {
              final winnerIdInt = winnerId as int;
              final shareAmount = potAmount / choppedWinners.length;
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('🏆 ${AppLocalizations.of(context).sessionHistoryPlayerWins(winnerIdInt)}',
                         style: TextStyle(fontWeight: FontWeight.w500, color: Colors.green)),
                    Text(formatAmount(shareAmount),
                         style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      );
    } else if (winnerId != null) {
      // Single winner display
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                '🏆 ${AppLocalizations.of(context).sessionHistoryPlayerWins(winnerId!)}',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ],
          ),
          Text(
            formatAmount(potAmount),
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
          ),
        ],
      );
    } else {
      // No winner info available
      return Text(
        AppLocalizations.of(context).sessionWinnerNotAvailable,
        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      );
    }
  }


  String _formatDuration(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '${hours}h ${remainingMinutes}min';
    } else {
      return '$minutes min';
    }
  }

  String _formatBlinds(Map<String, dynamic> session) {
    final smallBlind = session['smallBlind'] ?? 0;
    final bigBlind = session['bigBlind'] ?? 0;
    final gameTypeStr = session['gameType'] ?? 'cash';

    // Check if it's a cash game
    final isCashGame = gameTypeStr == 'cash';

    if (isCashGame) {
      return '${CurrencyService.formatCash(smallBlind.toDouble())}/${CurrencyService.formatCash(bigBlind.toDouble())}';
    } else {
      return '$smallBlind/$bigBlind';
    }
  }

  Widget _getGameTypeIcon(String? gameType) {
    final gameTypeStr = gameType ?? 'cash';
    switch (gameTypeStr.toLowerCase()) {
      case 'tournament':
        return _buildIcon('icons/figma_icons/clubs.svg', 24, Colors.white);
      case 'cash':
        return _buildIcon('icons/figma_icons/dollar.svg', 24, Colors.white);
      default:
        return Icon(
          Icons.sports_esports,
          color: Colors.white,
          size: 24,
        );
    }
  }
}