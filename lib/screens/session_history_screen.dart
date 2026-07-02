import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import '../services/subscription_service.dart';
import '../services/free_tier_limits.dart';
import '../utils/poker_positions.dart';
import '../widgets/loading_screen.dart';
import '../widgets/global_bottom_nav_bar.dart';
import '../design_system/components/cards/error_state_card.dart';
import '../design_system/components/headers/top_nav_bar.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../services/app_data_cache.dart';
import '../screens/paywall_screen.dart';
import 'session_analytics_screen.dart';
import '../services/currency_service.dart';
import '../services/logger_service.dart';

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
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;

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
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
        error = AppLocalizations.of(context).sessionHistoryFailedLoad(e.toString());
        isLoading = false;
      });
    }
  }

  void _scrollToSession(String sessionId) {
    // Wait a bit for the UI to render
    Future.delayed(Duration(milliseconds: 300), () {
      final targetIndex = sessions.indexWhere((session) => session['id'] == sessionId);

      if (targetIndex != -1) {
        // Calculate approximate position (each session card is roughly 120px + margins)
        const double itemHeight = 140.0;
        final double scrollOffset = targetIndex * itemHeight;

        // Scroll to the session with animation
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            scrollOffset,
            duration: Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
        }
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
    final l10n = AppLocalizations.of(context);
    const redColor = Color(0xFFFF3B30);
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFF3B30).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: redColor, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Left group: icon + label
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/icons/Info.svg',
                    width: 16,
                    height: 16,
                    colorFilter: const ColorFilter.mode(redColor, BlendMode.srcIn),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.sessionLast30Days,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: redColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              // Dot separator
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              // Upgrade link
              Text(
                l10n.sessionUpgradeForFullHistory,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
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
      backgroundColor: const Color(0xFF0C0C0C),
      extendBody: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TopNavBar(
            title: l10n.sessionHistoryTitle,
            onBack: () => Navigator.pop(context),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
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
                              color: Color.lerp(const Color(0xFF161719), Colors.transparent, t),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Center(
                              child: Text(
                                l10n.sessionHistoryCash,
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.5,
                                  color: Color.lerp(Colors.white, const Color(0xFF0C0C0C), t),
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
                              color: Color.lerp(Colors.transparent, const Color(0xFF161719), t),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Center(
                              child: Text(
                                l10n.sessionHistoryTournament,
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.5,
                                  color: Color.lerp(const Color(0xFF0C0C0C), Colors.white, t),
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
      bottomNavigationBar: GlobalBottomNavBar(currentScreen: 'sessions'),
    );
  }

  Widget _buildSessionsList(List<Map<String, dynamic>> sessionList, String gameType) {
    final l10n = AppLocalizations.of(context);
    if (isLoading) {
      return LoadingScreen(message: l10n.sessionLoadingMessage);
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
              style: GoogleFonts.ibmPlexSans(
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
              style: GoogleFonts.ibmPlexSans(
                color: const Color(0xFFB9B9B9),
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

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: sessionList.length,
      itemBuilder: (context, index) {
        final session = sessionList[index];
        return _buildSessionCard(session);
      },
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
        ? const Color(0xFF8C8C8C)
        : profitLoss > 0
            ? const Color(0xFFA3FF78)
            : profitLoss < 0
                ? const Color(0xFFFF3B30)
                : const Color(0xFFFF8A54);
    final plText = profitLoss == null
        ? '—'
        : profitLoss > 0
            ? '+${CurrencyService.formatCash(profitLoss)}'
            : CurrencyService.formatCash(profitLoss);

    return GestureDetector(
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
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFF161719), width: 1),
          ),
        ),
        child: Row(
          children: [
            // Icon box
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFA3FF78),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: SvgPicture.asset(
                  isTournament ? 'assets/icons/Trophy.svg' : 'assets/icons/Coin.svg',
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          sessionName,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 22 / 17,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        plText,
                        style: GoogleFonts.ibmPlexSans(
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
              colorFilter: const ColorFilter.mode(Color(0xFFB9B9B9), BlendMode.srcIn),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String iconPath, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            iconPath,
            width: 12,
            height: 12,
            colorFilter: const ColorFilter.mode(Color(0xFFB9B9B9), BlendMode.srcIn),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFB9B9B9),
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
                              color: isHero ? Color(0xFF5AC95A) : Colors.white,
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
        backgroundColor: Color(0xFF1F1F23),
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
            content: Text(l10n.sessionHistorySyncFailed(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showClearConfirmation() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text(l10n.sessionClearAllTitle),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.sessionClearAllDescription),
            SizedBox(height: 8),
            Text(
              l10n.sessionClearAllWarning,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAllSessions();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.sessionClearAll),
          ),
        ],
      ),
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
        error = AppLocalizations.of(context).sessionHistoryClearFailed(e.toString());
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).sessionHistoryClearFailed(e.toString())),
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