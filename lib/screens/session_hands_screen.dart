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
            top: -screenWidth * 0.3,
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
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3C3C43).withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 20,
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

  Widget _buildHandCard(Map<String, dynamic> hand, int handNumber) {
    final actions = hand['actions'] as List<dynamic>? ?? [];
    final startTime = DateTime.parse(hand['startTime']);
    final isStarred = hand['isStarred'] == true;
    final tags = (hand['tags'] as List<dynamic>?)?.cast<String>() ?? [];

    return GestureDetector(
      onTap: () => _navigateToHandActions(hand),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF131616),
          borderRadius: BorderRadius.circular(18),
          border: isStarred
              ? Border.all(color: Colors.amber.withOpacity(0.5), width: 1.5)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hand Header
            Row(
              children: [
                // Hand number badge
                Stack(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF89F1EC).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '#$handNumber',
                          style: GoogleFonts.ibmPlexSans(
                            color: const Color(0xFF89F1EC),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    // Star badge
                    if (isStarred)
                      Positioned(
                        top: -3,
                        right: -3,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.star,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Position: ${hand['heroPositionName'] ?? PokerPositions.getPositionName(hand['heroPosition'] ?? 1, hand['buttonPosition'], hand['playerCount'])}',
                        style: GoogleFonts.ibmPlexSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${actions.length} actions  •  ${DateFormat('HH:mm:ss').format(startTime)}',
                        style: GoogleFonts.ibmPlexSans(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withOpacity(0.3),
                  size: 20,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Hand Info Row
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildHandStat('Players', '${hand['playerCount']}'),
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  Expanded(
                    child: _buildHandStat('Actions', '${actions.length}'),
                  ),
                  // Show hero cards if available
                  if (_hasHeroCards(hand)) ...[
                    Container(
                      width: 1,
                      height: 24,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    Expanded(
                      child: _buildHeroCardsColumn(hand),
                    ),
                  ],
                ],
              ),
            ),

            // Tags row (if any)
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: tags.map((tag) => _buildTagBadge(tag)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTagBadge(String tag) {
    IconData tagIcon;
    switch (tag) {
      case 'Bluff':
        tagIcon = Icons.psychology;
        break;
      case 'Value':
        tagIcon = Icons.attach_money;
        break;
      case 'Mistake':
        tagIcon = Icons.error_outline;
        break;
      case 'Cooler':
        tagIcon = Icons.ac_unit;
        break;
      case 'Hero Call':
        tagIcon = Icons.shield;
        break;
      case 'Exploit':
        tagIcon = Icons.gps_fixed;
        break;
      default:
        tagIcon = Icons.label;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF89F1EC).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF89F1EC).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            tagIcon,
            size: 10,
            color: const Color(0xFF89F1EC),
          ),
          const SizedBox(width: 4),
          Text(
            tag,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 10,
              color: const Color(0xFF89F1EC),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.ibmPlexSans(
            color: const Color(0xFF89F1EC),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  bool _hasHeroCards(Map<String, dynamic> hand) {
    final ourHoleCards = hand['ourHoleCards'] as Map<String, dynamic>?;
    if (ourHoleCards == null) return false;
    return ourHoleCards['card1'] != null || ourHoleCards['card2'] != null;
  }

  Widget _buildHeroCardsColumn(Map<String, dynamic> hand) {
    final ourHoleCards = hand['ourHoleCards'] as Map<String, dynamic>?;
    final card1 = ourHoleCards?['card1'] as String?;
    final card2 = ourHoleCards?['card2'] as String?;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (card1 != null) _buildMiniCard(card1),
            if (card1 != null && card2 != null) const SizedBox(width: 3),
            if (card2 != null) _buildMiniCard(card2),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Hero Cards',
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniCard(String? card) {
    if (card == null || card.isEmpty) return const SizedBox.shrink();

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
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
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
