import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../models/opponent.dart';
import '../services/local_storage_service.dart';
import '../services/firebase_service.dart';
import '../utils/poker_positions.dart';
import 'hand_actions_page_view.dart';
import '../services/app_data_cache.dart';
import '../widgets/global_bottom_nav_bar.dart';
import '../services/currency_service.dart';
import '../design_system/constants/colors.dart';

class OpponentHandsScreen extends StatefulWidget {
  final Opponent opponent;

  const OpponentHandsScreen({Key? key, required this.opponent}) : super(key: key);

  /// Cached filtered hand counts by opponent ID.
  /// Updated after each hand history load so other screens can read it.
  static final Map<String, int> filteredHandCounts = {};

  /// Static cache of filtered hands per opponent, persists across screen instances.
  static final Map<String, List<Map<String, dynamic>>> _cachedHandsByOpponent = {};

  /// Clear all cached hand data (e.g., on logout).
  static void clearCache() {
    _cachedHandsByOpponent.clear();
    filteredHandCounts.clear();
  }

  @override
  _OpponentHandsScreenState createState() => _OpponentHandsScreenState();
}

class _OpponentHandsScreenState extends State<OpponentHandsScreen> {
  List<Map<String, dynamic>> hands = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMoreHands = true;
  String? error;
  int? totalHandsCount;

  final ScrollController _scrollController = ScrollController();
  static const int _handsPerPage = 10;
  int _currentPage = 0;

  // Full filtered list built once, pages served from cache
  List<Map<String, dynamic>>? _allFilteredHands;

