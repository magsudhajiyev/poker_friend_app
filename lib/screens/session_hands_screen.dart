import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../services/dealer_service.dart';
import '../services/auth_service.dart';
import '../utils/poker_positions.dart';
import '../widgets/loading_screen.dart';
import 'hand_actions_screen.dart';

class SessionHandsScreen extends StatefulWidget {
  final Map<String, dynamic> session;

  const SessionHandsScreen({Key? key, required this.session}) : super(key: key);

  @override
  _SessionHandsScreenState createState() => _SessionHandsScreenState();
}

class _SessionHandsScreenState extends State<SessionHandsScreen> {
  List<Map<String, dynamic>> hands = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadHands();
  }

  Future<void> _loadHands() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // For dealer sessions, fetch from dealer_sessions collection
      final isDealerSession = widget.session['isDealerSession'] == true;
      final dealerSessionId = widget.session['dealerSessionId'] as String?;

      List<Map<String, dynamic>> loadedHands;
      if (isDealerSession && dealerSessionId != null) {
        loadedHands = await DealerService.getSessionHands(dealerSessionId);
      } else {
        loadedHands = await FirebaseService.getSessionHands(widget.session['id']);
      }

      // Filter hands by participation periods for live sessions
      final isLiveSession = widget.session['isLive'] == true;
      final currentUserId = AuthService.userId;

      if (isLiveSession && currentUserId != null) {
        final participationPeriods = widget.session['participationPeriods'] as Map<String, dynamic>?;
        if (participationPeriods != null && participationPeriods.containsKey(currentUserId)) {
          final periods = List<Map<String, dynamic>>.from(participationPeriods[currentUserId] ?? []);
          if (periods.isNotEmpty) {
            loadedHands = loadedHands.where((hand) {
              final handNumber = hand['handNumber'] as int? ?? 0;
              return periods.any((period) {
                final joined = period['joinedAtHand'] as int? ?? 1;
                final left = period['leftAtHand'] as int?;
                return handNumber >= joined && (left == null || handNumber <= left);
              });
            }).toList();
          }
        }
      }

      setState(() {
        hands = loadedHands;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load hands: $e';
        isLoading = false;
      });
    }
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
                    const Color(0xFF1A4A4A).withOpacity(0.6),
                    const Color(0xFF133538).withOpacity(0.3),
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Row(
                    children: [
                      // Back button - glassy circle
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFF101115),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Session info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.session['sessionName'] != null &&
                              widget.session['sessionName'].isNotEmpty
                                  ? widget.session['sessionName']
                                  : 'Session ${widget.session['id'].substring(0, 8)}...',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${hands.length} hands logged',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.5),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: _buildBody(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return LoadingScreen(message: 'Loading hands...');
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error!,
              style: GoogleFonts.ibmPlexSans(color: Colors.white.withOpacity(0.5)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _loadHands,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF89F1EC),
                  borderRadius: BorderRadius.circular(60),
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (hands.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF131616),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/logo.png',
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.casino_outlined,
                      color: Colors.white.withOpacity(0.3),
                      size: 40,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Hands Logged',
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This session has no recorded hands yet.',
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: hands.length,
      itemBuilder: (context, index) => _buildHandCard(hands[index], index + 1),
    );
  }

  static const _cardColor = Color(0xFF131616);
  static const _mint = Color(0xFF89F1EC);

  Widget _buildHandCard(Map<String, dynamic> hand, int handNumber) {
    final actions = hand['actions'] as List<dynamic>? ?? [];
    final startTime = DateTime.parse(hand['startTime']);
    final isStarred = hand['isStarred'] == true;
    final tags = (hand['tags'] as List<dynamic>?)?.cast<String>() ?? [];
    final potAmount = hand['potAmount'] ?? 0;
    final isCash = hand['gameType'] == 'cash';
    final heroPositionName = hand['heroPositionName'] ??
        PokerPositions.getPositionName(
          hand['heroPosition'] ?? 1,
          hand['buttonPosition'],
          hand['playerCount'],
        );
    final winnerId = hand['winnerId'];
    final heroSeat = hand['heroSeatNumber'] ?? widget.session['ourSeatNumber'] ?? widget.session['ourSeat'];
    final heroWon = winnerId != null && winnerId == heroSeat;

    return GestureDetector(
      onTap: () => _navigateToHandActions(hand),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(14),
          border: isStarred
              ? Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 1.5)
              : null,
        ),
        child: Column(
          children: [
            // Top row: Hand # + time + star/won badge
            Row(
              children: [
                // Hand number pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '#$handNumber',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isStarred) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.star, color: Colors.amber, size: 12),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Time + actions count
                Expanded(
                  child: Text(
                    '${DateFormat('HH:mm').format(startTime)}  ·  ${actions.length} actions  ·  ${hand['playerCount']}p',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Won badge
                if (heroWon)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _mint.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'WON',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 10,
                        color: _mint,
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

            // Bottom row: position + hero cards + pot + chevron
            Row(
              children: [
                // Position chip
                _buildPositionChip(heroPositionName),
                const SizedBox(width: 8),
                // Hero cards
                if (_hasHeroCards(hand)) ...[
                  _buildMiniCards(hand),
                  const SizedBox(width: 8),
                ],
                // Tags
                if (tags.isNotEmpty) ...[
                  ...tags.take(2).map((tag) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _buildTagBadge(tag),
                  )),
                ],
                const Spacer(),
                // Pot
                Text(
                  'Pot ${isCash ? '\$' : ''}${potAmount is double ? potAmount.toStringAsFixed(0) : potAmount}',
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

  Widget _buildPositionChip(String position) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _mint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        position,
        style: GoogleFonts.ibmPlexSans(
          fontSize: 11,
          color: _mint,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTagBadge(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _mint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tag,
        style: GoogleFonts.ibmPlexSans(
          fontSize: 10,
          color: _mint.withValues(alpha: 0.7),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  bool _hasHeroCards(Map<String, dynamic> hand) {
    final ourHoleCards = hand['ourHoleCards'] as Map<String, dynamic>?;
    if (ourHoleCards == null) return false;
    final card1 = ourHoleCards['card1'] as String?;
    final card2 = ourHoleCards['card2'] as String?;
    return card1 != null && card1.isNotEmpty && card2 != null && card2.isNotEmpty;
  }

  Widget _buildMiniCards(Map<String, dynamic> hand) {
    final ourHoleCards = hand['ourHoleCards'] as Map<String, dynamic>?;
    final card1 = ourHoleCards?['card1'] as String?;
    final card2 = ourHoleCards?['card2'] as String?;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (card1 != null) _buildMiniCard(card1),
        const SizedBox(width: 2),
        if (card2 != null) _buildMiniCard(card2),
      ],
    );
  }

  Widget _buildMiniCard(String card) {
    if (card.isEmpty) return const SizedBox.shrink();

    final suit = card.length > 1 ? card.substring(1) : '';
    final rank = card.isNotEmpty ? card[0] : '';
    final isRedSuit = suit == '♥' || suit == '♦';
    final cardColor = isRedSuit ? Colors.red : Colors.black;

    return Container(
      width: 20,
      height: 26,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            rank,
            style: TextStyle(
              color: cardColor,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          Text(
            suit,
            style: TextStyle(
              color: cardColor,
              fontSize: 7,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToHandActions(Map<String, dynamic> hand) async {
    final ourSeat = widget.session['ourSeat'] as int?;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HandActionsScreen(hand: hand, ourSeat: ourSeat),
      ),
    );
    // Refresh data when returning (in case star was toggled)
    _loadHands();
  }
}
