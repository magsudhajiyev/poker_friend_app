import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/opponent.dart';
import '../services/local_storage_service.dart';
import '../services/firebase_service.dart';
import '../utils/poker_positions.dart';
import 'hand_actions_screen.dart';

class OpponentHandsScreen extends StatefulWidget {
  final Opponent opponent;

  const OpponentHandsScreen({Key? key, required this.opponent}) : super(key: key);

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
  static const int _handsPerPage = 5;
  int _currentPage = 0;

  // Cache sessions to avoid refetching
  List<Map<String, dynamic>>? _cachedSessions;

  static const _cardColor = Color(0xFF131616);
  static const _mint = Color(0xFF89F1EC);

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
      setState(() {
        isLoading = true;
        error = null;
        _currentPage = 0;
      });

      final firstPageHands = await _getHandsWithOpponentPaginated(
        widget.opponent.name,
        page: 0,
        pageSize: _handsPerPage,
      );

      setState(() {
        hands = firstPageHands['hands'];
        totalHandsCount = firstPageHands['totalCount'];
        hasMoreHands = hands.length == _handsPerPage &&
            (totalHandsCount == null || hands.length < totalHandsCount!);
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

      setState(() {
        hands.addAll(moreHands);
        _currentPage = nextPage;
        totalHandsCount = moreHandsData['totalCount'];
        hasMoreHands = moreHands.length == _handsPerPage &&
            (totalHandsCount == null || hands.length < totalHandsCount!);
        isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        isLoadingMore = false;
      });
    }
  }

  Future<Map<String, dynamic>> _getHandsWithOpponentPaginated(
    String opponentName, {
    required int page,
    required int pageSize,
  }) async {
    List<Map<String, dynamic>> opponentHands = [];
    int totalCount = 0;

    try {
      // Cache sessions on first load to avoid repeated fetching
      if (_cachedSessions == null) {
        try {
          _cachedSessions = await FirebaseService.getAllSessions();
        } catch (firebaseError) {
          final db = await LocalStorageService.database;
          _cachedSessions = await db.query('sessions');
        }
      }

      int handsFound = 0;
      int handsSkipped = 0;
      final skipCount = page * pageSize;
      bool useFirebase = true;

      try {
        await FirebaseService.getAllSessions();
      } catch (_) {
        useFirebase = false;
      }

      for (final session in _cachedSessions!) {
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
          bool opponentInvolved = _isOpponentInvolved(hand, opponentName);

          if (opponentInvolved) {
            totalCount++;

            if (handsSkipped < skipCount) {
              handsSkipped++;
              continue;
            }

            if (handsFound >= pageSize) {
              break;
            }

            final handWithSession = Map<String, dynamic>.from(hand);
            handWithSession['sessionName'] = session['sessionName'] ?? 'Session ${session['id']}';
            handWithSession['sessionDate'] = session['startTime'];
            opponentHands.add(handWithSession);
            handsFound++;
          }
        }

        if (handsFound >= pageSize) {
          break;
        }
      }

      // Sort by date (most recent first)
      opponentHands.sort((a, b) {
        final aTime = DateTime.parse(a['startTime'] ?? '1970-01-01');
        final bTime = DateTime.parse(b['startTime'] ?? '1970-01-01');
        return bTime.compareTo(aTime);
      });

      return {
        'hands': opponentHands,
        'totalCount': totalCount >= skipCount + handsFound ? null : totalCount,
      };
    } catch (e) {
      return {
        'hands': <Map<String, dynamic>>[],
        'totalCount': 0,
      };
    }
  }

  bool _isOpponentInvolved(Map<String, dynamic> hand, String opponentName) {
    final playerNamesData = hand['playerNames'];
    if (playerNamesData != null && playerNamesData is Map) {
      final involved = playerNamesData.values.any((name) =>
          name.toString().toLowerCase().trim() == opponentName.toLowerCase().trim());
      if (involved) return true;
    }

    final actions = List<Map<String, dynamic>>.from(hand['actions'] ?? []);
    return actions.any((action) =>
        action['playerName']?.toString().toLowerCase().trim() ==
        opponentName.toLowerCase().trim());
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.black,
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
                    const Color(0xFF133538).withValues(alpha: 0.3),
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
                            color: Color(0xFF101115),
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
                              'Hand History',
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
                            '${totalHandsCount ?? hands.length} hands',
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
            'Loading hand history...',
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
              'Something went wrong',
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
                  'Retry',
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
              'No Hands Found',
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You haven\'t played any hands\nwith ${widget.opponent.name} yet.',
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
    final startTime = DateTime.parse(hand['startTime']);
    final sessionName = hand['sessionName'] ?? 'Unknown Session';
    final handNumber = hand['handNumber'] ?? (index + 1);
    final buttonPosition = hand['buttonPosition'] ?? 1;
    final playerCount = hand['playerCount'] ?? 6;
    final heroPosition = hand['heroPosition'] ?? 1;
    final potAmount = hand['potAmount'] ?? 0;
    final winnerId = hand['winnerId'];
    final isCash = hand['gameType'] == 'cash';

    // Get hero position name
    final heroPositionName = PokerPositions.getPositionName(heroPosition, buttonPosition, playerCount);

    // Check if opponent won and get opponent position
    bool opponentWon = false;
    String? opponentPosition;
    final playerNamesData = hand['playerNames'];
    if (playerNamesData != null && playerNamesData is Map) {
      // Find opponent position
      playerNamesData.forEach((seat, name) {
        if (name.toString().toLowerCase().trim() == widget.opponent.name.toLowerCase().trim()) {
          final seatNum = int.tryParse(seat.toString()) ?? 1;
          opponentPosition = PokerPositions.getPositionName(seatNum, buttonPosition, playerCount);
        }
      });

      // Check winner
      if (winnerId != null) {
        final winnerName = playerNamesData[winnerId.toString()];
        opponentWon = winnerName?.toString().toLowerCase().trim() ==
            widget.opponent.name.toLowerCase().trim();
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HandActionsScreen(hand: hand),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            // Top row: Hand # + session + date | opponent won badge
            Row(
              children: [
                // Hand number
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#$handNumber',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Session name + date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sessionName,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        DateFormat('MMM dd, yyyy  HH:mm').format(startTime),
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                // Opponent won badge
                if (opponentWon)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'OPP WON',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 10,
                        color: Colors.red,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            const SizedBox(height: 12),

            // Bottom row: positions + pot + chevron
            Row(
              children: [
                // Your position
                _buildPositionChip('You', heroPositionName, _mint),
                const SizedBox(width: 8),
                // Opponent position
                if (opponentPosition != null)
                  _buildPositionChip(
                    widget.opponent.name.length > 8
                        ? '${widget.opponent.name.substring(0, 8)}.'
                        : widget.opponent.name,
                    opponentPosition!,
                    Colors.white.withValues(alpha: 0.6),
                  ),
                const Spacer(),
                // Pot
                Text(
                  'Pot ${isCash ? '\$' : ''}${potAmount.toStringAsFixed(0)}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    color: _mint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.3),
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionChip(String label, String position, Color positionColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: positionColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            position,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 11,
              color: positionColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