  static const _cardColor = AppColors.infoCardBg;
  static const _mint = AppColors.buttonPrimary;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadOpponentHands();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!isLoadingMore && hasMoreHands) {
        _loadMoreHands();
      }
    }
  }

  Future<void> _loadOpponentHands() async {
    try {
      // Serve from static cache if data hasn't changed
      final opId = widget.opponent.id;
      if (!AppDataCache.isOpponentHandsDirty &&
          OpponentHandsScreen._cachedHandsByOpponent.containsKey(opId)) {
        _allFilteredHands = OpponentHandsScreen._cachedHandsByOpponent[opId];
        final all = _allFilteredHands!;
        final firstPage = all.length > _handsPerPage
            ? all.sublist(0, _handsPerPage)
            : all;
        setState(() {
          hands = firstPage;
          totalHandsCount = all.length;
          hasMoreHands = firstPage.length < all.length;
          _currentPage = 0;
          isLoading = false;
        });
        return;
      }

      setState(() {
        isLoading = true;
        error = null;
        _currentPage = 0;
        _allFilteredHands = null; // Reset instance cache for fresh load
      });

      final firstPageHands = await _getHandsWithOpponentPaginated(
        widget.opponent.name,
        page: 0,
        pageSize: _handsPerPage,
      );

      final total = firstPageHands['totalCount'] as int;
      setState(() {
        hands = firstPageHands['hands'];
        totalHandsCount = total;
        hasMoreHands = hands.length < total;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load hands: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _loadMoreHands() async {
    if (isLoadingMore || !hasMoreHands) return;

    setState(() {
      isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;

      final moreHandsData = await _getHandsWithOpponentPaginated(
        widget.opponent.name,
        page: nextPage,
        pageSize: _handsPerPage,
      );

      final moreHands = moreHandsData['hands'] as List<Map<String, dynamic>>;

      final total = moreHandsData['totalCount'] as int;
      setState(() {
        hands.addAll(moreHands);
        _currentPage = nextPage;
        totalHandsCount = total;
        hasMoreHands = hands.length < total;
        isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        isLoadingMore = false;
      });
    }
  }

  /// Build the full filtered hand list once, then return a page from it.
  Future<Map<String, dynamic>> _getHandsWithOpponentPaginated(
    String opponentName, {
    required int page,
    required int pageSize,
  }) async {
    try {
      // Build the full list only on first call
      if (_allFilteredHands == null) {
        await _buildFilteredHandsList(opponentName);
      }

      final all = _allFilteredHands!;
      final start = page * pageSize;
      final end = (start + pageSize).clamp(0, all.length);
      final pageHands = start < all.length
          ? all.sublist(start, end)
          : <Map<String, dynamic>>[];

      return {
        'hands': pageHands,
        'totalCount': all.length,
      };
    } catch (e) {
      return {
        'hands': <Map<String, dynamic>>[],
        'totalCount': 0,
      };
    }
  }

  /// Fetch all sessions + hands once, filter, sort, and cache.
  Future<void> _buildFilteredHandsList(String opponentName) async {
    final List<Map<String, dynamic>> result = [];

    List<Map<String, dynamic>> sessions;
    bool useFirebase = true;
    try {
      sessions = await FirebaseService.getAllSessions();
    } catch (_) {
      useFirebase = false;
      final db = await LocalStorageService.database;
      sessions = await db.query('sessions');
    }

    for (final session in sessions) {
      final sessionId = session['id'] as String;

      List<Map<String, dynamic>> sessionHands;
      if (useFirebase) {
        try {
          sessionHands = await FirebaseService.getSessionHands(sessionId);
        } catch (_) {
          sessionHands = await LocalStorageService.getSessionHands(sessionId);
        }
      } else {
        sessionHands = await LocalStorageService.getSessionHands(sessionId);
      }

      for (final hand in sessionHands) {
        if (!_isOpponentInvolved(hand, opponentName)) continue;
        if (_isOpponentHandTrivial(hand, opponentName)) continue;

        final handWithSession = Map<String, dynamic>.from(hand);
        handWithSession['sessionName'] =
            session['sessionName'] ?? 'Session ${session['id']}';
        handWithSession['sessionDate'] = session['startTime'];
        result.add(handWithSession);
      }
    }

    // Sort by date (most recent first)
    result.sort((a, b) {
      final aTime = DateTime.parse(a['startTime'] ?? '1970-01-01');
      final bTime = DateTime.parse(b['startTime'] ?? '1970-01-01');
      return bTime.compareTo(aTime);
    });

    _allFilteredHands = result;
    // Store in static cache for cross-instance persistence
    OpponentHandsScreen._cachedHandsByOpponent[widget.opponent.id] = result;
    OpponentHandsScreen.filteredHandCounts[widget.opponent.id] = result.length;
    AppDataCache.clearOpponentHandsDirty();
  }

  bool _isOpponentInvolved(Map<String, dynamic> hand, String opponentName) {
    final playerNamesData = hand['playerNames'];
    if (playerNamesData != null && playerNamesData is Map) {
      final involved = playerNamesData.values.any((name) =>
          name.toString().toLowerCase().trim() ==
          opponentName.toLowerCase().trim());
      if (involved) return true;
    }

    final actions = List<Map<String, dynamic>>.from(hand['actions'] ?? []);
    return actions.any((action) =>
        action['playerName']?.toString().toLowerCase().trim() ==
        opponentName.toLowerCase().trim());
  }

  /// Returns true if the opponent did nothing interesting — their only action
  /// was a single fold with no prior voluntary action (no call, bet, or raise
  /// before folding). Hands where opponent raised then folded to a 3-bet
  /// are kept (they took a meaningful action before folding).
  bool _isOpponentHandTrivial(
      Map<String, dynamic> hand, String opponentName) {
    final actions = List<Map<String, dynamic>>.from(hand['actions'] ?? []);
    final nameLower = opponentName.toLowerCase().trim();

    // Find opponent's seat number from playerNames
    int? opponentSeat;
    final playerNamesData = hand['playerNames'];
    if (playerNamesData != null && playerNamesData is Map) {
      for (final entry in playerNamesData.entries) {
        if (entry.value.toString().toLowerCase().trim() == nameLower) {
          opponentSeat = int.tryParse(entry.key.toString());
          break;
        }
      }
    }

    // Get opponent's actions (match by seat number or name)
    final opponentActions = actions.where((a) {
      if (opponentSeat != null && a['player'] == opponentSeat) return true;
      return a['playerName']?.toString().toLowerCase().trim() == nameLower;
    }).toList();

    if (opponentActions.isEmpty) return true; // no actions = trivial

    // If opponent took ANY non-fold action, the hand is interesting
    final hasNonFoldAction = opponentActions.any((a) =>
        a['action'] != 'fold' && a['action'] != null);
    if (hasNonFoldAction) return false;

    // Opponent only folded — trivial hand
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      bottomNavigationBar: GlobalBottomNavBar(currentScreen: 'opponents'),
      body: Stack(
        children: [
          // Teal radial gradient at top
          Positioned(
            top: -screenWidth * 0.5,
            right: -screenWidth * 0.2,
            child: Container(
              width: screenWidth * 1.2,
              height: screenWidth * 1.2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1A4A4A).withValues(alpha: 0.6),
                    AppColors.headerGradientTeal.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      // Back button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceDark,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.opponent.name,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.opponentHandsTitle,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.5),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Hand count pill
                      if (!isLoading && hands.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: Text(
                            l10n.opponentHandsCount(totalHandsCount ?? hands.length),
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: isLoading
                      ? _buildLoadingState()
                      : error != null
                          ? _buildErrorState()
                          : hands.isEmpty
                              ? _buildEmptyState()
                              : _buildHandsList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              color: _mint,
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).opponentHandsLoading,
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, size: 28, color: Colors.red),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).opponentHandsError,
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error!,
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _loadOpponentHands,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: _mint,
                  borderRadius: BorderRadius.circular(60),
                ),
                child: Text(
                  AppLocalizations.of(context).opponentHandsRetry,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.style_outlined,
                size: 32,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context).opponentHandsNoHandsTitle,
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).opponentHandsNoHandsSubtitle(widget.opponent.name),
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandsList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: hands.length + (hasMoreHands ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == hands.length) {
          return _buildLoadingIndicator();
        }
        return _buildHandCard(hands[index], index);
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: _mint,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildHandCard(Map<String, dynamic> hand, int index) {
    final l10n = AppLocalizations.of(context);
    final sessionName = hand['sessionName'] ?? l10n.opponentHandsUnknownSession;
    final handNumber = hand['handNumber'] ?? (index + 1);
    final buttonPosition = hand['buttonPosition'] ?? 1;
    final playerCount = hand['playerCount'] ?? 6;
    final heroPosition = hand['heroPosition'] ?? 1;
    final potAmount = hand['potAmount'] ?? 0;
    final winnerId = hand['winnerId'];
    final isCash = hand['gameType'] == 'cash';

    final heroPositionName = PokerPositions.getPositionName(heroPosition, buttonPosition, playerCount);

    bool opponentWon = false;
    String? opponentPosition;
    final playerNamesData = hand['playerNames'];
    if (playerNamesData != null && playerNamesData is Map) {
      playerNamesData.forEach((seat, name) {
        if (name.toString().toLowerCase().trim() == widget.opponent.name.toLowerCase().trim()) {
          final seatNum = int.tryParse(seat.toString()) ?? 1;
          opponentPosition = PokerPositions.getPositionName(seatNum, buttonPosition, playerCount);
        }
      });
      if (winnerId != null) {
        final winnerName = playerNamesData[winnerId.toString()];
        opponentWon = winnerName?.toString().toLowerCase().trim() ==
            widget.opponent.name.toLowerCase().trim();
      }
    }

    final potText = 'Pot ${isCash ? CurrencyService.formatCash(potAmount) : potAmount.toStringAsFixed(0)}';

    return GestureDetector(
      onTap: () {
        final allHands = _allFilteredHands ?? [hand];
        final idx = allHands.indexOf(hand);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HandActionsPageView(
              hands: allHands,
              initialIndex: idx < 0 ? 0 : idx,
            ),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF161719), width: 1)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: hand number chip + session name | OPP WON badge
            Row(
              children: [
                Container(
                  width: 38,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF161719),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '#$handNumber',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      height: 20 / 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
                if (opponentWon)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.opponentHandsOppWon,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        height: 20 / 13,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Row 2: player chips | pot chip
            Row(
              children: [
                _buildPlayerChip(l10n.opponentHandsYou, heroPositionName, isHero: true),
                const SizedBox(width: 8),
                if (opponentPosition != null)
                  _buildPlayerChip(
                    widget.opponent.name.length > 8
                        ? '${widget.opponent.name.substring(0, 8)}.'
                        : widget.opponent.name,
                    opponentPosition!,
                    isHero: false,
                  ),
                const Spacer(),
                // Pot chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161719),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        potText,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF4CDE78),
                          height: 20 / 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 12, color: Color(0xFF4CDE78)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerChip(String label, String position, {required bool isHero}) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF161719),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 38,
            height: 28,
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 20 / 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Container(
            width: 38,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF0C0C0C),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              position,
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isHero ? const Color(0xFFA3FF78) : const Color(0xFFB9B9B9),
                height: 20 / 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
