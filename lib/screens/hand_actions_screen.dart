import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import '../utils/poker_positions.dart';
import '../utils/number_formatter.dart';
import '../models/game_types.dart';
import '../services/ai_analyzer_service.dart';
import '../services/firebase_service.dart';
import '../services/subscription_service.dart';
import '../services/pokerstars_export_service.dart';
import 'paywall_screen.dart';

class HandActionsScreen extends StatefulWidget {
  final Map<String, dynamic> hand;
  final int? ourSeat;

  const HandActionsScreen({Key? key, required this.hand, this.ourSeat}) : super(key: key);

  @override
  _HandActionsScreenState createState() => _HandActionsScreenState();
}

class _HandActionsScreenState extends State<HandActionsScreen> {
  Map<String, dynamic>? _aiAnalysis;
  bool _isAnalyzing = false;
  String? _analysisError;
  final ScrollController _scrollController = ScrollController();

  // Star and tags state
  late bool _isStarred;
  late List<String> _tags;
  String? _notes;

  @override
  void initState() {
    super.initState();
    _isStarred = widget.hand['isStarred'] == true;
    _tags = (widget.hand['tags'] as List<dynamic>?)?.cast<String>() ?? [];
    _notes = widget.hand['notes'] as String?;
    _loadExistingAnalysis();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleStar() async {
    final newStarredState = !_isStarred;
    setState(() {
      _isStarred = newStarredState;
    });

    try {
      final sessionId = widget.hand['sessionId'] as String?;
      final handId = widget.hand['id'] as String?;

      if (sessionId != null && handId != null) {
        await FirebaseService.updateHandAnnotations(
          sessionId: sessionId,
          handId: handId,
          isStarred: newStarredState,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isStarred = !newStarredState;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update star status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleExportButtonTap() async {
    final isPremium = SubscriptionService.isPremium;

    if (!isPremium) {
      final purchased = await PaywallScreen.show(context, featureName: 'Hand Export');
      if (purchased != true || !mounted) return;
      setState(() {});
    }

    if (!mounted) return;
    _exportPokerStarsFormat();
  }

  Future<void> _exportPokerStarsFormat() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating PokerStars export...'),
          duration: Duration(seconds: 2),
        ),
      );

      final sessionId = widget.hand['sessionId'] as String?;
      Map<String, dynamic> sessionData = {};
      if (sessionId != null) {
        final session = await FirebaseService.getSession(sessionId);
        if (session != null) {
          sessionData = session;
        }
      }

      await PokerStarsExportService.exportAndShare(widget.hand, sessionData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hand #${widget.hand['handNumber'] ?? 'N/A'} exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export hand: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadExistingAnalysis() async {
    try {
      final sessionId = widget.hand['sessionId'] as String?;
      final handId = widget.hand['id'] as String?;

      if (sessionId != null && handId != null) {
        final analysis = await AIAnalyzerService.getAnalysis(
          sessionId: sessionId,
          handId: handId,
        );

        if (analysis != null && mounted) {
          setState(() {
            _aiAnalysis = analysis;
          });
        }
      }
    } catch (e) {
      // Silently fail - analysis will be loaded on demand
    }
  }

  Future<void> _analyzeHand() async {
    final ourHoleCards = widget.hand['ourHoleCards'] as Map<String, dynamic>?;
    final card1 = ourHoleCards?['card1'] as String?;
    final card2 = ourHoleCards?['card2'] as String?;

    if (card1 == null || card2 == null || card1.isEmpty || card2.isEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF131616),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.orange, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Missing Hero Cards',
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              'AI analysis requires your hole cards to be recorded. This hand cannot be analyzed because hero cards are missing.',
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: GoogleFonts.ibmPlexSans(
                    color: const Color(0xFF89F1EC),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisError = null;
    });

    try {
      final handData = AIAnalyzerService.prepareHandDataForAnalysis(widget.hand);

      final analysis = await AIAnalyzerService.analyzeHand(
        handId: handData['handId'] as String,
        handData: handData,
      );

      final sessionId = widget.hand['sessionId'] as String?;
      final handId = widget.hand['id'] as String?;

      if (sessionId != null && handId != null) {
        await AIAnalyzerService.saveAnalysis(
          sessionId: sessionId,
          handId: handId,
          analysis: analysis,
        );
      }

      if (mounted) {
        setState(() {
          _aiAnalysis = analysis;
          _isAnalyzing = false;
        });

        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _analysisError = e.toString();
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final heroPositionName = widget.hand['heroPositionName'] as String?;
    final heroSeatNumber = widget.hand['heroSeatNumber'] as int?;
    final buttonPosition = widget.hand['buttonPosition'] ?? 1;
    final rawPlayerCount = (widget.hand['playerCount'] as int?) ?? 6;
    final playerCount = math.max(2, rawPlayerCount);
    final heroPosition = widget.ourSeat ?? heroSeatNumber ?? widget.hand['heroPosition'] ?? 1;

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
                      // Hand info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hand #${widget.hand['handNumber'] ?? 'N/A'}',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Position: ${heroPositionName ?? PokerPositions.getPositionName(heroPosition, buttonPosition, playerCount)}',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.5),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Export button
                      GestureDetector(
                        onTap: _handleExportButtonTap,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3C3C43).withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.download,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Star button
                      GestureDetector(
                        onTap: _toggleStar,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _isStarred
                                ? Colors.amber.withOpacity(0.2)
                                : const Color(0xFF3C3C43).withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isStarred ? Icons.star : Icons.star_border,
                            color: _isStarred ? Colors.amber : Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tags row
                        if (_tags.isNotEmpty) ...[
                          _buildTagsSection(),
                          const SizedBox(height: 12),
                        ],

                        // Notes section
                        if (_notes != null && _notes!.isNotEmpty) ...[
                          _buildNotesSection(),
                          const SizedBox(height: 12),
                        ],

                        // Hand Summary Stats
                        _buildHandSummaryCards(),

                        const SizedBox(height: 16),

                        // Hero Cards and Winner Info
                        _buildHeroCardsAndWinner(),

                        const SizedBox(height: 16),

                        // Street-by-street action table
                        _buildStreetByStreetTable(),

                        const SizedBox(height: 16),

                        // AI Analyzer Button
                        _buildAIAnalyzerButton(),

                        // AI Analysis Results
                        if (_aiAnalysis != null) ...[
                          const SizedBox(height: 16),
                          _buildAIAnalysisResults(),
                        ],

                        // Analysis Error
                        if (_analysisError != null) ...[
                          const SizedBox(height: 16),
                          _buildAnalysisError(),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCardsAndWinner() {
    final ourHoleCardsData = widget.hand['ourHoleCards'];
    final showdownData = widget.hand['showdownData'];
    final playerNamesData = widget.hand['playerNames'];

    String? heroCard1;
    String? heroCard2;
    if (ourHoleCardsData != null && ourHoleCardsData is Map) {
      heroCard1 = ourHoleCardsData['card1'];
      heroCard2 = ourHoleCardsData['card2'];
    }

    Map<int, Map<String, String?>>? opponentCards;
    if (showdownData != null && showdownData is Map) {
      final playerCardsData = showdownData['playerCards'];
      if (playerCardsData != null && playerCardsData is Map) {
        opponentCards = {};
        playerCardsData.forEach((key, value) {
          if (value != null && value is Map) {
            final playerId = int.tryParse(key.toString());
            if (playerId != null) {
              opponentCards![playerId] = {
                'card1': value['card1'] as String?,
                'card2': value['card2'] as String?,
              };
            }
          }
        });
      }
    }

    final bool hasHeroCards = (heroCard1 != null || heroCard2 != null);
    final bool hasOpponentCards = opponentCards != null && opponentCards.isNotEmpty;

    if (!hasHeroCards && !hasOpponentCards) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        // Hero Cards
        if (hasHeroCards)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF131616),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF89F1EC).withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.style, color: const Color(0xFF89F1EC), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Your Cards',
                        style: GoogleFonts.ibmPlexSans(
                          color: const Color(0xFF89F1EC),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (heroCard1 != null) _buildCard(heroCard1),
                      if (heroCard1 != null && heroCard2 != null) const SizedBox(width: 8),
                      if (heroCard2 != null) _buildCard(heroCard2),
                    ],
                  ),
                ],
              ),
            ),
          ),

        if (hasHeroCards && hasOpponentCards)
          const SizedBox(width: 12),

        // Opponent Cards
        if (hasOpponentCards)
          Expanded(
            child: _buildOpponentCardsCard(opponentCards!, playerNamesData),
          ),
      ],
    );
  }

  Widget _buildOpponentCardsCard(Map<int, Map<String, String?>> opponentCards, dynamic playerNamesData) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131616),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people, color: Color(0xFF8B5CF6), size: 16),
              const SizedBox(width: 6),
              Text(
                'Opponent Cards',
                style: GoogleFonts.ibmPlexSans(
                  color: const Color(0xFF8B5CF6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...opponentCards.entries.map((entry) {
            final playerId = entry.key;
            final cards = entry.value;
            final card1 = cards['card1'];
            final card2 = cards['card2'];

            if (card1 == null || card2 == null) {
              return const SizedBox.shrink();
            }

            String? playerName;
            if (playerNamesData != null && playerNamesData is Map) {
              playerName = playerNamesData[playerId.toString()];
            }
            playerName ??= 'Player $playerId';

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      playerName,
                      style: GoogleFonts.ibmPlexSans(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildSmallCard(card1),
                  const SizedBox(width: 4),
                  _buildSmallCard(card2),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSmallCard(String card) {
    return Container(
      width: 24,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Center(
        child: Text(
          card,
          style: TextStyle(
            color: _getCardColor(card),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildHandSummaryCards() {
    final pot = widget.hand['potAmount'] ?? widget.hand['pot'] ?? 0;
    final smallBlind = widget.hand['smallBlind'] ?? 1;
    final bigBlind = widget.hand['bigBlind'] ?? 2;
    final gameTypeStr = widget.hand['gameType'] ?? 'cash';
    final gameType = GameTypeExtension.fromString(gameTypeStr);

    String potText = gameType == GameType.cash
        ? formatCompactCurrency(pot)
        : formatCompactNumber(pot);
    String blindsText = gameType == GameType.cash
        ? '${formatCompactCurrency(smallBlind)}/${formatCompactCurrency(bigBlind)}'
        : '${formatCompactNumber(smallBlind)}/${formatCompactNumber(bigBlind)}';
    String? winnerText = _getWinnerText();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131616),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(child: _buildCompactStat('POT', potText)),
          Container(width: 1, height: 32, color: Colors.white.withOpacity(0.1)),
          Expanded(child: _buildCompactStat('BLINDS', blindsText)),
          if (winnerText != null) ...[
            Container(width: 1, height: 32, color: Colors.white.withOpacity(0.1)),
            Expanded(child: _buildCompactStat('WINNER', winnerText, isWinner: true)),
          ],
        ],
      ),
    );
  }

  String? _getWinnerText() {
    final isChoppedPot = widget.hand['isChoppedPot'] == true;
    final winnerId = widget.hand['winnerId'];
    final choppedWinners = widget.hand['choppedWinners'] as List<dynamic>?;
    final playerNamesData = widget.hand['playerNames'];

    if (isChoppedPot && choppedWinners != null && choppedWinners.isNotEmpty) {
      if (choppedWinners.length <= 2) {
        List<String> names = choppedWinners.map((w) {
          if (playerNamesData is Map) {
            return (playerNamesData[w.toString()] ?? 'P$w') as String;
          }
          return 'P$w';
        }).toList();
        return names.join(', ');
      }
      return '${choppedWinners.length} players';
    } else if (winnerId != null) {
      if (playerNamesData is Map) {
        return playerNamesData[winnerId.toString()] ?? 'P$winnerId';
      }
      return 'P$winnerId';
    }
    return null;
  }

  Widget _buildCompactStat(String label, String value, {bool isWinner = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.ibmPlexSans(
            color: isWinner ? const Color(0xFFFFD700) : const Color(0xFF89F1EC),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTagsSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: _tags.map((tag) => _buildTagBadge(tag)).toList(),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF89F1EC).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
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
            size: 14,
            color: const Color(0xFF89F1EC),
          ),
          const SizedBox(width: 6),
          Text(
            tag,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              color: const Color(0xFF89F1EC),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131616),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.note, color: Colors.white.withOpacity(0.5), size: 18),
              const SizedBox(width: 8),
              Text(
                'Notes',
                style: GoogleFonts.ibmPlexSans(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _notes!,
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreetByStreetTable() {
    final actions = List<Map<String, dynamic>>.from(widget.hand['actions'] ?? []);
    final boardCardsData = widget.hand['boardCards'];
    final buttonPosition = widget.hand['buttonPosition'] ?? 1;
    final rawPlayerCount = (widget.hand['playerCount'] as int?) ?? 6;
    final playerCount = math.max(2, rawPlayerCount);
    final heroPosition = widget.ourSeat ?? widget.hand['heroPosition'];
    final playerNamesData = widget.hand['playerNames'];
    final winnerId = widget.hand['winnerId'];
    final gameTypeStr = widget.hand['gameType'] ?? 'cash';
    final gameType = GameTypeExtension.fromString(gameTypeStr);

    Map<String, String> playerNamesMap = {};
    if (playerNamesData != null && playerNamesData is Map) {
      playerNamesData.forEach((key, value) {
        playerNamesMap[key.toString()] = value.toString();
      });
    }

    List<String> flop = [];
    String? turn;
    String? river;
    if (boardCardsData != null && boardCardsData is Map) {
      flop = List<String>.from(boardCardsData['flop'] ?? []);
      turn = boardCardsData['turn'] as String?;
      river = boardCardsData['river'] as String?;
    }

    Map<String, List<Map<String, dynamic>>> actionsByStreet = {
      'preflop': [],
      'flop': [],
      'turn': [],
      'river': [],
    };

    for (final action in actions) {
      final street = action['street'] as String? ?? 'preflop';
      actionsByStreet[street]?.add(action);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Action Summary',
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        // Preflop
        if (actionsByStreet['preflop']!.isNotEmpty)
          _buildStreetSection('PREFLOP', null, actionsByStreet['preflop']!,
              buttonPosition, playerCount, heroPosition, playerNamesMap, winnerId, gameType.value, widget.hand['preflopPot']),

        _buildPostflopSections(widget.hand, flop, turn, river, actionsByStreet,
            buttonPosition, playerCount, heroPosition, playerNamesMap, winnerId, gameType),
      ],
    );
  }

  Widget _buildStreetSection(String streetName, List<String>? cards, List<Map<String, dynamic>> actions,
      int buttonPosition, int playerCount, int? heroPosition,
      Map<String, String> playerNamesMap, int? winnerId, String gameType, dynamic potAmount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF131616),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Street header with cards
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      streetName,
                      style: GoogleFonts.ibmPlexSans(
                        color: const Color(0xFF89F1EC),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    if (cards != null && cards.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      ...cards.map((card) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _buildCard(card),
                      )),
                    ],
                  ],
                ),
                // Pot amount
                if (potAmount != null && (potAmount as double) > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF89F1EC).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF89F1EC).withOpacity(0.3)),
                    ),
                    child: Text(
                      _formatPotAmount(potAmount as double, gameType),
                      style: GoogleFonts.ibmPlexSans(
                        color: const Color(0xFF89F1EC),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Action table
          _buildActionTable(actions, buttonPosition, playerCount, heroPosition, playerNamesMap, winnerId, gameType),
        ],
      ),
    );
  }

  Widget _buildActionTable(List<Map<String, dynamic>> actions, int buttonPosition, int playerCount,
      int? heroPosition, Map<String, String> playerNamesMap, int? winnerId, String gameType) {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.5),
          1: FlexColumnWidth(1.5),
          2: FlexColumnWidth(1.5),
          3: FlexColumnWidth(1),
        },
        children: [
          TableRow(
            children: [
              _buildTableHeader('PLAYER'),
              _buildTableHeader('STACK'),
              _buildTableHeader('ACTION'),
              _buildTableHeader('AMT'),
            ],
          ),
          ...actions.map((action) => _buildActionRow(
              action, buttonPosition, playerCount, heroPosition, playerNamesMap, winnerId, gameType
          )),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.ibmPlexSans(
          color: Colors.white.withOpacity(0.4),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  bool _isAllInAction(Map<String, dynamic> action) {
    final actionType = action['action'] as String?;
    final amount = action['amount'];
    final playerStack = action['playerStack'] ?? action['stack'];

    if (actionType == null || (actionType.toLowerCase() != 'raise' && actionType.toLowerCase() != 'bet')) {
      return false;
    }

    if (amount == null || playerStack == null) return false;

    final betAmount = (amount as num).toDouble();
    final stack = (playerStack as num).toDouble();

    return betAmount >= (stack - 0.01);
  }

  bool _isAllInSituation(Map<String, dynamic> hand) {
    final actions = hand['actions'] as List<dynamic>? ?? [];
    return actions.any((action) => _isAllInAction(action));
  }

  bool _hasPostflopActions(Map<String, dynamic> hand) {
    final actions = hand['actions'] as List<dynamic>? ?? [];
    return actions.any((action) =>
        action['street'] != null &&
            action['street'].toString().toLowerCase() != 'preflop'
    );
  }

  Widget _buildPostflopSections(
      Map<String, dynamic> hand,
      List<String> flop,
      String? turn,
      String? river,
      Map<String, List<Map<String, dynamic>>> actionsByStreet,
      int buttonPosition,
      int playerCount,
      int? heroPosition,
      Map<String, String> playerNamesMap,
      int? winnerId,
      GameType gameType,
      ) {
    final hasPostflopActions = _hasPostflopActions(hand);
    final isAllInSituation = _isAllInSituation(hand);

    if (isAllInSituation && !hasPostflopActions) {
      return _buildCombinedBoardSection(flop, turn, river, gameType);
    } else {
      return _buildStreetByStreetSections(
          flop, turn, river, actionsByStreet,
          buttonPosition, playerCount, heroPosition, playerNamesMap, winnerId, gameType
      );
    }
  }

  Widget _buildCombinedBoardSection(List<String> flop, String? turn, String? river, GameType gameType) {
    final allCards = <String>[];
    allCards.addAll(flop);
    if (turn != null && turn.isNotEmpty) allCards.add(turn);
    if (river != null && river.isNotEmpty) allCards.add(river);

    if (allCards.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF131616),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'BOARD',
                  style: GoogleFonts.ibmPlexSans(
                    color: const Color(0xFF89F1EC),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: allCards.map((card) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Text(
                  card,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _getCardColor(card),
                  ),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreetByStreetSections(
      List<String> flop,
      String? turn,
      String? river,
      Map<String, List<Map<String, dynamic>>> actionsByStreet,
      int buttonPosition,
      int playerCount,
      int? heroPosition,
      Map<String, String> playerNamesMap,
      int? winnerId,
      GameType gameType,
      ) {
    return Column(
      children: [
        if (flop.isNotEmpty)
          _buildStreetSection('FLOP', flop, actionsByStreet['flop']!,
              buttonPosition, playerCount, heroPosition, playerNamesMap, winnerId, gameType.value, widget.hand['flopPot']),

        if (turn != null && turn.isNotEmpty)
          _buildStreetSection('TURN', [turn], actionsByStreet['turn']!,
              buttonPosition, playerCount, heroPosition, playerNamesMap, winnerId, gameType.value, widget.hand['turnPot']),

        if (river != null && river.isNotEmpty)
          _buildStreetSection('RIVER', [river], actionsByStreet['river']!,
              buttonPosition, playerCount, heroPosition, playerNamesMap, winnerId, gameType.value, widget.hand['riverPot']),
      ],
    );
  }

  TableRow _buildActionRow(Map<String, dynamic> action, int buttonPosition, int playerCount,
      int? heroPosition, Map<String, String> playerNamesMap, int? winnerId, String gameType) {
    final playerSeat = action['player'] as int? ?? action['playerSeat'] as int? ?? 1;
    final actionType = action['action'] as String? ?? 'Unknown';
    final amount = action['amount'];
    final stack = action['playerStack'] ?? action['stack'] ?? 0;

    String playerName = playerNamesMap[playerSeat.toString()] ??
        action['playerName'] as String? ??
        'Player $playerSeat';

    final isHero = heroPosition != null && playerSeat == heroPosition;
    final isWinner = winnerId != null && playerSeat == winnerId;
    final positionName = action['playerPosition'] as String? ??
        PokerPositions.getPositionName(playerSeat, buttonPosition, playerCount);

    String playerDisplay = isHero ? 'You' : playerName;
    playerDisplay = '$playerDisplay ($positionName)';

    Color actionColor = Colors.white.withOpacity(0.5);
    switch (actionType.toLowerCase()) {
      case 'fold':
        actionColor = Colors.red;
        break;
      case 'call':
      case 'check':
        actionColor = const Color(0xFF89F1EC);
        break;
      case 'raise':
      case 'bet':
        actionColor = const Color(0xFFFF9500);
        break;
      case 'all in':
      case 'allin':
        actionColor = Colors.red;
        break;
    }

    return TableRow(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              if (isWinner)
                const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 12),
              if (isWinner) const SizedBox(width: 3),
              Expanded(
                child: Text(
                  playerDisplay,
                  style: GoogleFonts.ibmPlexSans(
                    color: isHero ? const Color(0xFF89F1EC) : Colors.white,
                    fontSize: 11,
                    fontWeight: isHero ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            _formatStack(stack, gameType),
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white.withOpacity(0.5),
              fontSize: 11,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            _isAllInAction(action) ? 'ALL IN' : actionType.toUpperCase(),
            style: GoogleFonts.ibmPlexSans(
              color: actionColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            _formatAmount(amount, gameType),
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white.withOpacity(0.5),
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(String? card) {
    if (card == null || card.isEmpty) return const SizedBox.shrink();

    final suit = card.length > 1 ? card.substring(1) : '';
    final rank = card.isNotEmpty ? card[0] : '';

    Color suitColor = Colors.white;
    if (suit == '♥' || suit == '♦') suitColor = Colors.red;

    return Container(
      width: 30,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            rank,
            style: TextStyle(
              color: suitColor == Colors.red ? Colors.red : Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            suit,
            style: TextStyle(
              color: suitColor == Colors.red ? Colors.red : Colors.black,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPotAmount(double amount, String gameType) {
    if (amount <= 0) return '';

    final isCashGame = gameType == 'cash';

    if (isCashGame) {
      return 'Pot: \$${amount.toStringAsFixed(2)}';
    } else {
      return 'Pot: ${amount.toInt()}';
    }
  }

  String _formatStack(dynamic stack, String gameType) {
    if (stack == null || (stack is num && stack <= 0)) return '-';

    final stackNum = (stack is num) ? stack.toDouble() : 0.0;
    final isCashGame = gameType == 'cash';

    if (isCashGame) {
      return formatCompactCurrency(stackNum);
    } else {
      return formatCompactNumber(stackNum);
    }
  }

  String _formatAmount(dynamic amount, String gameType) {
    if (amount == null) return '-';

    final amountNum = (amount is num) ? amount.toDouble() : 0.0;
    if (amountNum <= 0) return '-';

    final isCashGame = gameType == 'cash';

    if (isCashGame) {
      return formatCompactCurrency(amountNum);
    } else {
      return formatCompactNumber(amountNum);
    }
  }

  Color _getCardColor(String card) {
    if (card.contains('♥') || card.contains('♦')) {
      return Colors.red;
    }
    return Colors.black;
  }

  Widget _buildAIAnalyzerButton() {
    final ourHoleCards = widget.hand['ourHoleCards'] as Map<String, dynamic>?;
    final card1 = ourHoleCards?['card1'] as String?;
    final card2 = ourHoleCards?['card2'] as String?;
    final hasHeroCards = card1 != null && card2 != null && card1.isNotEmpty && card2.isNotEmpty;

    final isPremium = SubscriptionService.isPremium;

    Color buttonColor;
    Color textColor;
    if (!hasHeroCards) {
      buttonColor = Colors.white.withOpacity(0.1);
      textColor = Colors.white.withOpacity(0.3);
    } else if (!isPremium) {
      buttonColor = const Color(0xFF89F1EC);
      textColor = Colors.black;
    } else if (_aiAnalysis != null) {
      buttonColor = const Color(0xFF8B5CF6);
      textColor = Colors.white;
    } else {
      buttonColor = const Color(0xFF89F1EC);
      textColor = Colors.black;
    }

    return GestureDetector(
      onTap: (_isAnalyzing || !hasHeroCards) ? null : () => _handleAnalyzeButtonTap(isPremium),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(60),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isAnalyzing) ...[
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Analyzing Hand...',
                style: GoogleFonts.ibmPlexSans(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else if (!hasHeroCards) ...[
              Icon(Icons.block, color: textColor),
              const SizedBox(width: 12),
              Text(
                'Hero Cards Missing',
                style: GoogleFonts.ibmPlexSans(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else if (!isPremium) ...[
              Icon(Icons.lock_open, color: textColor),
              const SizedBox(width: 12),
              Text(
                'Unlock AI Analysis',
                style: GoogleFonts.ibmPlexSans(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else ...[
              Icon(
                _aiAnalysis != null ? Icons.refresh : Icons.psychology,
                color: textColor,
              ),
              const SizedBox(width: 12),
              Text(
                _aiAnalysis != null ? 'Re-analyze Hand' : 'AI Analyzer',
                style: GoogleFonts.ibmPlexSans(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleAnalyzeButtonTap(bool isPremium) async {
    if (isPremium) {
      _analyzeHand();
    } else {
      final purchased = await PaywallScreen.show(context, featureName: 'AI Hand Analysis');
      if (purchased == true && mounted) {
        setState(() {});
        _analyzeHand();
      }
    }
  }

  Widget _buildAnalysisError() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131616),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analysis Failed',
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _analysisError ?? 'Unknown error',
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIAnalysisResults() {
    if (_aiAnalysis == null) return const SizedBox.shrink();

    final correct = _aiAnalysis!['correct'] as bool? ?? false;
    final severity = _aiAnalysis!['severity'] as String? ?? 'unknown';
    final scenarioCovered = _aiAnalysis!['scenarioCovered'] as bool? ?? true;
    final gtoAnalysis = _aiAnalysis!['gtoAnalysis'] as Map<String, dynamic>?;
    final aiAnalysis = _aiAnalysis!['aiAnalysis'] as Map<String, dynamic>?;
    final processingTime = _aiAnalysis!['processingTimeMs'] as int? ?? 0;

    Color severityColor;
    IconData severityIcon;
    switch (severity.toLowerCase()) {
      case 'optimal':
        severityColor = const Color(0xFF89F1EC);
        severityIcon = Icons.check_circle;
        break;
      case 'minor':
        severityColor = const Color(0xFFFFD700);
        severityIcon = Icons.warning;
        break;
      case 'major':
        severityColor = Colors.orange;
        severityIcon = Icons.error;
        break;
      case 'critical':
        severityColor = Colors.red;
        severityIcon = Icons.dangerous;
        break;
      default:
        severityColor = Colors.white.withOpacity(0.5);
        severityIcon = Icons.help;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI Analysis',
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        // Overall Result
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF131616),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: severityColor.withOpacity(0.4)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: severityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(severityIcon, color: severityColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          correct ? 'Correct Play' : 'Mistake Detected',
                          style: GoogleFonts.ibmPlexSans(
                            color: severityColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Severity: ${severity.toUpperCase()}',
                          style: GoogleFonts.ibmPlexSans(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // AI Insights
        if (aiAnalysis != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF131616),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.psychology, color: Color(0xFF89F1EC), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AI Insights (Preflop Only)',
                        style: GoogleFonts.ibmPlexSans(
                          color: const Color(0xFF89F1EC),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (scenarioCovered && gtoAnalysis != null && gtoAnalysis['rangePercentile'] != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
                        ),
                        child: Text(
                          'Range: ${gtoAnalysis['rangePercentile']}%',
                          style: GoogleFonts.ibmPlexSans(
                            color: const Color(0xFF8B5CF6),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                if (aiAnalysis['reasoning'] != null) ...[
                  Text(
                    aiAnalysis['reasoning'],
                    style: GoogleFonts.ibmPlexSans(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (aiAnalysis['optimalAction'] != null) ...[
                  _buildHighlightedText('Optimal Play', aiAnalysis['optimalAction']),
                  const SizedBox(height: 12),
                ],
                if (aiAnalysis['exploitativeAdjustment'] != null) ...[
                  _buildHighlightedText('Exploitative Adjustment', aiAnalysis['exploitativeAdjustment']),
                  const SizedBox(height: 12),
                ],
                if (aiAnalysis['learningPoint'] != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb, color: Color(0xFFFFD700), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            aiAnalysis['learningPoint'],
                            style: GoogleFonts.ibmPlexSans(
                              color: const Color(0xFFFFD700),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        // Processing Time
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Analysis completed in ${(processingTime / 1000).toStringAsFixed(2)}s',
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightedText(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.ibmPlexSans(
            color: const Color(0xFF89F1EC),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white.withOpacity(0.5),
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
