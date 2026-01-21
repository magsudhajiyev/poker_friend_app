import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import '../models/opponent.dart';
import '../services/local_storage_service.dart';
import '../services/firebase_service.dart';
import '../widgets/loading_screen.dart';
import '../utils/poker_positions.dart';
import 'hand_actions_screen.dart';
import '../widgets/global_top_header.dart';

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
  int? totalHandsCount; // Track total count without loading all

  final ScrollController _scrollController = ScrollController();
  static const int _handsPerPage = 5;
  int _currentPage = 0;

  // Cache sessions to avoid refetching
  List<Map<String, dynamic>>? _cachedSessions;

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
      // Load more when user is 200 pixels from the bottom
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

      // Load first page of hands only
      final firstPageHands = await _getHandsWithOpponentPaginated(
        widget.opponent.name,
        page: 0,
        pageSize: _handsPerPage
      );

      setState(() {
        hands = firstPageHands['hands'];
        totalHandsCount = firstPageHands['totalCount'];
        hasMoreHands = hands.length == _handsPerPage &&
                       (totalHandsCount == null || hands.length < totalHandsCount!);
        isLoading = false;
      });

      print('📱 Loaded ${hands.length} hands (estimated ${totalHandsCount ?? "unknown"} total)');
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
        pageSize: _handsPerPage
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

      print('📱 Loaded ${moreHands.length} more hands (${hands.length}/${totalHandsCount ?? "unknown"} total)');
    } catch (e) {
      setState(() {
        isLoadingMore = false;
      });
      print('❌ Error loading more hands: $e');
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
      print('🔍 Searching for hands with opponent: $opponentName (page $page, size $pageSize)');

      // Cache sessions on first load to avoid repeated fetching
      if (_cachedSessions == null) {
        try {
          _cachedSessions = await FirebaseService.getAllSessions();
          print('📱 Cached ${_cachedSessions!.length} Firebase sessions');
        } catch (firebaseError) {
          print('⚠️ Firebase error, falling back to local storage: $firebaseError');
          final db = await LocalStorageService.database;
          _cachedSessions = await db.query('sessions');
          print('💾 Cached ${_cachedSessions!.length} local sessions');
        }
      }

      int handsFound = 0;
      int handsSkipped = 0;
      final skipCount = page * pageSize;
      bool useFirebase = true;

      // Check if we originally loaded from Firebase or local
      try {
        await FirebaseService.getAllSessions();
      } catch (_) {
        useFirebase = false;
      }

      for (final session in _cachedSessions!) {
        final sessionId = session['id'] as String;

        // Get hands for this session
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
          // Check if opponent was involved in this hand
          bool opponentInvolved = _isOpponentInvolved(hand, opponentName);

          if (opponentInvolved) {
            totalCount++;

            // Skip hands until we reach the requested page
            if (handsSkipped < skipCount) {
              handsSkipped++;
              continue;
            }

            // Stop collecting once we have enough for this page
            if (handsFound >= pageSize) {
              break;
            }

            // Add session info to hand
            final handWithSession = Map<String, dynamic>.from(hand);
            handWithSession['sessionName'] = session['sessionName'] ?? 'Session ${session['id']}';
            handWithSession['sessionDate'] = session['startTime'];
            opponentHands.add(handWithSession);
            handsFound++;
          }
        }

        // Early exit if we have enough hands for this page
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

      print('🎯 Page $page: Found ${opponentHands.length} hands for $opponentName (${totalCount} total seen)');

      return {
        'hands': opponentHands,
        'totalCount': totalCount >= skipCount + handsFound ? null : totalCount, // null means we don't know the exact total yet
      };
    } catch (e) {
      print('❌ Error getting opponent hands: $e');
      return {
        'hands': <Map<String, dynamic>>[],
        'totalCount': 0,
      };
    }
  }

  bool _isOpponentInvolved(Map<String, dynamic> hand, String opponentName) {
    // Check if opponent name appears in player names
    final playerNamesData = hand['playerNames'];
    if (playerNamesData != null && playerNamesData is Map) {
      final involved = playerNamesData.values.any((name) =>
        name.toString().toLowerCase().trim() == opponentName.toLowerCase().trim()
      );
      if (involved) return true;
    }

    // Also check actions for opponent name (fallback)
    final actions = List<Map<String, dynamic>>.from(hand['actions'] ?? []);
    return actions.any((action) =>
      action['playerName']?.toString().toLowerCase().trim() == opponentName.toLowerCase().trim()
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Green gradient background overlay at top
          Positioned(
            left: -98,
            top: -148,
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 132, sigmaY: 132),
                child: Container(
                  width: 595,
                  height: 727,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFFABFFB4).withOpacity(0.6),
                        const Color(0xFF006434).withOpacity(0.6),
                        const Color(0xFF000000).withOpacity(0.6),
                      ],
                      stops: [0.0, 0.32, 1.0],
                    ),
                    borderRadius: BorderRadius.all(Radius.elliptical(297.5, 363.5)),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Global Top Header
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 24),
                  child: GlobalTopHeader(currentScreen: 'opponent_hands'),
                ),

                // Content
                Expanded(
                  child: isLoading
                      ? LoadingScreen(message: "Loading hand history...")
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

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          SizedBox(height: 16),
          Text(
            error!,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadOpponentHands,
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Color(0xFF1F1F23),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Image.asset(
                'assets/images/logo.png',
                width: 50,
                height: 50,
                color: Color(0xFF9A9A9A),
              ),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No Hands Found',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You haven\'t played any hands with ${widget.opponent.name} yet.',
            style: TextStyle(
              color: Color(0xFF9A9A9A),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHandsList() {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(24),
      itemCount: hands.length + (hasMoreHands ? 1 : 0), // +1 for loading indicator
      itemBuilder: (context, index) {
        if (index == hands.length) {
          // Loading indicator at the bottom
          return _buildLoadingIndicator();
        }

        final hand = hands[index];
        return _buildHandCard(hand, index);
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(
              color: Color(0xFF5AC95A),
              strokeWidth: 2,
            ),
            SizedBox(height: 12),
            Text(
              'Loading more hands...',
              style: TextStyle(
                color: Color(0xFF9A9A9A),
                fontSize: 14,
              ),
            ),
          ],
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
    
    // Get hero position name
    final heroPositionName = PokerPositions.getPositionName(heroPosition, buttonPosition, playerCount);
    
    // Check if opponent won
    bool opponentWon = false;
    String? opponentPosition;
    if (winnerId != null) {
      final playerNamesData = hand['playerNames'];
      if (playerNamesData != null && playerNamesData is Map) {
        final winnerName = playerNamesData[winnerId.toString()];
        opponentWon = winnerName?.toString().toLowerCase().trim() == widget.opponent.name.toLowerCase().trim();
        
        // Get opponent's position
        playerNamesData.forEach((seat, name) {
          if (name.toString().toLowerCase().trim() == widget.opponent.name.toLowerCase().trim()) {
            final seatNum = int.tryParse(seat) ?? 1;
            opponentPosition = PokerPositions.getPositionName(seatNum, buttonPosition, playerCount);
          }
        });
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
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Color(0xFF1F1F23),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Color(0xFF2A2A2E)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hand #$handNumber',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (opponentWon)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(0xFFFFD700).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Color(0xFFFFD700)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 14),
                        SizedBox(width: 4),
                        Text(
                          'OPPONENT WON',
                          style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            
            SizedBox(height: 12),
            
            // Info row
            Row(
              children: [
                // Session info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sessionName,
                        style: TextStyle(
                          color: Color(0xFF9A9A9A),
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, HH:mm').format(startTime),
                        style: TextStyle(
                          color: Color(0xFF9A9A9A),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Positions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Text(
                          'You: ',
                          style: TextStyle(
                            color: Color(0xFF9A9A9A),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          heroPositionName,
                          style: TextStyle(
                            color: Color(0xFF5AC95A),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (opponentPosition != null) ...[
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${widget.opponent.name}: ',
                            style: TextStyle(
                              color: Color(0xFF9A9A9A),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            opponentPosition!,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            // Bottom row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pot: ${hand['gameType'] == 'cash' ? '\$' : ''}${potAmount.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: Color(0xFF5AC95A),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFF9A9A9A),
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}